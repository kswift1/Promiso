/// 구독 상태 전환 시 발생하는 Slack 알림 종류
#[derive(Debug, Clone, PartialEq)]
pub enum SlackNotificationType {
    NewSubscription,
    PromoCode,
    Cancelled,
    Expired,
    GracePeriod,
    Recovered,
    AutoRenewDisabled,
}

/// 상태 전환 감지에 필요한 컨텍스트
#[derive(Debug, Clone)]
pub struct SubscriptionTransitionContext {
    pub before_status: Option<String>,
    pub after_status: String,
    pub before_last_notification_type: Option<String>,
    pub after_last_notification_type: Option<String>,
    pub product_id: String,
    pub expiration_date: Option<String>,
}

/// Slack 메시지 Block Kit 구조
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
pub struct SlackMessage {
    pub text: String,
    pub blocks: Vec<SlackBlock>,
}

/// Block Kit 블록 종류 (최소 subset)
#[derive(Debug, Clone, PartialEq, serde::Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum SlackBlock {
    Header(String),
    Section(String),
    Divider,
}

/// 알림 타입별 메시지 생성에 필요한 컨텍스트
#[derive(Debug, Clone)]
pub struct SlackMessageContext {
    pub nickname: Option<String>,
    pub product_id: String,
    pub price: Option<String>,
    pub pro_user_count: Option<u32>,
    pub expiration_date: Option<String>,
    pub promo_code: Option<String>,
}

// ============================================================
// 내부 헬퍼
// ============================================================

const ACTIVE_STATUSES: &[&str] = &["subscribed", "lifetime"];

fn is_active(status: &str) -> bool {
    ACTIVE_STATUSES.contains(&status)
}

fn is_inactive(status_opt: &Option<String>) -> bool {
    match status_opt {
        None => true,
        Some(s) => !is_active(s.as_str()) && s.as_str() != "grace_period",
    }
}

// ============================================================
// 공개 함수
// ============================================================

/// before/after 상태를 비교하여 어떤 Slack 알림을 보내야 하는지 결정
pub fn detect_subscription_transition(
    ctx: &SubscriptionTransitionContext,
) -> Option<SlackNotificationType> {
    let after = ctx.after_status.as_str();
    let before = ctx.before_status.as_deref();

    // SN-7: DID_CHANGE_RENEWAL_STATUS — 상태 변화보다 먼저 체크
    let after_notif = ctx.after_last_notification_type.as_deref();
    let before_notif = ctx.before_last_notification_type.as_deref();
    if after_notif == Some("DID_CHANGE_RENEWAL_STATUS")
        && before_notif != Some("DID_CHANGE_RENEWAL_STATUS")
    {
        return Some(SlackNotificationType::AutoRenewDisabled);
    }

    // SN-8: 상태 변화 없으면 스킵
    if before == Some(after) {
        return None;
    }

    // SN-6: grace_period → 활성 = 갱신 복구
    if is_active(after) && before == Some("grace_period") {
        return Some(SlackNotificationType::Recovered);
    }

    // SN-1/SN-2: 비활성 → 활성 = 신규 구독 또는 프로모션 코드
    if is_active(after) && is_inactive(&ctx.before_status) {
        if after_notif == Some("OFFER_REDEEMED") {
            return Some(SlackNotificationType::PromoCode);
        }
        return Some(SlackNotificationType::NewSubscription);
    }

    // SN-3: 활성 → revoked = 취소/환불
    if after == "revoked" {
        if let Some(b) = before {
            if is_active(b) {
                return Some(SlackNotificationType::Cancelled);
            }
        }
    }

    // SN-4: 활성 또는 grace_period → expired = 만료
    if after == "expired" {
        if let Some(b) = before {
            if is_active(b) || b == "grace_period" {
                return Some(SlackNotificationType::Expired);
            }
        }
    }

    // SN-5: subscribed → grace_period = 갱신 실패
    if after == "grace_period" && before == Some("subscribed") {
        return Some(SlackNotificationType::GracePeriod);
    }

    None
}

/// 알림 타입과 컨텍스트를 받아 Slack Block Kit 메시지를 생성
pub fn build_slack_message(
    notification_type: &SlackNotificationType,
    ctx: &SlackMessageContext,
) -> SlackMessage {
    let nickname = ctx.nickname.as_deref().unwrap_or("(알 수 없음)");
    let product_id = ctx.product_id.as_str();
    let price = ctx.price.as_deref().unwrap_or("");
    let pro_count = ctx
        .pro_user_count
        .map(|n| format!("Pro 사용자 수: {n}명"))
        .unwrap_or_default();

    match notification_type {
        SlackNotificationType::NewSubscription => {
            let header = "🎉 신규 구독".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n가격: {price}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::PromoCode => {
            let promo = ctx.promo_code.as_deref().unwrap_or("");
            let header = "🎟 프로모션 코드 구독".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n프로모션 코드: {promo}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::Cancelled => {
            let header = "❌ 구독 취소/환불".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::Expired => {
            let header = "⏰ 구독 만료".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::GracePeriod => {
            let exp = ctx.expiration_date.as_deref().unwrap_or("");
            let header = "⚠️ 갱신 실패 (유예 기간)".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n만료예정일: {exp}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::Recovered => {
            let header = "✅ 구독 갱신 복구".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }

        SlackNotificationType::AutoRenewDisabled => {
            let header = "🔕 자동갱신 해제".to_string();
            let section = format!(
                "닉네임: {nickname}\n플랜: {product_id}\n{pro_count}"
            );
            SlackMessage {
                text: header.clone(),
                blocks: vec![
                    SlackBlock::Header(header),
                    SlackBlock::Section(section),
                ],
            }
        }
    }
}

/// Slack HTTP 클라이언트 — 프로세스당 한 번만 생성
fn slack_http_client() -> &'static reqwest::Client {
    use std::sync::OnceLock;
    static CLIENT: OnceLock<reqwest::Client> = OnceLock::new();
    CLIENT.get_or_init(reqwest::Client::new)
}

/// Slack webhook으로 메시지를 발송한다.
///
/// SN-9: 실패 시 경고 로그만 남기고 에러를 반환한다 (메인 흐름 비차단은 호출자 책임).
/// SN-10: webhook_url이 비어있으면 조기 반환한다.
pub async fn send_slack_notification(
    webhook_url: &str,
    message: &SlackMessage,
) -> Result<(), ()> {
    if webhook_url.is_empty() {
        return Ok(());
    }

    let client = slack_http_client();
    match client.post(webhook_url).json(message).send().await {
        Ok(resp) if resp.status().is_success() => Ok(()),
        Ok(resp) => {
            tracing::warn!("Slack webhook returned {}", resp.status());
            Err(())
        }
        Err(e) => {
            tracing::warn!("Slack webhook failed: {}", e);
            Err(())
        }
    }
}
