/**
 * Widget Snapshot Functions
 *
 * 위젯용 약속 스냅샷을 제공하는 Cloud Functions
 *
 * @why 위젯은 네트워크 호출 불가 → 앱이 Functions에서 받아서 캐시에 저장
 * @returns 오늘/다가오는/다음 약속 + updatedAt (캐시 무효화용)
 */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";

// MARK: - Types

interface WidgetPromise {
  id: string;
  title: string;
  emoji: string;
  startAt: string; // ISO 8601
  endAt: string | null;
  location: string | null;
  groupId: string;
  groupName: string | null;
  isConfirmed: boolean;
  participantCount: number;
}

interface WidgetSnapshotResponse {
  next: WidgetPromise | null;
  today: WidgetPromise[];
  upcoming: WidgetPromise[];
  updatedAt: string; // ISO 8601
}

// MARK: - Helper Functions

/**
 * Firestore Timestamp를 ISO 8601 문자열로 변환
 *
 * @param {FirebaseFirestore.Timestamp | undefined} timestamp Firestore
 * @return {string | null} ISO 8601 문자열
 */
function toISOString(
  timestamp: FirebaseFirestore.Timestamp | undefined
): string | null {
  if (!timestamp) return null;
  return timestamp.toDate().toISOString();
}

/**
 * 오늘 날짜의 시작/끝 시간 계산 (KST 기준)
 *
 * @return {{startOfDay: Date, endOfDay: Date}} 오늘 시작/끝
 */
function getTodayRange(): { startOfDay: Date; endOfDay: Date } {
  const now = new Date();
  // KST 기준으로 오늘 시작 (00:00:00)
  const kstOffset = 9 * 60 * 60 * 1000;
  const kstNow = new Date(now.getTime() + kstOffset);
  const startOfDay = new Date(
    Date.UTC(
      kstNow.getUTCFullYear(),
      kstNow.getUTCMonth(),
      kstNow.getUTCDate()
    ) - kstOffset
  );
  const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);
  return {startOfDay, endOfDay};
}

// MARK: - Main Function

/**
 * 위젯용 약속 스냅샷 조회
 *
 * @description 사용자의 그룹에 속한 약속 중 위젯에 표시할 데이터를 반환
 * @requires 인증 필수
 *
 * @returns {WidgetSnapshotResponse}
 * - next: 가장 가까운 다음 약속 (1개)
 * - today: 오늘 약속 (최대 3개)
 * - upcoming: 다가오는 약속 (최대 5개, 오늘 제외)
 * - updatedAt: 스냅샷 생성 시각 (캐시 무효화용)
 */
export const getWidgetSnapshot = onCall(
  {region: REGION},
  async (request): Promise<WidgetSnapshotResponse> => {
    // 인증 확인
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const userId = request.auth.uid;
    const db = admin.firestore();
    // 클라이언트에서 전달받은 환경 사용 (stage 또는 prod)
    const requestedEnv = request.data?.env as string | undefined;
    const env = requestedEnv === "stage" ? "stage" : "prod";

    const usersCollection = getEnvironmentCollection("users", db, env);
    const promisesCollection = getEnvironmentCollection("promises", db, env);

    // 1. 사용자의 그룹 ID 목록 조회
    const userDoc = await usersCollection.doc(userId).get();
    if (!userDoc.exists) {
      return {
        next: null,
        today: [],
        upcoming: [],
        updatedAt: new Date().toISOString(),
      };
    }

    const userData = userDoc.data();
    type UserGroupMap = { [key: string]: { name?: string } };
    const userGroups = userData?.groups as UserGroupMap | undefined;

    if (!userGroups || Object.keys(userGroups).length === 0) {
      return {
        next: null,
        today: [],
        upcoming: [],
        updatedAt: new Date().toISOString(),
      };
    }

    const groupIds = Object.keys(userGroups);

    // 2. 그룹 이름 맵 생성
    const groupNameMap: { [key: string]: string } = {};
    for (const groupId of groupIds) {
      if (userGroups[groupId]?.name) {
        groupNameMap[groupId] = userGroups[groupId].name as string;
      }
    }

    // 3. 약속 조회 (현재 시간 이후, 확정된 약속만)
    const now = new Date();
    const {startOfDay, endOfDay} = getTodayRange();

    // Firestore는 array-contains-any 최대 30개 제한
    const chunkedGroupIds: string[][] = [];
    for (let i = 0; i < groupIds.length; i += 10) {
      chunkedGroupIds.push(groupIds.slice(i, i + 10));
    }

    const allPromises: WidgetPromise[] = [];

    for (const chunk of chunkedGroupIds) {
      const snapshot = await promisesCollection
        .where("groupId", "in", chunk)
        .where("startAt", ">=", now)
        .orderBy("startAt", "asc")
        .limit(20)
        .get();

      for (const doc of snapshot.docs) {
        const data = doc.data();

        // 확정된 약속만 포함
        const votes = data.votes as {
          accepted?: string[];
        } | undefined;
        const minimumParticipants = (data.minimumParticipants as number) || 2;
        const acceptedCount = votes?.accepted?.length || 0;
        const isConfirmed = acceptedCount >= minimumParticipants;

        if (!isConfirmed) continue;

        const startAt = data.startAt as FirebaseFirestore.Timestamp;
        const endAt = data.endAt as FirebaseFirestore.Timestamp | undefined;
        const location = data.location as { name?: string } | undefined;

        allPromises.push({
          id: doc.id,
          title: (data.title as string) || "",
          emoji: (data.emoji as string) || "📅",
          startAt: startAt.toDate().toISOString(),
          endAt: toISOString(endAt),
          location: location?.name || null,
          groupId: data.groupId as string,
          groupName: groupNameMap[data.groupId as string] || null,
          isConfirmed: true,
          participantCount: acceptedCount,
        });
      }
    }

    // 4. 정렬 (startAt 기준 오름차순) - 이미 정렬됨
    // 5. 분류: next, today, upcoming
    const todayPromises: WidgetPromise[] = [];
    const upcomingPromises: WidgetPromise[] = [];

    for (const promise of allPromises) {
      const promiseDate = new Date(promise.startAt);

      if (promiseDate >= startOfDay && promiseDate < endOfDay) {
        if (todayPromises.length < 3) {
          todayPromises.push(promise);
        }
      } else if (promiseDate >= endOfDay) {
        if (upcomingPromises.length < 5) {
          upcomingPromises.push(promise);
        }
      }
    }

    // next: 현재 시간 이후 가장 가까운 약속
    const nextPromise = allPromises.length > 0 ? allPromises[0] : null;

    console.log(`📊 Widget: user=${userId}, groups=${groupIds.length}`);
    console.log(
      `📊 Widget: all=${allPromises.length}, ` +
      `today=${todayPromises.length}, upcoming=${upcomingPromises.length}`
    );

    return {
      next: nextPromise,
      today: todayPromises,
      upcoming: upcomingPromises,
      updatedAt: new Date().toISOString(),
    };
  }
);
