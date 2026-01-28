---
updated: 2025-01-29
expires: 2025-04-29
version: iOS 26 / Swift 6
source: https://developer.apple.com/documentation/swiftui
---

# SwiftUI / iOS 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.

## 현재 버전 정보

- **최신 iOS**: 26.x (2025)
- **최신 Swift**: 6.0
- **확인 일자**: 2025-01-29
- **출처**: [Apple Developer](https://developer.apple.com), Promiso 코드베이스

## Promiso 프로젝트 상태

- **Target iOS**: 18.0+
- **Swift 버전**: 6.0
- **iOS 26 기능 사용**: Glass Effect, Tab Bottom Accessory

---

## iOS 26 신규 API (⚠️ 정보 제한적)

> iOS 26은 2025년 출시 예정으로, 공식 문서가 제한적입니다.
> 아래 내용은 Promiso 코드베이스 분석 기반입니다.

### 1. Glass Effect API

#### 기본 사용법
```swift
// 기본 Glass Effect
view.glassEffect(.regular, in: .rect(cornerRadius: 12))

// Interactive (터치 반응)
view.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

// Tint 적용
view.glassEffect(
  .regular.tint(Color.blue.opacity(0.8)).interactive(),
  in: .rect(cornerRadius: 10)
)
```

#### Glass Effect 옵션
| 옵션 | 설명 |
|------|------|
| `.regular` | 기본 glass 효과 |
| `.regular.interactive()` | 터치 시 반응하는 효과 |
| `.regular.tint(Color)` | 색상 틴트 적용 |

#### Shape 옵션
| Shape | 사용법 |
|-------|--------|
| `.rect` | 사각형 |
| `.rect(cornerRadius: N)` | 둥근 모서리 사각형 |
| `.capsule` | 캡슐 형태 |
| `.circle` | 원형 |

#### GlassEffectContainer
```swift
// Glass Effect 컨테이너 (morphing 효과용)
@available(iOS 26, *)
GlassEffectContainer {
  content
    .glassEffect(.regular, in: dynamicShape)
}
```

### 2. TabView Bottom Accessory

#### iOS 26.0
```swift
@available(iOS 26.0, *)
tabView
  .tabViewBottomAccessory {
    // 항상 표시되는 컨텐츠
    LivePromiseCompactView()
  }
```

#### iOS 26.1 (isEnabled 파라미터 추가)
```swift
@available(iOS 26.1, *)
tabView
  .tabViewBottomAccessory(isEnabled: hasLivePromise) {
    // isEnabled가 true일 때만 표시
    LivePromiseCompactView()
  }
```

### 3. Tab Bar Minimize Behavior

```swift
@available(iOS 26.0, *)
tabView
  .tabBarMinimizeBehavior(.onScrollDown)
```

| Behavior | 설명 |
|----------|------|
| `.onScrollDown` | 스크롤 시 탭바 최소화 |
| `.never` | 항상 표시 (기본값) |

---

## Promiso 프로젝트 iOS 26 적용 현황

### 적용된 컴포넌트

| 컴포넌트 | 파일 | iOS 26 기능 |
|----------|------|------------|
| `adaptiveGlassBackground` | `View+GlassBackground.swift` | Glass Effect |
| `adaptiveGlassCard` | `View+GlassBackground.swift` | Glass Effect + Shadow |
| `adaptiveGlassSectionBackground` | `GlassEffectModifiers.swift` | Glass Effect |
| `adaptiveGlassRespondButton` | `GlassEffectModifiers.swift` | Glass Effect + Tint |
| `GlassExpandableMenu` | `GlassExpandableMenu.swift` | Glass Effect + Morphing |
| `GlassActionButton` | `GlassActionButton.swift` | Glass Effect |
| `LivePromiseCompactView` | `RootTabFeature.swift` | Bottom Accessory |

### Fallback 패턴 (필수)

```swift
// ✅ 올바른 패턴: #available 분기 + Fallback
if #available(iOS 26.0, *) {
  view.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
  view.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}

// ❌ 잘못된 패턴: Fallback 없음
view.glassEffect(.regular, in: .rect) // iOS 26 미만에서 크래시
```

### 버전별 분기 구조

```swift
@ViewBuilder
private var content: some View {
  if #available(iOS 26.1, *) {
    // iOS 26.1+ 전용 기능
    newFeature
  } else if #available(iOS 26.0, *) {
    // iOS 26.0 호환 기능
    legacyFeature
  } else {
    // iOS 25 이하 Fallback
    fallbackFeature
  }
}
```

---

## Swift 6 Concurrency

### Sendable 요구사항

```swift
// ✅ TCA Action은 Sendable 필수
enum Action: ViewAction, Sendable {
  case view(ViewAction)

  enum ViewAction: Sendable {
    case buttonTapped
  }
}

// ✅ State는 Equatable + Sendable (via @ObservableState)
@ObservableState
struct State: Equatable {
  var count: Int = 0
}
```

### MainActor 사용

```swift
// UI 업데이트가 필요한 코드
@MainActor
func updateUI() {
  // ...
}

// TCA Effect에서
Effect.run { send in
  await MainActor.run {
    // UI 관련 작업
  }
}
```

---

## 자주 묻는 질문

### Q: iOS 26의 Glass Effect가 iOS 25 이하에서 크래시하나요?
A: 네. 반드시 `#available(iOS 26.0, *)` 분기 처리가 필요합니다.

### Q: adaptiveGlassBackground vs 직접 glassEffect 사용?
A: Promiso에서는 `adaptiveGlassBackground()` 사용을 권장합니다.
   자동으로 Fallback이 적용됩니다.

### Q: tabViewBottomAccessory iOS 26.0 vs 26.1 차이?
A: iOS 26.1에서 `isEnabled` 파라미터가 추가되어, 조건부 표시가 가능합니다.
   iOS 26.0에서는 항상 표시되거나 View 자체를 조건부로 생성해야 합니다.

### Q: GlassEffectContainer는 언제 사용하나요?
A: Morphing 애니메이션 (shape 변경)이 필요한 경우에 사용합니다.
   예: `GlassExpandableMenu`의 원형 → 사각형 전환

---

## 참고 자료

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Evolution](https://www.swift.org/swift-evolution/)
- [WWDC Videos](https://developer.apple.com/videos/)

### Promiso 코드 참조
- `Projects/Shared/Sources/UI/View+GlassBackground.swift`
- `Projects/Shared/Sources/UI/Components/GlassExpandableMenu.swift`
- `Projects/Features/RootTabFeature/Sources/RootTabFeature.swift`
- `Projects/Features/CalendarFeature/Sources/Views/GlassEffectModifiers.swift`

---

*마지막 업데이트: 2025-01-29 (코드베이스 분석 기반)*
