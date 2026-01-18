# Promiso LiveActivity Widget

약속 당일 실시간 도착 상황을 공유하기 위한 라이브액티비티 위젯

## 개요

| 항목 | 값 |
|------|-----|
| iOS 최소 버전 | 16.1+ (ActivityKit) |
| Dynamic Island | iPhone 14 Pro 이상 |
| App Group | `group.com.promiso.app` |

## 파일 구조

```
LiveActivityWidget/
├── Sources/
│   ├── LiveActivityWidgetBundle.swift  # Widget 진입점
│   ├── PromiseLiveActivity.swift       # Dynamic Island 정의
│   ├── LiveActivityIntents.swift       # AppIntent (ETA 업데이트)
│   └── Views/
│       ├── LockScreenView.swift        # 잠금화면 배너
│       └── RacingTrackView.swift       # 레이싱 트랙 UI
└── README.md
```

---

## 데이터 모델

### PromiseActivityAttributes

```swift
// 고정 속성 (Activity 생성 시 설정)
struct PromiseActivityAttributes: ActivityAttributes {
  let trackingDurationMinutes: Int  // 추적 시간 (기본 30분)
  let promiseId: String
  let currentUserId: String
  let emoji: String                 // 약속 이모지
  let title: String                 // 약속 제목
  let location: String?             // 장소명
  let scheduledTime: Date           // 약속 시간
}

// 동적 상태 (실시간 업데이트)
struct ContentState {
  let trackingDurationMinutes: Int
  let participants: [ParticipantState]
}
```

### ParticipantState

```swift
struct ParticipantState {
  let id: String
  let name: String
  var estimatedArrivalMinutes: Int?  // nil=대기, 0=도착, N=N분 후 도착
}
```

**진행률 계산:**
```swift
// trackPosition: 트랙 상 위치 (0.0 ~ 1.0)
progress = (trackingDuration - eta) / trackingDuration

// 예시 (30분 추적 기준)
// eta=nil → 0.0 (출발점)
// eta=30  → 0.0 (방금 출발)
// eta=15  → 0.5 (절반)
// eta=0   → 1.0 (도착)
```

**상태 이모지:**
| ETA | 이모지 | 의미 |
|-----|--------|------|
| nil | 😴 | 대기 |
| 1~5 | 🏃 | 거의 도착 |
| 6+  | 🚶 | 이동 중 |
| 0   | ✅ | 도착 완료 |

---

## UI 컴포넌트

### 1. Lock Screen Banner (`LockScreenBannerView`)

잠금화면에 표시되는 메인 배너 뷰

```
┌─────────────────────────────────────────────────────┐
│  🍜 점심 모임                               약속 시간    │
│  📍 강남역 11번 출구                        PM 2:30     │
│                                                     │
│  ○ ─ ─ ─ ─ 🚶 ─ ─ ─ 🏃 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 🏁        │
│         민수      지현                                │
│                                                     │
│  ┌─────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌────────┐      │
│  │도착  │ │ 완료  │ │ 5분  │ │ 10분  │ │직접 입력   │     │
│  │까지  │ └──────┘ └──────┘ └──────┘ └────────┘      │
│  └─────┘                                            │
└─────────────────────────────────────────────────────┘
```

**헤더 섹션:**
- 왼쪽: 이모지 + 제목, 장소 (📍)
- 오른쪽: "약속 시간" 라벨 + AM/PM 시간

**레이싱 트랙:**
- 줄무늬 배경 (세로 스트라이프)
- 진행률 바 (그라데이션)
- 참가자 마커 (이모지 + 이름 2글자)

**ETA 버튼 섹션:**
- 라벨: "도착" (eta=0) / "도착까지" (eta>0)
- 커스텀 ETA 표시: "N분" (0, 5, 10 외의 값)
- Segmented Control: 완료(✓), 5분, 10분, 직접

### 2. Dynamic Island

#### Expanded (확장)

```
┌─────────────────────────────────────────────────────┐
│                    (Center Region)                  │
│  🍜 점심 모임                               약속 시간    │
│  📍 강남역 11번 출구                        PM 2:30     │
│                                                     │
│                    (Bottom Region)                  │
│  ○ ─ ─ ─ ─ 🚶 ─ ─ ─ 🏃 ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ 🏁        │
└─────────────────────────────────────────────────────┘
```

- **Center**: HStack으로 좌(제목+장소) / 우(시간) 배치
- **Bottom**: RacingTrackView (height: 44)
- 긴 제목: `minimumScaleFactor(0.7)` 적용

#### Compact (축소)

```
┌──────────────────┐          ┌────────────┐
│ 🍜 점심 모임        │          │ PM 2:30    │
│ (Leading)        │          │ (Trailing) │
└──────────────────┘          └────────────┘
```

- **Leading**: 뱃지 스타일 (Capsule + 반투명 배경)
- **Trailing**: AM/PM + 시간 (monospaced)

#### Minimal (최소)

```
┌──────┐
│  🍜  │
└──────┘
```

- 약속 이모지만 표시

### 3. Racing Track (`RacingTrackView`)

레이싱 게임 스타일의 진행 상황 시각화

**구성요소:**
1. **트랙 배경**: Capsule + 세로 줄무늬 (VerticalStripes)
2. **진행률 바**: 현재 사용자 기준 그라데이션
3. **출발 마커**: 흰색 원 (6pt)
4. **도착 깃발**: 🏁 이모지
5. **참가자 마커**: 원형 배경 + 상태 이모지 + 이름 라벨

**진행률 색상 (ProgressColor):**
| 진행률 | 단색 | 그라데이션 |
|--------|------|-----------|
| 75%+ | pmindigo.n500 | pmindigo.n500 → pmpurple.n500 |
| 50-75% | pmpurple.n500 | pmpurple.n500 → pmpurple.n400 |
| 25-50% | orange | orange → pmpurple.n400 |
| 0-25% | gray | gray → orange |

### 4. ETA Segmented Control (`ETASegmentedControl`)

ETA 빠른 선택 버튼

**옵션:**
| 버튼 | 값 | 동작 |
|------|-----|------|
| 완료 | 0 | Intent 실행 |
| 5분 | 5 | Intent 실행 |
| 10분 | 10 | Intent 실행 |
| 직접 입력 | - | 앱으로 딥링크 |

**선택 상태 스타일:**
- 선택됨: 그라데이션 배경 (pmindigo → pmpurple)
- 미선택: 반투명 배경 (white 8%)
- "직접" 버튼: 항상 미선택 스타일

**딥링크:**
```
promiso://promise/{promiseId}/eta
```

---

## Intent (AppIntent)

### UpdateETAIntent

라이브액티비티에서 ETA 버튼 탭 시 실행

```swift
struct UpdateETAIntent: LiveActivityIntent {
  var promiseId: String
  var userId: String
  var estimatedMinutes: Int

  func perform() async throws -> some IntentResult {
    // 1. UserDefaults에 저장 (앱 동기화용)
    // 2. Activity UI 즉시 업데이트
  }
}
```

**데이터 흐름:**
```
[버튼 탭] → UpdateETAIntent.perform()
    ├─→ UserDefaults 저장 (ETAUpdate)
    └─→ Activity.update() 호출 (UI 즉시 반영)

[앱 포그라운드] → pendingETAUpdate 확인
    └─→ 서버 동기화
```

---

## 색상 시스템

### 브랜드 색상 (ResourceKit)

```swift
Color.pmindigo.n500  // 메인 인디고
Color.pmpurple.n500  // 메인 퍼플
Color.pmpurple.n400  // 서브 퍼플
```

### 참가자 마커 색상

진행률 기반 자동 결정:
```swift
switch progress {
case 0.75...: .green   // 거의 도착
case 0.50..<0.75: .blue
case 0.25..<0.50: .orange
default: .gray         // 대기/출발
}
```

---

## 미리보기 (Preview)

`PromiseLiveActivity.swift`에 정의된 프리뷰 상태:

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

## 참고

- [Human Interface Guidelines - Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
- [ActivityKit Documentation](https://developer.apple.com/documentation/activitykit)
