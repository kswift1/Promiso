use reqwest::Client;

#[derive(Debug, Clone, serde::Serialize)]
pub struct TransitRoute {
    /// 총 소요시간 (분)
    pub total_time: i32,
    /// 요금 (원)
    pub payment: i32,
    /// 환승 횟수 (버스 + 지하철 합산)
    pub transfer_count: i32,
    /// 경로 유형 (1=지하철, 2=버스, 3=지하철+버스)
    pub path_type: i32,
    /// 경로 설명 (예: "2호선 → 버스 142")
    pub description: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct DrivingRoute {
    /// 소요시간 (분)
    pub duration_minutes: i32,
    /// 거리 (km)
    pub distance_km: f64,
    /// 통행료 (원)
    pub toll: i32,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct TransportationResult {
    pub transit_routes: Vec<TransitRoute>,
    pub driving: Option<DrivingRoute>,
    pub walk_minutes: i32,
}

/// ODsay 대중교통 경로 응답 파싱 (최대 5개)
///
/// 응답 형식:
/// ```json
/// {
///   "result": {
///     "path": [
///       {
///         "info": { "totalTime": 45, "payment": 1500, "busTransitCount": 0,
///                   "subwayTransitCount": 1, "pathType": 1 },
///         "subPath": [...]
///       }
///     ]
///   }
/// }
/// ```
pub fn parse_odsay_response(json: &serde_json::Value) -> Vec<TransitRoute> {
    let paths = match json.pointer("/result/path") {
        Some(serde_json::Value::Array(arr)) => arr,
        _ => return vec![],
    };

    paths
        .iter()
        .take(5)
        .map(|path| {
            let info = &path["info"];
            let total_time = info["totalTime"].as_i64().unwrap_or(0) as i32;
            let payment = info["payment"].as_i64().unwrap_or(0) as i32;
            let bus_count = info["busTransitCount"].as_i64().unwrap_or(0) as i32;
            let subway_count = info["subwayTransitCount"].as_i64().unwrap_or(0) as i32;
            let path_type = info["pathType"].as_i64().unwrap_or(3) as i32;
            let transfer_count = bus_count + subway_count;

            let description = build_odsay_description(&path["subPath"]);

            TransitRoute {
                total_time,
                payment,
                transfer_count,
                path_type,
                description,
            }
        })
        .collect()
}

/// subPath 배열에서 경로 설명 문자열 생성
fn build_odsay_description(sub_path: &serde_json::Value) -> String {
    let sub_paths = match sub_path.as_array() {
        Some(arr) => arr,
        None => return String::new(),
    };

    let mut parts: Vec<String> = Vec::new();

    for sp in sub_paths {
        let traffic_type = sp["trafficType"].as_i64().unwrap_or(3);

        match traffic_type {
            1 => {
                // 지하철
                let lane_name = sp["lane"]
                    .as_array()
                    .and_then(|lanes| lanes.first())
                    .and_then(|lane| lane["name"].as_str())
                    .unwrap_or("지하철")
                    .to_string();
                parts.push(lane_name);
            }
            2 => {
                // 버스
                let bus_no = sp["lane"]
                    .as_array()
                    .and_then(|lanes| lanes.first())
                    .and_then(|lane| lane["busNo"].as_str().or_else(|| lane["name"].as_str()))
                    .unwrap_or("버스")
                    .to_string();
                parts.push(format!("버스 {bus_no}"));
            }
            _ => {}
        }
    }

    parts.join(" → ")
}

/// Kakao Mobility 자동차 경로 응답 파싱
///
/// 응답 형식:
/// ```json
/// {
///   "routes": [
///     {
///       "summary": { "duration": 2700, "distance": 18500,
///                    "fare": { "toll": 900 } }
///     }
///   ]
/// }
/// ```
///
/// duration: 초 → 분 변환 (반올림)
/// distance: m → km 변환
pub fn parse_kakao_response(json: &serde_json::Value) -> Option<DrivingRoute> {
    let routes = json["routes"].as_array()?;
    let first = routes.first()?;
    let summary = &first["summary"];

    let duration_secs = summary["duration"].as_i64().unwrap_or(0);
    let duration_minutes = ((duration_secs as f64) / 60.0).round() as i32;

    let distance_m = summary["distance"].as_f64().unwrap_or(0.0);
    let distance_km = distance_m / 1000.0;

    let toll = summary
        .pointer("/fare/toll")
        .and_then(|v| v.as_i64())
        .unwrap_or(0) as i32;

    Some(DrivingRoute {
        duration_minutes,
        distance_km,
        toll,
    })
}

/// ODsay 대중교통 조회
pub async fn fetch_transit(
    from_lat: f64,
    from_lng: f64,
    to_lat: f64,
    to_lng: f64,
    api_key: &str,
) -> Vec<TransitRoute> {
    let client = match Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("[Transit] Failed to build HTTP client: {e}");
            return vec![];
        }
    };

    let result = client
        .get("https://api.odsay.com/v1/api/searchPubTransPathT")
        .query(&[
            ("SX", &from_lng.to_string()),
            ("SY", &from_lat.to_string()),
            ("EX", &to_lng.to_string()),
            ("EY", &to_lat.to_string()),
            ("apiKey", &api_key.to_string()),
        ])
        .send()
        .await;

    match result {
        Ok(resp) if resp.status().is_success() => match resp.json::<serde_json::Value>().await {
            Ok(json) => parse_odsay_response(&json),
            Err(e) => {
                tracing::warn!("[Transit] JSON parse error: {e}");
                vec![]
            }
        },
        Ok(resp) => {
            tracing::warn!("[Transit] ODsay API error: {}", resp.status());
            vec![]
        }
        Err(e) => {
            tracing::warn!("[Transit] fetch error: {e}");
            vec![]
        }
    }
}

/// Kakao Mobility 자동차 경로 조회
pub async fn fetch_driving(
    from_lat: f64,
    from_lng: f64,
    to_lat: f64,
    to_lng: f64,
    api_key: &str,
) -> Option<DrivingRoute> {
    let client = match Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            tracing::warn!("[Driving] Failed to build HTTP client: {e}");
            return None;
        }
    };

    let origin = format!("{from_lng},{from_lat}");
    let destination = format!("{to_lng},{to_lat}");

    let result = client
        .get("https://apis-navi.kakaomobility.com/v1/directions")
        .header("Authorization", format!("KakaoAK {api_key}"))
        .query(&[("origin", &origin), ("destination", &destination)])
        .send()
        .await;

    match result {
        Ok(resp) if resp.status().is_success() => match resp.json::<serde_json::Value>().await {
            Ok(json) => parse_kakao_response(&json),
            Err(e) => {
                tracing::warn!("[Driving] JSON parse error: {e}");
                None
            }
        },
        Ok(resp) => {
            tracing::warn!("[Driving] Kakao API error: {}", resp.status());
            None
        }
        Err(e) => {
            tracing::warn!("[Driving] fetch error: {e}");
            None
        }
    }
}
