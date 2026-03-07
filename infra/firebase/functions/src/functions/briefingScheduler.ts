/**
 * Briefing Scheduler Functions
 *
 * 매 시간 정각 실행 → Pro 유저의 브리핑 알림 시간 매칭 → 브리핑 생성 + FCM 푸시
 *
 * @added 2026-03-07
 */
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {getFunctions} from "firebase-admin/functions";
import {admin, REGION, GEMINI_API_KEY, KMA_API_KEY} from "../config";
import {generateBriefingInternal} from "./briefing";
import {DeviceInfo} from "../types/api";

// MARK: - Types

interface BriefingTaskPayload {
  uid: string;
  timezone: string;
  language: string;
  style: string;
}

// MARK: - Scheduler (매 시간 정각 실행)

/**
 * 매 시간 정각에 실행되는 브리핑 디스패처
 *
 * 1. Firestore에서 Pro 유저 중 briefingNotificationHour가 설정된 유저 조회
 * 2. 현재 UTC 시간을 기준으로 각 유저의 타임존에서 해당 시간인지 확인
 * 3. 매칭되는 유저별로 Cloud Task enqueue
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

    console.log(
      `[BriefingScheduler] Dispatch started at UTC ${currentUtcHour}:00`
    );

    // briefing.notificationHour가 설정된 유저만 조회
    // (Pro 유저만 설정 가능하므로 별도 plan 체크 불필요)
    const settingsSnap = await db
      .collectionGroup("settings")
      .where(
        "proSettings.briefing.notificationHour", ">=", 0
      )
      .get();

    if (settingsSnap.empty) {
      console.log(
        "[BriefingScheduler] No users with briefing notification"
      );
      return;
    }

    const tasksToEnqueue: BriefingTaskPayload[] = [];

    for (const doc of settingsSnap.docs) {
      const data = doc.data();
      const briefing = data.proSettings?.briefing as {
        notificationHour?: number;
        timezone?: string;
        language?: string;
        style?: string;
      } | undefined;

      if (!briefing || briefing.notificationHour == null) {
        continue;
      }

      // 경로에서 uid 추출: users/{uid}/settings/main
      const pathParts = doc.ref.path.split("/");
      const uid = pathParts[1];

      const tz = briefing.timezone || "Asia/Seoul";
      const lang = briefing.language || "ko";
      const style = briefing.style || "friendly";

      // 유저의 로컬 시간 계산
      const userLocalHour = getHourInTimezone(now, tz);

      if (userLocalHour !== briefing.notificationHour) continue;

      tasksToEnqueue.push({
        uid,
        timezone: tz,
        language: lang,
        style,
      });
    }

    console.log(
      `[BriefingScheduler] ${tasksToEnqueue.length} users matched ` +
      `for UTC hour ${currentUtcHour}`
    );

    if (tasksToEnqueue.length === 0) return;

    // Cloud Tasks에 enqueue
    const queue = getFunctions().taskQueue<BriefingTaskPayload>(
      `locations/${REGION}/functions/executeBriefingNotification`
    );

    let enqueued = 0;
    for (const payload of tasksToEnqueue) {
      try {
        await queue.enqueue(payload);
        enqueued++;
      } catch (error) {
        console.error(
          `[BriefingScheduler] Failed to enqueue task for ${payload.uid}:`,
          error
        );
      }
    }

    console.log(
      `[BriefingScheduler] Enqueued ${enqueued}/${tasksToEnqueue.length} tasks`
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
      secrets: [GEMINI_API_KEY, KMA_API_KEY],
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
      const {uid, timezone, language, style} = req.data;

      console.log(
        `[BriefingNotification] Starting for uid=${uid}, ` +
      `tz=${timezone}, style=${style}`
      );

      try {
      // 1. 브리핑 생성 (location 없이 — 서버에서는 유저 위치를 모름)
        const briefing = await generateBriefingInternal({
          uid,
          timezone,
          language,
          location: null, // 스케줄러에서는 위치 정보 없음
          forceRefresh: false, // 캐시 활용
          style,
        });

        console.log(
          `[BriefingNotification] uid=${uid}, summary="${briefing.summary}"`
        );

        // 2. FCM 푸시 전송
        await sendBriefingPush(uid, briefing.summary);

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
 * 특정 타임존에서의 현재 시간(hour) 반환
 * @param {Date} date - 기준 시간
 * @param {string} timezone - 타임존 식별자
 * @return {number} 해당 타임존의 시간 (0~23)
 */
function getHourInTimezone(date: Date, timezone: string): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "numeric",
    hourCycle: "h23",
  });
  const parsed = parseInt(formatter.format(date), 10);
  if (isNaN(parsed)) {
    console.warn(
      `[BriefingScheduler] Failed to parse hour for tz=${timezone}`
    );
    return -1;
  }
  return parsed;
}

/**
 * 브리핑 요약을 FCM 푸시로 전송
 * @param {string} uid - 사용자 ID
 * @param {string} summary - 브리핑 요약 (알림 본문)
 * @return {Promise<void>}
 */
async function sendBriefingPush(
  uid: string,
  summary: string
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
      title: "오늘의 브리핑 ✨",
      body: summary,
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
