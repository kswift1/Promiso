/**
 * Promise Badge Functions (Simplified)
 *
 * 그룹별 신규 소식 배지(hasNewActivity) 관리를 위한 Cloud Functions
 *
 * @why 비용 효율적인 단순 배지 시스템
 * @ios GroupMainView - 그룹 가로 바의 배지 표시
 *
 * @approach
 * - 복잡한 카운팅/스케줄러 대신 단순 on/off 방식
 * - 약속 생성 시 → hasNewActivity = true
 * - 앱에서 확인 시 → API 호출로 hasNewActivity = false
 */
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";

/**
 * 약속 생성 시 그룹 멤버들에게 신규 소식 배지 표시
 *
 * @remarks
 * promises/{promiseId} 문서가 생성되면 트리거됩니다.
 * - 그룹 멤버 전원에게 hasNewActivity = true 설정
 * - 약속 생성자 본인 제외
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

    // 약속 생성자
    const creatorId = typeof promiseData.creatorId === "string" ?
      promiseData.creatorId : null;

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

    const rawMemberIds = groupDoc.data()?.memberIds;
    const memberIds: string[] = Array.isArray(rawMemberIds) ?
      (rawMemberIds as string[]) :
      [];

    // 생성자 제외한 멤버들에게 배지 표시
    const targetUsers = memberIds.filter((id) => id !== creatorId);

    if (targetUsers.length === 0) {
      console.log("[onPromiseCreatedBadges] No other members to notify");
      return;
    }

    // 배치로 각 유저의 hasNewActivity 설정
    const usersCollection = getEnvironmentCollection("users", db, env);
    const batch = db.batch();

    for (const userId of targetUsers) {
      const userRef = usersCollection.doc(userId);
      batch.update(userRef, {
        [`groups.${groupId}.hasNewActivity`]: true,
      });
    }

    await batch.commit();
    console.log(
      `[onPromiseCreatedBadges] ${targetUsers.length} users badge set`
    );
  }
);

/**
 * 그룹 배지 해제 API
 *
 * @remarks
 * 앱에서 그룹 화면 진입 시 호출하여 배지를 해제합니다.
 *
 * @param groupId - 배지를 해제할 그룹 ID
 */
export const clearGroupBadge = onCall(
  {region: REGION},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const groupId = request.data?.groupId;
    if (!groupId || typeof groupId !== "string") {
      throw new HttpsError("invalid-argument", "groupId가 필요합니다.");
    }

    const env = request.data?.env;
    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);

    try {
      await usersCollection.doc(uid).update({
        [`groups.${groupId}.hasNewActivity`]: false,
      });

      console.log(`[clearGroupBadge] User ${uid} cleared badge for ${groupId}`);

      return {success: true};
    } catch (error) {
      console.error("[clearGroupBadge] Error:", error);
      throw new HttpsError("internal", "배지 해제에 실패했습니다.");
    }
  }
);
