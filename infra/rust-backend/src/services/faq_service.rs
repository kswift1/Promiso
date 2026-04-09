use chrono::{DateTime, Utc};
use reqwest::Client;
use serde::Deserialize;
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::faq::FAQItemResponse;
use crate::services::app_config_service;

#[derive(Debug, Deserialize)]
struct NotionQueryResponse {
    results: Vec<NotionPage>,
}

#[derive(Debug, Deserialize)]
struct NotionPage {
    id: String,
    created_time: String,
    last_edited_time: String,
    properties: NotionProperties,
}

#[derive(Debug, Deserialize)]
struct NotionProperties {
    #[serde(rename = "Question")]
    question: Option<NotionTitleProperty>,
    #[serde(rename = "Answer")]
    answer: Option<NotionRichTextProperty>,
    #[serde(rename = "Category")]
    category: Option<NotionSelectProperty>,
    #[serde(rename = "Order")]
    order: Option<NotionNumberProperty>,
}

#[derive(Debug, Deserialize)]
struct NotionTitleProperty {
    title: Vec<NotionText>,
}

#[derive(Debug, Deserialize)]
struct NotionRichTextProperty {
    rich_text: Vec<NotionText>,
}

#[derive(Debug, Deserialize)]
struct NotionText {
    plain_text: String,
}

#[derive(Debug, Deserialize)]
struct NotionSelectProperty {
    select: Option<NotionSelectValue>,
}

#[derive(Debug, Deserialize)]
struct NotionSelectValue {
    name: String,
}

#[derive(Debug, Deserialize)]
struct NotionNumberProperty {
    number: Option<i32>,
}

pub async fn fetch_faqs(pool: &PgPool) -> Result<Vec<FAQItemResponse>, AppError> {
    let config = app_config_service::get_app_config(pool).await?;
    let database_id = config.notion_faq_database_id.trim();
    if database_id.is_empty() {
        return Err(AppError::PreconditionFailed(
            "FAQ database id가 설정되지 않았습니다".to_string(),
        ));
    }

    let api_key = std::env::var("NOTION_FAQ_API_KEY")
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .ok_or_else(|| {
            AppError::PreconditionFailed("NOTION_FAQ_API_KEY가 설정되지 않았습니다".to_string())
        })?;

    let url = format!("https://api.notion.com/v1/databases/{database_id}/query");
    let response = Client::new()
        .post(url)
        .header("Authorization", format!("Bearer {api_key}"))
        .header("Notion-Version", "2022-06-28")
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "filter": {
                "property": "Active",
                "checkbox": { "equals": true }
            },
            "sorts": [{
                "property": "Order",
                "direction": "ascending"
            }]
        }))
        .send()
        .await
        .map_err(|error| AppError::Internal(format!("Notion request failed: {error}")))?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        return Err(AppError::Internal(format!(
            "Notion FAQ request failed: status={status}, body={body}"
        )));
    }

    let notion_response: NotionQueryResponse = response
        .json()
        .await
        .map_err(|error| AppError::Internal(format!("Notion decode failed: {error}")))?;

    let mut faqs: Vec<FAQItemResponse> = notion_response
        .results
        .into_iter()
        .filter_map(|page| {
            let question = page
                .properties
                .question
                .map(|property| join_plain_texts(property.title))
                .unwrap_or_default();
            let answer = page
                .properties
                .answer
                .map(|property| join_plain_texts(property.rich_text))
                .unwrap_or_default();

            if question.trim().is_empty() || answer.trim().is_empty() {
                return None;
            }

            let created_at = parse_rfc3339(&page.created_time)?;
            let updated_at = parse_rfc3339(&page.last_edited_time)?;

            Some(FAQItemResponse {
                id: page.id,
                question,
                answer,
                category: page
                    .properties
                    .category
                    .and_then(|property| property.select)
                    .map(|value| value.name)
                    .unwrap_or_else(|| "기타".to_string()),
                order: page
                    .properties
                    .order
                    .and_then(|property| property.number)
                    .unwrap_or(999),
                created_at,
                updated_at,
            })
        })
        .collect();

    faqs.sort_by_key(|item| item.order);
    Ok(faqs)
}

fn join_plain_texts(parts: Vec<NotionText>) -> String {
    parts
        .into_iter()
        .map(|part| part.plain_text)
        .collect::<Vec<_>>()
        .join("")
}

fn parse_rfc3339(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|date| date.with_timezone(&Utc))
}
