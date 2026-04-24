use serde::Deserialize;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetTransportationRequest {
    pub from_lat: f64,
    pub from_lng: f64,
    pub to_lat: f64,
    pub to_lng: f64,
}
