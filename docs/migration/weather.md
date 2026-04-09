# Weather 도메인 마이그레이션

## Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `getWeather` | `POST /api/v1/weather` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `WeatherClient.getWeather` | Rust weather API + client cache | ✅ Rust 고정 |

메모:

- 서버는 KMA 단기예보와 중기예보를 직접 조회한다.
- iOS는 기존 `WeatherDataSource`의 캐시 키와 current forecast 선택 규칙을 `WeatherRustDataSource`로 유지한다.

## 남은 항목

- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- Rust:
  - `infra/rust-backend/tests/support_routes_test.rs`
- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
