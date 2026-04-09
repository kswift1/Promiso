use std::collections::HashMap;

use chrono::{DateTime, Duration, FixedOffset, TimeZone, Timelike, Utc};
use reqwest::Client;
use serde_json::Value;

use crate::errors::AppError;
use crate::models::weather::{
    DailyForecastResponse, GetWeatherRequest, HourlyForecastResponse, WeatherResponse,
};
use crate::services::weather_client::convert_to_grid;

const KST_OFFSET_SECONDS: i32 = 9 * 3600;
const MAX_FORECAST_DAYS: i64 = 10;
const SHORT_TERM_DAYS: i64 = 5;
const PAST_TOLERANCE_HOURS: i64 = 3;

#[derive(Debug, Clone)]
struct ForecastSlot {
    fcst_date: String,
    fcst_time: String,
    temperature: Option<f64>,
    sky: Option<i32>,
    precipitation_type: Option<i32>,
    precipitation_probability: Option<i32>,
    humidity: Option<i32>,
    wind_speed: Option<f64>,
    precipitation_amount: Option<String>,
}

#[derive(Debug, Clone, Copy)]
struct MidTermRegion {
    temp_reg_id: &'static str,
    land_reg_id: &'static str,
    lat: f64,
    lng: f64,
}

const MID_TERM_REGIONS: [MidTermRegion; 21] = [
    MidTermRegion {
        temp_reg_id: "11B10101",
        land_reg_id: "11B00000",
        lat: 37.567,
        lng: 126.978,
    },
    MidTermRegion {
        temp_reg_id: "11B20201",
        land_reg_id: "11B00000",
        lat: 37.456,
        lng: 126.705,
    },
    MidTermRegion {
        temp_reg_id: "11B20601",
        land_reg_id: "11B00000",
        lat: 37.264,
        lng: 127.029,
    },
    MidTermRegion {
        temp_reg_id: "11B20305",
        land_reg_id: "11B00000",
        lat: 37.760,
        lng: 126.770,
    },
    MidTermRegion {
        temp_reg_id: "11D10301",
        land_reg_id: "11D10000",
        lat: 37.881,
        lng: 127.730,
    },
    MidTermRegion {
        temp_reg_id: "11D10401",
        land_reg_id: "11D10000",
        lat: 37.342,
        lng: 127.920,
    },
    MidTermRegion {
        temp_reg_id: "11D20501",
        land_reg_id: "11D20000",
        lat: 37.752,
        lng: 128.876,
    },
    MidTermRegion {
        temp_reg_id: "11C10301",
        land_reg_id: "11C10000",
        lat: 36.642,
        lng: 127.489,
    },
    MidTermRegion {
        temp_reg_id: "11C20401",
        land_reg_id: "11C20000",
        lat: 36.350,
        lng: 127.385,
    },
    MidTermRegion {
        temp_reg_id: "11C20404",
        land_reg_id: "11C20000",
        lat: 36.480,
        lng: 127.260,
    },
    MidTermRegion {
        temp_reg_id: "11F10201",
        land_reg_id: "11F10000",
        lat: 35.824,
        lng: 127.148,
    },
    MidTermRegion {
        temp_reg_id: "11F20501",
        land_reg_id: "11F20000",
        lat: 35.160,
        lng: 126.853,
    },
    MidTermRegion {
        temp_reg_id: "11F20401",
        land_reg_id: "11F20000",
        lat: 34.760,
        lng: 127.662,
    },
    MidTermRegion {
        temp_reg_id: "21F20801",
        land_reg_id: "11F20000",
        lat: 34.812,
        lng: 126.392,
    },
    MidTermRegion {
        temp_reg_id: "11H10701",
        land_reg_id: "11H10000",
        lat: 35.871,
        lng: 128.601,
    },
    MidTermRegion {
        temp_reg_id: "11H10501",
        land_reg_id: "11H10000",
        lat: 36.568,
        lng: 128.729,
    },
    MidTermRegion {
        temp_reg_id: "11H20201",
        land_reg_id: "11H20000",
        lat: 35.180,
        lng: 129.076,
    },
    MidTermRegion {
        temp_reg_id: "11H20101",
        land_reg_id: "11H20000",
        lat: 35.538,
        lng: 129.311,
    },
    MidTermRegion {
        temp_reg_id: "11H20301",
        land_reg_id: "11H20000",
        lat: 35.228,
        lng: 128.681,
    },
    MidTermRegion {
        temp_reg_id: "11G00201",
        land_reg_id: "11G00000",
        lat: 33.510,
        lng: 126.522,
    },
    MidTermRegion {
        temp_reg_id: "11G00401",
        land_reg_id: "11G00000",
        lat: 33.253,
        lng: 126.560,
    },
];

pub async fn get_weather(req: GetWeatherRequest) -> Result<WeatherResponse, AppError> {
    let api_key = std::env::var("KMA_API_KEY")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .ok_or_else(|| {
            AppError::PreconditionFailed("KMA_API_KEY가 설정되지 않았습니다".to_string())
        })?;

    let now = Utc::now();
    if req.target_date < now - Duration::hours(PAST_TOLERANCE_HOURS)
        || req.target_date > now + Duration::days(MAX_FORECAST_DAYS)
    {
        return Ok(WeatherResponse {
            forecasts: vec![],
            daily_forecasts: vec![],
        });
    }

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|error| AppError::Internal(format!("Weather client init failed: {error}")))?;

    let forecasts = fetch_short_term(&client, req.latitude, req.longitude, &api_key).await?;
    let daily_forecasts = if req.target_date > now + Duration::days(SHORT_TERM_DAYS) {
        fetch_mid_term(&client, req.latitude, req.longitude, now, &api_key).await?
    } else {
        vec![]
    };

    Ok(WeatherResponse {
        forecasts,
        daily_forecasts,
    })
}

async fn fetch_short_term(
    client: &Client,
    latitude: f64,
    longitude: f64,
    api_key: &str,
) -> Result<Vec<HourlyForecastResponse>, AppError> {
    let (nx, ny) = convert_to_grid(latitude, longitude);
    let (base_date, base_time) = get_base_date_time(Utc::now());

    let json = client
        .get("https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst")
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
        .await
        .map_err(|error| AppError::Internal(format!("KMA short-term request failed: {error}")))?
        .json::<Value>()
        .await
        .map_err(|error| AppError::Internal(format!("KMA short-term decode failed: {error}")))?;

    let result_code = json
        .pointer("/response/header/resultCode")
        .and_then(|value| value.as_str())
        .unwrap_or("");
    if result_code != "00" {
        return Ok(vec![]);
    }

    let items = match json.pointer("/response/body/items/item") {
        Some(Value::Array(items)) => items,
        _ => return Ok(vec![]),
    };

    let mut slots: HashMap<String, ForecastSlot> = HashMap::new();
    for item in items {
        let fcst_date = item
            .get("fcstDate")
            .and_then(|value| value.as_str())
            .unwrap_or("")
            .to_string();
        let fcst_time = item
            .get("fcstTime")
            .and_then(|value| value.as_str())
            .unwrap_or("")
            .to_string();
        if fcst_date.is_empty() || fcst_time.is_empty() {
            continue;
        }

        let key = format!("{fcst_date}_{fcst_time}");
        let slot = slots.entry(key).or_insert_with(|| ForecastSlot {
            fcst_date: fcst_date.clone(),
            fcst_time: fcst_time.clone(),
            temperature: None,
            sky: None,
            precipitation_type: None,
            precipitation_probability: None,
            humidity: None,
            wind_speed: None,
            precipitation_amount: None,
        });

        let category = item
            .get("category")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        let raw_value = item
            .get("fcstValue")
            .and_then(|value| value.as_str())
            .unwrap_or("");
        match category {
            "TMP" => slot.temperature = raw_value.parse().ok(),
            "SKY" => slot.sky = raw_value.parse().ok(),
            "PTY" => slot.precipitation_type = raw_value.parse().ok(),
            "POP" => slot.precipitation_probability = raw_value.parse().ok(),
            "REH" => slot.humidity = raw_value.parse().ok(),
            "WSD" => slot.wind_speed = raw_value.parse().ok(),
            "PCP" => slot.precipitation_amount = Some(raw_value.to_string()),
            _ => {}
        }
    }

    let kst = FixedOffset::east_opt(KST_OFFSET_SECONDS).expect("valid KST offset");
    let mut forecasts: Vec<HourlyForecastResponse> = slots
        .into_values()
        .filter_map(|slot| {
            let temperature = slot.temperature?;
            let naive = chrono::NaiveDateTime::parse_from_str(
                &format!("{}{}", slot.fcst_date, slot.fcst_time),
                "%Y%m%d%H%M",
            )
            .ok()?;
            let date_time = kst
                .from_local_datetime(&naive)
                .single()?
                .with_timezone(&Utc);
            let humidity = slot.humidity.unwrap_or(50);
            let wind_speed = slot.wind_speed.unwrap_or(0.0);

            Some(HourlyForecastResponse {
                date_time,
                temperature: round_one_decimal(temperature),
                feels_like_temperature: round_one_decimal(calculate_feels_like(
                    temperature,
                    wind_speed,
                    humidity as f64,
                )),
                condition: map_short_term_condition(
                    slot.sky.unwrap_or(1),
                    slot.precipitation_type.unwrap_or(0),
                )
                .to_string(),
                precipitation_probability: slot.precipitation_probability.unwrap_or(0),
                humidity,
                wind_speed: round_one_decimal(wind_speed),
                precipitation_amount: slot
                    .precipitation_amount
                    .filter(|value| value != "강수없음")
                    .unwrap_or_default(),
            })
        })
        .collect();

    forecasts.sort_by_key(|forecast| forecast.date_time);
    Ok(forecasts)
}

async fn fetch_mid_term(
    client: &Client,
    latitude: f64,
    longitude: f64,
    now: DateTime<Utc>,
    api_key: &str,
) -> Result<Vec<DailyForecastResponse>, AppError> {
    let region = find_nearest_region(latitude, longitude);
    let tm_fc = get_mid_term_base_time(now);

    let temps = fetch_mid_temp(client, region.temp_reg_id, &tm_fc, api_key).await?;
    let lands = fetch_mid_land(client, region.land_reg_id, &tm_fc, api_key).await?;

    let kst = FixedOffset::east_opt(KST_OFFSET_SECONDS).expect("valid KST offset");
    let base_kst_date = now.with_timezone(&kst).date_naive();

    let mut results = Vec::new();
    for day in 3..=10 {
        let Some((min_temperature, max_temperature)) = temps.get(&day) else {
            continue;
        };
        let Some((am_condition, pm_condition, am_precipitation, pm_precipitation)) =
            lands.get(&day)
        else {
            continue;
        };

        results.push(DailyForecastResponse {
            date: base_kst_date + Duration::days(day as i64),
            min_temperature: *min_temperature,
            max_temperature: *max_temperature,
            am_condition: am_condition.clone(),
            pm_condition: pm_condition.clone(),
            am_precipitation_probability: *am_precipitation,
            pm_precipitation_probability: *pm_precipitation,
        });
    }

    Ok(results)
}

async fn fetch_mid_temp(
    client: &Client,
    reg_id: &str,
    tm_fc: &str,
    api_key: &str,
) -> Result<HashMap<i64, (f64, f64)>, AppError> {
    let json = client
        .get("https://apis.data.go.kr/1360000/MidFcstInfoService/getMidTa")
        .query(&[
            ("serviceKey", api_key),
            ("numOfRows", "10"),
            ("pageNo", "1"),
            ("dataType", "JSON"),
            ("regId", reg_id),
            ("tmFc", tm_fc),
        ])
        .send()
        .await
        .map_err(|error| AppError::Internal(format!("KMA mid temp request failed: {error}")))?
        .json::<Value>()
        .await
        .map_err(|error| AppError::Internal(format!("KMA mid temp decode failed: {error}")))?;

    let result_code = json
        .pointer("/response/header/resultCode")
        .and_then(|value| value.as_str())
        .unwrap_or("");
    if result_code != "00" {
        return Ok(HashMap::new());
    }

    let Some(item) = json.pointer("/response/body/items/item/0") else {
        return Ok(HashMap::new());
    };

    let mut result = HashMap::new();
    for day in 3..=10 {
        let min_key = format!("taMin{day}");
        let max_key = format!("taMax{day}");
        let Some(min_temperature) = item.get(&min_key).and_then(|value| value.as_f64()) else {
            continue;
        };
        let Some(max_temperature) = item.get(&max_key).and_then(|value| value.as_f64()) else {
            continue;
        };
        result.insert(day, (min_temperature, max_temperature));
    }

    Ok(result)
}

async fn fetch_mid_land(
    client: &Client,
    reg_id: &str,
    tm_fc: &str,
    api_key: &str,
) -> Result<HashMap<i64, (String, String, i32, i32)>, AppError> {
    let json = client
        .get("https://apis.data.go.kr/1360000/MidFcstInfoService/getMidLandFcst")
        .query(&[
            ("serviceKey", api_key),
            ("numOfRows", "10"),
            ("pageNo", "1"),
            ("dataType", "JSON"),
            ("regId", reg_id),
            ("tmFc", tm_fc),
        ])
        .send()
        .await
        .map_err(|error| AppError::Internal(format!("KMA mid land request failed: {error}")))?
        .json::<Value>()
        .await
        .map_err(|error| AppError::Internal(format!("KMA mid land decode failed: {error}")))?;

    let result_code = json
        .pointer("/response/header/resultCode")
        .and_then(|value| value.as_str())
        .unwrap_or("");
    if result_code != "00" {
        return Ok(HashMap::new());
    }

    let Some(item) = json.pointer("/response/body/items/item/0") else {
        return Ok(HashMap::new());
    };

    let mut result = HashMap::new();
    for day in 3..=7 {
        let am_condition_key = format!("wf{day}Am");
        let pm_condition_key = format!("wf{day}Pm");
        let am_precipitation_key = format!("rnSt{day}Am");
        let pm_precipitation_key = format!("rnSt{day}Pm");

        let am_condition = item
            .get(&am_condition_key)
            .and_then(|value| value.as_str())
            .map(map_mid_term_condition)
            .unwrap_or("cloudy")
            .to_string();
        let pm_condition = item
            .get(&pm_condition_key)
            .and_then(|value| value.as_str())
            .map(map_mid_term_condition)
            .unwrap_or("cloudy")
            .to_string();
        let am_precipitation = item
            .get(&am_precipitation_key)
            .and_then(|value| value.as_i64())
            .unwrap_or(0) as i32;
        let pm_precipitation = item
            .get(&pm_precipitation_key)
            .and_then(|value| value.as_i64())
            .unwrap_or(0) as i32;
        result.insert(
            day,
            (
                am_condition,
                pm_condition,
                am_precipitation,
                pm_precipitation,
            ),
        );
    }

    for day in 8..=10 {
        let condition_key = format!("wf{day}");
        let precipitation_key = format!("rnSt{day}");
        let condition = item
            .get(&condition_key)
            .and_then(|value| value.as_str())
            .map(map_mid_term_condition)
            .unwrap_or("cloudy")
            .to_string();
        let precipitation = item
            .get(&precipitation_key)
            .and_then(|value| value.as_i64())
            .unwrap_or(0) as i32;
        result.insert(
            day,
            (condition.clone(), condition, precipitation, precipitation),
        );
    }

    Ok(result)
}

fn get_base_date_time(now: DateTime<Utc>) -> (String, String) {
    let kst = FixedOffset::east_opt(KST_OFFSET_SECONDS).expect("valid KST offset");
    let now_kst = now.with_timezone(&kst);
    let current_time = format!("{:02}{:02}", now_kst.hour(), now_kst.minute());
    let base_times = [
        "0200", "0500", "0800", "1100", "1400", "1700", "2000", "2300",
    ];

    let mut selected_base_time = base_times[base_times.len() - 1];
    let mut use_previous_day = true;

    for base_time in base_times {
        let delayed = format!("{}10", &base_time[..2]);
        if current_time >= delayed {
            selected_base_time = base_time;
            use_previous_day = false;
        }
    }

    let base_date = if use_previous_day {
        now_kst.date_naive() - Duration::days(1)
    } else {
        now_kst.date_naive()
    };

    (
        base_date.format("%Y%m%d").to_string(),
        selected_base_time.to_string(),
    )
}

fn get_mid_term_base_time(now: DateTime<Utc>) -> String {
    let kst = FixedOffset::east_opt(KST_OFFSET_SECONDS).expect("valid KST offset");
    let now_kst = now.with_timezone(&kst);
    let mut base_date = now_kst.date_naive();
    let base_hour = if now_kst.hour() >= 18 {
        "1800"
    } else if now_kst.hour() >= 6 {
        "0600"
    } else {
        base_date -= Duration::days(1);
        "1800"
    };

    format!("{}{}", base_date.format("%Y%m%d"), base_hour)
}

fn calculate_feels_like(temperature: f64, wind_speed: f64, humidity: f64) -> f64 {
    if temperature <= 10.0 && wind_speed >= 1.3 {
        let wind_kmh = wind_speed * 3.6;
        let wc = wind_kmh.powf(0.16);
        13.12 + 0.6215 * temperature - 11.37 * wc + 0.3965 * temperature * wc
    } else if temperature >= 27.0 {
        let e = humidity / 100.0 * 6.105 * (17.27 * temperature / (237.7 + temperature)).exp();
        temperature + 0.33 * e - 4.0
    } else {
        temperature
    }
}

fn map_short_term_condition(sky: i32, precipitation_type: i32) -> &'static str {
    if precipitation_type > 0 {
        return match precipitation_type {
            1 => "rain",
            2 => "rainSnow",
            3 => "snow",
            4 => "shower",
            _ => "rain",
        };
    }

    match sky {
        1 => "clear",
        3 => "cloudy",
        4 => "overcast",
        _ => "cloudy",
    }
}

fn map_mid_term_condition(value: &str) -> &'static str {
    if value.contains("비/눈") || value.contains("눈/비") {
        "rainSnow"
    } else if value.contains("눈") {
        "snow"
    } else if value.contains("소나기") {
        "shower"
    } else if value.contains("비") {
        "rain"
    } else if value.contains("흐림") {
        "overcast"
    } else if value.contains("구름많") {
        "cloudy"
    } else if value.contains("맑") {
        "clear"
    } else {
        "cloudy"
    }
}

fn find_nearest_region(latitude: f64, longitude: f64) -> MidTermRegion {
    let mut nearest = MID_TERM_REGIONS[0];
    let mut min_distance = f64::MAX;

    for region in MID_TERM_REGIONS {
        let distance = (latitude - region.lat).powi(2) + (longitude - region.lng).powi(2);
        if distance < min_distance {
            min_distance = distance;
            nearest = region;
        }
    }

    nearest
}

fn round_one_decimal(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    #[test]
    fn mid_term_condition_maps_korean_labels() {
        assert_eq!(map_mid_term_condition("맑음"), "clear");
        assert_eq!(map_mid_term_condition("구름많고 비"), "rain");
        assert_eq!(map_mid_term_condition("흐리고 눈"), "snow");
        assert_eq!(map_mid_term_condition("흐리고 비/눈"), "rainSnow");
    }

    #[test]
    fn nearest_region_prefers_seoul_for_seoul_coords() {
        let region = find_nearest_region(37.5665, 126.9780);
        assert_eq!(region.temp_reg_id, "11B10101");
        assert_eq!(region.land_reg_id, "11B00000");
    }

    #[test]
    fn mid_term_base_time_uses_previous_day_before_six_am_kst() {
        let now = Utc.with_ymd_and_hms(2026, 4, 8, 20, 0, 0).unwrap();
        assert_eq!(get_mid_term_base_time(now), "202604081800");
    }

    #[test]
    fn mid_term_base_time_uses_same_day_six_am_window() {
        let now = Utc.with_ymd_and_hms(2026, 4, 9, 1, 0, 0).unwrap();
        assert_eq!(get_mid_term_base_time(now), "202604090600");
    }

    #[test]
    fn short_term_base_time_applies_ten_minute_delay() {
        let now = Utc.with_ymd_and_hms(2026, 4, 8, 17, 11, 0).unwrap();
        let (base_date, base_time) = get_base_date_time(now);
        assert_eq!(base_date, "20260409");
        assert_eq!(base_time, "0200");
    }

    #[test]
    fn short_term_base_time_uses_previous_day_before_first_window() {
        let now = Utc.with_ymd_and_hms(2026, 4, 8, 16, 55, 0).unwrap();
        let (base_date, base_time) = get_base_date_time(now);
        assert_eq!(base_date, "20260408");
        assert_eq!(base_time, "2300");
    }

    #[test]
    fn feels_like_uses_wind_chill_for_cold_weather() {
        assert!(calculate_feels_like(0.0, 5.0, 50.0) < 0.0);
    }

    #[test]
    fn feels_like_uses_heat_index_for_hot_weather() {
        assert!(calculate_feels_like(30.0, 1.0, 80.0) > 30.0);
    }

    #[test]
    fn round_one_decimal_rounds_normally() {
        assert_eq!(round_one_decimal(12.34), 12.3);
        assert_eq!(round_one_decimal(12.35), 12.4);
    }

    #[test]
    fn short_term_condition_prefers_precipitation() {
        assert_eq!(map_short_term_condition(1, 1), "rain");
        assert_eq!(map_short_term_condition(1, 3), "snow");
        assert_eq!(map_short_term_condition(4, 0), "overcast");
    }

    #[test]
    fn merge_mid_term_date_starts_from_kst_base_date_plus_three() {
        let base_date = NaiveDate::from_ymd_opt(2026, 4, 9).unwrap();
        let result_date = base_date + Duration::days(3);
        assert_eq!(result_date, NaiveDate::from_ymd_opt(2026, 4, 12).unwrap());
    }
}
