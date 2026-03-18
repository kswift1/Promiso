# Pro Plan 정의

> 빠른 overview는 [PRO_FEATURES_GUIDE.md](./PRO_FEATURES_GUIDE.md) 먼저 참고.

## 상품 구성

Product ID는 `Bundle.main.bundleIdentifier` 기반으로 환경별 자동 생성:

| 상품 | Dev | Stage | Prod | 가격 |
|------|-----|-------|------|------|
| 월간 | `com.promiso.dev.pro.monthly` | `com.promiso.stage.pro.monthly` | `com.promiso.pro.monthly` | ₩3,900/월 |
| 연간 | `com.promiso.dev.pro.yearly` | `com.promiso.stage.pro.yearly` | `com.promiso.pro.yearly` | ₩29,000/년 |
| 평생 | `com.promiso.dev.pro.lifetime` | `com.promiso.stage.pro.lifetime` | `com.promiso.pro.lifetime` | ₩39,000 |

코드에서 `SubscriptionProductType.monthly.productId` 로 접근 (하드코딩 금지).

## Pro 기능

### 1. 일정 충돌 감지
- 일정 생성 / 개인 일정 생성 시 기존 일정과의 충돌 여부 자동 감지
- 충돌 감지 임계값 커스텀 (0/15/30/60분)
- 설정 화면에서 충돌 감지 ON/OFF 및 임계값 변경 가능
- **게이팅**: 무료 사용자는 설정 화면에서 토글/옵션 진입 시 Pro Plan 진입

### 2. 날씨 확인
- 일정 생성 / 개인 일정 생성 / 홈 일정 카드에서 장소 기반 날씨 정보 표시
- 홈에서는 Pro 사용자만 날씨 fetch 수행
- **게이팅**: 무료 사용자는 날씨가 blur 되는 형태가 아니라, 날씨 정보 자체를 받지 않음

### 3. 매일 일정 브리핑
- 날씨, 교통, 출발 알림 등을 포함한 일일 브리핑
- 브리핑 스타일 선택 (friendly / humorous / concise / motivational / calm)
- 알림 시간 커스텀 설정
- **게이팅**: `DailyBriefingCard` — 무료 사용자는 상세 텍스트 블러 처리

### 4. 일정간 출발시간 안내
- 홈 오늘 일정 카드에서 교통수단 기반 이동시간 계산
- 출발 시간 안내 / 알림 설정
- 브리핑에서 사용 가능한 교통수단 설정 반영
- **게이팅**: 홈 출발 알림 CTA는 Pro 사용자에게만 노출

### Pro가 아닌 기능
- Live Activity
- 홈 위젯
- 기본 약속 관리, 그룹 약속

## 구독 상태 (SubscriptionStatus)

| 상태 | isPro | 설명 |
|------|-------|------|
| `.none` | false | 구독 없음 |
| `.subscribed` | true | 활성 구독 |
| `.lifetime` | true | 평생 구매 |
| `.gracePeriod` | true | 결제 재시도 중 |
| `.expired` | false | 만료됨 |
| `.revoked` | false | 환불/취소됨 |

## 아키텍처

```
StoreKit 2 (앱) → verifyPurchase (Cloud Function)
                  ├→ Firestore subscriptionOwners/{originalTransactionId}
                  └→ Firestore subscriptions/{userId}

Apple Server Notifications V2 → appleServerNotification (Cloud Function)
                                 ├→ subscriptionOwners/{originalTransactionId} 조회
                                 └→ subscriptions/{userId} 갱신
```

- **앱**: StoreKit 2로 구매 → JWS 토큰을 서버로 전송
- **서버**: `@apple/app-store-server-library`로 transaction / renewal / notification JWS를 검증
- **저장소 역할 분리**: `subscriptions/{userId}`는 현재 구독 상태 SSOT, `subscriptionOwners/{originalTransactionId}`는 App Store 구매 소유권 인덱스
- **정합성 보강**: `signedRenewalInfo`를 반영해 `gracePeriod` / billing retry 상태를 계산하고, `latestAppStoreSignedDate`로 stale replay를 차단
- **웹훅 재시도**: owner를 찾지 못한 Apple Notification은 `500`을 반환해 Apple 재시도를 유도
- **실시간**: StoreKit + Firestore 리스너 통합 스트림 (`unifiedStatusStream`)
- **앱 시작 시 상태 동기화**: `RootTabFeature.observeSubscriptionStatus`에서 `fetchStatus()` 1회 호출 후 `unifiedStatusStream()` 구독
- **수동 복원**: Paywall의 `restoreTapped`에서만 `AppStore.sync()` 실행

## 운영 메모

- `infra/firebase/functions/certs/AppleRootCA-G2.der`, `AppleRootCA-G3.der`는 Functions 배포 산출물에 반드시 포함되어야 한다.
- 원격 Dev / Stage 환경은 Apple Sandbox 서명 데이터만 검증한다. Xcode StoreKit 로컬 토큰은 Firebase Emulator에서만 허용된다.
- `subscriptions/{userId}`는 클라이언트 읽기 전용이며, 모든 쓰기는 `verifyPurchase` / `appleServerNotification` Cloud Functions를 통해서만 이뤄진다.

## 환경별 배포

| 컴포넌트 | Dev | Stage | Prod |
|----------|:---:|:-----:|:----:|
| Firebase 프로젝트 | `promiso-dev` | `promiso-stage` | `promiso-prod` |
| `verifyPurchase` 함수 | ✅ | ✅ | ✅ |
| `appleServerNotification` 웹훅 | ✅ | ✅ | ✅ |
| Firestore 규칙 | ✅ | ✅ | ✅ |
| Feature Flag | ❌ 없음 | ❌ 없음 | ❌ 없음 |

모든 환경에 동일하게 배포. 환경별 Pro 제어 플래그 없음.

## 주요 파일

| 파일 | 역할 |
|------|------|
| `Projects/Features/ProPlanFeature/` | Feature (Reducer + PaywallView + 온보딩) |
| `Projects/Clients/Sources/Clients/SubscriptionClient.swift` | 구독 클라이언트 |
| `Projects/Clients/Sources/Data/DataSources/Implementations/StoreKitDataSource.swift` | StoreKit 2 구현 |
| `Projects/Clients/Sources/Domain/Models/Subscription.swift` | 구독 모델/상태 |
| `Projects/App/ProPlan.storekit` | StoreKit 설정 파일 (Dev/Prod용) |
| `Projects/App/ProPlan-Stage.storekit` | StoreKit 설정 파일 (Stage용) |
| `infra/firebase/functions/src/functions/subscription.ts` | Cloud Functions |
| `Projects/Shared/Sources/UI/Components/ProBadge.swift` | Pro 뱃지 UI |

## Pro 설정 (Firestore)

```
users/{userId}/settings/main
└── proSettings
    ├── conflictDetectionThresholdMinute: 0 | 15 | 30 | 60
    └── briefing
        ├── style: "friendly" | "humorous" | "concise" | "motivational" | "calm"
        ├── notificationHour: 0-23
        ├── timezone: TimeZone identifier
        ├── language: Locale code
        └── availableTransports: ["transit", "car", ...]
```

## 런치 체크리스트

- 현재 구현 기준 체크리스트는 `.ai/PRO_PLAN_LAUNCH_CHECKLIST.md` 참조
