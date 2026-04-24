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

/// Gemini API 호출
///
/// `gemini-2.5-flash` 모델을 사용한다.
/// 응답 텍스트만 반환하며, 에러 시 `Err(())`를 반환한다.
pub async fn call_gemini(prompt: &str, api_key: &str) -> Result<String, ()> {
    let url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={}",
        api_key
    );

    let body = serde_json::json!({
        "contents": [
            {
                "parts": [
                    { "text": prompt }
                ]
            }
        ]
    });

    let client = Client::builder()
        .build()
        .map_err(|e| {
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
