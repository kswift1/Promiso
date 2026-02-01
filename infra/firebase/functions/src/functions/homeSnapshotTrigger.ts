/**
 * Home Snapshot Trigger Functions
 *
 * Firestore Trigger 기반 홈화면 스냅샷 자동 갱신
 *
 * @why 홈화면에서 N개 그룹 × M개 약속 읽기 → 1회 읽기로 비용 절감
 *
 * @triggers
 * - onPromiseWriteUpdateHomeSnapshot: 약속 생성/수정/삭제 시
 * - scheduledHomeSnapshotRefresh: 매일 자정 (KST)
 */
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {
  SnapshotPromise,
  HomeSnapshotDocument,
  HomeSnapshotGroup,
  MyVoteStatus,
} from "../types/api";

// MARK: - Helper Functions

/**
 * Firestore Timestamp를 ISO 8601 문자열로 변환
 *
 * @param {FirebaseFirestore.Timestamp | undefined} timestamp 타임스탬프
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
 * 사용자의 홈 스냅샷 갱신
 *
 * @description 그룹 약속을 조회해서 분류 후 homeSnapshot 문서에 저장
 *
 * @param {string} userId 사용자 ID
 * @param {string} env 환경 (stage | prod)
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @return {Promise<void>} 없음
 */
export async function updateHomeSnapshot(
  userId: string,
  env: string,
  db: FirebaseFirestore.Firestore
): Promise<void> {
  const usersCollection = getEnvironmentCollection("users", db, env);
  const promisesCollection = getEnvironmentCollection("promises", db, env);

  // 1. 사용자 문서 조회
  const userDoc = await usersCollection.doc(userId).get();
  if (!userDoc.exists) {
    console.log(`⚠️ [HomeSnapshot] User not found: ${userId}`);
    return;
  }

  const userData = userDoc.data();
  type UserGroupMap = {
    [key: string]: { name?: string; groupName?: string; imageUrl?: string }
  };
  const userGroups = userData?.groups as UserGroupMap | undefined;

  // 빈 스냅샷 저장
  const emptySnapshot: HomeSnapshotDocument = {
    todayPromises: [],
    pendingPromises: [],
    upcomingPromises: [],
    groups: [],
    meta: {
      todayCount: 0,
      pendingCount: 0,
      upcomingCount: 0,
      updatedAt: new Date().toISOString(),
      version: 1,
    },
  };

  if (!userGroups || Object.keys(userGroups).length === 0) {
    await usersCollection.doc(userId).collection("cache").doc("homeSnapshot")
      .set(emptySnapshot);
    console.log(`📦 [HomeSnapshot] Empty snapshot saved: ${userId}`);
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

  // 3. 약속 조회 (현재 시간 이후)
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
      .limit(100)
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
        participantCount: acceptedCount,
        myVoteStatus,
        votingDeadline,
      });
    }
  }

  // 4. 분류: today, pending, upcoming
  const todayPromises: SnapshotPromise[] = [];
  const pendingPromises: SnapshotPromise[] = [];
  const upcomingPromises: SnapshotPromise[] = [];

  for (const promise of allPromises) {
    const promiseDate = new Date(promise.startAt);
    const isToday = promiseDate >= startOfDay && promiseDate < endOfDay;
    const votingDeadline = promise.votingDeadline ?
      new Date(promise.votingDeadline) : null;
    const isVotingOpen = votingDeadline ? votingDeadline > now : true;

    // 오늘 확정 약속
    if (isToday && promise.isConfirmed && todayPromises.length < 5) {
      todayPromises.push(promise);
    }

    // 응답 필요 약속 (pending + 투표 마감 전)
    if (promise.myVoteStatus === "pending" &&
        isVotingOpen &&
        pendingPromises.length < 5) {
      pendingPromises.push(promise);
    }

    // 다가오는 약속 (오늘 이후 + 확정)
    if (promiseDate >= endOfDay &&
        promise.isConfirmed &&
        upcomingPromises.length < 10) {
      upcomingPromises.push(promise);
    }
  }

  // pending은 마감 임박순으로 정렬
  pendingPromises.sort((a, b) => {
    const aDeadline = a.votingDeadline ?
      new Date(a.votingDeadline).getTime() : Infinity;
    const bDeadline = b.votingDeadline ?
      new Date(b.votingDeadline).getTime() : Infinity;
    return aDeadline - bDeadline;
  });

  // 5. 그룹별 요약 생성
  const groupNextPromiseMap: { [key: string]: SnapshotPromise | null } = {};
  for (const groupId of groupIds) {
    groupNextPromiseMap[groupId] = null;
  }

  // 시간순 정렬된 약속에서 각 그룹의 첫 번째 약속 찾기
  const sortedByTime = [...allPromises].sort(
    (a, b) => new Date(a.startAt).getTime() - new Date(b.startAt).getTime()
  );

  for (const promise of sortedByTime) {
    if (groupNextPromiseMap[promise.groupId] === null) {
      groupNextPromiseMap[promise.groupId] = promise;
    }
  }

  const groups: HomeSnapshotGroup[] = groupIds.map((groupId) => ({
    id: groupId,
    name: groupInfoMap[groupId]?.name || "",
    emoji: null,
    imageUrl: groupInfoMap[groupId]?.imageUrl || null,
    nextPromise: groupNextPromiseMap[groupId],
  }));

  // 6. 스냅샷 저장
  const snapshotDoc: HomeSnapshotDocument = {
    todayPromises,
    pendingPromises,
    upcomingPromises,
    groups,
    meta: {
      todayCount: todayPromises.length,
      pendingCount: pendingPromises.length,
      upcomingCount: upcomingPromises.length,
      updatedAt: new Date().toISOString(),
      version: 1,
    },
  };

  await usersCollection.doc(userId).collection("cache").doc("homeSnapshot")
    .set(snapshotDoc);

  console.log(
    `📦 [HomeSnapshot] Updated: ${userId} ` +
    `(today=${todayPromises.length}, pending=${pendingPromises.length}, ` +
    `upcoming=${upcomingPromises.length}, groups=${groups.length})`
  );
}

// MARK: - Firestore Triggers

/**
 * 약속 문서 변경 시 관련 사용자의 홈 스냅샷 갱신
 *
 * @triggers promises/{promiseId} 생성/수정/삭제
 */
export const onPromiseWriteUpdateHomeSnapshot = onDocumentWritten(
  {
    region: REGION,
    document: "stage/promises/{promiseId}",
  },
  async (event) => {
    const db = admin.firestore();
    const env = "stage";

    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    const affectedGroupIds = new Set<string>();
    if (before?.groupId) affectedGroupIds.add(before.groupId as string);
    if (after?.groupId) affectedGroupIds.add(after.groupId as string);

    if (affectedGroupIds.size === 0) {
      console.log("⚠️ [HomeSnapshot] No groupId found, skipping");
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
      `🔄 [HomeSnapshot] Updating ${affectedUserIds.size} users ` +
      `for groups: ${Array.from(affectedGroupIds).join(", ")}`
    );

    const userIds = Array.from(affectedUserIds);
    const batchSize = 10;

    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      await Promise.all(
        batch.map((uid) => updateHomeSnapshot(uid, env, db))
      );
    }

    console.log(`✅ [HomeSnapshot] Updated ${userIds.length} users`);
  }
);

/**
 * Production 환경용 트리거
 */
export const onPromiseWriteUpdateHomeSnapshotProd = onDocumentWritten(
  {
    region: REGION,
    document: "prod/promises/{promiseId}",
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
      console.log("⚠️ [HomeSnapshot] No groupId found, skipping");
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
      `🔄 [HomeSnapshot] Updating ${affectedUserIds.size} users ` +
      `for groups: ${Array.from(affectedGroupIds).join(", ")}`
    );

    const userIds = Array.from(affectedUserIds);
    const batchSize = 10;

    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      await Promise.all(
        batch.map((uid) => updateHomeSnapshot(uid, env, db))
      );
    }

    console.log(`✅ [HomeSnapshot] Updated ${userIds.length} users`);
  }
);

// MARK: - Scheduled Tasks

/**
 * 매일 자정 (KST) 전체 사용자 홈 스냅샷 갱신
 *
 * @why 날짜 변경 시 today/upcoming 분류가 바뀜
 * @schedule 00:05 KST = 15:05 UTC (전날) - Widget보다 5분 늦게
 */
export const scheduledHomeSnapshotRefresh = onSchedule(
  {
    region: REGION,
    schedule: "5 15 * * *", // 15:05 UTC = 00:05 KST
    timeZone: "UTC",
  },
  async () => {
    console.log("🕛 [HomeSnapshot] Starting daily refresh...");

    const db = admin.firestore();

    await refreshAllHomeSnapshots(db, "stage");
    await refreshAllHomeSnapshots(db, "prod");

    console.log("✅ [HomeSnapshot] Daily refresh completed");
  }
);

/**
 * 특정 환경의 모든 사용자 홈 스냅샷 갱신
 *
 * @param {FirebaseFirestore.Firestore} db Firestore 인스턴스
 * @param {string} env 환경 (stage | prod)
 * @return {Promise<void>} 없음
 */
async function refreshAllHomeSnapshots(
  db: FirebaseFirestore.Firestore,
  env: string
): Promise<void> {
  const usersCollection = getEnvironmentCollection("users", db, env);

  const usersSnapshot = await usersCollection
    .where("groups", "!=", null)
    .limit(1000)
    .get();

  const userIds = usersSnapshot.docs.map((doc) => doc.id);
  console.log(`📊 [HomeSnapshot] ${env}: ${userIds.length} users to refresh`);

  const batchSize = 10;
  for (let i = 0; i < userIds.length; i += batchSize) {
    const batch = userIds.slice(i, i + batchSize);
    await Promise.all(
      batch.map((uid) => updateHomeSnapshot(uid, env, db))
    );
  }

  console.log(`✅ [HomeSnapshot] ${env}: Refreshed ${userIds.length} users`);
}
