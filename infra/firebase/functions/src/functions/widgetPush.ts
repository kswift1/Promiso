/**
 * Widget Silent Push Functions
 *
 * 위젯 갱신을 위한 Silent Push 발송 Cloud Functions
 *
 * @why 홈 화면 위젯이 앱 접속 없이도 최신 데이터를 유지하도록 함
 * @ios AppDelegate에서 didReceiveRemoteNotification으로 수신 후 위젯 캐시 갱신
 *
 * @triggers
 * - onPromiseChangedForWidget: 약속 생성/수정/삭제 시 관련 사용자에게 Silent Push
 */
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {admin, REGION, APNS_BUNDLE_ID} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";

// NOTE: iOS 26 Widget Push 전용 topic은 "{bundleId}.push-type.widgets"
// 현재는 일반 Silent Push로 위젯 갱신 (APNS_BUNDLE_ID 사용)

// Widget Silent Push 상수
const WIDGET_REFRESH_TYPE = "widget_refresh";
const WIDGET_REFRESH_COLLAPSE_ID = "widget-refresh";

/**
 * 사용자들에게 Silent Push 발송
 *
 * @param {string[]} userIds - 수신 대상 사용자 ID 배열
 * @param {string|null} env - 환경 (stage/prod)
 * @return {Promise<void>} void
 */
async function sendWidgetSilentPush(
  userIds: string[],
  env: "stage" | "prod" | null = null
): Promise<void> {
  if (userIds.length === 0) {
    console.log("📭 No users to send widget silent push");
    return;
  }

  const db = admin.firestore();
  const usersCollection = getEnvironmentCollection("users", db, env);

  // 1. 각 사용자의 FCM 토큰 수집
  const allTokens: string[] = [];

  for (const userId of userIds) {
    try {
      const userDoc = await usersCollection.doc(userId).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      type DeviceMap = { [key: string]: { fcmToken?: string } };
      const devices = userData?.devices as DeviceMap | null;

      if (!devices) continue;

      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.fcmToken) {
          allTokens.push(device.fcmToken);
        }
      }
    } catch (error) {
      console.error(`Failed to get tokens for user ${userId}:`, error);
    }
  }

  if (allTokens.length === 0) {
    console.log("📭 No FCM tokens found for widget push");
    return;
  }

  // 2. Silent Push 전송 (APNs 필수 헤더 포함)
  // - apns-topic: iOS 13+ 필수
  // - apns-collapse-id: 중복 푸시 방지 (최신 1개만 유지)
  const message: admin.messaging.MulticastMessage = {
    tokens: allTokens,
    apns: {
      headers: {
        "apns-push-type": "background",
        "apns-priority": "5",
        "apns-topic": APNS_BUNDLE_ID,
        "apns-collapse-id": WIDGET_REFRESH_COLLAPSE_ID,
      },
      payload: {
        aps: {
          "content-available": 1,
        },
        type: WIDGET_REFRESH_TYPE,
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    const successCount = response.successCount;
    const failureCount = response.failureCount;
    console.log(
      `🔔 Widget push sent: ${successCount} success, ` +
      `${failureCount} failures`
    );
  } catch (error) {
    console.error("❌ Widget push error:", error);
  }
}

/**
 * 그룹의 모든 멤버 ID 조회
 *
 * @param {string} groupId - 그룹 ID
 * @param {string|null} env - 환경
 * @return {Promise<string[]>} 멤버 ID 배열
 */
async function getGroupMemberIds(
  groupId: string,
  env: "stage" | "prod" | null = null
): Promise<string[]> {
  const db = admin.firestore();
  const groupsCollection = getEnvironmentCollection("groups", db, env);

  try {
    const groupDoc = await groupsCollection.doc(groupId).get();
    if (!groupDoc.exists) return [];

    const groupData = groupDoc.data();
    const memberIds = groupData?.memberIds as string[] | undefined;

    if (!memberIds || memberIds.length === 0) return [];
    return memberIds;
  } catch (error) {
    console.error(`Failed to get group members for ${groupId}:`, error);
    return [];
  }
}

/**
 * 약속 생성 시 위젯 갱신 Silent Push
 */
export const onPromiseCreatedWidgetPush = onDocumentCreated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const promiseData = event.data?.data();
    if (!promiseData) return;

    const groupId = promiseData.groupId as string | undefined;
    if (!groupId) return;

    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";
    console.log(`🆕 Promise created: ${promiseId}, sending widget push`);

    const memberIds = await getGroupMemberIds(groupId, env);
    await sendWidgetSilentPush(memberIds, env);
  }
);

/**
 * 약속 수정 시 위젯 갱신 Silent Push
 *
 * 주요 필드 변경 시에만 발송:
 * - title, startAt, endAt, location, votes (확정 상태 변경)
 */
export const onPromiseUpdatedWidgetPush = onDocumentUpdated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    // 주요 필드 변경 여부 확인 (votes 전체 비교로 응답 변경도 감지)
    const significantChange =
      before.title !== after.title ||
      before.startAt?.toMillis() !== after.startAt?.toMillis() ||
      before.endAt?.toMillis() !== after.endAt?.toMillis() ||
      JSON.stringify(before.location) !== JSON.stringify(after.location) ||
      JSON.stringify(before.votes) !== JSON.stringify(after.votes) ||
      before.isConfirmed !== after.isConfirmed;

    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";

    if (!significantChange) {
      console.log(`📭 No significant change for promise ${promiseId}`);
      return;
    }

    const groupId = after.groupId as string | undefined;
    if (!groupId) return;

    console.log(`✏️ Promise updated: ${promiseId}, sending widget push`);

    const memberIds = await getGroupMemberIds(groupId, env);
    await sendWidgetSilentPush(memberIds, env);
  }
);

/**
 * 약속 삭제 시 위젯 갱신 Silent Push
 */
export const onPromiseDeletedWidgetPush = onDocumentDeleted(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const promiseData = event.data?.data();
    if (!promiseData) return;

    const groupId = promiseData.groupId as string | undefined;
    if (!groupId) return;

    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";
    console.log(`🗑️ Promise deleted: ${promiseId}, sending widget push`);

    const memberIds = await getGroupMemberIds(groupId, env);
    await sendWidgetSilentPush(memberIds, env);
  }
);
