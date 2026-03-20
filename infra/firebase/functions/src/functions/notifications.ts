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
import {
  DeviceInfo,
  NotificationDocument,
  NotificationType,
  SendPushNotificationRequest,
  SendPushNotificationResponse,
} from "../types/api";

/**
 * 그룹 알림 상세 설정 경로 모델.
 */
type NotificationPreferencePath = {
  category: "promise" | "group";
  key: string;
};

/**
 * 알림 타입을 그룹 알림 상세 설정 경로로 변환합니다.
 *
 * @param {NotificationType} type - 알림 타입
 * @return {NotificationPreferencePath | null} 그룹 알림 상세 설정 경로
 */
function notificationPreferencePath(
  type: NotificationType
): NotificationPreferencePath | null {
  switch (type) {
  case NotificationType.PromiseInvitation:
    return {category: "promise", key: "invitation"};
  case NotificationType.PromiseReminder:
    return {category: "promise", key: "reminder"};
  case NotificationType.PromiseConfirmed:
    return {category: "promise", key: "confirmed"};
  case NotificationType.PromiseCancelled:
    return {category: "promise", key: "cancelled"};
  case NotificationType.PromiseUpdated:
    return {category: "promise", key: "updated"};
  case NotificationType.AttendanceResponse:
    return {category: "promise", key: "attendanceResponse"};
  case NotificationType.GroupInvitation:
    return {category: "group", key: "invitation"};
  case NotificationType.GroupUpdate:
    return {category: "group", key: "update"};
  case NotificationType.LocationSharingReminder:
    return null; // 별도 설정 불가 (항상 발송)
  case NotificationType.System:
    return null;
  default:
    return null;
  }
}

/**
 * 레거시 알림 설정 키로 변환합니다.
 *
 * @param {NotificationType} type - 알림 타입
 * @return {string | null} 레거시 알림 설정 키
 */
function legacyPreferenceKey(type: NotificationType): string | null {
  switch (type) {
  case NotificationType.PromiseInvitation:
    return "promiseInvitation";
  case NotificationType.PromiseReminder:
    return "promiseReminder";
  case NotificationType.PromiseConfirmed:
    return "promiseConfirmed";
  case NotificationType.PromiseCancelled:
    return "promiseCancelled";
  case NotificationType.PromiseUpdated:
    return "promiseUpdated";
  case NotificationType.AttendanceResponse:
    return "attendanceResponse";
  case NotificationType.GroupInvitation:
    return "groupInvitation";
  case NotificationType.GroupUpdate:
    return "groupUpdate";
  case NotificationType.LocationSharingReminder:
    return null; // 별도 설정 불가
  case NotificationType.System:
    return null;
  default:
    return null;
  }
}

/**
 * 그룹 알림 전체 활성화 여부를 반환합니다.
 *
 * @param {unknown} value - notifications 필드 값
 * @return {boolean} 활성화 여부
 */
function notificationSettingsEnabled(value: unknown): boolean {
  if (typeof value === "boolean") {
    return value;
  }
  if (value && typeof value === "object") {
    const enabled = (value as {enabled?: boolean}).enabled;
    return enabled ?? true;
  }
  return true;
}

/**
 * 알림 타입별 설정이 활성화되었는지 확인합니다.
 *
 * @param {Object} params - 설정 체크 파라미터
 * @param {NotificationType} params.type - 알림 타입
 * @param {*} params.settings - notifications 필드 값
 * @param {Object<string, boolean>|null} params.legacyPreferences
 * @return {boolean} 활성화 여부
 */
function notificationPreferenceEnabled(params: {
  type: NotificationType;
  settings: unknown;
  legacyPreferences?: { [key: string]: boolean } | null;
}): boolean {
  const {type, settings, legacyPreferences} = params;
  const path = notificationPreferencePath(type);
  if (!path) {
    return true;
  }

  if (settings && typeof settings === "object") {
    const settingsMap = settings as {[key: string]: unknown};
    const categoryMap = settingsMap[path.category] as
      {[key: string]: boolean} | undefined;
    if (categoryMap && categoryMap[path.key] === false) {
      return false;
    }
  }

  const legacyKey = legacyPreferenceKey(type);
  if (
    legacyPreferences &&
    legacyKey &&
    legacyPreferences[legacyKey] === false
  ) {
    return false;
  }

  return true;
}

/**
 * 날짜/시간을 "오늘/내일/M월 D일 H시 M분" 형식으로 포맷 (KST 기준)
 * - 오늘이면 "오늘"
 * - 내일이면 "내일"
 * - 그 외 "M월 D일"
 * - 시간은 "H시" (0분일 때) 또는 "H시 M분"
 *
 * @param {Date} date - 포맷할 날짜 (UTC)
 * @return {string} 포맷된 날짜/시간 문자열 (KST)
 */
function formatDateTime(date: Date): string {
  // Intl.DateTimeFormat으로 KST 시간대 직접 사용
  const kstFormatter = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });
  const nowFormatter = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    year: "numeric",
    month: "numeric",
    day: "numeric",
  });

  const kstDateStr = kstFormatter.format(date);
  const kstNowStr = nowFormatter.format(new Date());

  // 오늘/내일 판단
  const kstTomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
  const kstTomorrowStr = nowFormatter.format(kstTomorrow);

  let dateStr: string;
  if (kstDateStr === kstNowStr) {
    dateStr = "오늘";
  } else if (kstDateStr === kstTomorrowStr) {
    dateStr = "내일";
  } else {
    // "2024. 1. 25." → "1월 25일"
    const parts = kstDateStr.split(". ");
    dateStr = `${parseInt(parts[1])}월 ${parseInt(parts[2])}일`;
  }

  // 시간 부분 (KST 기준)
  const timeFormatter = new Intl.DateTimeFormat("ko-KR", {
    timeZone: "Asia/Seoul",
    hour: "numeric",
    minute: "numeric",
    hour12: true,
  });
  const timeStr = timeFormatter.format(date);

  return `${dateStr} ${timeStr}`;
}

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

    const senderId = request.auth.uid;
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

    // 3. Authorization: 발신자와 같은 그룹에 속한 사용자에게만 알림 전송 가능
    const db = admin.firestore();
    const usersCollection = db.collection("users");
    const senderDoc = await usersCollection.doc(senderId).get();

    if (!senderDoc.exists) {
      throw new HttpsError(
        "internal",
        "발신자 정보를 찾을 수 없습니다",
      );
    }

    const senderData = senderDoc.data();
    if (!senderData) {
      throw new HttpsError(
        "internal",
        "발신자 데이터를 읽을 수 없습니다",
      );
    }

    const senderGroups = Object.keys(senderData.groups || {});

    // 각 수신자가 발신자와 같은 그룹에 속하는지 확인
    for (const recipientId of data.userIds) {
      // 본인에게 보내는 것은 항상 허용
      if (recipientId === senderId) {
        continue;
      }

      const recipientDoc = await usersCollection.doc(recipientId).get();
      if (!recipientDoc.exists) {
        throw new HttpsError(
          "not-found",
          `수신자를 찾을 수 없습니다: ${recipientId}`,
        );
      }

      const recipientData = recipientDoc.data();
      if (!recipientData) {
        throw new HttpsError(
          "internal",
          "수신자 데이터를 읽을 수 없습니다",
        );
      }

      const recipientGroups = Object.keys(recipientData.groups || {});
      const hasCommonGroup = senderGroups.some(
        (groupId) => recipientGroups.includes(groupId)
      );

      if (!hasCommonGroup) {
        throw new HttpsError(
          "permission-denied",
          `같은 그룹에 속하지 않은 사용자에게 알림을 보낼 수 없습니다: ${recipientId}`,
        );
      }
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
}): Promise<SendPushNotificationResponse> {
  const {userIds, type, title, body, promiseId, groupId,
    relatedUserId, data} = params;

  const db = admin.firestore();
  const usersCollection = db.collection("users");
  const notificationsCollection = db.collection("notifications");

  // 1. Firestore에 알림 기록 저장 (항상 실행, 설정과 무관)
  // Firestore 배치는 500개 제한이므로 청크 단위로 처리
  const now = FieldValue.serverTimestamp();
  const notificationRefs: Map<string, FirebaseFirestore.DocumentReference> =
    new Map();

  const chunkSize = 500;
  for (let i = 0; i < userIds.length; i += chunkSize) {
    const chunk = userIds.slice(i, i + chunkSize);
    const batch = db.batch();

    for (const userId of chunk) {
      const notificationDoc: Omit<NotificationDocument, "createdAt" |
        "readAt" | "deliveredAt"> & {
        createdAt: FirebaseFirestore.FieldValue;
        readAt: null;
        deliveredAt: null;
      } = {
        userId,
        type,
        title,
        body,
        promiseId,
        groupId,
        relatedUserId,
        isRead: false,
        isDelivered: false, // 기본값, FCM 전송 성공 시 업데이트
        createdAt: now,
        readAt: null,
        deliveredAt: null,
        data: data,
      };

      const notificationRef = notificationsCollection.doc();
      notificationRefs.set(userId, notificationRef);
      batch.set(notificationRef, notificationDoc);
    }

    await batch.commit();
  }
  console.log(`📝 Notifications saved for ${userIds.length} users`);

  // 2. 각 사용자의 FCM 토큰 수집 (알림 설정 체크 포함)
  const allTokens: string[] = [];
  const userTokenMap: Map<string, string[]> = new Map();

  for (const userId of userIds) {
    try {
      const userDoc = await usersCollection.doc(userId).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data();
      const groups = userData?.groups as {
        [key: string]: {
          notifications?: { enabled?: boolean };
          notificationPreferences?: { [key: string]: boolean };
        };
      } | undefined;

      if (groupId) {
        const groupSettings = groups?.[groupId];
        if (!groupSettings) continue;

        const notificationsEnabled = notificationSettingsEnabled(
          groupSettings.notifications
        );
        if (!notificationsEnabled) continue;

        const legacyPreferences = groupSettings.notificationPreferences as
          { [key: string]: boolean } | undefined;
        if (!notificationPreferenceEnabled({
          type,
          settings: groupSettings.notifications,
          legacyPreferences,
        })) {
          continue;
        }
      }

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

  // 3. 토큰이 없으면 푸시 전송 스킵 (알림은 이미 저장됨)
  if (allTokens.length === 0) {
    console.log("📭 No FCM tokens found, notifications already saved");
    return {
      success: true,
      successCount: 0,
      failureCount: 0,
    };
  }

  // 4. FCM 멀티캐스트 전송
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
          // TODO: 읽지 않은 알림 수로 동적 계산 필요
          // badge: 1,
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

  // 5. FCM 전송 성공한 사용자의 알림 isDelivered 업데이트
  // 업데이트할 문서 참조 수집
  const refsToUpdate: FirebaseFirestore.DocumentReference[] = [];

  for (const [userId, tokens] of userTokenMap) {
    const delivered = tokens.some((token) => deliveredTokens.has(token));
    if (delivered) {
      const ref = notificationRefs.get(userId);
      if (ref) {
        refsToUpdate.push(ref);
      }
    }
  }

  // Firestore 배치는 500개 제한이므로 청크 단위로 처리
  if (refsToUpdate.length > 0) {
    for (let i = 0; i < refsToUpdate.length; i += chunkSize) {
      const chunk = refsToUpdate.slice(i, i + chunkSize);
      const updateBatch = db.batch();

      for (const ref of chunk) {
        updateBatch.update(ref, {
          isDelivered: true,
          deliveredAt: now,
        });
      }

      await updateBatch.commit();
    }
    console.log(
      `✅ Updated isDelivered for ${refsToUpdate.length} notifications`
    );
  }

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
    document: "promises/{promiseId}",
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

    const groupId = promiseData.groupId as string;
    const hostId = promiseData.hostId as string;
    const title = promiseData.title as string;
    const notificationMethod =
      (promiseData.notificationMethod as string) || "pushNotification";

    console.log(
      `📅 Promise created: ${promiseId} ` +
      `(notification: ${notificationMethod})`
    );

    // 라이브액티비티 선택 시 푸시 알림 건너뛰기
    // (startVoteLiveActivity가 별도로 LiveActivity 시작)
    if (notificationMethod === "liveActivity") {
      console.log("LiveActivity selected, skip push");
      return;
    }

    // 없음 선택 시 알림 건너뛰기
    if (notificationMethod === "none") {
      console.log("No notification selected, skip");
      return;
    }

    // 그룹 멤버 조회
    const db = admin.firestore();
    const groupsCollection = db.collection("groups");
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
    const usersCollection = db.collection("users");
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
    document: "promises/{promiseId}",
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
    const groupsCollection = db.collection("groups");

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
      const dateTimeString = formatDateTime(startDate);

      await sendPushNotificationInternal({
        userIds: afterAccepted,
        type: NotificationType.PromiseConfirmed,
        title: `${title} 약속 확정! 🎉`,
        body: `${dateTimeString}에 만나요!`,
        promiseId,
        groupId,
        relatedUserId: null,
        data: null,
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
          title: `${title} 약속 무산 😢`,
          body: "참여 인원이 부족해서 확정되지 않았어요",
          promiseId,
          groupId,
          relatedUserId: null,
          data: null,
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
    document: "groups/{groupId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      return;
    }

    const groupId = event.params.groupId;

    const beforeMembers = new Set(beforeData.memberIds as string[] || []);
    const afterMembers = afterData.memberIds as string[] || [];

    // 새로 참여한 멤버 찾기
    const newMembers = afterMembers.filter((id) => !beforeMembers.has(id));

    if (newMembers.length === 0) {
      return; // 새 멤버 없음
    }

    const groupName = afterData.name as string || "그룹";
    const db = admin.firestore();
    const usersCollection = db.collection("users");

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
      });
    }
  },
);

/**
 * 약속 정보 수정 시 참가자에게 알림
 *
 * @remarks
 * promises/{promiseId} 문서의 주요 정보가 변경되면 트리거됩니다.
 * - 제목, 시간, 장소, 설명, 최소인원 변경 감지
 * - 수락한 참가자들에게 알림 전송
 */
export const onPromiseInfoUpdated = onDocumentUpdated(
  {
    document: "promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const beforeData = event.data?.before.data();
    const afterData = event.data?.after.data();

    if (!beforeData || !afterData) {
      return;
    }

    const promiseId = event.params.promiseId;

    // 주요 필드 변경 감지
    const fieldsToCheck = [
      "title",
      "startAt",
      "location",
      "description",
      "minimumParticipants",
    ];

    const hasChanges = fieldsToCheck.some((field) => {
      const before = JSON.stringify(beforeData[field]);
      const after = JSON.stringify(afterData[field]);
      return before !== after;
    });

    if (!hasChanges) {
      return; // 주요 정보 변경 없음
    }

    // 수락한 참가자들에게 알림
    const afterVotes = afterData.votes || {accepted: []};
    const acceptedUsers = (afterVotes.accepted as string[]) || [];
    const title = afterData.title as string;
    const groupId = afterData.groupId as string;

    if (acceptedUsers.length === 0) {
      return; // 수락자 없음
    }

    console.log(`📝 Promise info updated: ${promiseId}`);

    await sendPushNotificationInternal({
      userIds: acceptedUsers,
      type: NotificationType.PromiseUpdated,
      title: `${title} 변경 📝`,
      body: "약속 정보가 수정됐어요. 확인해주세요!",
      promiseId,
      groupId,
      relatedUserId: null,
      data: null,
    });
  },
);
