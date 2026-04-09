use reqwest::Client;
use serde::Serialize;

const MIN_DISTANCE_FOR_API_KM: f64 = 1.0;

#[derive(Debug, Clone, Serialize)]
pub struct TransitLane {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bus_no: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subway_code: Option<i32>,
    #[serde(rename = "type", skip_serializing_if = "Option::is_none")]
    pub lane_type: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bus_color: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TransitSubPath {
    pub traffic_type: i32,
    pub section_time: i32,
    pub distance: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub station_count: Option<i32>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub lanes: Vec<TransitLane>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_x: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_y: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_x: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_y: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub way: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_exit_no: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub pass_stop_coords: Vec<Vec<f64>>,
}

#[derive(Debug, Clone, Serialize)]
pub struct TransitRoute {
    /// 총 소요시간 (분)
    pub total_time: i32,
    /// 요금 (원)
    pub payment: i32,
    /// 버스 환승 횟수
    pub bus_transit_count: i32,
    /// 지하철 환승 횟수
    pub subway_transit_count: i32,
    /// 경로 유형 (1=지하철, 2=버스, 3=지하철+버스)
    pub path_type: i32,
    /// 구간별 상세 정보
    pub sub_paths: Vec<TransitSubPath>,
}

impl TransitRoute {
    pub fn transfer_count(&self) -> i32 {
        self.bus_transit_count + self.subway_transit_count
    }

    pub fn description(&self) -> String {
        let mut parts: Vec<String> = Vec::new();

        for sub_path in &self.sub_paths {
            match sub_path.traffic_type {
                1 => {
                    let lane_name = sub_path
                        .lanes
                        .first()
                        .and_then(|lane| lane.name.clone())
                        .unwrap_or_else(|| "지하철".to_string());
                    parts.push(lane_name);
                }
                2 => {
                    let bus_no = sub_path
                        .lanes
                        .first()
                        .and_then(|lane| lane.bus_no.clone().or_else(|| lane.name.clone()))
                        .unwrap_or_else(|| "버스".to_string());
                    parts.push(format!("버스 {bus_no}"));
                }
                _ => {}
            }
        }

        parts.join(" → ")
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct DrivingRoute {
    /// 총 거리 (미터)
    pub distance: i32,
    /// 소요시간 (분)
    pub duration: i32,
    /// 통행료 (원)
    pub toll: i32,
    /// 자동차 경로 좌표 [[lng, lat], ...]
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub route_points: Vec<Vec<f64>>,
}

impl DrivingRoute {
    pub fn distance_km(&self) -> f64 {
        self.distance as f64 / 1000.0
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct TransportationResult {
    pub transit_routes: Vec<TransitRoute>,
    pub driving: Option<DrivingRoute>,
    pub walking_minutes: i32,
    pub walking_distance_km: f64,
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
            let bus_transit_count = info["busTransitCount"].as_i64().unwrap_or(0) as i32;
            let subway_transit_count = info["subwayTransitCount"].as_i64().unwrap_or(0) as i32;
            let path_type = info["pathType"].as_i64().unwrap_or(3) as i32;
            let sub_paths = parse_odsay_sub_paths(&path["subPath"]);

            TransitRoute {
                total_time,
                payment,
                bus_transit_count,
                subway_transit_count,
                path_type,
                sub_paths,
            }
        })
        .collect()
}

fn parse_odsay_sub_paths(sub_paths: &serde_json::Value) -> Vec<TransitSubPath> {
    let sub_paths = match sub_paths.as_array() {
        Some(arr) => arr,
        None => return vec![],
    };

    sub_paths
        .iter()
        .map(|sub_path| TransitSubPath {
            traffic_type: sub_path["trafficType"].as_i64().unwrap_or(3) as i32,
            section_time: sub_path["sectionTime"].as_i64().unwrap_or(0) as i32,
            distance: sub_path["distance"].as_i64().unwrap_or(0) as i32,
            start_name: sub_path["startName"].as_str().map(str::to_string),
            end_name: sub_path["endName"].as_str().map(str::to_string),
            station_count: sub_path["stationCount"].as_i64().map(|v| v as i32),
            lanes: parse_odsay_lanes(&sub_path["lane"]),
            start_x: value_as_f64(&sub_path["startX"]),
            start_y: value_as_f64(&sub_path["startY"]),
            end_x: value_as_f64(&sub_path["endX"]),
            end_y: value_as_f64(&sub_path["endY"]),
            way: sub_path["way"].as_str().map(str::to_string),
            end_exit_no: match &sub_path["endExitNo"] {
                serde_json::Value::String(value) => Some(value.clone()),
                serde_json::Value::Number(value) => Some(value.to_string()),
                _ => None,
            },
            pass_stop_coords: extract_pass_stop_coords(sub_path),
        })
        .collect()
}

fn parse_odsay_lanes(lanes: &serde_json::Value) -> Vec<TransitLane> {
    lanes
        .as_array()
        .map(|lanes| {
            lanes
                .iter()
                .map(|lane| TransitLane {
                    name: lane["name"].as_str().map(str::to_string),
                    bus_no: lane["busNo"].as_str().map(str::to_string),
                    subway_code: lane["subwayCode"].as_i64().map(|v| v as i32),
                    lane_type: lane["type"].as_i64().map(|v| v as i32),
                    bus_color: lane["busColor"].as_str().map(str::to_string),
                })
                .collect()
        })
        .unwrap_or_default()
}

fn extract_pass_stop_coords(sub_path: &serde_json::Value) -> Vec<Vec<f64>> {
    let stations = match sub_path.pointer("/passStopList/stations") {
        Some(serde_json::Value::Array(arr)) => arr,
        _ => return vec![],
    };

    stations
        .iter()
        .filter_map(|station| {
            let x = value_as_f64(&station["x"])?;
            let y = value_as_f64(&station["y"])?;
            Some(vec![x, y])
        })
        .collect()
}

fn value_as_f64(value: &serde_json::Value) -> Option<f64> {
    match value {
        serde_json::Value::Number(number) => number.as_f64(),
        serde_json::Value::String(value) => value.parse().ok(),
        _ => None,
    }
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
    let duration = ((duration_secs as f64) / 60.0).round() as i32;

    let distance = summary["distance"].as_i64().unwrap_or(0) as i32;

    let toll = summary
        .pointer("/fare/toll")
        .and_then(|v| v.as_i64())
        .unwrap_or(0) as i32;

    let route_points = first["sections"]
        .as_array()
        .map(|sections| {
            sections
                .iter()
                .flat_map(|section| {
                    section["roads"]
                        .as_array()
                        .into_iter()
                        .flatten()
                        .flat_map(|road| {
                            let vertices = road["vertexes"].as_array().cloned().unwrap_or_default();
                            vertices
                                .chunks(2)
                                .filter_map(|chunk| {
                                    if chunk.len() != 2 {
                                        return None;
                                    }
                                    Some(vec![chunk[0].as_f64()?, chunk[1].as_f64()?])
                                })
                                .collect::<Vec<_>>()
                        })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    Some(DrivingRoute {
        duration,
        distance,
        toll,
        route_points,
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

pub async fn fetch_transportation(
    from_lat: f64,
    from_lng: f64,
    to_lat: f64,
    to_lng: f64,
    odsay_api_key: Option<&str>,
    kakao_api_key: Option<&str>,
) -> TransportationResult {
    let distance_km = haversine_distance(from_lat, from_lng, to_lat, to_lng);
    let walking_minutes = estimate_walk_minutes(distance_km);
    let walking_distance_km = distance_km * 1.3;

    if distance_km < MIN_DISTANCE_FOR_API_KM {
        return TransportationResult {
            transit_routes: vec![],
            driving: None,
            walking_minutes,
            walking_distance_km,
        };
    }

    let transit_fut = async {
        match odsay_api_key {
            Some(api_key) => fetch_transit(from_lat, from_lng, to_lat, to_lng, api_key).await,
            None => {
                tracing::warn!("[Transportation] ODSAY_API_KEY not configured");
                vec![]
            }
        }
    };

    let driving_fut = async {
        match kakao_api_key {
            Some(api_key) => fetch_driving(from_lat, from_lng, to_lat, to_lng, api_key).await,
            None => {
                tracing::warn!("[Transportation] KAKAO_REST_API_KEY not configured");
                None
            }
        }
    };

    let (transit_routes, driving) = tokio::join!(transit_fut, driving_fut);

    TransportationResult {
        transit_routes,
        driving,
        walking_minutes,
        walking_distance_km,
    }
}

fn estimate_walk_minutes(distance_km: f64) -> i32 {
    let actual_distance = distance_km * 1.3;
    ((actual_distance / 4.0) * 60.0).round() as i32
}

fn haversine_distance(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    let r = 6371.0;
    let d_lat = (lat2 - lat1).to_radians();
    let d_lng = (lng2 - lng1).to_radians();
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lng / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().atan2((1.0 - a).sqrt());
    r * c
}
