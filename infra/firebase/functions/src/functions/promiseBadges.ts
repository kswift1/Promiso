/**
 * Promise Badge Functions
 *
 * 미응답 배지(needResponseCount) 관리를 위한 Cloud Functions
 *
 * @why 그룹 탭에서 미응답 약속 수를 실시간으로 표시하기 위해 비정규화 카운트 사용
 * @ios GroupMainView - 그룹 가로 바의 배지 표시
 *
 * @triggers
 * - onPromiseCreatedBadges: 약속 생성 시 미응답자 +1
 * - onPromiseDeletedBadges: 약속 삭제 시 미응답자 -1
 * - onPromiseVotesUpdatedBadges: 투표 변경 시 카운트 조정
 * - cleanupExpiredPromiseBadges: 마감된 약속 배지 정리 (1시간마다)
 */
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";

/**
 * 약속 생성 시 미응답자 배지 증가
 *
 * @remarks
 * promises/{promiseId} 문서가 생성되면 트리거됩니다.
 * - 그룹 멤버 중 votes.accepted/declined에 없는 유저 = 미응답자
 * - 미응답자들의 groups[groupId].needResponseCount += 1
 */
export const onPromiseCreatedBadges = onDocumentCreated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("[onPromiseCreatedBadges] No data");
      return;
    }

    const promiseData = snapshot.data();
    const promiseId = event.params.promiseId;
    const env = event.params.env;

    const groupId = promiseData.groupId;
    if (typeof groupId !== "string" || !groupId) {
      console.error(
        `[onPromiseCreatedBadges] Invalid groupId for ${promiseId}`
      );
      return;
    }

    const votes = promiseData.votes || {accepted: [], declined: []};
    const accepted = (votes.accepted as string[]) ?? [];
    const declined = (votes.declined as string[]) ?? [];

    console.log(
      `[onPromiseCreatedBadges] Promise ${promiseId} created in ${groupId}`
    );

    // 그룹 멤버 조회
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const groupDoc = await groupsCollection.doc(groupId).get();

    if (!groupDoc.exists) {
      console.error(`[onPromiseCreatedBadges] Group ${groupId} not found`);
      return;
    }

    const memberIds = (groupDoc.data()?.memberIds as string[]) ?? [];

    // 미응답자 필터링 (accepted/declined에 없는 유저)
    const needResponseUsers = memberIds.filter(
      (id) => !accepted.includes(id) && !declined.includes(id)
    );

    if (needResponseUsers.length === 0) {
      console.log("[onPromiseCreatedBadges] No users need to respond");
      return;
    }

    // 배치로 각 유저의 needResponseCount 증가
    const usersCollection = getEnvironmentCollection("users", db, env);
    const batch = db.batch();

    for (const userId of needResponseUsers) {
      const userRef = usersCollection.doc(userId);
      batch.update(userRef, {
        [`groups.${groupId}.needResponseCount`]: FieldValue.increment(1),
      });
    }

    await batch.commit();
    console.log(
      `[onPromiseCreatedBadges] ${needResponseUsers.length} users badge +1`
    );
  }
);

/**
 * 약속 삭제 시 미응답자 배지 감소
 *
 * @remarks
 * promises/{promiseId} 문서가 삭제되면 트리거됩니다.
 * - 삭제 시점에 미응답이었던 유저들의 needResponseCount -= 1
 */
export const onPromiseDeletedBadges = onDocumentDeleted(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("[onPromiseDeletedBadges] No data associated with the event");
      return;
    }

    const promiseData = snapshot.data();
    const promiseId = event.params.promiseId;
    const env = event.params.env;

    const groupId = promiseData.groupId as string;
    const votes = promiseData.votes || {accepted: [], declined: []};
    const accepted = (votes.accepted as string[]) ?? [];
    const declined = (votes.declined as string[]) ?? [];

    // 이미 마감 처리된 약속은 스킵
    if (promiseData.badgesCleared === true) {
      console.log(
        `[onPromiseDeletedBadges] Promise ${promiseId} already cleared`
      );
      return;
    }

    console.log(
      `[onPromiseDeletedBadges] Promise ${promiseId} deleted from ${groupId}`
    );

    // 그룹 멤버 조회
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const groupDoc = await groupsCollection.doc(groupId).get();

    if (!groupDoc.exists) {
      console.log(
        `[onPromiseDeletedBadges] Group ${groupId} not found (deleted?)`
      );
      return;
    }

    const memberIds = (groupDoc.data()?.memberIds as string[]) ?? [];

    // 삭제 시점에 미응답이었던 유저들
    const needResponseUsers = memberIds.filter(
      (id) => !accepted.includes(id) && !declined.includes(id)
    );

    if (needResponseUsers.length === 0) {
      console.log("[onPromiseDeletedBadges] No users had pending response");
      return;
    }

    // 배치로 각 유저의 needResponseCount 감소
    const usersCollection = getEnvironmentCollection("users", db, env);
    const batch = db.batch();

    for (const userId of needResponseUsers) {
      const userRef = usersCollection.doc(userId);
      batch.update(userRef, {
        [`groups.${groupId}.needResponseCount`]: FieldValue.increment(-1),
      });
    }

    await batch.commit();
    console.log(
      `[onPromiseDeletedBadges] ${needResponseUsers.length} users badge -1`
    );
  }
);

/**
 * 약속 투표 변경 시 배지 카운트 조정
 *
 * @remarks
 * promises/{promiseId} 문서의 votes가 변경되면 트리거됩니다.
 * - pending → accepted/declined: 해당 유저 -1
 * - accepted/declined → pending: 해당 유저 +1 (응답 취소)
 */
export const onPromiseVotesUpdatedBadges = onDocumentUpdated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      console.log("[onPromiseVotesUpdatedBadges] No data");
      return;
    }

    const promiseId = event.params.promiseId;
    const env = event.params.env;
    const groupId = afterData.groupId as string;

    // votes 변경 여부 체크
    const beforeVotes = beforeData.votes || {accepted: [], declined: []};
    const afterVotes = afterData.votes || {accepted: [], declined: []};

    const beforeAccepted = new Set<string>(
      (beforeVotes.accepted as string[]) ?? []
    );
    const beforeDeclined = new Set<string>(
      (beforeVotes.declined as string[]) ?? []
    );
    const afterAccepted = new Set<string>(
      (afterVotes.accepted as string[]) ?? []
    );
    const afterDeclined = new Set<string>(
      (afterVotes.declined as string[]) ?? []
    );

    // Set 비교 함수
    const setsEqual = (a: Set<string>, b: Set<string>) =>
      a.size === b.size && [...a].every((x) => b.has(x));

    // 변경 없으면 종료
    if (setsEqual(beforeAccepted, afterAccepted) &&
        setsEqual(beforeDeclined, afterDeclined)) {
      return;
    }

    console.log(
      `[onPromiseVotesUpdatedBadges] Promise ${promiseId} votes changed`
    );

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);
    const batch = db.batch();
    let updateCount = 0;

    // 모든 관련 유저 수집
    const allUsers = new Set([
      ...beforeAccepted, ...beforeDeclined,
      ...afterAccepted, ...afterDeclined,
    ]);

    for (const userId of allUsers) {
      const wasPending =
        !beforeAccepted.has(userId) && !beforeDeclined.has(userId);
      const nowPending =
        !afterAccepted.has(userId) && !afterDeclined.has(userId);

      if (wasPending && !nowPending) {
        // pending → responded: 카운트 감소
        const userRef = usersCollection.doc(userId);
        batch.update(userRef, {
          [`groups.${groupId}.needResponseCount`]: FieldValue.increment(-1),
        });
        updateCount++;
      } else if (!wasPending && nowPending) {
        // responded → pending: 카운트 증가 (응답 취소)
        const userRef = usersCollection.doc(userId);
        batch.update(userRef, {
          [`groups.${groupId}.needResponseCount`]: FieldValue.increment(1),
        });
        updateCount++;
      }
    }

    if (updateCount > 0) {
      await batch.commit();
      console.log(
        `[onPromiseVotesUpdatedBadges] ${updateCount} users updated`
      );
    }
  }
);

/**
 * 마감된 약속의 미응답자 배지 정리 (매시간 실행)
 *
 * @remarks
 * 투표 마감(votes.until) 지난 약속들을 처리합니다.
 * - 미응답자들의 needResponseCount -= 1
 * - badgesCleared = true 설정
 */
export const cleanupExpiredPromiseBadges = onSchedule(
  {
    schedule: "every 1 hours",
    region: REGION,
  },
  async () => {
    const now = Timestamp.now();
    const envs = ["dev", "stage", "prod"];
    const db = admin.firestore();

    for (const env of envs) {
      try {
        // 마감됐지만 처리 안 된 약속 조회
        const promisesCollection = db
          .collection(env)
          .doc("root")
          .collection("promises");

        const expiredPromises = await promisesCollection
          .where("badgesCleared", "==", false)
          .limit(200)
          .get();

        if (expiredPromises.empty) {
          console.log(`[cleanupExpiredBadges] ${env}: No expired promises`);
          continue;
        }

        // 단일 배치로 모든 업데이트 처리 (최대 500개 작업)
        const batch = db.batch();
        let processedCount = 0;
        const groupsCollection = db
          .collection(env)
          .doc("root")
          .collection("groups");
        const usersCollection = db
          .collection(env)
          .doc("root")
          .collection("users");

        // 그룹 캐시 (동일 그룹 중복 조회 방지)
        const groupCache = new Map<string, string[] | null>();

        for (const doc of expiredPromises.docs) {
          const promise = doc.data();
          const votes = promise.votes || {};

          // 마감 시간 확인 (votes.until 없으면 startAt 사용)
          const deadline = votes.until ?? promise.startAt;
          if (!deadline || deadline.toMillis() > now.toMillis()) {
            continue; // 아직 마감 안 됨
          }

          const groupId = promise.groupId;
          if (typeof groupId !== "string") continue;

          const accepted = (votes.accepted as string[]) ?? [];
          const declined = (votes.declined as string[]) ?? [];

          // 그룹 멤버 조회 (캐시 사용)
          let memberIds = groupCache.get(groupId);
          if (memberIds === undefined) {
            const groupDoc = await groupsCollection.doc(groupId).get();
            if (groupDoc.exists) {
              memberIds = (groupDoc.data()?.memberIds as string[]) ?? [];
            } else {
              memberIds = null;
            }
            groupCache.set(groupId, memberIds);
          }

          if (memberIds === null) {
            // 그룹이 삭제된 경우 badgesCleared만 설정
            batch.update(doc.ref, {badgesCleared: true});
            processedCount++;
            continue;
          }

          const needResponseUsers = memberIds.filter(
            (id) => !accepted.includes(id) && !declined.includes(id)
          );

          // 미응답자 카운트 감소
          for (const userId of needResponseUsers) {
            batch.update(usersCollection.doc(userId), {
              [`groups.${groupId}.needResponseCount`]: FieldValue.increment(-1),
            });
          }

          // 처리 완료 플래그
          batch.update(doc.ref, {badgesCleared: true});
          processedCount++;
        }

        // 모든 업데이트를 한 번에 커밋
        if (processedCount > 0) {
          await batch.commit();
        }

        console.log(
          `[cleanupExpiredBadges] ${env}: ${processedCount} processed`
        );
      } catch (error) {
        console.error(`[cleanupExpiredBadges] ${env} error:`, error);
      }
    }
  }
);

/**
 * 배지 카운트 정합성 체크 (6시간마다 실행)
 *
 * @remarks
 * 트리거 실패 등으로 발생할 수 있는 카운트 불일치를 교정합니다.
 * - 실제 미응답 약속 수와 needResponseCount 비교
 * - 불일치 시 교정
 * - 음수인 경우 0으로 교정
 *
 * @note 메모리/타임아웃 제한으로 최대 500명 유저만 처리합니다.
 * 대규모 서비스 시 페이지네이션 구현 필요.
 */
export const reconcileBadgeCounts = onSchedule(
  {
    schedule: "every 6 hours",
    region: REGION,
  },
  async () => {
    const now = Timestamp.now();
    const envs = ["dev", "stage", "prod"];
    const db = admin.firestore();

    for (const env of envs) {
      try {
        const usersCollection = db
          .collection(env)
          .doc("root")
          .collection("users");
        const promisesCollection = db
          .collection(env)
          .doc("root")
          .collection("promises");

        // 활성 약속 조회 (마감 안 됨 + 배지 미정리)
        const activePromises = await promisesCollection
          .where("badgesCleared", "==", false)
          .get();

        // 그룹 캐시 (동일 그룹 중복 조회 방지)
        const groupCache = new Map<string, string[] | null>();
        const groupsCollection = db
          .collection(env)
          .doc("root")
          .collection("groups");

        // 그룹별 약속 카운트 계산
        const groupPromiseCounts = new Map<string, Map<string, number>>();

        for (const doc of activePromises.docs) {
          const promise = doc.data();
          const votes = promise.votes || {};
          const deadline = votes.until ?? promise.startAt;

          // 아직 마감 안 된 약속만
          if (deadline && deadline.toMillis() > now.toMillis()) {
            const groupId = promise.groupId;
            if (typeof groupId !== "string") continue;

            const accepted = (votes.accepted as string[]) ?? [];
            const declined = (votes.declined as string[]) ?? [];

            // 그룹 멤버 조회 (캐시 사용)
            let memberIds = groupCache.get(groupId);
            if (memberIds === undefined) {
              const groupDoc = await groupsCollection.doc(groupId).get();
              if (groupDoc.exists) {
                memberIds = (groupDoc.data()?.memberIds as string[]) ?? [];
              } else {
                memberIds = null;
              }
              groupCache.set(groupId, memberIds);
            }

            if (memberIds) {
              const needResponseUsers = memberIds.filter(
                (id) => !accepted.includes(id) && !declined.includes(id)
              );

              for (const userId of needResponseUsers) {
                if (!groupPromiseCounts.has(userId)) {
                  groupPromiseCounts.set(userId, new Map());
                }
                const userGroups = groupPromiseCounts.get(userId)!;
                userGroups.set(groupId, (userGroups.get(groupId) || 0) + 1);
              }
            }
          }
        }

        // 유저별 카운트 검증 및 교정
        let correctionCount = 0;
        const userDocs = await usersCollection.limit(500).get();

        for (const userDoc of userDocs.docs) {
          const userData = userDoc.data();
          const groups = (userData.groups as Record<string, unknown>) || {};
          const userId = userDoc.id;
          const expectedCounts = groupPromiseCounts.get(userId) || new Map();
          const batch = db.batch();
          let needsUpdate = false;

          for (const [groupId, groupData] of Object.entries(groups)) {
            const data = groupData as Record<string, unknown>;
            const currentCount = (data.needResponseCount as number) ?? 0;
            const expectedCount = expectedCounts.get(groupId) || 0;

            // 음수 교정 또는 불일치 교정
            if (currentCount < 0 || currentCount !== expectedCount) {
              batch.update(userDoc.ref, {
                [`groups.${groupId}.needResponseCount`]: expectedCount,
              });
              needsUpdate = true;
              correctionCount++;
              console.log(
                `[reconcileBadges] ${env}: ${userId}/${groupId} ` +
                `${currentCount} -> ${expectedCount}`
              );
            }
          }

          if (needsUpdate) {
            await batch.commit();
          }
        }

        console.log(
          `[reconcileBadges] ${env}: ${correctionCount} corrections`
        );
      } catch (error) {
        console.error(`[reconcileBadges] ${env} error:`, error);
      }
    }
  }
);
