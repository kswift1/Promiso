# Promiso LiveActivity 구현 명세서

## 개요

약속 당일 실시간 도착 상황을 Dynamic Island와 잠금화면에서 공유하는 기능.
**레이싱 트랙 UI**로 참가자들의 ETA(도착 예상 시간)를 시각화.

```
┌─Start───────────────────────────────────Finish─┐
│  😀         🙂           😎                 🏁  │
│  Seo       Jihyun      Me+Minsu                │
│ (wait)     (15m)        (10m)        (arrived) │
└────────────────────────────────────────────────┘
```

---

## 기술 스택

| 항목 | 값 |
|------|-----|
| iOS Target | 18.0+ |
| ActivityKit | iOS 16.1+ |
| Dynamic Island | iPhone 14 Pro+ |
| Backend | Firebase Functions + APNs |
| Widget Bundle | `LiveActivityWidgetBundle` |
| App Group | `group.com.promiso.shared` |

---

## 아키텍처

```
┌───────────────────────────────────────────────────────┐
│                  Firebase Functions                   │
│  ┌───────────────────┐  ┌──────────────────┐          │
│  │ startLiveActivity │  │ updateETA        │          │
│  │ (APNs start)      │  │ (APNs update)    │          │
│  └────────┬──────────┘  └────────┬─────────┘          │
└───────────┼──────────────────────┼────────────────────┘
            │                      │
            ▼                      ▼
┌───────────────────────────────────────────────────────┐
│                      APNs Push                        │
│              ContentState update payload              │
└───────────────────────────────────────────────────────┘
            │
            ▼
┌───────────────────────────────────────────────────────┐
│                       iOS App                         │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │          LiveActivityWidget (Extension)         │  │
│  │  ┌─────────────┐ ┌─────────────┐ ┌───────────┐  │  │
│  │  │ LockScreen  │ │DynamicIsland│ │ Racing    │  │  │
│  │  │ BannerView  │ │ (Expanded)  │ │ TrackView │  │  │
│  │  └─────────────┘ └─────────────┘ └───────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │                    Main App                     │  │
│  │  ┌──────────────┐  ┌─────────────────────────┐  │  │
│  │  │ LiveActivity │  │ LiveActivityImageStore  │  │  │
│  │  │ Client       │  │ (App Group caching)     │  │  │
│  │  └──────────────┘  └─────────────────────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

---

## 디렉토리 구조

```
Projects/
├── App/
│   └── Extensions/
│       └── LiveActivityWidget/
│           ├── Sources/
│           │   ├── LiveActivityWidgetBundle.swift   # Widget 진입점
│           │   ├── PromiseLiveActivity.swift        # Widget 정의 + Previews
│           │   ├── UpdateETAIntent.swift            # ETA 버튼 Intent
│           │   └── Views/
│           │       ├── LockScreenView.swift         # 잠금화면 배너
│           │       └── RacingTrackView.swift        # 레이싱 트랙 UI
│           ├── LiveActivityWidget.entitlements
│           └── LIVE_ACTIVITY_SPEC.md
│
├── Shared/
│   └── Sources/
│       ├── LiveActivity/
│       │   ├── PromiseActivityAttributes.swift     # 공유 모델
│       │   └── LiveActivityImageStore.swift        # 프로필 이미지 캐싱
│       └── Common/
│           └── AppLogger.swift
│
└── Clients/
    └── Sources/
        └── Clients/
            └── LiveActivityClient.swift            # TCA Dependency
```

---

## 데이터 모델

### PromiseActivityAttributes

```swift
/// 라이브액티비티 속성 (Activity 생성 시 고정)
public struct PromiseActivityAttributes: ActivityAttributes {
  public let trackingDurationMinutes: Int  // 추적 시간 (기본 30분)
  public let promiseId: String
  public let currentUserId: String
  public let emoji: String                 // 약속 이모지
  public let title: String                 // 약속 제목
  public let location: String?             // 장소명
  public let scheduledTime: Date           // 약속 시간
  public let hostId: String                // 호스트 사용자 ID
  public let hostName: String?             // 호스트 표시 이름

  /// 동적 상태 (APNs로 업데이트)
  public struct ContentState: Codable, Hashable, Sendable {
    public let trackingDurationMinutes: Int
    public let participants: [ParticipantState]
  }
}
```

### ParticipantState

```swift
/// 참가자 상태
public struct ParticipantState: Codable, Hashable, Identifiable, Sendable {
  public let id: String           // userId
  public let name: String         // 표시 이름
  public var estimatedArrivalMinutes: Int?  // ETA (nil=대기, 0=도착, N=N분 후)

  /// 트랙 위치 계산 (0.0 ~ 1.0)
  public func trackPosition(trackingDurationMinutes: Int) -> Double {
    guard let eta = estimatedArrivalMinutes else { return 0.0 }  // 대기
    if eta == 0 { return 1.0 }  // 도착
    let progress = Double(trackingDurationMinutes - eta) / Double(trackingDurationMinutes)
    return min(max(progress, 0.05), 0.95)
  }
}
```

### ETA 상태 매핑

| ETA 값 | 상태 | 트랙 위치 | 뱃지 색상 |
|--------|------|----------|----------|
| `nil` | 대기 | 0.0 (출발점) | Gray |
| `30` | 이동 중 | 0.05 | Indigo |
| `15` | 이동 중 | 0.5 | Indigo |
| `5` | 거의 도착 | 0.83 | Indigo |
| `0` | 도착 | 1.0 (도착점) | Green |

---

## Widget UI

### 1. LockScreen Banner

잠금화면에 표시되는 메인 배너 뷰

```
┌───────────────────────────────────────────────────┐
│  🍜 Lunch                            Scheduled    │
│  📍 Gangnam Station Exit 11           PM 12:30    │
│                                                   │
│  ┌─Start─────────────────────────────Finish─┐     │
│  │  😀Seo   🙂Jihyun   😎Me+Minsu       🏁  │     │
│  └──────────────────────────────────────────┘     │
│                                                   │
│  ETA  [ Done ] [ 5m ] [ 10m ] [ Custom ]          │
└───────────────────────────────────────────────────┘
```

**헤더 섹션:**
- 왼쪽: 이모지 + 제목, 장소 (📍)
- 오른쪽: "약속 시간" 라벨 + AM/PM 시간

**레이싱 트랙:**
- 줄무늬 배경 (세로 스트라이프)
- 진행률 바 (그라데이션)
- 참가자 마커 (프로필/이모지 + 이름)

**ETA 버튼 섹션:**
- 라벨: "도착" (eta=0) / "도착까지" (eta>0)
- Segmented Control: 완료(✓), 5분, 10분, 직접

### 2. Dynamic Island (Expanded)

```
┌────────────────────────────────────────────┐
│  🍜 Lunch                      Scheduled   │
│  📍 Gangnam Exit 11             PM 12:30   │
├────────────────────────────────────────────┤
│  ┌──────────────────────────────────────┐  │
│  │  😀Seo  🙂Jihyun  😎Me+Minsu     🏁  │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

- **Center**: HStack으로 좌(제목+장소) / 우(시간) 배치
- **Bottom**: RacingTrackView (height: 44)
- 긴 제목: `minimumScaleFactor(0.7)` 적용

### 3. Dynamic Island (Compact)

```
┌──────────────────────────────────┐
│ 🍜 Lunch         │    PM 12:30   │
└──────────────────────────────────┘
```

- **Leading**: 뱃지 스타일 (Capsule + 반투명 배경)
- **Trailing**: AM/PM + 시간 (monospaced)

### 4. Dynamic Island (Minimal)

```
┌─────┐
│ 🍜  │
└─────┘
```

- 약속 이모지만 표시

---

## 마커 디자인 (V5)

### 구성 요소

```
        ┌─────────┐
        │  Name   │  <- Top label (4 chars + "+N")
        └────┬────┘
             │
      ┌──────┴──────┐
      │             │
      │   Profile   │  <- 32x32 circle (image or emoji)
      │   /Emoji    │
      │             │
      └──────┬──────┘
             │
          ┌──┴──┐
          │ ETA │  <- Bottom-right badge
          └─────┘
```

### 상태별 표시

| 상태 | 마커 | 이름 라벨 | ETA 뱃지 |
|------|------|----------|----------|
| 대기 | 프로필/이모지 + Gray 테두리 | 반투명 검정 배경 | 없음 |
| 이동 중 | 프로필/이모지 + Indigo 테두리 | 반투명 검정 배경 | "N분" (Indigo) |
| 도착 | **숨김** | Green 배경 | 없음 |

### 그룹화 (같은 ETA)

동일한 ETA를 가진 참가자들은 하나의 마커로 그룹화:
- 대표 참가자: 나 > 첫 번째 참가자
- 이름 라벨: "이름 외N명"

### 프로필 이미지 Fallback

프로필 이미지가 없는 경우 userId 해시 기반 이모지 할당:
```swift
private static let defaultEmojis = ["😀", "😊", "🙂", "😎", "🤗", "😇", "🥳", "🤩", "😺", "🐻"]
let index = abs(userId.hashValue) % defaultEmojis.count
```

---

## 색상 시스템

### 브랜드 색상 (ResourceKit)

```swift
Color.pmindigo.n500  // 메인 인디고
Color.pmpurple.n500  // 메인 퍼플
Color.pmpurple.n400  // 서브 퍼플
Color.pmsuccess.n500 // 그린 (도착)
Color.pmgray.n500    // 그레이 (대기)
```

### 진행률 색상 (ProgressColor)

| 진행률 | 단색 | 그라데이션 |
|--------|------|-----------|
| 75%+ | pmindigo.n500 | pmindigo.n500 → pmpurple.n500 |
| 50-75% | pmpurple.n500 | pmpurple.n500 → pmpurple.n400 |
| 25-50% | orange | orange → pmpurple.n400 |
| 0-25% | gray | gray → orange |

### 참가자 마커 뱃지 색상

```swift
switch eta {
case nil:    .pmgray.n500    // 대기
case 0:      .pmsuccess.n500 // 도착
default:     .pmindigo.n500  // 이동 중
}
```

---

## 프로필 이미지 캐싱

### 문제

Widget Extension은 네트워크 요청 불가 → 프로필 이미지 로드 불가

### 해결

App Group 공유 컨테이너에 미리 캐싱

```
┌─────────────────────────────────────────────────┐
│                   Main App                      │
│                                                 │
│  GroupMainFeature.groupMembersResponse          │
│           │                                     │
│           ▼                                     │
│  cacheProfileImagesForLiveActivity()            │
│           │                                     │
│           ▼                                     │
│  ┌───────────────────────────────────────────┐  │
│  │  LiveActivityImageStore.saveImage()       │  │
│  │  - Download via Nuke (use cache)          │  │
│  │  - Resize to 64x64 JPEG                   │  │
│  │  - Save to App Group: profile-{id}.jpg    │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│             App Group Container                 │
│  group.com.promiso.shared/LiveActivityImages/   │
│  ├── profile-user1.jpg                          │
│  ├── profile-user2.jpg                          │
│  └── profile-user3.jpg                          │
└─────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│               Widget Extension                  │
│                                                 │
│  LiveActivityImageStore.loadImage(userId:)      │
│  - Load from App Group via FileManager          │
│  - Return nil if not found -> emoji fallback    │
└─────────────────────────────────────────────────┘
```

### API

```swift
public enum LiveActivityImageStore {
  /// 이미지 저장 (앱에서 호출)
  public static func saveImage(_ image: UIImage, userId: String) -> String?

  /// 이미지 로드 (Widget에서 호출)
  public static func loadImage(userId: String) -> UIImage?

  /// 캐시 전체 삭제 (로그아웃 시)
  public static func clearCache()
}
```

---

## ETA 버튼 (AppIntent)

### UpdateETAIntent

```swift
struct UpdateETAIntent: LiveActivityIntent {
  @Parameter(title: "Promise ID") var promiseId: String
  @Parameter(title: "User ID") var userId: String
  @Parameter(title: "ETA Minutes") var estimatedMinutes: Int

  func perform() async throws -> some IntentResult {
    // 1. App Group UserDefaults에 저장 (앱 동기화용)
    let update = ETAUpdate(
      promiseId: promiseId,
      userId: userId,
      estimatedMinutes: estimatedMinutes,
      timestamp: Date()
    )
    let data = try JSONEncoder().encode(update)
    UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
      .set(data, forKey: LiveActivityIntentKey.etaUpdateKey)

    // 2. Live Activity UI 즉시 업데이트
    await updateActivityETA(
      promiseId: promiseId,
      participantId: userId,
      estimatedArrivalMinutes: estimatedMinutes
    )

    return .result()
  }
}
```

### 버튼 배치

| 버튼 | ETA 값 | 동작 |
|------|--------|------|
| 완료 | 0 | 도착 처리 |
| 5분 | 5 | 5분 후 도착 |
| 10분 | 10 | 10분 후 도착 |
| 직접 입력 | - | 앱으로 딥링크 |

### 딥링크

```
promiso://promise/{promiseId}/eta
```

---

## 백엔드 연동 (Firebase Functions)

### APNs Payload 구조

#### Start Event

```json
{
  "aps": {
    "timestamp": 1704067200,
    "event": "start",
    "attributes-type": "PromiseActivityAttributes",
    "attributes": {
      "trackingDurationMinutes": 30,
      "promiseId": "promise-123",
      "currentUserId": "{{USER_ID}}",
      "emoji": "🍜",
      "title": "점심 모임",
      "location": "강남역 11번 출구",
      "scheduledTime": 1704070800,
      "hostId": "user1",
      "hostName": "김민수"
    },
    "content-state": {
      "trackingDurationMinutes": 30,
      "participants": [
        {"id": "user1", "name": "나", "estimatedArrivalMinutes": null},
        {"id": "user2", "name": "민수", "estimatedArrivalMinutes": null}
      ]
    }
  }
}
```

#### Update Event

```json
{
  "aps": {
    "timestamp": 1704068000,
    "event": "update",
    "content-state": {
      "trackingDurationMinutes": 30,
      "participants": [
        {"id": "user1", "name": "나", "estimatedArrivalMinutes": 10},
        {"id": "user2", "name": "민수", "estimatedArrivalMinutes": 0}
      ]
    }
  }
}
```

#### End Event

```json
{
  "aps": {
    "timestamp": 1704070800,
    "event": "end",
    "dismissal-date": 1704070860
  }
}
```

---

## 테스트

### Mock 테스트 UI (PromiseDetailView)

Debug 빌드에서 사용 가능한 테스트 패널:

#### 개별 ETA 설정
각 참가자(나, 민수, 지현, 서연)에 대해:
- 대기 / 30분 / 15분 / 10분 / 5분 / 도착

#### 시나리오 테스트
- **모두 대기**: 전원 nil
- **모두 출발(15분)**: 전원 15분
- **모두 도착**: 전원 0
- **그룹화 테스트**: 나+민수 10분, 지현 5분, 서연 대기
- **순차 도착**: 1.5초 간격 순차 상태 변경
- **혼합 상태**: 도착/5분/15분/대기 각각

### Preview 상태

`PromiseLiveActivity.swift`에 정의된 프리뷰:

| 프리뷰 | 설명 |
|--------|------|
| 0. 긴 제목 | 제목/장소 truncation 테스트 |
| 1. 초기 상태 | 모두 대기 (eta=nil) |
| 2. 진행 중 | 일부 출발 |
| 3. 긴급 | 거의 도착 |
| 4. 거의 완료 | 대부분 도착 |
| 5. 완료 | 모두 도착 |
| 6. 다양한 진행률 | 혼합 상태 |

**Dynamic Island 프리뷰:**
- DI - Compact
- DI - Compact (Urgent)
- DI - Expanded
- DI - Minimal

---

## 구현 체크리스트

### iOS

- [x] Widget Extension 설정
- [x] PromiseActivityAttributes 모델
- [x] LiveActivityClient (TCA Dependency)
- [x] LockScreenBannerView
- [x] RacingTrackView
- [x] CompactParticipantMarker (V5 디자인)
- [x] ETA 기반 그룹화
- [x] 프로필 이미지 캐싱 (LiveActivityImageStore)
- [x] UpdateETAIntent
- [x] 테스트 UI
- [ ] 지각 표시 UI (마커 색상, 뱃지 변경)

### Backend (TODO)

- [ ] Firebase Functions: startLiveActivity
- [ ] Firebase Functions: updateETA
- [ ] Firebase Functions: endLiveActivity
- [ ] APNs 인증 설정 (P8 키)
- [ ] Firestore 스키마 업데이트

### Future Features (TODO)

#### 1. Update with Alert (강조 효과와 함께 업데이트)

APNs 업데이트 시 **Dynamic Island 확장 애니메이션** + 알림으로 변경 사항 강조

**APNs Payload:**
```json
{
  "aps": {
    "timestamp": 1704068000,
    "event": "update",
    "content-state": { ... },
    "alert": {
      "title": "민수님이 출발했어요",
      "body": "도착 예정: 10분 후",
      "sound": "default"
    }
  }
}
```

**효과:**
- Dynamic Island가 잠깐 확장되어 변경 사항 표시
- 잠금화면에 알림 배너 표시
- 소리/진동 (sound 필드)

**트리거 케이스:**

| 케이스 | 기본 | 메시지 예시 |
|--------|------|-------------|
| LiveActivity 시작 | ON | "약속 추적이 시작되었어요" |
| 첫 번째 도착자 | ON | "민수님이 1등으로 도착!" |
| 모두 도착 | ON | "모든 참가자가 도착했어요" |
| 지각 예상 발생 | OFF | "민수님이 5분 늦을 것 같아요" |
| 약속 시간 5분 전 | OFF | "약속 시간 5분 전이에요" |

**구현 계획:**
- [ ] Firebase Functions에서 alert 필드 조건부 추가
- [ ] Firestore에 트리거 케이스별 on/off 설정 저장
- [ ] iOS 설정 화면에서 on/off UI

#### 2. 지각 관련 UI

약속 시간 초과 시 지각자 표시 UI

**표시 케이스:**
- ETA > 약속시간: 지각 예상
- 약속시간 지남 + 미도착: 지각 중

**UI 변경 사항:**
- [ ] 마커 테두리 색상 변경 (Red/Warning)
- [ ] ETA 뱃지에 "지각" 표시 or 색상 변경
- [ ] 잠금화면 배너에 지각자 수 표시
- [ ] Dynamic Island Compact에 지각 아이콘

---

## 의존성

```
LiveActivityWidget
├── ActivityKit (시스템)
├── WidgetKit (시스템)
├── SwiftUI (시스템)
├── AppIntents (시스템)
├── PromisoShared (공유 모델)
└── ResourceKit (브랜드 색상)
```

---

## 참고 파일

| 파일 | 설명 |
|------|------|
| `PromiseActivityAttributes.swift` | 공유 데이터 모델 |
| `LiveActivityImageStore.swift` | 프로필 이미지 캐싱 |
| `RacingTrackView.swift` | 레이싱 트랙 + 마커 UI |
| `LockScreenView.swift` | 잠금화면 배너 |
| `PromiseLiveActivity.swift` | Widget 정의 + Dynamic Island |
| `UpdateETAIntent.swift` | ETA 버튼 Intent |
| `LiveActivityClient.swift` | TCA Dependency |
| `PromiseDetailView.swift` | 테스트 UI (DEBUG) |

---

## 참고 링크

- [Human Interface Guidelines - Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
- [Starting and updating Live Activities with ActivityKit push notifications](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications)
- [AlertConfiguration](https://developer.apple.com/documentation/activitykit/alertconfiguration)
