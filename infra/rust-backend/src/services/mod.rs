pub mod admin_subscription_service;
pub mod app_config_service;
pub mod app_store_service;
pub mod auth_service;
pub mod briefing_projection_service;
pub mod briefing_scheduler_service;
pub mod briefing_service;
pub mod data_migration_service;
pub mod emoji_service;
pub mod faq_service;
pub mod gemini_client;
pub mod group_service;
pub mod live_activity_service;
pub mod media_service;
pub mod notification_service;
pub mod places_service;
pub mod provider_verifier;
pub mod schedule_service;
pub mod slack_service;
pub mod storage_service;
pub mod subscription_backfill_service;
pub mod subscription_service;
pub mod transportation_client;
pub mod transportation_service;
pub mod user_service;
pub mod user_settings_service;
pub mod vote_live_activity_service;
pub mod weather_client;
pub mod weather_service;
pub mod widget_service;

/// 쿼리스트링의 비밀값(`serviceKey`, `key`, `apiKey`, `appKey`)을 `***`로 치환한다.
///
/// 키 이름은 대소문자를 구분하지 않으며, 앞 글자가 영숫자인 경우(`monkey=`)는 건드리지 않는다.
/// 값은 `&`, 공백, 따옴표, 괄호, `>` 앞까지로 본다.
pub fn redact_url_secrets(input: &str) -> String {
    const KEYS: [&str; 4] = ["servicekey", "apikey", "appkey", "key"];
    let lower = input.to_ascii_lowercase();
    let bytes = input.as_bytes();
    let mut out = String::with_capacity(input.len());
    let mut i = 0;
    let mut copied = 0;

    while i < bytes.len() {
        let boundary = i == 0 || !bytes[i - 1].is_ascii_alphanumeric();
        let matched = if boundary {
            KEYS.iter().find(|k| {
                lower.as_bytes()[i..].starts_with(k.as_bytes())
                    && bytes.get(i + k.len()) == Some(&b'=')
            })
        } else {
            None
        };

        if let Some(k) = matched {
            let value_start = i + k.len() + 1;
            let mut value_end = value_start;
            while value_end < bytes.len()
                && !matches!(
                    bytes[value_end],
                    b'&' | b' ' | b'"' | b'\'' | b')' | b'>' | b'\n' | b'\r'
                )
            {
                value_end += 1;
            }
            out.push_str(&input[copied..value_start]);
            out.push_str("***");
            copied = value_end;
            i = value_end;
        } else {
            i += 1;
        }
    }
    out.push_str(&input[copied..]);
    out
}

/// reqwest 에러를 로그/에러 메시지용 문자열로 변환한다.
///
/// 요청 URL(쿼리스트링의 API 키 포함)을 제거하고, 남은 메시지도 한 번 더 마스킹한다.
pub(crate) fn safe_reqwest_error(error: reqwest::Error) -> String {
    redact_url_secrets(&error.without_url().to_string())
}

#[cfg(test)]
mod redact_tests {
    use super::redact_url_secrets;

    #[test]
    fn redacts_service_key() {
        let s = "error sending request for url (https://a.b/c?serviceKey=SECRET%2B&numOfRows=1000)";
        let r = redact_url_secrets(s);
        assert!(!r.contains("SECRET"));
        assert!(r.contains("serviceKey=***&numOfRows=1000"));
    }

    #[test]
    fn redacts_gemini_key_at_end() {
        let r = redact_url_secrets("https://g/x:generateContent?key=AIzaABC");
        assert_eq!(r, "https://g/x:generateContent?key=***");
    }

    #[test]
    fn redacts_case_insensitive_and_multiple() {
        let r = redact_url_secrets("?ServiceKey=a&apikey=b&appKey=c&x=1");
        assert_eq!(r, "?ServiceKey=***&apikey=***&appKey=***&x=1");
    }

    #[test]
    fn keeps_unrelated_and_embedded_names() {
        let s = "monkey=1&tmFc=202601&regId=11B";
        assert_eq!(redact_url_secrets(s), s);
        assert_eq!(redact_url_secrets("연결 실패"), "연결 실패");
    }
}
