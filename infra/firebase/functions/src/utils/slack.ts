/**
 * Slack 알림 유틸리티
 *
 * Incoming Webhook을 통해 Slack 메시지를 전송합니다.
 */
import {SLACK_WEBHOOK_URL} from "../config";
import {
  getCurrentEnvironment,
  FirestoreEnvironment,
} from "./firestore";

interface SignupNotificationParams {
  nickname: string;
  name: string;
  providerType: string;
  email: string;
}

interface SubscriptionNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
  status: string;
  price: number;
  totalProUsers: number;
}

interface SubscriptionCancelNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
  totalProUsers: number;
}

interface SubscriptionExpiredNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
  totalProUsers: number;
}

interface SubscriptionRecoveredNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
}

interface SubscriptionGracePeriodNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
  expirationDate: string | null;
}

interface SubscriptionPromoNotificationParams {
  uid: string;
  nickname: string;
  productId: string;
  expirationDate: string | null;
  totalProUsers: number;
}

/**
 * productId를 한글 플랜명으로 변환
 *
 * @param {string} productId 상품 ID
 * @return {string} 한글 플랜명
 */
function getPlanLabel(productId: string): string {
  if (productId.includes("monthly")) return "월간 구독";
  if (productId.includes("yearly")) return "연간 구독";
  if (productId.includes("lifetime")) return "평생 이용권";
  return productId;
}

/**
 * Slack 웹훅으로 메시지를 전송하는 내부 헬퍼
 *
 * 환경 체크, 웹훅 URL 확인, fetch 호출, 에러 로깅을 담당한다.
 *
 * @param {string} label 로그에 표시할 알림 종류 레이블
 * @param {object[]} blocks Slack Block Kit 블록 배열
 * @return {Promise<void>}
 */
async function sendSlackNotification(
  label: string,
  blocks: object[],
): Promise<void> {
  const env = getCurrentEnvironment();

  if (env !== FirestoreEnvironment.Release) {
    console.log(`📢 [Slack] 프로덕션 환경이 아니므로 ${label} 스킵 (env: ${env})`);
    return;
  }

  const webhookUrl = SLACK_WEBHOOK_URL.value();
  if (!webhookUrl) {
    console.warn("⚠️ [Slack] SLACK_WEBHOOK_URL이 설정되지 않았습니다");
    return;
  }

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({blocks}),
    });

    if (!response.ok) {
      console.error(`❌ [Slack] ${label} 전송 실패: ${response.status}`);
    } else {
      console.log(`✅ [Slack] ${label} 전송 완료`);
    }
  } catch (error) {
    console.error(`❌ [Slack] ${label} 전송 중 오류:`, error);
  }
}

/**
 * 신규 유료 구독 시 Slack 알림 전송
 *
 * @param {SubscriptionNotificationParams} params 구독 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionNotification(
  params: SubscriptionNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const priceLabel = params.price > 0 ?
    `₩${params.price.toLocaleString("ko-KR")}` : "-";
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  await sendSlackNotification("구독 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "💰 새로운 Pro 구독이 시작되었습니다!",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
        {type: "mrkdwn", text: `*금액*\n${priceLabel}`},
        {type: "mrkdwn", text: `*구독 상태*\n${params.status}`},
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: `⏰ ${now}  |  ` +
            `총 Pro 사용자: ${params.totalProUsers}명`,
        },
      ],
    },
  ]);
}

/**
 * 신규 가입 시 Slack 알림 전송
 *
 * @param {SignupNotificationParams} params - 가입 정보
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음 (가입 플로우 비차단)
 */
export async function sendSlackSignupNotification(
  params: SignupNotificationParams,
): Promise<void> {
  const providerLabel = params.providerType === "apple" ? "Apple" : "Google";
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  await sendSlackNotification("가입 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "🎉 새로운 유저가 가입했습니다!",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*이름*\n${params.name}`},
        {type: "mrkdwn", text: `*가입 방식*\n${providerLabel}`},
        {type: "mrkdwn", text: `*이메일*\n${params.email}`},
      ],
    },
    {
      type: "context",
      elements: [
        {type: "mrkdwn", text: `⏰ ${now}`},
      ],
    },
  ]);
}

/**
 * 구독 취소/환불 시 Slack 알림 전송
 *
 * @param {SubscriptionCancelNotificationParams} params 구독 취소 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionCancelNotification(
  params: SubscriptionCancelNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  await sendSlackNotification("구독 취소 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "🚫 구독이 취소/환불되었습니다",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: `⏰ ${now}  |  ` +
            `총 Pro 사용자: ${params.totalProUsers}명`,
        },
      ],
    },
  ]);
}

/**
 * 구독 만료 시 Slack 알림 전송
 *
 * @param {SubscriptionExpiredNotificationParams} params 구독 만료 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionExpiredNotification(
  params: SubscriptionExpiredNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  await sendSlackNotification("구독 만료 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "⏰ 구독이 만료되었습니다",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: `⏰ ${now}  |  ` +
            `총 Pro 사용자: ${params.totalProUsers}명`,
        },
      ],
    },
  ]);
}

/**
 * 구독 갱신 실패(유예 기간 진입) 시 Slack 알림 전송
 *
 * @param {SubscriptionGracePeriodNotificationParams} params 유예 기간 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionGracePeriodNotification(
  params: SubscriptionGracePeriodNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});
  const locale = "ko-KR";
  const tz = {timeZone: "Asia/Seoul"};
  const expirationLabel = params.expirationDate ?
    new Date(params.expirationDate).toLocaleString(locale, tz) :
    "-";

  await sendSlackNotification("갱신 실패 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "⚠️ 구독 갱신에 실패했습니다",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
        {type: "mrkdwn", text: `*유예 만료일*\n${expirationLabel}`},
      ],
    },
    {
      type: "context",
      elements: [
        {type: "mrkdwn", text: `⏰ ${now}`},
      ],
    },
  ]);
}

/**
 * 프로모션 코드 등록 시 Slack 알림 전송
 *
 * @param {SubscriptionPromoNotificationParams} params 프로모션 코드 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionPromoNotification(
  params: SubscriptionPromoNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});
  const locale = "ko-KR";
  const tz = {timeZone: "Asia/Seoul"};
  const expirationLabel = params.expirationDate ?
    new Date(params.expirationDate).toLocaleString(locale, tz) :
    "-";

  await sendSlackNotification("프로모션 코드 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "🎟️ 프로모션 코드가 등록되었습니다",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
        {type: "mrkdwn", text: `*만료일*\n${expirationLabel}`},
      ],
    },
    {
      type: "context",
      elements: [
        {
          type: "mrkdwn",
          text: `⏰ ${now}  |  ` +
            `총 Pro 사용자: ${params.totalProUsers}명`,
        },
      ],
    },
  ]);
}

/**
 * 구독 갱신 복구 시 Slack 알림 전송
 *
 * @param {SubscriptionRecoveredNotificationParams} params 복구 정보
 * @return {Promise<void>}
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음
 */
export async function sendSlackSubscriptionRecoveredNotification(
  params: SubscriptionRecoveredNotificationParams,
): Promise<void> {
  const planLabel = getPlanLabel(params.productId);
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  await sendSlackNotification("갱신 복구 알림", [
    {
      type: "header",
      text: {
        type: "plain_text",
        text: "✅ 구독 갱신이 복구되었습니다",
        emoji: true,
      },
    },
    {
      type: "section",
      fields: [
        {type: "mrkdwn", text: `*닉네임*\n${params.nickname}`},
        {type: "mrkdwn", text: `*플랜 종류*\n${planLabel}`},
      ],
    },
    {
      type: "context",
      elements: [
        {type: "mrkdwn", text: `⏰ ${now}`},
      ],
    },
  ]);
}
