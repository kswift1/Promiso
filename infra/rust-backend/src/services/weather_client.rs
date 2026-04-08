use std::collections::HashMap;

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
                sky: slot.sky.map(|s| map_sky_to_condition(s, slot.pty.unwrap_or(0))),
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

    let base_times = ["0200", "0500", "0800", "1100", "1400", "1700", "2000", "2300"];

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

/// KMA 단기예보 조회
pub async fn fetch_weather(lat: f64, lon: f64, api_key: &str) -> Vec<WeatherForecast> {
    let (nx, ny) = convert_to_grid(lat, lon);
    let (base_date, base_time) = get_base_date_time();

    let url = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst";

    let client = match Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("[Weather] Failed to build HTTP client: {e}");
            return vec![];
        }
    };

    let result = client
        .get(url)
        .query(&[
            ("serviceKey", api_key),
            ("numOfRows", "1000"),
            ("pageNo", "1"),
            ("dataType", "JSON"),
            ("base_date", &base_date),
            ("base_time", &base_time),
            ("nx", &nx.to_string()),
            ("ny", &ny.to_string()),
        ])
        .send()
        .await;

    match result {
        Ok(resp) if resp.status().is_success() => match resp.json::<serde_json::Value>().await {
            Ok(json) => parse_kma_response(&json),
            Err(e) => {
                tracing::warn!("[Weather] JSON parse error: {e}");
                vec![]
            }
        },
        Ok(resp) => {
            tracing::warn!("[Weather] KMA API error: {}", resp.status());
            vec![]
        }
        Err(e) => {
            tracing::warn!("[Weather] fetch error: {e}");
            vec![]
        }
    }
}
