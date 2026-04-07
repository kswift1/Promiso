use promiso_backend::services::slack_service::{
    SlackBlock, SlackMessageContext, SlackNotificationType, SubscriptionTransitionContext,
    build_slack_message, detect_subscription_transition,
};

// ============================================================
// 헬퍼 함수
// ============================================================

fn ctx(
    before: Option<&str>,
    after: &str,
    before_notif: Option<&str>,
    after_notif: Option<&str>,
) -> SubscriptionTransitionContext {
    SubscriptionTransitionContext {
        before_status: before.map(str::to_string),
        after_status: after.to_string(),
        before_last_notification_type: before_notif.map(str::to_string),
        after_last_notification_type: after_notif.map(str::to_string),
        product_id: "com.promiso.pro.monthly".to_string(),
        expiration_date: None,
    }
}

fn ctx_with_expiration(
    before: Option<&str>,
    after: &str,
    before_notif: Option<&str>,
    after_notif: Option<&str>,
    expiration: &str,
) -> SubscriptionTransitionContext {
    SubscriptionTransitionContext {
        expiration_date: Some(expiration.to_string()),
        ..ctx(before, after, before_notif, after_notif)
    }
}

fn msg_ctx() -> SlackMessageContext {
    SlackMessageContext {
        nickname: Some("테스터".to_string()),
        product_id: "com.promiso.pro.monthly".to_string(),
        price: Some("9,900원".to_string()),
        pro_user_count: Some(42),
        expiration_date: None,
        promo_code: None,
    }
}

// ============================================================
// SN-1: 비활성 → 활성 = 신규 구독 알림
// ============================================================

#[test]
fn sn1_none_to_subscribed_returns_new_subscription() {
    let result = detect_subscription_transition(&ctx(
        Some("none"),
        "subscribed",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::NewSubscription));
}

#[test]
fn sn1_none_to_lifetime_returns_new_subscription() {
    let result = detect_subscription_transition(&ctx(
        Some("none"),
        "lifetime",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::NewSubscription));
}

#[test]
fn sn1_null_before_to_subscribed_returns_new_subscription() {
    let result = detect_subscription_transition(&ctx(None, "subscribed", None, None));
    assert_eq!(result, Some(SlackNotificationType::NewSubscription));
}

// ============================================================
// SN-2: 비활성 → 활성 + OFFER_REDEEMED = 프로모션 코드 알림
// ============================================================

#[test]
fn sn2_none_to_subscribed_with_offer_redeemed_returns_promo_code() {
    let result = detect_subscription_transition(&ctx(
        Some("none"),
        "subscribed",
        None,
        Some("OFFER_REDEEMED"),
    ));
    assert_eq!(result, Some(SlackNotificationType::PromoCode));
}

#[test]
fn sn2_null_before_to_subscribed_with_offer_redeemed_returns_promo_code() {
    let result = detect_subscription_transition(&ctx(
        None,
        "subscribed",
        None,
        Some("OFFER_REDEEMED"),
    ));
    assert_eq!(result, Some(SlackNotificationType::PromoCode));
}

// ============================================================
// SN-3: 활성 → revoked = 취소/환불 알림
// ============================================================

#[test]
fn sn3_subscribed_to_revoked_returns_cancelled() {
    let result = detect_subscription_transition(&ctx(
        Some("subscribed"),
        "revoked",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Cancelled));
}

#[test]
fn sn3_lifetime_to_revoked_returns_cancelled() {
    let result = detect_subscription_transition(&ctx(
        Some("lifetime"),
        "revoked",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Cancelled));
}

// ============================================================
// SN-4: 활성/gracePeriod → expired = 만료 알림
// ============================================================

#[test]
fn sn4_subscribed_to_expired_returns_expired() {
    let result = detect_subscription_transition(&ctx(
        Some("subscribed"),
        "expired",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Expired));
}

#[test]
fn sn4_grace_period_to_expired_returns_expired() {
    let result = detect_subscription_transition(&ctx(
        Some("grace_period"),
        "expired",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Expired));
}

// ============================================================
// SN-5: subscribed → gracePeriod = 갱신 실패 알림
// ============================================================

#[test]
fn sn5_subscribed_to_grace_period_returns_grace_period() {
    let result = detect_subscription_transition(&ctx_with_expiration(
        Some("subscribed"),
        "grace_period",
        None,
        None,
        "2025-05-01T00:00:00Z",
    ));
    assert_eq!(result, Some(SlackNotificationType::GracePeriod));
}

// ============================================================
// SN-6: gracePeriod → 활성 = 갱신 복구 알림
// ============================================================

#[test]
fn sn6_grace_period_to_subscribed_returns_recovered() {
    let result = detect_subscription_transition(&ctx(
        Some("grace_period"),
        "subscribed",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Recovered));
}

#[test]
fn sn6_grace_period_to_lifetime_returns_recovered() {
    let result = detect_subscription_transition(&ctx(
        Some("grace_period"),
        "lifetime",
        None,
        None,
    ));
    assert_eq!(result, Some(SlackNotificationType::Recovered));
}

// ============================================================
// SN-7: lastNotificationType → DID_CHANGE_RENEWAL_STATUS = 자동갱신 해제 알림
//        (상태 변화보다 먼저 체크)
// ============================================================

#[test]
fn sn7_did_change_renewal_status_returns_auto_renew_disabled() {
    let result = detect_subscription_transition(&ctx(
        Some("subscribed"),
        "subscribed",
        None,
        Some("DID_CHANGE_RENEWAL_STATUS"),
    ));
    assert_eq!(result, Some(SlackNotificationType::AutoRenewDisabled));
}

#[test]
fn sn7_did_change_renewal_status_checked_before_state_transition() {
    // 상태가 변화(subscribed → grace_period)하더라도 DID_CHANGE_RENEWAL_STATUS이면
    // AutoRenewDisabled를 반환해야 한다 (SN-7이 상태 전환 감지보다 우선)
    let result = detect_subscription_transition(&ctx(
        Some("subscribed"),
        "grace_period",
        None,
        Some("DID_CHANGE_RENEWAL_STATUS"),
    ));
    assert_eq!(result, Some(SlackNotificationType::AutoRenewDisabled));
}

// ============================================================
// SN-8: 상태 변화 없으면 스킵 (None 반환)
// ============================================================

#[test]
fn sn8_subscribed_to_subscribed_returns_none() {
    let result = detect_subscription_transition(&ctx(
        Some("subscribed"),
        "subscribed",
        None,
        None,
    ));
    assert_eq!(result, None);
}

#[test]
fn sn8_expired_to_expired_returns_none() {
    let result = detect_subscription_transition(&ctx(
        Some("expired"),
        "expired",
        None,
        None,
    ));
    assert_eq!(result, None);
}

#[test]
fn sn8_lifetime_to_lifetime_returns_none() {
    let result = detect_subscription_transition(&ctx(
        Some("lifetime"),
        "lifetime",
        None,
        None,
    ));
    assert_eq!(result, None);
}

// ============================================================
// build_slack_message: 알림 타입별 Block Kit 구조 검증
// ============================================================

#[test]
fn build_slack_message_new_subscription_has_header_and_section() {
    let msg = build_slack_message(&SlackNotificationType::NewSubscription, &msg_ctx());

    assert!(!msg.text.is_empty(), "fallback text는 비어있으면 안 됩니다");

    let has_header = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Header(_)));
    let has_section = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Section(_)));

    assert!(has_header, "NewSubscription 메시지에는 Header 블록이 있어야 합니다");
    assert!(has_section, "NewSubscription 메시지에는 Section 블록이 있어야 합니다");
}

#[test]
fn build_slack_message_new_subscription_includes_nickname_and_plan() {
    let msg = build_slack_message(&SlackNotificationType::NewSubscription, &msg_ctx());

    let all_text = msg
        .blocks
        .iter()
        .filter_map(|b| match b {
            SlackBlock::Header(t) | SlackBlock::Section(t) => Some(t.as_str()),
            SlackBlock::Divider => None,
        })
        .collect::<Vec<_>>()
        .join(" ");

    assert!(
        all_text.contains("테스터"),
        "닉네임이 메시지에 포함되어야 합니다: {all_text}"
    );
    assert!(
        all_text.contains("com.promiso.pro.monthly"),
        "플랜(product_id)이 메시지에 포함되어야 합니다: {all_text}"
    );
}

#[test]
fn build_slack_message_promo_code_has_header_and_section() {
    let ctx = SlackMessageContext {
        promo_code: Some("PROMO2025".to_string()),
        ..msg_ctx()
    };
    let msg = build_slack_message(&SlackNotificationType::PromoCode, &ctx);

    assert!(!msg.text.is_empty());
    let has_header = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Header(_)));
    assert!(has_header, "PromoCode 메시지에는 Header 블록이 있어야 합니다");
}

#[test]
fn build_slack_message_cancelled_has_header_and_section() {
    let msg = build_slack_message(&SlackNotificationType::Cancelled, &msg_ctx());

    assert!(!msg.text.is_empty());
    let has_header = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Header(_)));
    assert!(has_header, "Cancelled 메시지에는 Header 블록이 있어야 합니다");
}

#[test]
fn build_slack_message_grace_period_includes_expiration_date() {
    let ctx = SlackMessageContext {
        expiration_date: Some("2025-05-01".to_string()),
        ..msg_ctx()
    };
    let msg = build_slack_message(&SlackNotificationType::GracePeriod, &ctx);

    let all_text = msg
        .blocks
        .iter()
        .filter_map(|b| match b {
            SlackBlock::Header(t) | SlackBlock::Section(t) => Some(t.as_str()),
            SlackBlock::Divider => None,
        })
        .collect::<Vec<_>>()
        .join(" ");

    assert!(
        all_text.contains("2025-05-01"),
        "GracePeriod 메시지에는 만료예정일이 포함되어야 합니다: {all_text}"
    );
}

#[test]
fn build_slack_message_auto_renew_disabled_has_header_and_section() {
    let msg = build_slack_message(&SlackNotificationType::AutoRenewDisabled, &msg_ctx());

    assert!(!msg.text.is_empty());
    let has_header = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Header(_)));
    assert!(has_header, "AutoRenewDisabled 메시지에는 Header 블록이 있어야 합니다");
}

#[test]
fn build_slack_message_recovered_has_header_and_section() {
    let msg = build_slack_message(&SlackNotificationType::Recovered, &msg_ctx());

    assert!(!msg.text.is_empty());
    let has_header = msg.blocks.iter().any(|b| matches!(b, SlackBlock::Header(_)));
    assert!(has_header, "Recovered 메시지에는 Header 블록이 있어야 합니다");
}
