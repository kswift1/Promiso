use sqlx::PgPool;

/// 테스트용 DB pool 생성
/// DATABASE_URL 환경변수 사용 (Neon Dev)
pub async fn setup_test_pool() -> PgPool {
    dotenvy::dotenv().ok();
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set for tests");

    let pool = PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to test database");

    // 마이그레이션 실행
    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    pool
}

/// 테스트용 유저 생성 헬퍼
pub async fn create_test_user(pool: &PgPool, id: &str, nickname: &str) {
    sqlx::query(
        "INSERT INTO users (id, name, nickname, provider_type, provider_uid, email)
         VALUES ($1, $2, $3, 'google', 'test-uid', 'test@test.com')
         ON CONFLICT (id) DO NOTHING",
    )
    .bind(id)
    .bind(nickname) // name = nickname
    .bind(nickname)
    .execute(pool)
    .await
    .expect("Failed to create test user");
}

/// 테스트 후 정리 — 특정 유저 삭제
pub async fn cleanup_test_user(pool: &PgPool, id: &str) {
    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await
        .ok(); // 없어도 에러 무시
}

/// 테스트 후 정리 — 테스트 유저 전체 삭제 (test_ prefix)
pub async fn cleanup_all_test_users(pool: &PgPool) {
    sqlx::query("DELETE FROM users WHERE id LIKE 'test_%'")
        .execute(pool)
        .await
        .ok();
}
