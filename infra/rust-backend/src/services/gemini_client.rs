use reqwest::Client;

/// Gemini 응답 텍스트에서 {summary, detail} 파싱
///
/// 파싱 전략 (순서대로 시도):
/// 1. ```json ... ``` 또는 ``` ... ``` fence 블록 추출
/// 2. fence 없으면 전체 텍스트를 JSON으로 시도
/// 3. JSON 파싱 성공 + summary/detail 필드 존재 시 반환
/// 4. 실패 시 fallback: 첫 문장 → summary(30자), 전체 텍스트 → detail
///
/// <user-data> 태그는 파싱 성공/실패 모두 제거한다.
pub fn parse_gemini_response(text: &str) -> (String, String) {
    // 1. ``` fence 블록 추출 (```json 또는 ``` 시작)
    let mut blocks: Vec<&str> = Vec::new();

    let mut search = text;
    while let Some(start) = search.find("```") {
        let after_fence = &search[start + 3..];
        // "json" 접두사 스킵
        let content_start = if after_fence.starts_with("json") {
            &after_fence[4..]
        } else {
            after_fence
        };
        // 줄바꿈 이후부터 블록 내용 시작
        let content_start = content_start
            .trim_start_matches('\n')
            .trim_start_matches('\r');

        if let Some(end) = content_start.find("```") {
            blocks.push(&content_start[..end]);
            search = &content_start[end + 3..];
        } else {
            break;
        }
    }

    // fence 없으면 전체 텍스트 시도
    if blocks.is_empty() {
        blocks.push(text.trim());
    }

    // 2. 블록 순서대로 JSON 파싱 시도
    for block in &blocks {
        let block = block.trim();
        if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(block) {
            if let (Some(summary), Some(detail)) =
                (parsed["summary"].as_str(), parsed["detail"].as_str())
            {
                let summary = strip_user_data_tags(summary);
                let detail = strip_user_data_tags(detail);
                return (summary, detail);
            }
        }
    }

    // 3. fallback: 첫 문장(30자) → summary, 전체 → detail
    let cleaned = strip_user_data_tags(text);
    let first_sentence = cleaned
        .split(|c| c == '.' || c == '!' || c == '?' || c == '。')
        .next()
        .unwrap_or("")
        .trim()
        .to_string();

    // 30바이트 이하로 자르기 (한글 포함 멀티바이트 안전 처리)
    let summary = truncate_to_bytes(&first_sentence, 30);

    (summary, cleaned)
}

/// <user-data> 및 </user-data> 태그 제거
fn strip_user_data_tags(s: &str) -> String {
    s.replace("<user-data>", "").replace("</user-data>", "")
}

/// 문자열을 최대 max_bytes 바이트로 잘라 반환 (UTF-8 경계 안전)
fn truncate_to_bytes(s: &str, max_bytes: usize) -> String {
    if s.len() <= max_bytes {
        return s.to_string();
    }
    // UTF-8 경계에서 안전하게 자르기
    let mut end = max_bytes;
    while end > 0 && !s.is_char_boundary(end) {
        end -= 1;
    }
    s[..end].to_string()
}

/// 이모지 생성용 모델 환경변수
pub const ENV_MODEL_EMOJI: &str = "GEMINI_MODEL_EMOJI";
/// 브리핑 생성용 모델 환경변수
pub const ENV_MODEL_BRIEFING: &str = "GEMINI_MODEL_BRIEFING";
/// 일정 추출용 모델 환경변수
pub const ENV_MODEL_SCHEDULE_EXTRACTION: &str = "GEMINI_MODEL_SCHEDULE_EXTRACTION";

/// 이모지/브리핑 기본 모델
pub const DEFAULT_MODEL_LITE: &str = "gemini-2.5-flash-lite";
/// 일정 추출 기본 모델 (정확도 우선)
pub const DEFAULT_MODEL_SCHEDULE_EXTRACTION: &str = "gemini-2.5-flash";

/// 이모지 응답 최대 출력 토큰 (이모지 1개, ZWJ 시퀀스 여유 포함)
pub const EMOJI_MAX_OUTPUT_TOKENS: u32 = 64;
/// 브리핑 응답 최대 출력 토큰 (JSON summary + detail 3~5문장이 잘리지 않을 여유)
pub const BRIEFING_MAX_OUTPUT_TOKENS: u32 = 1024;

/// 모델 ID가 URL 경로에 안전한지 확인 (영숫자/`.`/`-`만, 첫 글자는 영숫자)
fn is_valid_model_id(model: &str) -> bool {
    model
        .chars()
        .next()
        .is_some_and(|c| c.is_ascii_alphanumeric())
        && model
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '.' || c == '-')
}

/// 환경변수 값(없거나 비어 있으면 None 취급)을 모델 ID로 해석한다.
///
/// 비어 있거나 허용되지 않는 문자가 있으면 기본값을 반환한다 (URL 인젝션 방지).
pub fn resolve_model_id(value: Option<&str>, default: &str) -> String {
    match value.map(str::trim) {
        None | Some("") => default.to_string(),
        Some(v) if is_valid_model_id(v) => v.to_string(),
        Some(_) => {
            tracing::warn!("[Gemini] Invalid model id in env, falling back to default: {default}");
            default.to_string()
        }
    }
}

/// 환경변수에서 모델 ID를 읽어 해석한다.
pub fn model_from_env(env_name: &str, default: &str) -> String {
    resolve_model_id(std::env::var(env_name).ok().as_deref(), default)
}

/// 이모지 생성 모델
pub fn emoji_model() -> String {
    model_from_env(ENV_MODEL_EMOJI, DEFAULT_MODEL_LITE)
}

/// 브리핑 생성 모델
pub fn briefing_model() -> String {
    model_from_env(ENV_MODEL_BRIEFING, DEFAULT_MODEL_LITE)
}

/// 일정 추출 모델
pub fn schedule_extraction_model() -> String {
    model_from_env(
        ENV_MODEL_SCHEDULE_EXTRACTION,
        DEFAULT_MODEL_SCHEDULE_EXTRACTION,
    )
}

/// Gemini API 호출
///
/// `model`로 지정한 모델을 사용하며, `max_output_tokens`를 generationConfig에 설정한다.
/// 모델 ID가 유효하지 않으면 URL에 넣지 않고 `Err(())`를 반환한다.
/// 응답 텍스트만 반환하며, 에러 시 `Err(())`를 반환한다.
pub async fn call_gemini(
    prompt: &str,
    api_key: &str,
    model: &str,
    max_output_tokens: u32,
) -> Result<String, ()> {
    if !is_valid_model_id(model) {
        tracing::warn!("[Gemini] Invalid model id");
        return Err(());
    }
    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    );

    let body = serde_json::json!({
        "contents": [
            {
                "parts": [
                    { "text": prompt }
                ]
            }
        ],
        "generationConfig": {
            "maxOutputTokens": max_output_tokens
        }
    });

    let client = Client::builder().build().map_err(|e| {
        tracing::warn!("[Gemini] Failed to build HTTP client: {e}");
        ()
    })?;
    let resp = client
        .post(&url)
        .timeout(std::time::Duration::from_secs(30))
        .json(&body)
        .send()
        .await
        .map_err(|e| {
            tracing::warn!("[Gemini] Request error: {e}");
        })?;

    if !resp.status().is_success() {
        tracing::warn!("[Gemini] API error: {}", resp.status());
        return Err(());
    }

    let json: serde_json::Value = resp.json().await.map_err(|e| {
        tracing::warn!("[Gemini] JSON parse error: {e}");
    })?;

    let text = json
        .pointer("/candidates/0/content/parts/0/text")
        .and_then(|v| v.as_str())
        .ok_or_else(|| {
            tracing::warn!("[Gemini] Unexpected response shape");
        })?;

    Ok(text.to_string())
}
