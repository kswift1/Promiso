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
