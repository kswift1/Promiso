/**
 * Notification Functions
 *
 * 푸시 알림 관련 Cloud Functions 및 Firestore Triggers
 *
 * @why FCM을 통한 푸시 알림으로 사용자 참여 유도
 * @ios AppDelegate - FCM 토큰 등록, 알림 수신 처리
 *
 * @triggers
 * - onPromiseCreated: 약속 생성 시 그룹 멤버에게 알림
 * - onPromiseVotesUpdated: 약속 확정/미성사 시 알림
 * - onGroupMemberJoined: 새 멤버 참여 시 기존 멤버에게 알림
 */
import {FieldValue} from "firebase-admin/firestore";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";
import {getEnvironmentCollection} from "../utils/firestore";
import {
  DeviceInfo,
  NotificationDocument,
  NotificationType,
  SendPushNotificationRequest,
  SendPushNotificationResponse,
} from "../types/api";

/**
 * 푸시 알림 전송 (Callable Function)
 *
 * @remarks
 * **인증 필수**
 *
 * 지정된 사용자들에게 푸시 알림을 전송합니다.
 * - 각 사용자의 devices Map에서 FCM 토큰을 조회
 * - FCM을 통해 멀티캐스트 전송
 * - notifications 컬렉션에 알림 기록 저장
 */
export const sendPushNotification = onCall<SendPushNotificationRequest>(
  {region: REGION},
  async (request): Promise<SendPushNotificationResponse> => {
    // 1. 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const data = request.data;

    // 2. 유효성 검사
    if (!data.userIds || data.userIds.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "수신자 ID 배열은 필수입니다",
      );
    }

    if (!data.type || !data.title || !data.body) {
      throw new HttpsError(
        "invalid-argument",
        "알림 타입, 제목, 본문은 필수입니다",
      );
    }

    try {
      const result = await sendPushNotificationInternal({
        userIds: data.userIds,
        type: data.type,
        title: data.title,
        body: data.body,
        promiseId: data.promiseId ?? null,
        groupId: data.groupId ?? null,
        relatedUserId: data.relatedUserId ?? null,
        data: data.data ?? null,
        env: data.env ?? null,
      });

      return result;
    } catch (error) {
      console.error("❌ sendPushNotification error:", error);
      throw new HttpsError(
        "internal",
        "푸시 알림 전송 중 오류가 발생했습니다",
      );
    }
  },
);

/**
 * 푸시 알림 전송 내부 헬퍼 함수
 *
 * Firestore 트리거나 Callable Function에서 공통으로 사용됩니다.
 *
 * @param {object} params - 알림 전송 파라미터
 */
export async function sendPushNotificationInternal(params: {
  userIds: string[];
  type: NotificationType;
  title: string;
  body: string;
  promiseId: string | null;
  groupId: string | null;
  relatedUserId: string | null;
  data: { [key: string]: string } | null;
  env: "stage" | "prod" | null;
}): Promise<SendPushNotificationResponse> {
  const {userIds, type, title, body, promiseId, groupId,
    relatedUserId, data, env} = params;

  const db = admin.firestore();
  const usersCollection = getEnvironmentCollection("users", db, env);
  const notificationsCollection = getEnvironmentCollection(
    "notifications",
    db,
    env,
  );

  // 1. 각 사용자의 FCM 토큰 수집
  const allTokens: string[] = [];
  const userTokenMap: Map<string, string[]> = new Map();

  for (const userId of userIds) {
    try {
      const userDoc = await usersCollection.doc(userId).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      const devices = userData?.devices as { [key: string]: DeviceInfo } | null;

      if (!devices) continue;

      const tokens: string[] = [];
      for (const deviceId of Object.keys(devices)) {
        const device = devices[deviceId];
        if (device.fcmToken) {
          tokens.push(device.fcmToken);
          allTokens.push(device.fcmToken);
        }
      }

      if (tokens.length > 0) {
        userTokenMap.set(userId, tokens);
      }
    } catch (error) {
      console.error(`Failed to get tokens for user ${userId}:`, error);
    }
  }

  // 2. 토큰이 없으면 조기 반환
  if (allTokens.length === 0) {
    console.log("📭 No FCM tokens found for users:", userIds);
    return {
      success: true,
      successCount: 0,
      failureCount: userIds.length,
    };
  }

  // 3. FCM 멀티캐스트 전송
  const message: admin.messaging.MulticastMessage = {
    tokens: allTokens,
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: type,
      ...(promiseId && {promiseId}),
      ...(groupId && {groupId}),
      ...(relatedUserId && {relatedUserId}),
      ...(data || {}),
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          // TODO: 읽지 않은 알림 수로 동적 계산 필요 (현재 하드코딩)
          badge: 1,
        },
      },
    },
  };

  let successCount = 0;
  let failureCount = 0;
  const deliveredTokens = new Set<string>();

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    successCount = response.successCount;
    failureCount = response.failureCount;

    console.log(`📤 FCM sent: ${successCount} success, ${failureCount} failed`);

    // 성공/실패 토큰 추적
    response.responses.forEach((resp, idx) => {
      if (resp.success) {
        deliveredTokens.add(allTokens[idx]);
      } else {
        console.error(`Token ${allTokens[idx]} failed:`, resp.error);
      }
    });
  } catch (error) {
    console.error("❌ FCM multicast error:", error);
    failureCount = allTokens.length;
  }

  // 유저별 전송 성공 여부 계산
  const userDeliveryStatus = new Map<string, boolean>();
  for (const [userId, tokens] of userTokenMap) {
    const delivered = tokens.some((token) => deliveredTokens.has(token));
    userDeliveryStatus.set(userId, delivered);
  }

  // 4. notifications 컬렉션에 알림 기록 저장
  const now = FieldValue.serverTimestamp();
  const batch = db.batch();

  for (const userId of userIds) {
    const isDelivered = userDeliveryStatus.get(userId) ?? false;
    const notificationDoc: Omit<NotificationDocument, "createdAt" |
      "readAt" | "deliveredAt"> & {
      createdAt: FirebaseFirestore.FieldValue;
      readAt: null;
      deliveredAt: FirebaseFirestore.FieldValue | null;
    } = {
      userId,
      type,
      title,
      body,
      promiseId,
      groupId,
      relatedUserId,
      isRead: false,
      isDelivered,
      createdAt: now,
      readAt: null,
      deliveredAt: isDelivered ? now : null,
      data: data,
    };

    const notificationRef = notificationsCollection.doc();
    batch.set(notificationRef, notificationDoc);
  }

  await batch.commit();

  return {
    success: true,
    successCount,
    failureCount,
  };
}

// ============================================================================
// Firestore Triggers for Push Notifications
// ============================================================================

/**
 * 약속 생성 시 그룹 멤버들에게 알림
 *
 * @remarks
 * promises/{promiseId} 문서가 생성되면 트리거됩니다.
 * - 호스트를 제외한 그룹 멤버들에게 알림 전송
 */
export const onPromiseCreated = onDocumentCreated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const promiseData = snapshot.data();
    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";

    const groupId = promiseData.groupId as string;
    const hostId = promiseData.hostId as string;
    const title = promiseData.title as string;

    console.log(`📅 Promise created: ${promiseId} in group ${groupId}`);

    // 그룹 멤버 조회
    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);
    const groupDoc = await groupsCollection.doc(groupId).get();

    if (!groupDoc.exists) {
      console.error(`Group ${groupId} not found`);
      return;
    }

    const groupData = groupDoc.data();
    const memberIds = (groupData?.memberIds as string[]) ?? [];

    // 호스트 제외
    const recipientIds = memberIds.filter((id) => id !== hostId);

    if (recipientIds.length === 0) {
      console.log("No recipients to notify");
      return;
    }

    // 호스트 이름 조회
    const usersCollection = getEnvironmentCollection("users", db, env);
    const hostDoc = await usersCollection.doc(hostId).get();
    const hostName = hostDoc.data()?.nickname as string || "누군가";

    // 푸시 알림 전송
    await sendPushNotificationInternal({
      userIds: recipientIds,
      type: NotificationType.PromiseInvitation,
      title: "새 약속 도착 📩",
      body: `${hostName}님이 ${title}을 제안했어요. 확인해주세요!`,
      promiseId,
      groupId,
      relatedUserId: hostId,
      data: null,
      env,
    });
  },
);

/**
 * 약속 투표 변경 시 확정/미성사 알림
 *
 * @remarks
 * promises/{promiseId} 문서의 votes가 변경되면 트리거됩니다.
 * - 최소 인원 충족 시 → 약속 확정 알림 (그룹 전체)
 * - 최소 인원 충족 불가 시 → 약속 미성사 알림 (그룹 전체)
 */
export const onPromiseVotesUpdated = onDocumentUpdated(
  {
    document: "{env}/root/promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      console.log("No data associated with the event");
      return;
    }

    const promiseId = event.params.promiseId;
    const env = event.params.env as "stage" | "prod";
    const groupId = afterData.groupId as string;
    const title = afterData.title as string;
    const minimumParticipants = afterData.minimumParticipants as number || 2;
    const startAt = afterData.startAt as admin.firestore.Timestamp;

    // votes 변경 확인
    const beforeVotes = beforeData.votes || {accepted: [], declined: []};
    const afterVotes = afterData.votes || {accepted: [], declined: []};

    const beforeAccepted = (beforeVotes.accepted as string[]) ?? [];
    const afterAccepted = (afterVotes.accepted as string[]) ?? [];
    const beforeDeclined = (beforeVotes.declined as string[]) ?? [];
    const afterDeclined = (afterVotes.declined as string[]) ?? [];

    // 새로 declined한 사용자 찾기 (미성사 알림용)
    const newDeclined = afterDeclined
      .filter((id: string) => !beforeDeclined.includes(id));

    const db = admin.firestore();
    const groupsCollection = getEnvironmentCollection("groups", db, env);

    // 그룹 멤버 조회
    const groupDoc = await groupsCollection.doc(groupId).get();
    if (!groupDoc.exists) {
      console.log("Group not found:", groupId);
      return;
    }
    const memberIds = groupDoc.data()?.memberIds as string[] || [];
    const totalMembers = memberIds.length;

    // 확정 체크: 이전에는 미충족 → 이제 충족
    const wasConfirmed = beforeAccepted.length >= minimumParticipants;
    const isConfirmed = afterAccepted.length >= minimumParticipants;

    if (!wasConfirmed && isConfirmed) {
      // 약속 확정 알림 (수락한 사람들에게만)
      const startDate = startAt.toDate();
      const dateString = `${startDate.getMonth() + 1}월 ${startDate.getDate()}일`;

      await sendPushNotificationInternal({
        userIds: afterAccepted,
        type: NotificationType.PromiseConfirmed,
        title: "약속 확정! 🎉",
        body: `${title} 약속 확정! ${dateString}에 만나요`,
        promiseId,
        groupId,
        relatedUserId: null,
        data: null,
        env,
      });
      return;
    }

    // 미성사 체크: 남은 가능 인원 < 최소 인원
    const remainingPossible = totalMembers - afterDeclined.length;
    const prevRemaining = totalMembers - beforeDeclined.length;
    const wasCancellable = prevRemaining >= minimumParticipants;
    const isCancelled = remainingPossible < minimumParticipants;

    if (wasCancellable && isCancelled && newDeclined.length > 0) {
      // 약속 미성사 알림 (수락한 사람들에게만)
      if (afterAccepted.length > 0) {
        await sendPushNotificationInternal({
          userIds: afterAccepted,
          type: NotificationType.PromiseCancelled,
          title: "약속 무산 😢",
          body: `${title}의 참여 인원이 부족해서 확정되지 않았어요`,
          promiseId,
          groupId,
          relatedUserId: null,
          data: null,
          env,
        });
      }
    }
  },
);

/**
 * 그룹에 새 멤버 참여 시 기존 멤버들에게 알림
 *
 * @remarks
 * groups/{groupId} 문서의 memberIds가 변경되면 트리거됩니다.
 * - 새로 참여한 멤버가 있으면 기존 멤버들에게 알림
 */
export const onGroupMemberJoined = onDocumentUpdated(
  {
    document: "{env}/root/groups/{groupId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      return;
    }

    const groupId = event.params.groupId;
    const env = event.params.env as "stage" | "prod";

    const beforeMembers = new Set(beforeData.memberIds as string[] || []);
    const afterMembers = afterData.memberIds as string[] || [];

    // 새로 참여한 멤버 찾기
    const newMembers = afterMembers.filter((id) => !beforeMembers.has(id));

    if (newMembers.length === 0) {
      return; // 새 멤버 없음
    }

    const groupName = afterData.name as string || "그룹";
    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db, env);

    for (const newMemberId of newMembers) {
      // 기존 멤버들에게 알림 (새 멤버 제외)
      const recipientIds = afterMembers.filter((id) => id !== newMemberId);

      if (recipientIds.length === 0) continue;

      const newMemberDoc = await usersCollection.doc(newMemberId).get();
      const newMemberName = newMemberDoc.data()?.nickname as string || "누군가";

      await sendPushNotificationInternal({
        userIds: recipientIds,
        type: NotificationType.GroupUpdate,
        title: "새 멤버 합류 👋",
        body: `${newMemberName}님이 ${groupName}에 들어왔어요`,
        promiseId: null,
        groupId,
        relatedUserId: newMemberId,
        data: null,
        env,
      });
    }
  },
);
