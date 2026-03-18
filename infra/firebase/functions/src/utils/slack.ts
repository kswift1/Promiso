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

/**
 * productId를 한글 플랜명으로 변환
 */
function getPlanLabel(productId: string): string {
  if (productId.includes("monthly")) return "월간 구독";
  if (productId.includes("yearly")) return "연간 구독";
  if (productId.includes("lifetime")) return "평생 이용권";
  return productId;
}

/**
 * 신규 유료 구독 시 Slack 알림 전송
 *
 * @param {SubscriptionNotificationParams} params - 구독 정보
 *
 * @remarks
 * - 프로덕션 환경에서만 실제 전송
 * - 전송 실패 시에도 에러를 throw하지 않음 (구독 처리 비차단)
 */
export async function sendSlackSubscriptionNotification(
  params: SubscriptionNotificationParams,
): Promise<void> {
  const env = getCurrentEnvironment();

  if (env !== FirestoreEnvironment.Release) {
    console.log(`📢 [Slack] 프로덕션 환경이 아니므로 구독 알림 스킵 (env: ${env})`);
    return;
  }

  const webhookUrl = SLACK_WEBHOOK_URL.value();
  if (!webhookUrl) {
    console.warn("⚠️ [Slack] SLACK_WEBHOOK_URL이 설정되지 않았습니다");
    return;
  }

  const planLabel = getPlanLabel(params.productId);
  const priceLabel = params.price > 0 ?
    `₩${params.price.toLocaleString("ko-KR")}` : "-";
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  const payload = {
    blocks: [
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
          {type: "mrkdwn", text: `⏰ ${now}  |  총 Pro 사용자: ${params.totalProUsers}명`},
        ],
      },
    ],
  };

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.error(`❌ [Slack] 구독 알림 전송 실패: ${response.status}`);
    } else {
      console.log("✅ [Slack] 구독 알림 전송 완료");
    }
  } catch (error) {
    console.error("❌ [Slack] 구독 알림 전송 중 오류:", error);
  }
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
  const env = getCurrentEnvironment();

  if (env !== FirestoreEnvironment.Release) {
    console.log(`📢 [Slack] 프로덕션 환경이 아니므로 Slack 알림 스킵 (env: ${env})`);
    return;
  }

  const webhookUrl = SLACK_WEBHOOK_URL.value();
  if (!webhookUrl) {
    console.warn("⚠️ [Slack] SLACK_WEBHOOK_URL이 설정되지 않았습니다");
    return;
  }

  const providerLabel = params.providerType === "apple" ? "Apple" : "Google";
  const now = new Date().toLocaleString("ko-KR", {timeZone: "Asia/Seoul"});

  const payload = {
    blocks: [
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
    ],
  };

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      console.error(`❌ [Slack] 전송 실패: ${response.status}`);
    } else {
      console.log("✅ [Slack] 가입 알림 전송 완료");
    }
  } catch (error) {
    console.error("❌ [Slack] 전송 중 오류:", error);
  }
}
