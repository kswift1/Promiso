use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GetWeatherRequest {
    pub latitude: f64,
    pub longitude: f64,
    pub target_date: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct WeatherResponse {
    pub forecasts: Vec<HourlyForecastResponse>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub daily_forecasts: Vec<DailyForecastResponse>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HourlyForecastResponse {
    pub date_time: DateTime<Utc>,
    pub temperature: f64,
    pub feels_like_temperature: f64,
    pub condition: String,
    pub precipitation_probability: i32,
    pub humidity: i32,
    pub wind_speed: f64,
    pub precipitation_amount: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DailyForecastResponse {
    pub date: NaiveDate,
    pub min_temperature: f64,
    pub max_temperature: f64,
    pub am_condition: String,
    pub pm_condition: String,
    pub am_precipitation_probability: i32,
    pub pm_precipitation_probability: i32,
}
