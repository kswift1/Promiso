/**
 * Briefing Scheduler Functions
 *
 * 매 시간 정각 실행 → Pro 유저의 브리핑 알림 시간 매칭 → 브리핑 생성 + FCM 푸시
 *
 * @added 2026-03-07
 */
import {FieldValue} from "firebase-admin/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {getFunctions} from "firebase-admin/functions";
import {
  admin, REGION, GEMINI_API_KEY, KMA_API_KEY,
  ODSAY_API_KEY, KAKAO_REST_API_KEY,
} from "../config";
import {generateBriefingInternal} from "./briefing";
import {DeviceInfo} from "../types/api";
import {isEntitlementOverrideActive} from "../utils/helpers";
import {
  BRIEFING_SUBSCRIPTIONS_COLLECTION,
  BriefingTaskPayload,
  buildScheduledBriefingTaskFromProjection,
  computeNextDispatchAt,
  isCurrentBriefingTaskEligible,
} from "../utils/briefingScheduler";

// MARK: - Scheduler (매 시간 정각 실행)

/**
 * 매 시간 정각에 실행되는 브리핑 디스패처
 *
 * 1. briefingSubscriptions projection에서 지금 due인 유저 조회
 * 2. due 문서별 Cloud Task enqueue
 * 3. 성공한 문서는 다음 dispatch 시각으로 advance
 */
export const scheduledBriefingDispatch = onSchedule(
  {
    schedule: "0 * * * *", // 매 시간 정각
    region: REGION,
    timeZone: "UTC",
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const currentUtcHour = now.getUTCHours();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

    console.log(
      `[BriefingScheduler] Dispatch started at UTC ${currentUtcHour}:00`
    );

    const projectionSnap = await db
      .collection(BRIEFING_SUBSCRIPTIONS_COLLECTION)
      .where("nextDispatchAt", "<=", nowTimestamp)
      .get();

    if (projectionSnap.empty) {
      console.log(
        "[BriefingScheduler] No due briefing subscriptions"
      );
      return;
    }

    const dueTasks = projectionSnap.docs
      .map((doc) => {
        return buildScheduledBriefingTaskFromProjection({
          uid: doc.id,
          projectionData: doc.data(),
          now,
        });
      })
      .filter((task): task is BriefingTaskPayload => task !== null);

    console.log(
      `[BriefingScheduler] ${dueTasks.length}/${projectionSnap.size} ` +
      `projection docs are due for UTC hour ${currentUtcHour}`
    );

    if (dueTasks.length === 0) return;

    // Cloud Tasks에 enqueue
    const queue = getFunctions().taskQueue<BriefingTaskPayload>(
      `locations/${REGION}/functions/executeBriefingNotification`
    );

    let enqueued = 0;
    for (const payload of dueTasks) {
      try {
        await queue.enqueue(payload);
        await advanceNextDispatch(payload.uid, payload, now);
        enqueued++;
      } catch (error) {
        console.error(
          `[BriefingScheduler] Failed to enqueue task for ${payload.uid}:`,
          error
        );
      }
    }

    console.log(
      `[BriefingScheduler] Enqueued ${enqueued}/${dueTasks.length} tasks`
    );
  }
);

// MARK: - Task Handler (개별 유저 브리핑 생성 + 푸시)

/**
 * Cloud Tasks에서 실행되는 개별 브리핑 생성 + FCM 푸시 전송
 *
 * 1. generateBriefingInternal로 브리핑 생성 (캐시 활용)
 * 2. 생성된 summary를 FCM 푸시 알림으로 전송
 */
export const executeBriefingNotification =
  onTaskDispatched<BriefingTaskPayload>(
    {
      region: REGION,
      secrets: [GEMINI_API_KEY, KMA_API_KEY, ODSAY_API_KEY, KAKAO_REST_API_KEY],
      retryConfig: {
        maxAttempts: 2,
        minBackoffSeconds: 30,
      },
      rateLimits: {
        maxConcurrentDispatches: 10,
        maxDispatchesPerSecond: 5,
      },
    },
    async (req) => {
      const {uid, timezone, language, style, defaultLocation} = req.data;

      console.log(
        `[BriefingNotification] Starting for uid=${uid}, ` +
      `tz=${timezone}, style=${style}`
      );

      try {
        const [settingsData, entitlement] = await Promise.all([
          loadUserSettings(uid),
          loadEntitlementState(uid),
        ]);

        if (!isCurrentBriefingTaskEligible({
          payload: req.data,
          settingsData,
          subscriptionStatus: entitlement.subscriptionStatus,
          overrideActive: entitlement.overrideActive,
        })) {
          console.log(
            `[BriefingNotification] Skipped stale or ineligible task for ${uid}`
          );
          return;
        }

        // 1. 브리핑 생성 (기본 위치 사용 — 설정된 경우)
        const briefing = await generateBriefingInternal({
          uid,
          timezone,
          language,
          location: defaultLocation,
          forceRefresh: false,
          style,
        });

        console.log(
          `[BriefingNotification] uid=${uid}, summary="${briefing.summary}"`
        );

        // 2. FCM 푸시 전송
        await sendBriefingPush(uid, briefing.summary, briefing.detail);

        console.log(`[BriefingNotification] uid=${uid}, push sent`);
      } catch (error) {
        console.error(
          `[BriefingNotification] uid=${uid}, Error:`, error
        );
      }
    }
  );

// MARK: - Helpers

/**
 * 현재 사용자의 entitlement 상태를 읽는다.
 * @param {string} uid 사용자 ID.
 * @return {Promise<object>} subscriptionStatus와 overrideActive를 담은 결과.
 */
async function loadEntitlementState(uid: string): Promise<{
  subscriptionStatus: unknown;
  overrideActive: boolean;
}> {
  const db = admin.firestore();
  const [subscriptionSnapshot, overrideSnapshot] = await Promise.all([
    db.collection("subscriptions").doc(uid).get(),
    db.collection("entitlementOverrides").doc(uid).get(),
  ]);

  return {
    subscriptionStatus: subscriptionSnapshot.data()?.status,
    overrideActive: isEntitlementOverrideActive(overrideSnapshot.data()),
  };
}

/**
 * 사용자의 최신 설정 문서를 로드한다.
 * @param {string} uid 사용자 ID.
 * @return {Promise<Record<string, unknown> | null>} settings/main 데이터.
 */
async function loadUserSettings(
  uid: string,
): Promise<Record<string, unknown> | null> {
  const settingsDoc = await admin.firestore()
    .collection("users").doc(uid)
    .collection("settings").doc("main")
    .get();

  if (!settingsDoc.exists) {
    return null;
  }

  return (settingsDoc.data() as Record<string, unknown> | undefined) ?? null;
}

/**
 * enqueue 성공 후 projection의 다음 dispatch 시각을 갱신한다.
 * @param {string} uid 사용자 ID.
 * @param {BriefingTaskPayload} payload enqueue된 task payload.
 * @param {Date} now 현재 dispatch 시각.
 * @return {Promise<void>}
 */
async function advanceNextDispatch(
  uid: string,
  payload: BriefingTaskPayload,
  now: Date,
): Promise<void> {
  const nextDispatchAt = computeNextDispatchAt({
    now: new Date(now.getTime() + 60 * 60 * 1000),
    timezone: payload.timezone,
    notificationHour: payload.notificationHour,
  });

  const projectionRef = admin.firestore()
    .collection(BRIEFING_SUBSCRIPTIONS_COLLECTION)
    .doc(uid);

  if (!nextDispatchAt) {
    await projectionRef.delete();
    return;
  }

  await projectionRef.update({
    nextDispatchAt: admin.firestore.Timestamp.fromDate(nextDispatchAt),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

/**
 * 브리핑 요약을 FCM 푸시로 전송
 * @param {string} uid - 사용자 ID
 * @param {string} summary - 브리핑 요약 (알림 제목)
 * @param {string} detail - 브리핑 상세 내용 (알림 본문)
 * @return {Promise<void>}
 */
async function sendBriefingPush(
  uid: string,
  summary: string,
  detail: string
): Promise<void> {
  const db = admin.firestore();
  const userDoc = await db.collection("users").doc(uid).get();

  if (!userDoc.exists) {
    console.warn(`[BriefingNotification] User not found: ${uid}`);
    return;
  }

  const userData = userDoc.data();
  const devices = userData?.devices as { [key: string]: DeviceInfo } | null;

  if (!devices) {
    console.warn(`[BriefingNotification] No devices for: ${uid}`);
    return;
  }

  // FCM 토큰 수집
  const tokens: string[] = [];
  for (const deviceId of Object.keys(devices)) {
    const device = devices[deviceId];
    if (device.fcmToken) {
      tokens.push(device.fcmToken);
    }
  }

  if (tokens.length === 0) {
    console.warn(`[BriefingNotification] No FCM tokens for: ${uid}`);
    return;
  }

  // FCM 멀티캐스트 전송
  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title: summary,
      body: detail,
    },
    data: {
      type: "daily_briefing",
    },
    apns: {
      payload: {
        aps: {
          "sound": "default",
          "interruption-level": "time-sensitive",
        },
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(
      `[BriefingNotification] uid=${uid}, ` +
      `sent=${response.successCount}, failed=${response.failureCount}`
    );
  } catch (error) {
    console.error(`[BriefingNotification] FCM error for ${uid}:`, error);
  }
}
