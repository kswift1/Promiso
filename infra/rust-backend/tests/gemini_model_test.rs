use std::sync::Mutex;

use promiso_backend::services::gemini_client::{
    briefing_model, build_request_body, emoji_model, resolve_model_id, schedule_extraction_model,
    ENV_MODEL_BRIEFING, ENV_MODEL_EMOJI, ENV_MODEL_SCHEDULE_EXTRACTION,
};

// env 변경 테스트는 프로세스 전역 상태를 건드리므로 직렬화한다.
static ENV_LOCK: Mutex<()> = Mutex::new(());

const ALL_ENVS: [&str; 3] = [
    ENV_MODEL_EMOJI,
    ENV_MODEL_BRIEFING,
    ENV_MODEL_SCHEDULE_EXTRACTION,
];

fn with_env<F: FnOnce()>(vars: &[(&str, Option<&str>)], f: F) {
    let _guard = ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let prev: Vec<(&str, Option<String>)> = ALL_ENVS
        .iter()
        .map(|k| (*k, std::env::var(k).ok()))
        .collect();
    for k in ALL_ENVS {
        std::env::remove_var(k);
    }
    for (k, v) in vars {
        if let Some(v) = v {
            std::env::set_var(k, v);
        }
    }

    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(f));

    for (k, v) in prev {
        match v {
            Some(v) => std::env::set_var(k, v),
            None => std::env::remove_var(k),
        }
    }
    if let Err(e) = result {
        std::panic::resume_unwind(e);
    }
}

#[test]
fn resolve_uses_default_when_unset_or_blank() {
    assert_eq!(
        resolve_model_id(None, "gemini-2.5-flash"),
        "gemini-2.5-flash"
    );
    assert_eq!(
        resolve_model_id(Some(""), "gemini-2.5-flash"),
        "gemini-2.5-flash"
    );
    assert_eq!(
        resolve_model_id(Some("   "), "gemini-2.5-flash"),
        "gemini-2.5-flash"
    );
}

#[test]
fn resolve_accepts_valid_override_and_trims() {
    assert_eq!(
        resolve_model_id(Some(" gemini-2.5-pro "), "gemini-2.5-flash"),
        "gemini-2.5-pro"
    );
}

#[test]
fn resolve_rejects_invalid_characters() {
    for bad in [
        "gemini/../x",
        "gemini-2.5-flash:generateContent?key=evil#",
        "a b",
        "model\n",
        "..",
        "-flash",
        "모델",
        "a%2fb",
    ] {
        let got = resolve_model_id(Some(bad), "gemini-2.5-flash");
        // trim 으로 공백만 제거된 값이 유효한 경우("model\n" -> "model")는 허용
        if bad.trim() == "model" {
            assert_eq!(got, "model");
        } else {
            assert_eq!(got, "gemini-2.5-flash", "input: {bad:?}");
        }
    }
}

#[test]
fn defaults_per_purpose() {
    with_env(&[], || {
        assert_eq!(emoji_model(), "gemini-2.5-flash");
        assert_eq!(briefing_model(), "gemini-2.5-flash");
        assert_eq!(schedule_extraction_model(), "gemini-2.5-flash");
    });
}

#[test]
fn env_overrides_per_purpose() {
    with_env(
        &[
            (ENV_MODEL_EMOJI, Some("gemini-x-emoji")),
            (ENV_MODEL_BRIEFING, Some("gemini-x-briefing")),
            (ENV_MODEL_SCHEDULE_EXTRACTION, Some("gemini-x-extract")),
        ],
        || {
            assert_eq!(emoji_model(), "gemini-x-emoji");
            assert_eq!(briefing_model(), "gemini-x-briefing");
            assert_eq!(schedule_extraction_model(), "gemini-x-extract");
        },
    );
}

#[test]
fn env_invalid_or_empty_falls_back_to_default() {
    with_env(
        &[
            (ENV_MODEL_EMOJI, Some("bad/model?x=1")),
            (ENV_MODEL_BRIEFING, Some("")),
            (ENV_MODEL_SCHEDULE_EXTRACTION, Some("a b")),
        ],
        || {
            assert_eq!(emoji_model(), "gemini-2.5-flash");
            assert_eq!(briefing_model(), "gemini-2.5-flash");
            assert_eq!(schedule_extraction_model(), "gemini-2.5-flash");
        },
    );
}

#[test]
fn request_body_includes_thinking_budget_zero_when_disabled() {
    let body = build_request_body("hello", 64, true);
    assert_eq!(body["generationConfig"]["maxOutputTokens"], 64);
    assert_eq!(
        body["generationConfig"]["thinkingConfig"]["thinkingBudget"],
        0
    );
    assert_eq!(body["contents"][0]["parts"][0]["text"], "hello");
}

#[test]
fn request_body_omits_thinking_config_when_enabled() {
    let body = build_request_body("hello", 1024, false);
    assert_eq!(body["generationConfig"]["maxOutputTokens"], 1024);
    assert!(body["generationConfig"].get("thinkingConfig").is_none());
}
