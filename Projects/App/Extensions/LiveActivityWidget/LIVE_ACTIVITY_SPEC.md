# Promiso LiveActivity 구현 명세서

## 개요

약속 당일 실시간 도착 상황을 Dynamic Island와 잠금화면에서 공유하는 기능.
**레이싱 트랙 UI**로 참가자들의 ETA(도착 예상 시간)를 시각화.

```
┌─출발──────────────────────────────────────도착─┐
│  😀         🙂            😎                🏁  │
│  서연       지현           나+민수               │
│  (대기)    (15분)        (10분)         (도착)  │
└───────────────────────────────────────────────┘
```

---

## 기술 스택

| 항목 | 값 |
|------|-----|
| iOS Target | 18.0+ |
| 아키텍처 | TCA (The Composable Architecture) 1.22.2 |
| 백엔드 | Firebase Functions + APNs |
| Widget Bundle | `LiveActivityWidgetBundle` |
| App Group | `group.com.promiso.shared` |

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                     Firebase Functions                       │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ startLiveActivity│  │ updateETA       │                   │
│  │ (APNs start)     │  │ (APNs update)   │                   │
│  └────────┬─────────┘  └────────┬────────┘                   │
└───────────┼─────────────────────┼────────────────────────────┘
            │                     │
            ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│                       APNs Push                              │
│              ContentState 업데이트 전송                       │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│                        iOS App                               │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              LiveActivityWidget (Extension)           │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  │   │
│  │  │LockScreen   │  │DynamicIsland│  │RacingTrack   │  │   │
│  │  │BannerView   │  │(Expanded)   │  │View          │  │   │
│  │  └─────────────┘  └─────────────┘  └──────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                  Main App                             │   │
│  │  ┌─────────────┐  ┌─────────────────────────────────┐│   │
│  │  │LiveActivity │  │LiveActivityImageStore            ││   │
│  │  │Client       │  │(App Group 프로필 이미지 캐싱)    ││   │
│  │  └─────────────┘  └─────────────────────────────────┘│   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 디렉토리 구조

```
Projects/
├── App/
│   └── Extensions/
│       └── LiveActivityWidget/
│           ├── Sources/
│           │   ├── LiveActivityWidgetBundle.swift
│           │   ├── PromiseLiveActivity.swift      # Widget 정의 + Previews
│           │   ├── UpdateETAIntent.swift          # ETA 버튼 Intent
│           │   └── Views/
│           │       ├── LockScreenView.swift       # 잠금화면 배너
│           │       └── RacingTrackView.swift      # 레이싱 트랙 UI
│           └── LiveActivityWidget.entitlements
│
├── Shared/
│   └── Sources/
│       ├── LiveActivity/
│       │   ├── PromiseActivityAttributes.swift   # 공유 모델
│       │   └── LiveActivityImageStore.swift      # 프로필 이미지 캐싱
│       └── Common/
│           └── AppLogger.swift
│
└── Clients/
    └── Sources/
        └── Clients/
            └── LiveActivityClient.swift          # TCA Dependency
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
| `30` | 이동 중 | 0.0 | Indigo |
| `15` | 이동 중 | 0.5 | Indigo |
| `5` | 거의 도착 | 0.83 | Indigo |
| `0` | 도착 | 1.0 (도착점) | Green |

---

## Widget UI

### 1. LockScreen Banner

```
┌────────────────────────────────────────────────────────┐
│  🍜 점심 모임                            약속 시간    │
│  📍 강남역 11번 출구                      PM 12:30    │
│                                                        │
│  ┌──출발────────────────────────────────────도착──┐   │
│  │  😀서연     🙂지현      😎나+민수         🏁    │   │
│  └────────────────────────────────────────────────┘   │
│                                                        │
│  도착까지  [ 완료 ] [ 5분 ] [ 10분 ] [ 직접 입력 ]    │
└────────────────────────────────────────────────────────┘
```

### 2. Dynamic Island (Expanded)

```
┌──────────────────────────────────────────────┐
│  🍜 점심 모임                  약속 시간     │
│  📍 강남역 11번 출구           PM 12:30     │
├──────────────────────────────────────────────┤
│  ┌────────────────────────────────────────┐  │
│  │  😀서연  🙂지현   😎나+민수        🏁  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### 3. Dynamic Island (Compact)

```
┌────────────────────────────────────────┐
│ 🍜 점심 모임          │    PM 12:30   │
└────────────────────────────────────────┘
```

### 4. Dynamic Island (Minimal)

```
┌─────┐
│ 🍜  │
└─────┘
```

---

## 마커 디자인 (V5)

### 구성 요소

```
        ┌─────────┐
        │ 이름    │  ← 상단 이름 라벨 (4글자 + "외N명")
        └─────────┘
           │
    ┌──────┴──────┐
    │             │
    │   프로필    │  ← 32x32 원형 (이미지 또는 이모지)
    │   /이모지   │
    │             │
    └──────┬──────┘
           │
        ┌──┴──┐
        │ETA  │  ← 우측 하단 ETA 뱃지
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

## 프로필 이미지 캐싱

### 문제

Widget Extension은 네트워크 요청 불가 → 프로필 이미지 로드 불가

### 해결

App Group 공유 컨테이너에 미리 캐싱

```
┌─────────────────────────────────────────────────────────┐
│                     Main App                             │
│                                                          │
│  GroupMainFeature.groupMembersResponse                   │
│           │                                              │
│           ▼                                              │
│  cacheProfileImagesForLiveActivity()                     │
│           │                                              │
│           ▼                                              │
│  ┌─────────────────────────────────────────────────┐    │
│  │  LiveActivityImageStore.saveImage()              │    │
│  │  - Nuke로 다운로드 (캐시 활용)                   │    │
│  │  - 64x64 JPEG 변환                               │    │
│  │  - App Group 저장: profile-{userId}.jpg         │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│               App Group Container                        │
│  group.com.promiso.shared/LiveActivityImages/            │
│  ├── profile-user1.jpg                                   │
│  ├── profile-user2.jpg                                   │
│  └── profile-user3.jpg                                   │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  Widget Extension                        │
│                                                          │
│  LiveActivityImageStore.loadImage(userId:)               │
│  - FileManager로 App Group에서 로드                      │
│  - 없으면 nil → 이모지 fallback                          │
└─────────────────────────────────────────────────────────┘
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
    // App Group UserDefaults에 저장
    let update = ETAUpdate(
      promiseId: promiseId,
      userId: userId,
      estimatedMinutes: estimatedMinutes,
      timestamp: Date()
    )
    // → 앱에서 checkPendingIntents로 처리
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
      "scheduledTime": 1704070800
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

---

## 구현 체크리스트

### iOS (완료)

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

### Backend (TODO)

- [ ] Firebase Functions: startLiveActivity
- [ ] Firebase Functions: updateETA
- [ ] Firebase Functions: endLiveActivity
- [ ] APNs 인증 설정 (P8 키)
- [ ] Firestore 스키마 업데이트

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
