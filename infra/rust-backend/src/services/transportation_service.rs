use crate::errors::AppError;
use crate::models::transportation::GetTransportationRequest;
use crate::services::transportation_client::{self, TransportationResult};

pub async fn get_transportation(
    req: GetTransportationRequest,
    odsay_api_key: Option<&str>,
    kakao_api_key: Option<&str>,
) -> Result<TransportationResult, AppError> {
    if !req.from_lat.is_finite()
        || !req.from_lng.is_finite()
        || !req.to_lat.is_finite()
        || !req.to_lng.is_finite()
    {
        return Err(AppError::BadRequest(
            "출발지와 도착지 좌표가 필요합니다".to_string(),
        ));
    }

    Ok(transportation_client::fetch_transportation(
        req.from_lat,
        req.from_lng,
        req.to_lat,
        req.to_lng,
        odsay_api_key,
        kakao_api_key,
    )
    .await)
}
