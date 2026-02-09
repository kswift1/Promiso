/**
 * Widget Functions
 *
 * 위젯용 약속 데이터를 제공하는 Cloud Functions
 *
 * @architecture Direct Query 방식
 * - 위젯 갱신 시 Firestore 직접 쿼리
 * - 위젯 사용자만 API 호출 (스냅샷 방식 대비 효율적)
 *
 * @auth Widget Token (30일 유효) 또는 Firebase ID Token
 */
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {verifyWidgetToken, WIDGET_JWT_SECRET} from "./widgetToken";
import {
  WidgetSnapshotDocument,
  SnapshotPromise,
  MyVoteStatus,
} from "../types/api";

// MARK: - Default Empty Snapshot

const emptySnapshot: WidgetSnapshotDocument = {
  next: null,
  today: [],
  upcoming: [],
  meta: {
    todayCount: 0,
    upcomingCount: 0,
    updatedAt: new Date().toISOString(),
    version: 1,
  },
};

// MARK: - Main Functions

/**
 * 위젯용 약속 스냅샷 조회 (Firebase ID Token 인증)
 *
 * @description 캐시된 스냅샷 문서를 반환
 * @requires 인증 필수
 */
export const getWidgetSnapshot = onCall(
  {region: REGION},
  async (request): Promise<WidgetSnapshotDocument> => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }

    const userId = request.auth.uid;
    const snapshot = await fetchPromisesDirectly(userId);
    return snapshot;
  }
);

/**
 * 위젯용 약속 스냅샷 조회 (Widget Token 인증)
 *
 * @description Widget Extension에서 직접 호출하는 HTTP 엔드포인트
 * @auth Widget Token (30일 유효) - Authorization: Bearer <token>
 */
export const getWidgetSnapshotWithToken = onRequest(
  {
    region: REGION,
    secrets: [WIDGET_JWT_SECRET],
  },
  async (req, res) => {
    // iOS Widget Extension 전용 엔드포인트 - 브라우저 CORS 불필요
    // 보안: 브라우저에서의 접근 차단
    if (req.method === "OPTIONS") {
      res.status(403).json({error: "CORS not allowed"});
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed"});
      return;
    }

    // 1. Authorization 헤더 확인
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      res.status(401).json({error: "Missing or invalid Authorization header"});
      return;
    }

    const token = authHeader.split("Bearer ")[1];

    try {
      // 2. Widget Token 검증
      const secret = WIDGET_JWT_SECRET.value();
      const decoded = verifyWidgetToken(token, secret);

      // 3. deviceId 바인딩 검증
      const requestBody = req.body?.data || {};
      const requestDeviceId = requestBody.deviceId as string | undefined;
      if (requestDeviceId && decoded.deviceId !== requestDeviceId) {
        console.warn(
          `⚠️ deviceId mismatch: token=${decoded.deviceId}, ` +
          `request=${requestDeviceId}`
        );
        res.status(401).json({
          error: "Device mismatch",
          error_code: "DEVICE_MISMATCH",
        });
        return;
      }

      // 4. 토큰 버전 확인 (revocation 체크)
      const db = admin.firestore();
      const usersCollection = db.collection("users");
      const userDoc = await usersCollection.doc(decoded.sub).get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        const currentVersion = (userData?.widgetTokenVersion as number) || 1;
        if (decoded.version < currentVersion) {
          res.status(401).json({
            error: "Token revoked",
            error_code: "TOKEN_REVOKED",
          });
          return;
        }
      }

      // 4. 약속 직접 쿼리
      const snapshot = await fetchPromisesDirectly(decoded.sub);

      // 5. 응답
      res.status(200).json({result: snapshot});
    } catch (error) {
      if (error instanceof HttpsError) {
        const statusCode = error.code === "unauthenticated" ? 401 :
          error.code === "permission-denied" ? 403 : 500;
        res.status(statusCode).json({error: error.message});
        return;
      }

      console.error("❌ getWidgetSnapshotWithToken error:", error);
      res.status(500).json({error: "Internal server error"});
    }
  }
);

// MARK: - Helper Functions

/**
 * 오늘 날짜의 시작/끝 시간 계산 (KST 기준)
 * @return {{startOfDay: Date, endOfDay: Date}} 오늘의 시작/끝 시간
 */
function getTodayRange(): { startOfDay: Date; endOfDay: Date } {
  const now = new Date();
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

/**
 * 사용자의 투표 상태 계산
 * @param {string} userId - 사용자 ID
 * @param {object} votes - 투표 정보
 * @return {MyVoteStatus} 투표 상태
 */
function getMyVoteStatus(
  userId: string,
  votes: { accepted?: string[]; declined?: string[] } | undefined
): MyVoteStatus {
  if (!votes) return "pending";
  if (votes.accepted?.includes(userId)) return "voted";
  if (votes.declined?.includes(userId)) return "declined";
  return "pending";
}

/**
 * Firestore Timestamp를 ISO 8601 문자열로 변환
 * @param {FirebaseFirestore.Timestamp} timestamp - Firestore 타임스탬프
 * @return {string | null} ISO 8601 문자열
 */
function toISOString(
  timestamp: FirebaseFirestore.Timestamp | undefined
): string | null {
  if (!timestamp) return null;
  return timestamp.toDate().toISOString();
}

/**
 * 약속 직접 쿼리
 *
 * @description Firestore에서 사용자 그룹의 약속을 직접 조회
 * @limit 위젯에 필요한 최소 데이터만 조회 (today 3개 + upcoming 4개 = 7개)
 *
 * @param {string} userId 사용자 ID
 * @return {Promise<WidgetSnapshotDocument>} 위젯 데이터
 */
async function fetchPromisesDirectly(
  userId: string
): Promise<WidgetSnapshotDocument> {
  const db = admin.firestore();
  const usersCollection = db.collection("users");
  const promisesCollection = db.collection("promises");

  // 1. 사용자 문서 조회 → 그룹 목록
  const userDoc = await usersCollection.doc(userId).get();
  if (!userDoc.exists) {
    console.log(`⚠️ [Widget] User not found: ${userId}`);
    return emptySnapshot;
  }

  const userData = userDoc.data();
  type UserGroupMap = {
    [key: string]: { name?: string; groupName?: string; imageUrl?: string }
  };
  const userGroups = userData?.groups as UserGroupMap | undefined;

  if (!userGroups || Object.keys(userGroups).length === 0) {
    console.log(`📦 [Widget] No groups for user: ${userId}`);
    return emptySnapshot;
  }

  const groupIds = Object.keys(userGroups);

  // 2. 그룹 정보 맵 생성
  const groupInfoMap: {
    [key: string]: { name: string; imageUrl: string | null }
  } = {};
  for (const groupId of groupIds) {
    const groupData = userGroups[groupId];
    groupInfoMap[groupId] = {
      name: groupData?.name || groupData?.groupName || "",
      imageUrl: groupData?.imageUrl || null,
    };
  }

  // 3. 약속 조회 (10개씩 청크, 최대 10개 결과)
  const now = new Date();
  const {startOfDay, endOfDay} = getTodayRange();

  // Firestore "in" 쿼리 최대 10개 제한
  const chunkedGroupIds: string[][] = [];
  for (let i = 0; i < groupIds.length; i += 10) {
    chunkedGroupIds.push(groupIds.slice(i, i + 10));
  }

  const allPromises: SnapshotPromise[] = [];

  for (const chunk of chunkedGroupIds) {
    const snapshot = await promisesCollection
      .where("groupId", "in", chunk)
      .where("isConfirmed", "==", true)
      .where("startAt", ">=", now)
      .orderBy("startAt", "asc")
      .limit(7) // 위젯 최대 표시 개수 (today 3 + upcoming 4)
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();

      const votes = data.votes as {
        accepted?: string[];
        declined?: string[];
        until?: FirebaseFirestore.Timestamp;
      } | undefined;

      const minimumParticipants = (data.minimumParticipants as number) || 2;
      const acceptedCount = votes?.accepted?.length || 0;
      const isConfirmed = acceptedCount >= minimumParticipants;

      // 재계산 결과 미확정인 약속은 위젯에서 제외
      if (!isConfirmed) continue;

      const myVoteStatus = getMyVoteStatus(userId, votes);

      const startAt = data.startAt as FirebaseFirestore.Timestamp;
      const endAt = data.endAt as FirebaseFirestore.Timestamp | undefined;
      const location = data.location as { name?: string } | undefined;
      const votingDeadline = votes?.until ?
        votes.until.toDate().toISOString() : null;

      allPromises.push({
        id: doc.id,
        title: (data.title as string) || "",
        emoji: (data.emoji as string) || "📅",
        startAt: startAt.toDate().toISOString(),
        endAt: toISOString(endAt),
        location: location?.name || null,
        groupId: data.groupId as string,
        groupName: groupInfoMap[data.groupId as string]?.name || null,
        groupImageUrl: groupInfoMap[data.groupId as string]?.imageUrl || null,
        isConfirmed,
        minimumParticipants,
        votes: {
          accepted: votes?.accepted || [],
          declined: votes?.declined || [],
        },
        myVoteStatus,
        votingDeadline,
      });
    }
  }

  // 4. 분류: today / upcoming (개인 일정 병합 전이므로 제한 없이 분류)
  const todayPromises: SnapshotPromise[] = [];
  const upcomingPromises: SnapshotPromise[] = [];

  for (const promise of allPromises) {
    const promiseDate = new Date(promise.startAt);

    if (promiseDate >= startOfDay && promiseDate < endOfDay) {
      todayPromises.push(promise);
    } else if (promiseDate >= endOfDay) {
      upcomingPromises.push(promise);
    }
  }

  // 5. 개인 일정 조회 → SnapshotPromise로 변환하여 통합
  const personalPromises: SnapshotPromise[] = [];
  try {
    const personalEventsRef = db
      .collection("users").doc(userId)
      .collection("personalEvents");
    const personalSnapshot = await personalEventsRef
      .where("startAt", ">=", now)
      .orderBy("startAt", "asc")
      .limit(5)
      .get();

    for (const doc of personalSnapshot.docs) {
      const data = doc.data();
      const peStartAt = data.startAt as FirebaseFirestore.Timestamp | undefined;
      const peEndAt = data.endAt as FirebaseFirestore.Timestamp | undefined;

      if (peStartAt) {
        personalPromises.push({
          type: "personal",
          id: doc.id,
          title: (data.title as string) || "",
          emoji: (data.emoji as string) || "📅",
          startAt: peStartAt.toDate().toISOString(),
          endAt: toISOString(peEndAt),
          location: (data.location as { name?: string })?.name || null,
          groupId: "",
          groupName: null,
          groupImageUrl: null,
          isConfirmed: true,
          minimumParticipants: 0,
          votes: {accepted: [], declined: []},
          myVoteStatus: "voted",
          votingDeadline: null,
        });
      }
    }
  } catch (error) {
    // 개인 일정 조회 실패 시 무시 (약속 데이터는 정상 반환)
    console.warn(
      "⚠️ [Widget] Personal events query failed:",
      error
    );
  }

  // 6. 개인 일정을 today/upcoming에 병합 후 정렬
  for (const pe of personalPromises) {
    const peDate = new Date(pe.startAt);
    if (peDate >= startOfDay && peDate < endOfDay) {
      todayPromises.push(pe);
    } else if (peDate >= endOfDay) {
      upcomingPromises.push(pe);
    }
  }

  // 시간순 재정렬 (개인 일정 병합 후)
  todayPromises.sort((a, b) =>
    new Date(a.startAt).getTime() - new Date(b.startAt).getTime()
  );
  upcomingPromises.sort((a, b) =>
    new Date(a.startAt).getTime() - new Date(b.startAt).getTime()
  );

  // today 3개, upcoming 4개로 제한
  const limitedToday = todayPromises.slice(0, 3);
  const limitedUpcoming = upcomingPromises.slice(0, 4);

  // 7. next = 첫 번째 일정 (today 우선, 없으면 upcoming)
  const nextPromise = limitedToday[0] || limitedUpcoming[0] || null;

  console.log(
    `📦 [Widget] Query: ${userId} ` +
    `(next=${nextPromise?.id ?? "null"}, ` +
    `today=${limitedToday.length}, upcoming=${limitedUpcoming.length}, ` +
    `personal=${personalPromises.length})`
  );

  return {
    next: nextPromise,
    today: limitedToday,
    upcoming: limitedUpcoming,
    meta: {
      todayCount: limitedToday.length,
      upcomingCount: limitedUpcoming.length,
      updatedAt: new Date().toISOString(),
      version: 1,
    },
  };
}
