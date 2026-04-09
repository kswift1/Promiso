# Places 도메인 마이그레이션

## Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `searchPlaces` | `GET /api/v1/places/search?q={query}&size={size}` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `MapClient.searchPlaces` | Rust places API | ✅ Rust 고정 |
| `MapClient.openDirections*` | 로컬 URL scheme deep link | ✅ 유지 |

메모:

- `MapClient`의 Firebase Functions fallback은 제거됐다.
- places 검색은 public API라 `RustAPIClient(getAuthToken: nil)`를 사용한다.

## 남은 항목

- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
