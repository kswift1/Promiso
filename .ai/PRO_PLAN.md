# Pro Plan 정의

## 상품 구성

Product ID는 `Bundle.main.bundleIdentifier` 기반으로 환경별 자동 생성:

| 상품 | Dev | Stage | Prod | 가격 |
|------|-----|-------|------|------|
| 월간 | `com.promiso.dev.pro.monthly` | `com.promiso.stage.pro.monthly` | `com.promiso.pro.monthly` | ₩3,900/월 |
| 연간 | `com.promiso.dev.pro.yearly` | `com.promiso.stage.pro.yearly` | `com.promiso.pro.yearly` | ₩39,000/년 |
| 평생 | `com.promiso.dev.pro.lifetime` | `com.promiso.stage.pro.lifetime` | `com.promiso.pro.lifetime` | ₩59,000 |

코드에서 `SubscriptionProductType.monthly.productId` 로 접근 (하드코딩 금지).

## Pro 기능

### 1. 일정 충돌 감지 + 날씨 확인
- 일정 생성/리스트 시 기존 일정과의 충돌 여부 자동 감지
- 장소 기반 날씨 정보 표시
- 충돌 감지 임계값 커스텀 (0/15/30/60분)
- **게이팅**: `CreatePromiseFeature.refreshProFeatures` — 무료 사용자는 빈 배열 반환

### 2. 매일 일정 브리핑
- 날씨, 교통, 출발 알림 등을 포함한 일일 브리핑
- 브리핑 스타일 선택 (friendly / humorous / concise / motivational / calm)
- 알림 시간 커스텀 설정
- **게이팅**: `DailyBriefingCard` — 무료 사용자는 상세 텍스트 블러 처리

### 3. 일정간 출발시간 안내
- 교통수단 기반 이동시간 계산
- 출발 시간 안내
- 교통수단 모드 선택 (transit, car 등)
- **게이팅**: 브리핑 시스템과 통합

### Pro가 아닌 기능
- Live Activity / 출발 알림 (Pro 게이팅 없음)
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
StoreKit 2 (앱) → verifyPurchase (Cloud Function) → Firestore subscriptions/{userId}
                                                   ↑
Apple Server Notifications V2 → appleServerNotification (Cloud Function) ─┘
```

- **앱**: StoreKit 2로 구매 → JWS 토큰을 서버로 전송
- **서버**: JWS 검증 후 Firestore 업데이트
- **실시간**: StoreKit + Firestore 리스너 통합 스트림 (`unifiedStatusStream`)

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
