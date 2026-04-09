//! 외부 API 응답 파싱 테스트 (Red Phase)
//!
//! 실제 HTTP 호출 없이 알려진 JSON 응답을 파싱하는 순수 함수를 테스트한다.

use promiso_backend::services::{gemini_client, transportation_client, weather_client};
use serde_json::json;

// ============================================================
// KMA 날씨 파싱 테스트
// ============================================================

/// TMP, SKY 카테고리 파싱 검증
#[test]
fn parse_kma_extracts_temperature_and_sky() {
    let json = json!({
        "response": {
            "header": { "resultCode": "00", "resultMsg": "NORMAL_SERVICE" },
            "body": {
                "items": {
                    "item": [
                        {
                            "baseDate": "20260408",
                            "baseTime": "0800",
                            "category": "TMP",
                            "fcstDate": "20260408",
                            "fcstTime": "1200",
                            "fcstValue": "18",
                            "nx": 60,
                            "ny": 127
                        },
                        {
                            "baseDate": "20260408",
                            "baseTime": "0800",
                            "category": "SKY",
                            "fcstDate": "20260408",
                            "fcstTime": "1200",
                            "fcstValue": "1",
                            "nx": 60,
                            "ny": 127
                        },
                        {
                            "baseDate": "20260408",
                            "baseTime": "0800",
                            "category": "POP",
                            "fcstDate": "20260408",
                            "fcstTime": "1200",
                            "fcstValue": "10",
                            "nx": 60,
                            "ny": 127
                        }
                    ]
                }
            }
        }
    });

    let forecasts = weather_client::parse_kma_response(&json);

    assert!(!forecasts.is_empty(), "예보 결과가 있어야 한다");
    let forecast = &forecasts[0];
    assert_eq!(
        forecast.temperature,
        Some(18.0),
        "TMP 카테고리에서 기온 18°C 파싱"
    );
    assert_eq!(
        forecast.sky,
        Some("clear".to_string()),
        "SKY=1 → clear 매핑"
    );
    assert_eq!(
        forecast.precipitation_probability,
        Some(10),
        "POP 카테고리에서 강수확률 10% 파싱"
    );
}

/// 빈 응답 시 빈 Vec 반환
#[test]
fn parse_kma_handles_empty_items() {
    let json = json!({
        "response": {
            "header": { "resultCode": "00", "resultMsg": "NORMAL_SERVICE" },
            "body": {
                "items": {
                    "item": []
                }
            }
        }
    });

    let forecasts = weather_client::parse_kma_response(&json);
    assert!(forecasts.is_empty(), "빈 item 배열이면 빈 Vec 반환");
}

/// 서울역(37.5547, 126.9707) → 알려진 격자 좌표 (60, 127)
#[test]
fn convert_to_grid_seoul_station() {
    let (nx, ny) = weather_client::convert_to_grid(37.5547, 126.9707);
    // 기상청 격자 변환 기준값 (서울역 인근)
    assert_eq!(nx, 60, "서울역 nx=60");
    assert_eq!(ny, 127, "서울역 ny=127");
}

// ============================================================
// ODsay 대중교통 파싱 테스트
// ============================================================

/// path 배열에서 시간/요금/환승 추출
#[test]
fn parse_odsay_extracts_routes() {
    let json = json!({
        "result": {
            "path": [
                {
                    "info": {
                        "totalTime": 45,
                        "payment": 1500,
                        "busTransitCount": 0,
                        "subwayTransitCount": 1,
                        "pathType": 1
                    },
                    "subPath": [
                        {
                            "trafficType": 1,
                            "sectionTime": 35,
                            "distance": 15000,
                            "startName": "서울역",
                            "endName": "강남역",
                            "startX": 126.9707,
                            "startY": 37.5547,
                            "endX": 127.0276,
                            "endY": 37.4979,
                            "way": "내선순환",
                            "endExitNo": "11",
                            "lane": [
                                { "subwayCode": 2, "name": "2호선" }
                            ],
                            "passStopList": {
                                "stations": [
                                    { "x": "126.9707", "y": "37.5547" },
                                    { "x": "126.9820", "y": "37.5650" },
                                    { "x": "127.0276", "y": "37.4979" }
                                ]
                            }
                        },
                        {
                            "trafficType": 2,
                            "sectionTime": 7,
                            "distance": 1100,
                            "startName": "강남역",
                            "endName": "역삼역",
                            "stationCount": 2,
                            "lane": [
                                {
                                    "busNo": "146",
                                    "name": "146",
                                    "type": 11,
                                    "busColor": "#5BB025"
                                }
                            ]
                        },
                        {
                            "trafficType": 3,
                            "sectionTime": 10,
                            "distance": 500
                        }
                    ]
                },
                {
                    "info": {
                        "totalTime": 55,
                        "payment": 1500,
                        "busTransitCount": 1,
                        "subwayTransitCount": 0,
                        "pathType": 2
                    },
                    "subPath": [
                        {
                            "trafficType": 2,
                            "sectionTime": 50,
                            "distance": 12000,
                            "startName": "서울역",
                            "endName": "강남역",
                            "lane": [
                                { "busNo": "142", "name": "142" }
                            ]
                        }
                    ]
                }
            ]
        }
    });

    let routes = transportation_client::parse_odsay_response(&json);

    assert_eq!(routes.len(), 2, "2개 경로 파싱");
    assert_eq!(routes[0].total_time, 45, "첫 번째 경로 소요시간 45분");
    assert_eq!(routes[0].payment, 1500, "첫 번째 경로 요금 1500원");
    assert_eq!(
        routes[0].transfer_count(),
        1,
        "첫 번째 경로 환승 1회 (subway)"
    );
    assert_eq!(routes[0].path_type, 1, "첫 번째 경로 지하철 타입");
    assert_eq!(routes[0].description(), "2호선 → 버스 146");
    assert_eq!(routes[0].sub_paths.len(), 3, "상세 subPath 파싱");
    assert_eq!(routes[0].sub_paths[0].way.as_deref(), Some("내선순환"));
    assert_eq!(routes[0].sub_paths[0].end_exit_no.as_deref(), Some("11"));
    assert_eq!(routes[0].sub_paths[0].pass_stop_coords.len(), 3);
    assert_eq!(
        routes[0].sub_paths[1].lanes[0].bus_color.as_deref(),
        Some("#5BB025")
    );
    assert_eq!(routes[0].sub_paths[1].lanes[0].lane_type, Some(11));
    assert_eq!(routes[1].path_type, 2, "두 번째 경로 버스 타입");
}

/// 최대 5개 경로만 반환
#[test]
fn parse_odsay_limits_to_5_routes() {
    let paths: Vec<serde_json::Value> = (0..8)
        .map(|i| {
            json!({
                "info": {
                    "totalTime": 30 + i,
                    "payment": 1500,
                    "busTransitCount": 0,
                    "subwayTransitCount": 0,
                    "pathType": 1
                },
                "subPath": []
            })
        })
        .collect();

    let json = json!({ "result": { "path": paths } });
    let routes = transportation_client::parse_odsay_response(&json);

    assert_eq!(routes.len(), 5, "최대 5개 경로만 반환");
}

/// 빈 응답 시 빈 Vec 반환
#[test]
fn parse_odsay_handles_empty_result() {
    let json = json!({ "result": { "path": [] } });
    let routes = transportation_client::parse_odsay_response(&json);
    assert!(routes.is_empty(), "빈 path 배열이면 빈 Vec 반환");

    // result 자체가 없는 경우
    let json2 = json!({});
    let routes2 = transportation_client::parse_odsay_response(&json2);
    assert!(routes2.is_empty(), "result 없으면 빈 Vec 반환");
}

// ============================================================
// Kakao Mobility 파싱 테스트
// ============================================================

/// duration(초→분), distance(m→km), toll 추출
#[test]
fn parse_kakao_extracts_duration_and_distance() {
    let json = json!({
        "routes": [
            {
                "summary": {
                    "duration": 2700,
                    "distance": 18500,
                    "fare": {
                        "toll": 900,
                        "taxi": 25000
                    }
                },
                "sections": [
                    {
                        "roads": [
                            {
                                "vertexes": [
                                    126.9707, 37.5547,
                                    126.9800, 37.5600,
                                    127.0276, 37.4979
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    });

    let driving = transportation_client::parse_kakao_response(&json);

    assert!(driving.is_some(), "경로가 있으면 Some 반환");
    let d = driving.unwrap();
    assert_eq!(d.duration, 45, "2700초 → 45분");
    assert_eq!(d.distance, 18500, "distance 원본 미터 유지");
    assert_eq!(d.toll, 900, "통행료 900원");
    assert_eq!(d.route_points.len(), 3, "자동차 polyline 좌표 파싱");
    assert_eq!(d.route_points[0], vec![126.9707, 37.5547]);
}

/// 빈 응답 시 None 반환
#[test]
fn parse_kakao_handles_no_routes() {
    let json = json!({ "routes": [] });
    let driving = transportation_client::parse_kakao_response(&json);
    assert!(driving.is_none(), "빈 routes 배열이면 None 반환");

    let json2 = json!({});
    let driving2 = transportation_client::parse_kakao_response(&json2);
    assert!(driving2.is_none(), "routes 없으면 None 반환");
}

// ============================================================
// Gemini 응답 파싱 테스트
// ============================================================

/// ```json {...} ``` fence에서 JSON 추출
#[test]
fn parse_gemini_extracts_json_from_fence() {
    let text = r#"네, 브리핑을 생성했습니다.

```json
{"summary": "오늘 오후 3시 강남역 미팅이 있습니다.", "detail": "오늘은 중요한 미팅이 예정되어 있습니다. 오후 3시 강남역 근처 카페에서 팀 전체 회의가 있으니 미리 출발하세요."}
```

위 내용이 오늘의 브리핑입니다."#;

    let (summary, detail): (String, String) = gemini_client::parse_gemini_response(text);

    assert_eq!(summary, "오늘 오후 3시 강남역 미팅이 있습니다.");
    assert!(
        detail.contains("중요한 미팅"),
        "detail에 본문 포함: {detail}"
    );
}

/// fence 없이 순수 JSON 파싱
#[test]
fn parse_gemini_extracts_json_without_fence() {
    let text = r#"{"summary": "일정 없는 여유로운 하루입니다.", "detail": "오늘은 특별한 일정이 없습니다. 여유롭게 하루를 보내세요."}"#;

    let (summary, detail): (String, String) = gemini_client::parse_gemini_response(text);

    assert_eq!(summary, "일정 없는 여유로운 하루입니다.");
    assert!(detail.contains("여유롭게"), "detail 내용 포함: {detail}");
}

/// JSON 파싱 실패 시 첫 문장 → summary(30자), 전체 → detail
#[test]
fn parse_gemini_fallback_on_invalid_json() {
    let text = "오늘은 정말 바쁜 하루가 될 것 같습니다. 오전 9시에 회의가 있고 오후에는 외부 미팅도 있습니다.";

    let (summary, detail): (String, String) = gemini_client::parse_gemini_response(text);

    assert!(
        summary.len() <= 30,
        "fallback summary는 30자 이하: '{summary}' ({}자)",
        summary.len()
    );
    assert_eq!(detail, text, "fallback detail은 전체 텍스트");
}

/// <user-data> 태그 제거
#[test]
fn parse_gemini_strips_user_data_tags() {
    let text = r#"```json
{"summary": "<user-data>홍길동</user-data>님의 오늘 일정", "detail": "오늘 <user-data>홍길동</user-data>님은 바쁜 하루를 보냅니다."}
```"#;

    let (summary, detail): (String, String) = gemini_client::parse_gemini_response(text);

    assert!(
        !summary.contains("<user-data>"),
        "summary에 <user-data> 태그 없어야 함: {summary}"
    );
    assert!(
        !summary.contains("</user-data>"),
        "summary에 </user-data> 태그 없어야 함: {summary}"
    );
    assert!(
        !detail.contains("<user-data>"),
        "detail에 <user-data> 태그 없어야 함: {detail}"
    );
    assert!(
        !detail.contains("</user-data>"),
        "detail에 </user-data> 태그 없어야 함: {detail}"
    );
    assert!(
        summary.contains("홍길동"),
        "태그 제거 후 텍스트 유지: {summary}"
    );
}
