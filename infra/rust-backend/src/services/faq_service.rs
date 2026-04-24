use chrono::{DateTime, Utc};
use sqlx::PgPool;

use crate::errors::AppError;
use crate::models::faq::FAQItemResponse;

pub async fn fetch_faqs(pool: &PgPool) -> Result<Vec<FAQItemResponse>, AppError> {
    let rows = sqlx::query_as::<_, FaqRow>(
        "SELECT id, question, answer, category, sort_order, created_at, updated_at \
         FROM faqs WHERE is_active = TRUE ORDER BY sort_order ASC, created_at ASC",
    )
    .fetch_all(pool)
    .await?;

    Ok(rows.into_iter().map(Into::into).collect())
}

#[derive(sqlx::FromRow)]
struct FaqRow {
    id: uuid::Uuid,
    question: String,
    answer: String,
    category: String,
    sort_order: i32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl From<FaqRow> for FAQItemResponse {
    fn from(row: FaqRow) -> Self {
        FAQItemResponse {
            id: row.id.to_string(),
            question: row.question,
            answer: row.answer,
            category: row.category,
            order: row.sort_order,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}
