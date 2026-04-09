# FAQ 도메인 마이그레이션

## Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `getFAQs` | `GET /api/v1/faq` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `FAQClient.fetchFAQs` | Rust FAQ API | ✅ Rust 고정 |

메모:

- FAQ 조회는 public API라 `RustAPIClient(getAuthToken: nil)`를 사용한다.
- FAQ database id는 클라이언트가 넘기지 않고 Rust가 `app_config.notion_faq_database_id`를 사용한다.

## 남은 항목

- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- Rust:
  - `infra/rust-backend/tests/support_routes_test.rs`
- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
