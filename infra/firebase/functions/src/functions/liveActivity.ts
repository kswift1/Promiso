/**
 * LiveActivity Functions
 *
 * iOS LiveActivity (Dynamic Island, Lock Screen) 관련 Cloud Functions
 *
 * @why 약속 시간 전 실시간 위치/ETA 공유로 지각 방지
 * @ios LiveActivityManager, PromiseWidgetExtension
 * @see ARCHITECTURE.md - ADR-001: iOS 18 Broadcast 방식 채택
 *
 * @architecture iOS 18 Broadcast Push 방식
 * 1. startLiveActivity → channelId 생성 + Push to Start
 * 2. iOS가 Activity 시작 시 채널 자동 구독
 * 3. updateETA → channelId로 Broadcast (모든 구독자 수신)
 * 4. dismissal-date로 자동 종료
 */
import {getFunctions} from "firebase-admin/functions";
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {
  admin,
  REGION,
  APNS_KEY_ID,
  APNS_TEAM_ID,
  APNS_AUTH_KEY,
  APNS_BUNDLE_ID,
} from "../config";
import {getEnvironmentCollection, getCurrentEnvironment} from "../utils/firestore";

/**
 * APNs 환경 결정
 *
 * @returns true = Production, false = Sandbox
 * @remarks Dev 환경만 Sandbox, Stage/Prod는 Production
 */
function isAPNsProduction(): boolean {
  const env = getCurrentEnvironment();
  // Dev 환경만 Sandbox (Xcode 개발 빌드용)
  // Stage/Prod는 Production (TestFlight/App Store 빌드)
  return env !== "dev";
}
import {
  sendAPNsPush,
  sendAPNsBroadcast,
  createAPNsChannel,
} from "../utils/apns";
import {
  DeviceInfo,
  LiveActivityParticipant,
  RegisterPushToStartTokenRequest,
  RegisterPushToStartTokenResponse,
  StartLiveActivityRequest,
  StartLiveActivityResponse,
  UpdateETARequest,
  UpdateETAResponse,
  ScheduledLiveActivityTaskPayload,
  ScheduledLiveActivityEndTaskPayload,
} from "../types/api";

/**
 * Push to Start 토큰 등록
 *
 * @remarks
 * **인증 필수**
 *
 * iOS 17.2+ 디바이스에서 앱 시작 시 Push to Start 토큰을 등록합니다.
 */
export const registerPushToStartToken = onCall<
  RegisterPushToStartTokenRequest
>(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request): Promise<RegisterPushToStartTokenResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {token, deviceId} = request.data;

    if (!token || !deviceId) {
      throw new HttpsError("invalid-argument", "token과 deviceId는 필수입니다");
    }

    const db = admin.firestore();
    const usersCollection = getEnvironmentCollection("users", db);

    try {
      await usersCollection.doc(userId).update({
        [`devices.${deviceId}.liveActivityPushToStartToken`]: token,
      });

      console.log(
        `✅ Push to Start 토큰 등록: userId=${userId}, deviceId=${deviceId}`,
      );
      return {success: true};
    } catch (error) {
      console.error("❌ Push to Start 토큰 등록 실패:", error);
      throw new HttpsError("internal", "토큰 등록에 실패했습니다");
    }
  },
);

/**
 * LiveActivity 시작 (Push to Start)
 *
 * @remarks
 * **인증 필수**
 *
 * 약속 참가자(accepted) 전원에게 Push to Start APNs를 전송하여
 * LiveActivity를 원격으로 시작합니다.
 */
export const startLiveActivity = onCall<StartLiveActivityRequest>(
  {
    region: REGION,
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (request): Promise<StartLiveActivityResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const userId = request.auth.uid;
    const {promiseId} = request.data;

    console.log(`📥 startLiveActivity called: promiseId="${promiseId}"`);

    if (!promiseId) {
      throw new HttpsError("invalid-argument", "promiseId는 필수입니다");
    }

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db);
    const usersCollection = getEnvironmentCollection("users", db);
    const groupsCollection = getEnvironmentCollection("groups", db);

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      throw new HttpsError("not-found", "약속을 찾을 수 없습니다");
    }

    const promiseData = promiseDoc.data()!;
    const groupId = promiseData.groupId as string;
    const hostId = promiseData.hostId as string;
    const title = promiseData.title as string;
    const emoji = promiseData.emoji as string || "📅";
    const location = promiseData.location?.name as string || null;
    const startAt = promiseData.startAt as FirebaseFirestore.Timestamp;
    const acceptedUserIds = promiseData.votes?.accepted as string[] || [];
    const trackingMinutes =
      (promiseData.trackingStartMinutesBefore as number) || 30;

    // 2. 권한 확인 (호스트만 시작 가능)
    if (userId !== hostId) {
      throw new HttpsError(
        "permission-denied",
        "호스트만 LiveActivity를 시작할 수 있습니다",
      );
    }

    // 3. 그룹 조회 후 멤버 ID 및 그룹 정보 확인
    const groupDoc = await groupsCollection.doc(groupId).get();
    const groupData = groupDoc.data();
    const memberIds = groupData?.memberIds as string[] || [];
    const groupName = groupData?.name as string || null;
    const groupImageUrl = groupData?.imageUrl as string || null;

    // 4. 참가자 정보 및 토큰 배치 조회 (최적화: 1회로 통합)
    const batchSize = 10;
    const participants: LiveActivityParticipant[] = [];
    const allTokens: {userId: string; token: string}[] = [];
    let hostName: string | null = null;

    // 호스트 + 참가자 한번에 조회 (배치)
    const userIdSet = new Set([hostId, ...acceptedUserIds, ...memberIds]);
    const allUserIds = Array.from(userIdSet);
    for (let i = 0; i < allUserIds.length; i += batchSize) {
      const batch = allUserIds.slice(i, i + batchSize);
      const userRefs = batch.map((uid) => usersCollection.doc(uid));
      const userDocs = await db.getAll(...userRefs);

      for (const userDoc of userDocs) {
        if (!userDoc.exists) continue;

        const uid = userDoc.id;
        const userData = userDoc.data()!;
        const nickname = userData.nickname as string || "참가자";

        // 호스트 이름 추출
        if (uid === hostId) {
          hostName = nickname;
        }

        // 참가자 정보 생성
        if (acceptedUserIds.includes(uid)) {
          participants.push({
            id: uid,
            name: nickname,
            estimatedArrivalMinutes: null,
          });
        }

        // 그룹 멤버의 토큰 수집
        if (memberIds.includes(uid)) {
          type DevicesMap = {[key: string]: DeviceInfo} | null;
          const devices = userData.devices as DevicesMap;
          if (devices) {
            for (const deviceId of Object.keys(devices)) {
              const device = devices[deviceId];
              if (device.liveActivityPushToStartToken) {
                allTokens.push({
                  userId: uid,
                  token: device.liveActivityPushToStartToken,
                });
              }
            }
          }
        }
      }
    }

    if (allTokens.length === 0) {
      console.log("📭 No Push to Start tokens found");
      return {
        success: true,
        successCount: 0,
        failureCount: acceptedUserIds.length,
      };
    }

    console.log(
      `📊 Batch query: ${participants.length} participants, ` +
      `${allTokens.length} tokens`
    );

    // 5. APNs Push to Start 전송
    const isProduction = isAPNsProduction();
    const trackingDurationMinutes = trackingMinutes;

    let successCount = 0;
    let failureCount = 0;

    // 첫 번째 payload만 로그 (디버깅용)
    const firstToken = allTokens[0];
    const samplePayload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "start",
        "attributes-type": "PromiseActivityAttributes",
        "attributes": {
          trackingDurationMinutes,
          promiseId,
          currentUserId: firstToken.userId,
          emoji,
          title,
          location,
          scheduledTime: startAt.toDate().getTime() / 1000,
          hostId,
          hostName,
        },
        "content-state": {
          trackingDurationMinutes,
          participants,
        },
      },
    };
    console.log("📦 APNs Payload Sample:");
    console.log(JSON.stringify(samplePayload, null, 2));
    console.log(`🔑 Token sample: ${firstToken.token.substring(0, 20)}...`);
    console.log(`🌐 Environment: ${isProduction ? "PRODUCTION" : "SANDBOX"}`);
    console.log(`📱 Topic: ${APNS_BUNDLE_ID}.push-type.liveactivity`);

    for (const {userId: tokenUserId, token} of allTokens) {
      // 각 사용자별로 currentUserId를 다르게 설정
      const payload = {
        aps: {
          "timestamp": Math.floor(Date.now() / 1000),
          "event": "start",
          "attributes-type": "PromiseActivityAttributes",
          "attributes": {
            trackingDurationMinutes,
            promiseId,
            currentUserId: tokenUserId,
            emoji,
            title,
            location,
            scheduledTime: startAt.toDate().getTime() / 1000,
            hostId,
            hostName,
            groupName,
            groupImageUrl,
          },
          "content-state": {
            trackingDurationMinutes,
            participants,
          },
          "alert": {
            "title": `${emoji} ${title}`,
            "body": "실시간 공유가 시작되었습니다",
          },
        },
      };

      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
        console.log(`✅ APNs success for ${tokenUserId}`);
      } else {
        failureCount++;
        console.log(`❌ APNs failed for ${tokenUserId}: ${result.error}`);
      }
    }

    console.log(
      `📤 LiveActivity started: ${successCount}/${failureCount}`
    );
    return {success: true, successCount, failureCount};
  },
);

/**
 * ETA 업데이트 (iOS 18 Broadcast 방식)
 *
 * @remarks
 * **인증 필수**
 *
 * Firestore 사용 없이 클라이언트에서 전달받은 channelId + participants로 Broadcast만 전송.
 * 클라이언트가 현재 LiveActivity 상태를 직접 전달합니다.
 */
export const updateETA = onCall<UpdateETARequest>(
  {region: REGION, secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY]},
  async (request): Promise<UpdateETAResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }

    const {
      promiseId, channelId, participants, trackingDurationMinutes,
    } = request.data;

    if (!channelId || !participants) {
      throw new HttpsError(
        "invalid-argument",
        "channelId와 participants는 필수입니다"
      );
    }

    console.log(
      `📱 ETA update: ch=${channelId}, cnt=${participants.length}, ` +
      `duration=${trackingDurationMinutes}`
    );

    // 도착 상태 분석 (0 = 도착, null = 대기, >0 = 이동중)
    const currentUserId = request.auth.uid;
    type Participant = {id: string; estimatedArrivalMinutes: number | null};
    const arrivedParticipants = participants.filter(
      (p: Participant) => p.estimatedArrivalMinutes === 0
    );
    const arrivedCount = arrivedParticipants.length;
    const totalCount = participants.length;

    // 현재 사용자가 방금 도착했는지 확인
    const currentUserJustArrived = arrivedParticipants.some(
      (p: Participant) => p.id === currentUserId
    );

    // alert 조건 판단
    let alert: {title: string; body: string} | undefined;
    let shouldScheduleEnd = false;

    if (arrivedCount === 1 && totalCount > 1 && currentUserJustArrived) {
      // 첫 번째 도착 (본인이 도착을 찍은 경우만)
      alert = {
        title: "🎉 첫 도착!",
        body: "가장 먼저 도착했어요!",
      };
      console.log("🎉 First arrival detected");
    } else if (arrivedCount === totalCount && totalCount > 1) {
      // 모두 도착 - 5분 후 종료 예약
      alert = {
        title: "✅ 모두 도착!",
        body: "모든 멤버들이 도착했어요! 잠시 후 종료됩니다",
      };
      shouldScheduleEnd = true;
      console.log(`🎊 All arrived (${totalCount} members), scheduling end`);
    }

    // Firestore 없이 바로 APNs Broadcast 전송
    const isProduction = isAPNsProduction();

    const payload: any = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "update",
        "content-state": {
          trackingDurationMinutes: trackingDurationMinutes || 30,
          participants,
        },
      },
    };

    // alert가 있으면 추가
    if (alert) {
      payload.aps.alert = alert;
    }

    const result = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    // 모두 도착 시 종료 Task 예약 (5분)
    if (shouldScheduleEnd) {
      type EndPayload = ScheduledLiveActivityEndTaskPayload;
      const endQueue = getFunctions().taskQueue<EndPayload>(
        `locations/${REGION}/functions/executeLiveActivityEnd`
      );

      const endDelayMinutes = 5;
      await endQueue.enqueue(
        {
          promiseId: promiseId || "unknown",
          channelId,
        },
        {scheduleDelaySeconds: endDelayMinutes * 60}
      );

      const id = promiseId || channelId;
      console.log(`📅 LiveActivity end scheduled (all arrived): ${id}`);
    }

    if (result.success) {
      console.log(`📤 ETA Broadcast sent: channelId=${channelId}`);
      return {success: true, successCount: 1, failureCount: 0};
    } else {
      console.log(`❌ ETA Broadcast failed: ${result.error}`);
      return {success: false, successCount: 0, failureCount: 1};
    }
  },
);

/**
 * Widget 전용 ETA 업데이트 (onRequest)
 *
 * @remarks
 * Widget Extension은 Firebase SDK를 사용할 수 없어서 별도의 HTTP 엔드포인트 필요.
 * Firestore 사용 없이 클라이언트에서 전달받은 데이터로 Broadcast만 전송.
 *
 * **Endpoint URL**: https://widgetupdateeta-dfaqqrbqgq-du.a.run.app
 *
 * **Headers**:
 * - X-User-Id: 사용자 ID (필수)
 * - X-Auth-Token: Firebase ID Token (선택적)
 *
 * **Request Body**:
 * ```json
 * {
 *   "promiseId": "promise_abc123",
 *   "channelId": "ch_abc123",
 *   "participants": [{"id": "...", "name": "...", "eta": 5}],
 *   "trackingDurationMinutes": 30
 * }
 * ```
 */
export const widgetUpdateETA = onRequest(
  {region: REGION, secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY]},
  async (req, res) => {
    // CORS 헤더
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, X-User-Id, X-Auth-Token"
    );

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({
        error: {code: "method-not-allowed", message: "Method not allowed"},
      });
      return;
    }

    // 헤더에서 인증 정보 추출
    const userId = req.headers["x-user-id"] as string;
    const authToken = req.headers["x-auth-token"] as string;

    if (!userId) {
      res.status(401).json({
        error: {
          code: "unauthenticated",
          message: "X-User-Id header is required",
        },
      });
      return;
    }

    // authToken 검증 (선택적 - 토큰이 있으면 검증)
    if (authToken) {
      try {
        const decodedToken = await admin.auth().verifyIdToken(authToken);
        if (decodedToken.uid !== userId) {
          res.status(401).json({
            error: {code: "unauthenticated", message: "Token uid mismatch"},
          });
          return;
        }
      } catch (error) {
        console.warn(`⚠️ Widget auth token verification failed: ${error}`);
        // 토큰 만료 등의 경우 userId만으로 진행 (Widget 특성상 허용)
      }
    }

    const {
      promiseId, channelId, participants, trackingDurationMinutes,
    } = req.body;

    if (!channelId || !participants) {
      res.status(400).json({
        error: {
          code: "invalid-argument",
          message: "channelId and participants are required",
        },
      });
      return;
    }

    console.log(
      `📱 Widget ETA: u=${userId}, ch=${channelId}, cnt=${participants.length}`
    );

    // 도착 상태 분석 (0 = 도착, null = 대기, >0 = 이동중)
    type Participant = {id: string; estimatedArrivalMinutes: number | null};
    const arrivedParticipants = participants.filter(
      (p: Participant) => p.estimatedArrivalMinutes === 0
    );
    const arrivedCount = arrivedParticipants.length;
    const totalCount = participants.length;

    // 현재 사용자(위젯 호출자)가 방금 도착했는지 확인
    const currentUserJustArrived = arrivedParticipants.some(
      (p: Participant) => p.id === userId
    );

    // alert 조건 판단
    let alert: {title: string; body: string} | undefined;
    let shouldScheduleEnd = false;

    if (arrivedCount === 1 && totalCount > 1 && currentUserJustArrived) {
      // 첫 번째 도착 (본인이 도착을 찍은 경우만)
      alert = {
        title: "🎉 첫 도착!",
        body: "가장 먼저 도착했어요!",
      };
      console.log("🎉 Widget: First arrival detected");
    } else if (arrivedCount === totalCount && totalCount > 1) {
      // 모두 도착 - 종료 예약
      alert = {
        title: "✅ 모두 도착!",
        body: "모든 멤버들이 도착했어요! 잠시 후 종료됩니다",
      };
      shouldScheduleEnd = true;
      console.log(`🎊 Widget: All arrived (${totalCount} members)`);
    }

    // Firestore 없이 바로 APNs Broadcast 전송
    const isProduction = isAPNsProduction();

    const payload: any = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "update",
        "content-state": {
          trackingDurationMinutes: trackingDurationMinutes || 30,
          participants,
        },
      },
    };

    // alert가 있으면 추가
    if (alert) {
      payload.aps.alert = alert;
    }

    const result = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    // 모두 도착 시 종료 Task 예약 (5분)
    if (shouldScheduleEnd) {
      type EndPayload = ScheduledLiveActivityEndTaskPayload;
      const endQueue = getFunctions().taskQueue<EndPayload>(
        `locations/${REGION}/functions/executeLiveActivityEnd`
      );

      const endDelayMinutes = 5;
      await endQueue.enqueue(
        {
          promiseId: promiseId || "unknown",
          channelId,
        },
        {scheduleDelaySeconds: endDelayMinutes * 60}
      );

      const id = promiseId || channelId;
      console.log(`📅 Widget: LiveActivity end scheduled: ${id}`);
    }

    if (result.success) {
      console.log(`📤 Widget ETA Broadcast sent: channelId=${channelId}`);
      res.status(200).json({success: true});
    } else {
      console.log(`❌ Widget ETA Broadcast failed: ${result.error}`);
      res.status(200).json({success: false, error: result.error});
    }
  }
);

// ============================================================================
// Cloud Tasks - LiveActivity 예약 실행
// ============================================================================

/**
 * LiveActivity 예약 시작 태스크 핸들러 (iOS 18 Broadcast 방식)
 *
 * @remarks
 * Cloud Tasks에 의해 예약된 시간에 자동 실행됩니다.
 * 약속 시간 N분 전에 모든 참가자에게 LiveActivity를 시작합니다.
 */
export const executeLiveActivityStart = onTaskDispatched<
  ScheduledLiveActivityTaskPayload
>(
  {
    region: REGION,
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (req) => {
    const {promiseId} = req.data;
    console.log(`⏰ Scheduled LiveActivity start: ${promiseId}`);

    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db);
    const usersCollection = getEnvironmentCollection("users", db);

    // 1. 약속 정보 조회
    const promiseDoc = await promisesCollection.doc(promiseId).get();
    if (!promiseDoc.exists) {
      console.warn(`Promise not found: ${promiseId}`);
      return;
    }

    const promiseData = promiseDoc.data()!;
    const hostId = promiseData.hostId as string;
    const groupId = promiseData.groupId as string;
    const emoji = promiseData.emoji as string || "📌";
    const title = promiseData.title as string;
    const location = promiseData.location?.name as string || null;
    const startAt = promiseData.startAt as admin.firestore.Timestamp;
    const accepted = promiseData.votes?.accepted as string[] || [];
    const minParticipants = promiseData.minimumParticipants as number || 2;
    const trackingMinutes =
      (promiseData.trackingStartMinutesBefore as number) || 30;

    // 2. 그룹 정보 조회
    const groupsCollection = getEnvironmentCollection("groups", db);
    const groupDoc = await groupsCollection.doc(groupId).get();
    const groupData = groupDoc.data();
    const groupName = groupData?.name as string || null;
    const groupImageUrl = groupData?.imageUrl as string || null;

    // 3. 약속이 확정 상태인지 확인
    if (accepted.length < minParticipants) {
      console.log(`Promise not confirmed: ${promiseId}`);
      return;
    }

    // 4. 참가자 정보 및 토큰 배치 조회 (최적화: 1회로 통합)
    // Firestore getAll()로 최대 10개씩 배치 조회 가능
    const batchSize = 10;
    const participants: LiveActivityParticipant[] = [];
    const allTokens: {userId: string; token: string}[] = [];
    let hostName: string | null = null;

    // 호스트 + 참가자 한번에 조회 (배치, 중복 제거)
    const allUserIds = Array.from(new Set([hostId, ...accepted]));
    for (let i = 0; i < allUserIds.length; i += batchSize) {
      const batch = allUserIds.slice(i, i + batchSize);
      const userRefs = batch.map((uid) => usersCollection.doc(uid));
      const userDocs = await db.getAll(...userRefs);

      for (const userDoc of userDocs) {
        if (!userDoc.exists) continue;

        const uid = userDoc.id;
        const userData = userDoc.data()!;
        const nickname = userData.nickname as string || "참가자";

        // 호스트 이름 추출
        if (uid === hostId) {
          hostName = nickname;
        }

        // 참가자 정보 생성
        if (accepted.includes(uid)) {
          participants.push({
            id: uid,
            name: nickname,
            estimatedArrivalMinutes: null,
          });

          // 토큰 수집
          type DevicesMap = {[key: string]: DeviceInfo} | null;
          const devices = userData.devices as DevicesMap;
          if (devices) {
            for (const deviceId of Object.keys(devices)) {
              const device = devices[deviceId];
              if (device.liveActivityPushToStartToken) {
                allTokens.push({
                  userId: uid,
                  token: device.liveActivityPushToStartToken,
                });
              }
            }
          }
        }
      }
    }

    // 5. iOS 18 Broadcast 채널 생성 (Apple이 channelId 생성)
    const isProduction = isAPNsProduction();
    const channelResult = await createAPNsChannel(isProduction);
    let channelId: string | undefined;

    if (channelResult.success && channelResult.channelId) {
      channelId = channelResult.channelId;
      console.log(`✅ APNs channel created: ${channelId}`);
    } else {
      console.error(`❌ Channel creation failed: ${channelResult.error}`);
      // 채널 없이는 Broadcast 불가 → Push to Start 중단
      console.error(`⚠️ Aborting Push to Start: ${promiseId}`);
      return;
    }

    const trackingDurationMinutes = trackingMinutes;

    // 6. 토큰 검증
    if (allTokens.length === 0) {
      console.log(`📭 No Push to Start tokens for: ${promiseId}`);
      return;
    }

    console.log(
      `📊 Batch query: ${participants.length} participants, ` +
      `${allTokens.length} tokens`
    );

    // 7. APNs Push to Start 전송
    // 각 사용자에게 개별 Push to Start 전송 (Activity 시작 시 채널 구독됨)
    let successCount = 0;
    let failureCount = 0;

    for (const {userId: tokenUserId, token} of allTokens) {
      const payload = {
        aps: {
          "timestamp": Math.floor(Date.now() / 1000),
          "event": "start",
          "input-push-channel": channelId || "", // iOS 18 채널 구독
          "attributes-type": "PromiseActivityAttributes",
          "attributes": {
            trackingDurationMinutes,
            promiseId,
            currentUserId: tokenUserId,
            emoji,
            title,
            location,
            scheduledTime: startAt.toDate().getTime() / 1000,
            hostId,
            hostName,
            channelId: channelId || "",
            groupName,
            groupImageUrl,
          },
          "content-state": {
            trackingDurationMinutes,
            participants,
          },
          "alert": {
            "title": `${emoji} ${title}`,
            "body": "실시간 공유가 시작되었습니다",
          },
        },
      };

      const result = await sendAPNsPush({
        deviceToken: token,
        payload,
        pushType: "liveactivity",
        topic: `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        priority: 10,
        isProduction,
      });

      if (result.success) {
        successCount++;
      } else {
        failureCount++;
      }
    }

    console.log(
      `⏰ Scheduled LiveActivity started (Broadcast channel: ${channelId}): ` +
      `${successCount}/${failureCount}`
    );

    // 8. 종료 Task 예약 (30분)
    const endMinutes = 30;
    const endTime = startAt.toDate().getTime() + endMinutes * 60 * 1000;
    const endDelaySeconds = Math.max(
      0,
      Math.floor((endTime - Date.now()) / 1000)
    );

    type EndPayload = ScheduledLiveActivityEndTaskPayload;
    const endQueue = getFunctions().taskQueue<EndPayload>(
      `locations/${REGION}/functions/executeLiveActivityEnd`
    );

    await endQueue.enqueue(
      {promiseId, channelId: channelId || ""},
      {scheduleDelaySeconds: endDelaySeconds}
    );

    console.log(
      `📅 LiveActivity end scheduled: ${promiseId} in ${endDelaySeconds}s`
    );
  }
);

/**
 * LiveActivity 종료 태스크 핸들러
 *
 * @remarks
 * Cloud Tasks에 의해 예약된 시간에 자동 실행됩니다.
 * 약속 시간 + 30분 또는 모두 도착 + 5분에 LiveActivity를 종료합니다.
 */
export const executeLiveActivityEnd = onTaskDispatched<
  ScheduledLiveActivityEndTaskPayload
>(
  {
    region: REGION,
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 10,
    },
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
    secrets: [APNS_KEY_ID, APNS_TEAM_ID, APNS_AUTH_KEY],
  },
  async (req) => {
    const {promiseId, channelId} = req.data;
    console.log(`⏰ Scheduled LiveActivity end: ${promiseId}`);

    if (!channelId) {
      console.error(`❌ channelId missing for end task: ${promiseId}`);
      return;
    }

    const isProduction = isAPNsProduction();

    // end 이벤트 전송 (dismissal-date는 과거로 설정하여 즉시 제거)
    const payload = {
      aps: {
        "timestamp": Math.floor(Date.now() / 1000),
        "event": "end",
        "dismissal-date": Math.floor(Date.now() / 1000) - 60, // 과거 시간 (즉시 제거)
        "content-state": {
          trackingDurationMinutes: 30,
          participants: [],
        },
      },
    };

    const result = await sendAPNsBroadcast({
      channelId,
      payload,
      isProduction,
    });

    if (result.success) {
      console.log(`✅ LiveActivity ended: ${promiseId}`);
    } else {
      console.error(`❌ LiveActivity end failed: ${promiseId}, ${result.error}`);
    }
  }
);

/**
 * 약속 확정 또는 실시간 공유 설정 변경 시 LiveActivity 예약
 *
 * @remarks
 * 다음 경우에 Cloud Task를 예약합니다:
 * 1. 약속이 확정됨 (accepted >= minimumParticipants) + trackingMinutes 설정됨
 * 2. 이미 확정된 약속에서 trackingStartMinutesBefore가 변경됨
 */
export const onPromiseConfirmedScheduleLiveActivity = onDocumentUpdated(
  {
    document: "promises/{promiseId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const promiseId = event.params.promiseId;

    if (!before || !after) return;

    const minParticipants = after.minimumParticipants as number || 2;
    const beforeAccepted = before.votes?.accepted as string[] || [];
    const afterAccepted = after.votes?.accepted as string[] || [];
    const beforeTrackingMinutes =
      before.trackingStartMinutesBefore as number | null;
    const afterTrackingMinutes =
      after.trackingStartMinutesBefore as number | null;
    const startAt = after.startAt as admin.firestore.Timestamp;

    // 확정 상태 확인
    const wasConfirmed = beforeAccepted.length >= minParticipants;
    const isNowConfirmed = afterAccepted.length >= minParticipants;

    // trackingMinutes 변경 확인
    const trackingMinutesChanged =
      beforeTrackingMinutes !== afterTrackingMinutes;

    // 스케줄링이 필요한 조건:
    // 1. 새로 확정됨 (미확정 → 확정) + trackingMinutes 설정됨
    // 2. 이미 확정 + trackingMinutes가 null → 값으로 변경됨
    // 3. 이미 확정 + trackingMinutes 값이 변경됨
    const justConfirmed = !wasConfirmed && isNowConfirmed;
    const trackingEnabledOnConfirmed =
      isNowConfirmed && trackingMinutesChanged && afterTrackingMinutes !== null;

    const shouldSchedule = justConfirmed || trackingEnabledOnConfirmed;

    if (!shouldSchedule) {
      return;
    }

    // trackingStartMinutesBefore가 설정되지 않으면 예약 안함
    if (!afterTrackingMinutes) {
      console.log(`📭 No tracking schedule for: ${promiseId}`);
      return;
    }

    // 예약 시간 계산
    const startTime = startAt.toDate();
    const scheduleTime = new Date(
      startTime.getTime() - afterTrackingMinutes * 60 * 1000
    );
    const now = new Date();

    // 약속 시작 시간이 이미 지났으면 스킵
    if (startTime <= now) {
      console.log(`⏰ Promise already started, skipping: ${promiseId}`);
      return;
    }

    // 이미 예약되었고 trackingMinutes가 변경되지 않았으면 스킵
    const wasAlreadyScheduled = after.liveActivityScheduled === true;
    if (wasAlreadyScheduled && !trackingMinutesChanged) {
      console.log(`📅 Already scheduled (no change): ${promiseId}`);
      return;
    }

    // 재스케줄링인 경우 로그
    if (wasAlreadyScheduled && trackingMinutesChanged) {
      console.log(
        `🔄 Rescheduling LiveActivity: ${promiseId} ` +
        `(${beforeTrackingMinutes}분 → ${afterTrackingMinutes}분)`
      );
    }

    // Cloud Task 예약
    const queue = getFunctions().taskQueue<ScheduledLiveActivityTaskPayload>(
      `locations/${REGION}/functions/executeLiveActivityStart`
    );

    const delaySeconds = Math.max(
      0,
      Math.floor((scheduleTime.getTime() - now.getTime()) / 1000)
    );

    await queue.enqueue(
      {promiseId},
      {scheduleDelaySeconds: delaySeconds}
    );

    // 예약 완료 표시
    const db = admin.firestore();
    const promisesCollection = getEnvironmentCollection("promises", db);
    await promisesCollection.doc(promiseId).update({
      liveActivityScheduled: true,
      liveActivityScheduledAt: scheduleTime,
    });

    const isImmediate = delaySeconds === 0;
    console.log(
      `📅 LiveActivity scheduled: ${promiseId} at ` +
      `${scheduleTime.toISOString()}${isImmediate ? " (즉시 실행)" : ""}`
    );
  }
);
