# Subscription 도메인 마이그레이션

## Firebase Functions / Firestore → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `verifyPurchase` | `POST /api/v1/subscriptions/verify-purchase` | ✅ 완료 |
| `subscriptions/{userId}` 상태 조회 | `GET /api/v1/subscriptions/status` | ✅ 완료 |
| `entitlements/{userId}` Pro 판정 조회 | `GET /api/v1/subscriptions/entitlement` | ✅ 완료 |
| Apple Server Notification webhook | `POST /api/v1/subscriptions/apple-notifications` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `SubscriptionClient.fetchStatus` | Rust subscriptions status API | ✅ Rust 고정 |
| `SubscriptionClient.verifyPurchase` | Rust verify-purchase API | ✅ Rust 고정 |
| `SubscriptionClient.fetchEntitlementInfo` | Rust entitlement API | ✅ Rust 고정 |
| `SubscriptionClient.unifiedStatusStream` | Rust entitlement polling + StoreKit updates | ✅ Rust 고정 |
| `StoreKitDataSource` | 로컬 StoreKit purchase/restore/status | ✅ 유지 |

메모:

- `SubscriptionClient`의 서버 authority는 Firestore listener가 아니라 Rust entitlement 응답이다.
- `SubscriptionRemoteDataSource`와 Firebase `verifyPurchase` helper는 제거됐다.

## 남은 항목

- 레거시 Firebase 결제 보조 코드 정리:
  - `StoreKitDataSource` 외 다른 결제/권한 관련 Firebase 직접 참조 점검
- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
