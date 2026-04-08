use reqwest::Client;

use crate::errors::AppError;

#[derive(Debug, Clone, serde::Serialize)]
pub struct PlaceResult {
    pub id: String,
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub address: Option<String>,
    pub road_address: Option<String>,
    pub category: Option<String>,
    pub phone: Option<String>,
}

/// Kakao 장소 키워드 검색
///
/// GET https://dapi.kakao.com/v2/local/search/keyword.json
/// Authorization: KakaoAK {api_key}
/// size는 1~45로 clamp한다.
pub async fn search_places(
    query: &str,
    size: i32,
    api_key: &str,
) -> Result<Vec<PlaceResult>, AppError> {
    let size = size.clamp(1, 45);

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| AppError::Internal(format!("Failed to build HTTP client: {e}")))?;

    let resp = client
        .get("https://dapi.kakao.com/v2/local/search/keyword.json")
        .header("Authorization", format!("KakaoAK {api_key}"))
        .query(&[("query", query), ("size", &size.to_string())])
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Kakao Places API request failed: {e}")))?;

    if !resp.status().is_success() {
        return Err(AppError::Internal(format!(
            "Kakao Places API error: {}",
            resp.status()
        )));
    }

    let json: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("Kakao Places response parse failed: {e}")))?;

    Ok(parse_kakao_places_response(&json))
}

/// Kakao 키워드 검색 응답 JSON에서 장소 목록을 파싱한다.
///
/// `documents` 배열에서 각 항목의 필드를 추출한다:
/// - `id`, `place_name`, `y`(lat), `x`(lng), `address_name`,
///   `road_address_name`, `category_group_name`, `phone`
pub fn parse_kakao_places_response(json: &serde_json::Value) -> Vec<PlaceResult> {
    let documents = match json.get("documents").and_then(|v| v.as_array()) {
        Some(arr) => arr,
        None => return vec![],
    };

    documents
        .iter()
        .filter_map(|doc| {
            let id = doc.get("id")?.as_str()?.to_string();
            let name = doc.get("place_name")?.as_str()?.to_string();
            let lat: f64 = doc.get("y")?.as_str()?.parse().ok()?;
            let lng: f64 = doc.get("x")?.as_str()?.parse().ok()?;

            let address = doc
                .get("address_name")
                .and_then(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());

            let road_address = doc
                .get("road_address_name")
                .and_then(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());

            let category = doc
                .get("category_group_name")
                .and_then(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());

            let phone = doc
                .get("phone")
                .and_then(|v| v.as_str())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string());

            Some(PlaceResult {
                id,
                name,
                latitude: lat,
                longitude: lng,
                address,
                road_address,
                category,
                phone,
            })
        })
        .collect()
}
