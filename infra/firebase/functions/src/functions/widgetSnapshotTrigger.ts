/**
 * Widget Snapshot Trigger Functions
 *
 * Firestore Trigger 기반 위젯 스냅샷 자동 갱신
 *
 * @why 위젯에서 API 호출 시 Race Condition 발생
 *      → 서버에서 미리 스냅샷 저장 → 위젯은 읽기만
 *
 * @triggers
 * - onPromiseWrite: 약속 생성/수정/삭제 시
 * - scheduledSnapshotRefresh: 매일 자정 (KST)
 */
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {
  SnapshotPromise,
  WidgetSnapshotDocument,
  MyVoteStatus,
} from "../types/api";

// MARK: - Helper Functions

/**
 * Firestore Timestamp를 ISO 8601 문자열로 변환
 *
 * @param {FirebaseFirestore.Timestamp | undefined} timestamp Firestore 타임스탬프
 * @return {string | null} ISO 8601 문자열 또는 null
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
 * @return {object} 오늘 시작/끝 시간 (startOfDay, endOfDay)
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
 *
 * @param {string} userId 사용자 ID
 * @param {object|undefined} votes 투표 데이터
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

// MARK: - Core Function

/**
 * 사용자의 위젯 스냅샷 갱신
 *
 * @description 그룹 약속을 조회해서 정렬 후 widgetSnapshot 문서에 저장
 *
 * @priority 정렬 우선순위:
 * 1. myVoteStatus === "pending" (투표 필요)
 * 2. isConfirmed === false (미확정)
 * 3. startAt 오름차순 (시간순)
 *
 * @param {string} userId 사용자 ID
 * @param {string} env 환경 (stage | prod)
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @return {Promise<void>} 없음
 */
export async function updateWidgetSnapshot(
  userId: string,
  env: string,
  db: FirebaseFirestore.Firestore
): Promise<void> {
  const usersCollection = getEnvironmentCollection("users", db, env);
  const promisesCollection = getEnvironmentCollection("promises", db, env);
  const groupsCollection = getEnvironmentCollection("groups", db, env);

  // 1. 사용자 문서 조회
  const userDoc = await usersCollection.doc(userId).get();
  if (!userDoc.exists) {
    console.log(`⚠️ [WidgetSnapshot] User not found: ${userId}`);
    return;
  }

  const userData = userDoc.data();
  type UserGroupMap = {
    [key: string]: { name?: string; groupName?: string; imageUrl?: string }
  };
  const userGroups = userData?.groups as UserGroupMap | undefined;

  // 빈 스냅샷 저장
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

  if (!userGroups || Object.keys(userGroups).length === 0) {
    await usersCollection.doc(userId).collection("cache").doc("widgetSnapshot")
      .set(emptySnapshot);
    console.log(`📦 [WidgetSnapshot] Empty snapshot saved: ${userId}`);
    return;
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

  // 3. 그룹별 멤버 수 조회 (확정 여부 판단용)
  const groupMemberCountMap: { [key: string]: number } = {};
  for (const groupId of groupIds) {
    const groupDoc = await groupsCollection.doc(groupId).get();
    if (groupDoc.exists) {
      const groupData = groupDoc.data();
      const memberIds = (groupData?.memberIds as string[]) || [];
      groupMemberCountMap[groupId] = memberIds.length;
    }
  }

  // 4. 약속 조회 (현재 시간 이후)
  const now = new Date();
  const {startOfDay, endOfDay} = getTodayRange();

  // Firestore는 "in" 쿼리 최대 30개 제한 → 10개씩 분할
  const chunkedGroupIds: string[][] = [];
  for (let i = 0; i < groupIds.length; i += 10) {
    chunkedGroupIds.push(groupIds.slice(i, i + 10));
  }

  const allPromises: SnapshotPromise[] = [];

  for (const chunk of chunkedGroupIds) {
    const snapshot = await promisesCollection
      .where("groupId", "in", chunk)
      .where("startAt", ">=", now)
      .orderBy("startAt", "asc")
      .limit(50)
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

  // 5. 우선순위 정렬
  // 1순위: 투표 필요 (pending)
  // 2순위: 미확정 (isConfirmed = false)
  // 3순위: 시간순 (startAt)
  allPromises.sort((a, b) => {
    // pending 우선
    const aPending = a.myVoteStatus === "pending" ? 0 : 1;
    const bPending = b.myVoteStatus === "pending" ? 0 : 1;
    if (aPending !== bPending) return aPending - bPending;

    // 미확정 우선
    const aConfirmed = a.isConfirmed ? 1 : 0;
    const bConfirmed = b.isConfirmed ? 1 : 0;
    if (aConfirmed !== bConfirmed) return aConfirmed - bConfirmed;

    // 시간순
    return new Date(a.startAt).getTime() - new Date(b.startAt).getTime();
  });

  // 6. 분류: next, today, upcoming
  const nextPromise = allPromises.length > 0 ? allPromises[0] : null;

  const todayPromises: SnapshotPromise[] = [];
  const upcomingPromises: SnapshotPromise[] = [];

  for (const promise of allPromises) {
    const promiseDate = new Date(promise.startAt);

    if (promiseDate >= startOfDay && promiseDate < endOfDay) {
      if (todayPromises.length < 5) {
        todayPromises.push(promise);
      }
    } else if (promiseDate >= endOfDay) {
      if (upcomingPromises.length < 7) {
        upcomingPromises.push(promise);
      }
    }
  }

  // 7. 스냅샷 저장
  const snapshotDoc: WidgetSnapshotDocument = {
    next: nextPromise,
    today: todayPromises,
    upcoming: upcomingPromises,
    meta: {
      todayCount: todayPromises.length,
      upcomingCount: upcomingPromises.length,
      updatedAt: new Date().toISOString(),
      version: 1,
    },
  };

  await usersCollection.doc(userId).collection("cache").doc("widgetSnapshot")
    .set(snapshotDoc);

  console.log(
    `📦 [WidgetSnapshot] Updated: ${userId} ` +
    `(next=${nextPromise?.id ?? "null"}, ` +
    `today=${todayPromises.length}, upcoming=${upcomingPromises.length})`
  );
}

// MARK: - Firestore Triggers

/**
 * 약속 문서 변경 시 관련 사용자의 스냅샷 갱신
 *
 * @triggers promises/{promiseId} 생성/수정/삭제
 *
 * @logic
 * 1. 약속의 groupId로 그룹 멤버 조회
 * 2. 각 멤버의 widgetSnapshot 갱신
 */
export const onPromiseWriteUpdateSnapshot = onDocumentWritten(
  {
    region: REGION,
    document: "stage/root/promises/{promiseId}",
  },
  async (event) => {
    const db = admin.firestore();
    const env = "stage";

    // 변경 전/후 데이터
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // 영향받는 그룹 ID 수집
    const affectedGroupIds = new Set<string>();
    if (before?.groupId) affectedGroupIds.add(before.groupId as string);
    if (after?.groupId) affectedGroupIds.add(after.groupId as string);

    if (affectedGroupIds.size === 0) {
      console.log("⚠️ [WidgetSnapshot] No groupId found, skipping");
      return;
    }

    // 각 그룹의 멤버들 스냅샷 갱신
    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const affectedUserIds = new Set<string>();

    for (const groupId of affectedGroupIds) {
      const groupDoc = await groupsCollection.doc(groupId).get();
      if (groupDoc.exists) {
        const memberIds = (groupDoc.data()?.memberIds as string[]) || [];
        memberIds.forEach((uid) => affectedUserIds.add(uid));
      }
    }

    console.log(
      `🔄 [WidgetSnapshot] Updating ${affectedUserIds.size} users ` +
      `for groups: ${Array.from(affectedGroupIds).join(", ")}`
    );

    // 병렬로 스냅샷 갱신 (최대 10개씩)
    const userIds = Array.from(affectedUserIds);
    const batchSize = 10;

    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      await Promise.all(
        batch.map((uid) => updateWidgetSnapshot(uid, env, db))
      );
    }

    console.log(`✅ [WidgetSnapshot] Updated ${userIds.length} users`);
  }
);

/**
 * Production 환경용 트리거
 */
export const onPromiseWriteUpdateSnapshotProd = onDocumentWritten(
  {
    region: REGION,
    document: "prod/root/promises/{promiseId}",
  },
  async (event) => {
    const db = admin.firestore();
    const env = "prod";

    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    const affectedGroupIds = new Set<string>();
    if (before?.groupId) affectedGroupIds.add(before.groupId as string);
    if (after?.groupId) affectedGroupIds.add(after.groupId as string);

    if (affectedGroupIds.size === 0) {
      console.log("⚠️ [WidgetSnapshot] No groupId found, skipping");
      return;
    }

    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const affectedUserIds = new Set<string>();

    for (const groupId of affectedGroupIds) {
      const groupDoc = await groupsCollection.doc(groupId).get();
      if (groupDoc.exists) {
        const memberIds = (groupDoc.data()?.memberIds as string[]) || [];
        memberIds.forEach((uid) => affectedUserIds.add(uid));
      }
    }

    console.log(
      `🔄 [WidgetSnapshot] Updating ${affectedUserIds.size} users ` +
      `for groups: ${Array.from(affectedGroupIds).join(", ")}`
    );

    const userIds = Array.from(affectedUserIds);
    const batchSize = 10;

    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      await Promise.all(
        batch.map((uid) => updateWidgetSnapshot(uid, env, db))
      );
    }

    console.log(`✅ [WidgetSnapshot] Updated ${userIds.length} users`);
  }
);

// MARK: - Scheduled Tasks

/**
 * 매일 자정 (KST) 전체 사용자 스냅샷 갱신
 *
 * @why 날짜 변경 시 today/upcoming 분류가 바뀜
 * @schedule 00:00 KST = 15:00 UTC (전날)
 */
export const scheduledSnapshotRefresh = onSchedule(
  {
    region: REGION,
    schedule: "0 15 * * *", // 15:00 UTC = 00:00 KST
    timeZone: "UTC",
  },
  async () => {
    console.log("🕛 [WidgetSnapshot] Starting daily refresh...");

    const db = admin.firestore();

    // Stage 환경
    await refreshAllUserSnapshots(db, "stage");

    // Prod 환경
    await refreshAllUserSnapshots(db, "prod");

    console.log("✅ [WidgetSnapshot] Daily refresh completed");
  }
);

/**
 * 특정 환경의 모든 사용자 스냅샷 갱신
 *
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @param {string} env 환경 (stage | prod)
 * @return {Promise<void>} 없음
 */
async function refreshAllUserSnapshots(
  db: FirebaseFirestore.Firestore,
  env: string
): Promise<void> {
  const usersCollection = getEnvironmentCollection("users", db, env);

  // 그룹이 있는 사용자만 조회 (스냅샷 갱신 대상)
  const usersSnapshot = await usersCollection
    .where("groups", "!=", null)
    .limit(1000)
    .get();

  const userIds = usersSnapshot.docs.map((doc) => doc.id);
  console.log(`📊 [WidgetSnapshot] ${env}: ${userIds.length} users to refresh`);

  // 10명씩 병렬 처리
  const batchSize = 10;
  for (let i = 0; i < userIds.length; i += batchSize) {
    const batch = userIds.slice(i, i + batchSize);
    await Promise.all(
      batch.map((uid) => updateWidgetSnapshot(uid, env, db))
    );
  }

  console.log(`✅ [WidgetSnapshot] ${env}: Refreshed ${userIds.length} users`);
}
