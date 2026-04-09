# Transportation 도메인 마이그레이션

## Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `getTransportation` | `POST /api/v1/transportation` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `TransportationClient.getTransportation` | Rust transportation API | ✅ Rust 고정 |

메모:

- Rust 응답은 기존 Functions 계약과 동일하게 `transitRoutes / driving / walkingMinutes / walkingDistanceKm`를 유지한다.
- 대중교통은 `subPaths`, `lanes`, `passStopCoords`를 포함하고, 자동차는 `routePoints`를 포함한다.
- 직선거리 1km 미만은 기존과 동일하게 외부 API 호출 없이 도보 결과만 반환한다.

## 남은 항목

- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- Rust:
  - `infra/rust-backend/tests/external_api_test.rs`
  - `infra/rust-backend/tests/support_routes_test.rs`
- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
