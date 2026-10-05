use std::collections::HashMap;
use std::time::Duration;

use chrono::{FixedOffset, Utc};
use reqwest::Client;

use crate::services::briefing_service::WeatherForecast;

/// KMA 단기예보 응답 파싱
///
/// 응답 형식:
/// ```json
/// {
///   "response": {
///     "body": {
///       "items": {
///         "item": [
///           { "fcstDate": "20260408", "fcstTime": "0600", "category": "TMP", "fcstValue": "12" },
///           { "fcstDate": "20260408", "fcstTime": "0600", "category": "SKY", "fcstValue": "1" },
///           ...
///         ]
///       }
///     }
///   }
/// }
/// ```
///
/// category 코드:
/// - TMP: 기온 (°C)
/// - SKY: 하늘상태 (1=맑음, 3=구름많음, 4=흐림)
/// - PTY: 강수형태 (0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기)
/// - POP: 강수확률 (%)
/// - REH: 습도 (%)
/// - WSD: 풍속 (m/s)
pub fn parse_kma_response(json: &serde_json::Value) -> Vec<WeatherForecast> {
    let result_code = json
        .pointer("/response/header/resultCode")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    if result_code != "00" {
        return vec![];
    }

    let items = match json.pointer("/response/body/items/item") {
        Some(serde_json::Value::Array(arr)) => arr,
        _ => return vec![],
    };

    // fcstDate + fcstTime → 슬롯 맵
    let mut slots: HashMap<String, ForecastSlot> = HashMap::new();

    for item in items {
        let fcst_date = item["fcstDate"].as_str().unwrap_or("").to_string();
        let fcst_time = item["fcstTime"].as_str().unwrap_or("").to_string();
        let category = item["category"].as_str().unwrap_or("");
        let value = item["fcstValue"].as_str().unwrap_or("");

        let key = format!("{fcst_date}{fcst_time}");
        let slot = slots.entry(key.clone()).or_insert_with(|| ForecastSlot {
            fcst_time: key,
            tmp: None,
            sky: None,
            pty: None,
            pop: None,
            reh: None,
            wsd: None,
        });

        match category {
            "TMP" => slot.tmp = value.parse::<f64>().ok(),
            "SKY" => slot.sky = value.parse::<i32>().ok(),
            "PTY" => slot.pty = value.parse::<i32>().ok(),
            "POP" => slot.pop = value.parse::<i32>().ok(),
            "REH" => slot.reh = value.parse::<i32>().ok(),
            "WSD" => slot.wsd = value.parse::<f64>().ok(),
            _ => {}
        }
    }

    let mut keys: Vec<String> = slots.keys().cloned().collect();
    keys.sort();

    keys.iter()
        .map(|k| {
            let slot = &slots[k];
            WeatherForecast {
                fcst_time: slot.fcst_time.clone(),
                temperature: slot.tmp,
                sky: slot
                    .sky
                    .map(|s| map_sky_to_condition(s, slot.pty.unwrap_or(0))),
                precipitation_type: slot.pty.map(|p| map_pty(p)),
                precipitation_probability: slot.pop,
                humidity: slot.reh,
                wind_speed: slot.wsd,
            }
        })
        .collect()
}

struct ForecastSlot {
    fcst_time: String,
    tmp: Option<f64>,
    sky: Option<i32>,
    pty: Option<i32>,
    pop: Option<i32>,
    reh: Option<i32>,
    wsd: Option<f64>,
}

fn map_sky_to_condition(sky: i32, pty: i32) -> String {
    if pty > 0 {
        return map_pty(pty);
    }
    match sky {
        1 => "clear",
        3 => "cloudy",
        4 => "overcast",
        _ => "cloudy",
    }
    .to_string()
}

fn map_pty(pty: i32) -> String {
    match pty {
        1 => "rain",
        2 => "rainSnow",
        3 => "snow",
        4 => "shower",
        _ => "rain",
    }
    .to_string()
}

/// 위경도 → KMA 격자 좌표 변환 (Lambert Conformal Conic)
///
/// KMA 단기예보 API는 위경도 대신 격자 좌표(nx, ny)를 사용한다.
/// 공식 변환 수식 (기상청 격자-위경도 변환 공식):
/// - RE = 6371.00877 (지구 반경, km)
/// - GRID = 5.0 (격자 간격, km)
/// - SLAT1 = 30.0, SLAT2 = 60.0 (표준 위도)
/// - OLON = 126.0, OLAT = 38.0 (기준 경도/위도)
/// - XO = 43, YO = 136 (기준점 격자 좌표)
pub fn convert_to_grid(lat: f64, lon: f64) -> (i32, i32) {
    const RE: f64 = 6371.00877;
    const GRID: f64 = 5.0;
    const SLAT1: f64 = 30.0;
    const SLAT2: f64 = 60.0;
    const OLON: f64 = 126.0;
    const OLAT: f64 = 38.0;
    const XO: f64 = 43.0;
    const YO: f64 = 136.0;

    let degrad = std::f64::consts::PI / 180.0;

    let re = RE / GRID;
    let slat1 = SLAT1 * degrad;
    let slat2 = SLAT2 * degrad;
    let olon = OLON * degrad;
    let olat = OLAT * degrad;

    let sn = (std::f64::consts::PI * 0.25 + slat2 * 0.5).tan()
        / (std::f64::consts::PI * 0.25 + slat1 * 0.5).tan();
    let sn = (slat1.cos() / slat2.cos()).ln() / sn.ln();

    let sf = (std::f64::consts::PI * 0.25 + slat1 * 0.5).tan();
    let sf = (sf.powf(sn) * slat1.cos()) / sn;

    let ro = (std::f64::consts::PI * 0.25 + olat * 0.5).tan();
    let ro = (re * sf) / ro.powf(sn);

    let ra = (std::f64::consts::PI * 0.25 + lat * degrad * 0.5).tan();
    let ra = (re * sf) / ra.powf(sn);

    let mut theta = lon * degrad - olon;
    if theta > std::f64::consts::PI {
        theta -= 2.0 * std::f64::consts::PI;
    }
    if theta < -std::f64::consts::PI {
        theta += 2.0 * std::f64::consts::PI;
    }
    theta *= sn;

    let nx = (ra * theta.sin() + XO + 0.5).round() as i32;
    let ny = (ro - ra * theta.cos() + YO + 0.5).round() as i32;

    (nx, ny)
}

/// 현재 KST 기준 최신 발표 시각 계산
///
/// 단기예보 발표 시각: 0200,0500,0800,1100,1400,1700,2000,2300
/// 발표 후 약 10분 뒤부터 데이터 사용 가능
fn get_base_date_time() -> (String, String) {
    let kst_offset = FixedOffset::east_opt(9 * 3600).expect("valid offset");
    let now_kst = Utc::now().with_timezone(&kst_offset);

    let base_times = [
        "0200", "0500", "0800", "1100", "1400", "1700", "2000", "2300",
    ];

    let current_hhmm = format!("{:02}{:02}", now_kst.hour(), now_kst.minute());

    let mut selected_base_time = base_times[base_times.len() - 1];
    let mut use_previous_day = true;

    for bt in &base_times {
        let bt_hour = &bt[..2];
        let bt_with_delay = format!("{bt_hour}10");
        if current_hhmm.as_str() >= bt_with_delay.as_str() {
            selected_base_time = bt;
            use_previous_day = false;
        }
    }

    let base_date = if use_previous_day {
        now_kst.date_naive() - chrono::Duration::days(1)
    } else {
        now_kst.date_naive()
    };

    let base_date_str = base_date.format("%Y%m%d").to_string();
    (base_date_str, selected_base_time.to_string())
}

// chrono::DateTime<FixedOffset> hour/minute 접근을 위해 trait 사용
use chrono::Timelike;

/// KMA 연결 타임아웃
const KMA_CONNECT_TIMEOUT: Duration = Duration::from_secs(2);
/// KMA 요청 1회 전체 타임아웃 (연결 + 응답 본문)
const KMA_REQUEST_TIMEOUT: Duration = Duration::from_secs(3);
/// 총 시도 횟수 (최초 1회 + 재시도 2회)
const KMA_MAX_ATTEMPTS: u32 = 3;
/// 재시도 사이 backoff (시도 횟수에 비례, 100ms, 200ms)
const KMA_RETRY_BACKOFF_STEP: Duration = Duration::from_millis(100);

/// KMA 호출 실패 종류
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum KmaRequestError {
    /// 연결 오류/타임아웃/5xx 등 재시도 가능한 오류
    Retryable(String),
    /// 4xx, 응답 본문 파싱 오류 등 재시도해도 소용없는 오류
    Fatal(String),
}

impl KmaRequestError {
    pub fn is_retryable(&self) -> bool {
        matches!(self, Self::Retryable(_))
    }
}

impl std::fmt::Display for KmaRequestError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Retryable(m) | Self::Fatal(m) => f.write_str(m),
        }
    }
}

/// KMA 호출용 HTTP 클라이언트.
///
/// 짧은 타임아웃을 두고, 실패한 연결이 재시도에서 재사용되지 않도록 idle 연결을 풀에 남기지 않는다.
pub fn build_kma_client() -> Result<Client, reqwest::Error> {
    Client::builder()
        .connect_timeout(KMA_CONNECT_TIMEOUT)
        .timeout(KMA_REQUEST_TIMEOUT)
        .pool_max_idle_per_host(0)
        .build()
}

/// 시도 클로저를 최대 `max_attempts`회 실행한다.
///
/// `is_retryable`이 true인 에러만 재시도하며, 시도 사이에 `backoff_step * 시도번호`만큼 대기한다.
/// 모든 시도가 실패하면 마지막 에러를 반환한다.
pub async fn retry_with_backoff<T, E, F, Fut>(
    max_attempts: u32,
    backoff_step: Duration,
    is_retryable: impl Fn(&E) -> bool,
    mut attempt: F,
) -> Result<T, E>
where
    F: FnMut(u32) -> Fut,
    Fut: std::future::Future<Output = Result<T, E>>,
{
    let max_attempts = max_attempts.max(1);
    let mut n = 1;
    loop {
        match attempt(n).await {
            Ok(v) => return Ok(v),
            Err(e) if n < max_attempts && is_retryable(&e) => {
                tokio::time::sleep(backoff_step * n).await;
                n += 1;
            }
            Err(e) => return Err(e),
        }
    }
}

/// KMA GET 호출 후 JSON 반환 (재시도 포함).
///
/// 연결 오류/타임아웃/5xx는 최대 3회 시도하고, 4xx와 본문 파싱 오류는 재시도하지 않는다.
/// 에러 메시지에는 요청 URL(serviceKey)이 포함되지 않는다.
pub async fn kma_get_json(
    client: &Client,
    url: &str,
    query: &[(&str, &str)],
) -> Result<serde_json::Value, KmaRequestError> {
    retry_with_backoff(
        KMA_MAX_ATTEMPTS,
        KMA_RETRY_BACKOFF_STEP,
        KmaRequestError::is_retryable,
        |attempt| async move {
            let resp = client.get(url).query(query).send().await.map_err(|e| {
                KmaRequestError::Retryable(format!(
                    "request failed (attempt {attempt}): {}",
                    crate::services::safe_reqwest_error(e)
                ))
            })?;
            let status = resp.status();
            if status.is_server_error() {
                return Err(KmaRequestError::Retryable(format!(
                    "server error {status} (attempt {attempt})"
                )));
            }
            if status.is_client_error() {
                return Err(KmaRequestError::Fatal(format!("client error {status}")));
            }
            resp.json::<serde_json::Value>().await.map_err(|e| {
                KmaRequestError::Fatal(format!(
                    "decode failed: {}",
                    crate::services::safe_reqwest_error(e)
                ))
            })
        },
    )
    .await
}

/// KMA 단기예보 조회
pub async fn fetch_weather(lat: f64, lon: f64, api_key: &str) -> Vec<WeatherForecast> {
    let (nx, ny) = convert_to_grid(lat, lon);
    let (base_date, base_time) = get_base_date_time();

    let url = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";

    let client = match build_kma_client() {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!(
                "[Weather] Failed to build HTTP client: {}",
                crate::services::safe_reqwest_error(e)
            );
            return vec![];
        }
    };

    let query = [
        ("serviceKey", api_key),
        ("numOfRows", "1000"),
        ("pageNo", "1"),
        ("dataType", "JSON"),
        ("base_date", base_date.as_str()),
        ("base_time", base_time.as_str()),
        ("nx", &nx.to_string()),
        ("ny", &ny.to_string()),
    ];

    match kma_get_json(&client, url, &query).await {
        Ok(json) => parse_kma_response(&json),
        Err(e) => {
            tracing::warn!("[Weather] KMA fetch failed: {e}");
            vec![]
        }
    }
}

#[cfg(test)]
mod retry_tests {
    use std::sync::atomic::{AtomicU32, Ordering};

    use super::*;

    const STEP: Duration = Duration::from_millis(1);

    #[tokio::test]
    async fn success_runs_once() {
        let calls = AtomicU32::new(0);
        let r: Result<i32, KmaRequestError> =
            retry_with_backoff(3, STEP, KmaRequestError::is_retryable, |_| {
                calls.fetch_add(1, Ordering::SeqCst);
                async { Ok(7) }
            })
            .await;
        assert_eq!(r, Ok(7));
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn retries_then_succeeds() {
        let calls = AtomicU32::new(0);
        let r = retry_with_backoff(3, STEP, KmaRequestError::is_retryable, |n| {
            calls.fetch_add(1, Ordering::SeqCst);
            async move {
                if n < 3 {
                    Err(KmaRequestError::Retryable(format!("fail {n}")))
                } else {
                    Ok("ok")
                }
            }
        })
        .await;
        assert_eq!(r, Ok("ok"));
        assert_eq!(calls.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn returns_last_error_when_all_fail() {
        let calls = AtomicU32::new(0);
        let r: Result<(), KmaRequestError> =
            retry_with_backoff(3, STEP, KmaRequestError::is_retryable, |n| {
                calls.fetch_add(1, Ordering::SeqCst);
                async move { Err(KmaRequestError::Retryable(format!("fail {n}"))) }
            })
            .await;
        assert_eq!(r, Err(KmaRequestError::Retryable("fail 3".to_string())));
        assert_eq!(calls.load(Ordering::SeqCst), 3);
    }

    #[tokio::test]
    async fn does_not_retry_fatal() {
        let calls = AtomicU32::new(0);
        let r: Result<(), KmaRequestError> =
            retry_with_backoff(3, STEP, KmaRequestError::is_retryable, |_| {
                calls.fetch_add(1, Ordering::SeqCst);
                async { Err(KmaRequestError::Fatal("client error 403".to_string())) }
            })
            .await;
        assert_eq!(
            r,
            Err(KmaRequestError::Fatal("client error 403".to_string()))
        );
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }
}
