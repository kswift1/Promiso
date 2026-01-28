---
updated: 2025-01-29
expires: 2025-04-29
version: iOS 26 / Swift 6
source: https://developer.apple.com/documentation/swiftui
---

# SwiftUI / iOS 26 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.
> WWDC 2025 발표 내용 및 최신 검색 결과 기반.

## 현재 버전 정보

- **최신 iOS**: 26.x (2025년 9월 15일 정식 출시)
- **최신 Swift**: 6.0
- **확인 일자**: 2025-01-29
- **출처**: [Apple Developer](https://developer.apple.com), [Hacking with Swift](https://www.hackingwithswift.com/articles/278/whats-new-in-swiftui-for-ios-26)

## Promiso 프로젝트 상태

- **Target iOS**: 18.0+
- **Swift 버전**: 6.0
- **iOS 26 기능 사용**: Glass Effect, Tab Bottom Accessory

---

## WWDC 2025 핵심 발표

### Liquid Glass 디자인 시스템

iOS 26은 **iOS 7 이후 가장 큰 UI 변화**를 도입했습니다:
- 광택 있는 아이콘
- 부드러운 둥근 모서리
- 반투명 배경 (주변 환경 반영)
- 모든 Apple 플랫폼 통일 (iOS, iPadOS, macOS Tahoe, watchOS, tvOS, visionOS)

> **명명 체계 변경**: iOS 19가 아닌 iOS 26. 모든 Apple OS가 연도 기반 버전으로 통일됨.

### 지원 기기

| 지원 | 제한적 지원 | 미지원 |
|------|------------|--------|
| iPhone 11 이상 | iPhone XS/XR (iOS 18까지) | iPhone X 이하 |
| iPhone SE 2세대 이상 | | |

**AI 기능 (Foundation Models)**: iPhone 15 Pro/Pro Max 이상에서만 On-Device 실행

---

## 1. Liquid Glass API

### 1.1 기본 Glass Effect

```swift
import SwiftUI

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

### 1.2 Glass Effect 옵션

| 옵션 | 설명 |
|------|------|
| `.regular` | 기본 glass 효과 |
| `.regular.interactive()` | 터치 시 반응하는 효과 |
| `.regular.tint(Color)` | 색상 틴트 적용 |

### 1.3 Shape 옵션

| Shape | 사용법 |
|-------|--------|
| `.rect` | 사각형 |
| `.rect(cornerRadius: N)` | 둥근 모서리 사각형 |
| `.capsule` | 캡슐 형태 |
| `.circle` | 원형 |

### 1.4 GlassEffectContainer (⭐ 중요)

여러 Glass Effect를 그룹화하여 **morphing 효과**와 **블렌딩**을 제공합니다.

```swift
import SwiftUI

struct GlassContainerExample: View {
    var body: some View {
        ZStack {
            Image("background")
                .resizable()
                .ignoresSafeArea()

            GlassEffectContainer {
                HStack(spacing: 20) {
                    Button("Home") { }
                        .glassEffect()
                    Button("Settings") { }
                        .glassEffect()
                    Button("Profile") { }
                        .glassEffect()
                }
                .padding()
            }
        }
    }
}
```

**주요 기능**:
- 겹치는 요소 자동 블렌딩
- 일관된 blur/lighting 효과
- 부드러운 morphing 전환
- 렌더링 성능 최적화

**spacing 파라미터**:
```swift
// spacing 내 요소들이 시각적으로 블렌딩됨
GlassEffectContainer(spacing: 40.0) {
    // ...
}
```

### 1.5 glassEffectID (전환 애니메이션)

```swift
@Namespace private var namespace

GlassEffectContainer(spacing: 20) {
    VStack(spacing: 12) {
        if isExpanded {
            ForEach(actions, id: \.0) { action in
                actionButton(action.0)
                    .glassEffectID(action.0, in: namespace)
            }
        }

        Button {
            withAnimation(.bouncy(duration: 0.4)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "xmark" : "plus")
        }
        .glassEffectID("toggle", in: namespace)
    }
}
```

### 1.6 Liquid Glass 디자인 가이드라인

> ⚠️ Apple 권장사항: Liquid Glass는 **네비게이션 레이어**에만 사용.
> 메인 컨텐츠가 아닌, 컨트롤이 위에 떠있는 구조.

```
┌─────────────────────────┐
│   Glass Controls (상단)  │  ← Liquid Glass
├─────────────────────────┤
│                         │
│   Content (중앙)         │  ← 일반 콘텐츠
│                         │
├─────────────────────────┤
│   Glass TabBar (하단)    │  ← Liquid Glass
└─────────────────────────┘
```

### 1.7 주의사항

- iOS 26.1에서 `Menu`를 `GlassEffectContainer` 안에 넣지 말 것 (iOS 26.0에서는 작동)
- 성능: 40% 적은 GPU 사용 (Metal Performance Shaders + Core ML 활용)

---

## 2. TabView API 변경

### 2.1 TabView Bottom Accessory

#### iOS 26.0
```swift
@available(iOS 26.0, *)
tabView
  .tabViewBottomAccessory {
    LivePromiseCompactView()
  }
```

#### iOS 26.1 (isEnabled 파라미터 추가)
```swift
@available(iOS 26.1, *)
tabView
  .tabViewBottomAccessory(isEnabled: hasLivePromise) {
    LivePromiseCompactView()
  }
```

### 2.2 Tab Bar Minimize Behavior

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

## 3. Foundation Models Framework (On-Device AI)

### 3.1 개요

- **iOS 26에서 새로 도입**
- 30억 파라미터 On-Device LLM
- Apple Intelligence 기반
- 인터넷 연결 불필요 (완전 로컬 실행)
- 개인정보 보호

**요구 사항**:
- Apple Silicon 지원 기기
- Apple Intelligence 활성화 (설정에서)
- 충분한 배터리 (게임 모드 아님)

### 3.2 기본 사용법

```swift
import FoundationModels

// SwiftUI에서 세션 관리
@State var session = LanguageModelSession()

// 기본 응답 생성
let response = try await session.respond(to: "Tell me a story")
```

### 3.3 Streaming 응답

```swift
// 실시간 스트리밍 (토큰 단위가 아닌 구조적 스냅샷)
for try await partialResponse in session.streamResponse(to: prompt) {
    // SwiftUI 선언적 업데이트와 자연스럽게 통합
    self.currentResponse = partialResponse
}
```

### 3.4 Guided Generation (@Generable, @Guide)

```swift
import FoundationModels

@Generable
struct RecipeResponse {
    let title: String
    let ingredients: [String]
    let steps: [String]
    let cookingTime: Int
}

// 구조화된 응답 생성
let recipe: RecipeResponse = try await session.respond(
    to: "Give me a pasta recipe",
    generating: RecipeResponse.self
)
```

### 3.5 성능 최적화

```swift
// Model Prewarming (AI 화면 진입 전 미리 로드)
await session.prewarm(promptPrefix: "You are a helpful assistant...")
```

---

## 4. 기타 iOS 26 SwiftUI 신규 API

### 4.1 WebKit for SwiftUI

```swift
import WebKit
import SwiftUI

// 새로운 네이티브 WebView
WebView(url: URL(string: "https://example.com")!)

// WebPage로 프로그래밍적 제어
@State var webPage = WebPage()

WebView(page: webPage)
    .onAppear {
        webPage.load(URLRequest(url: url))
    }
```

### 4.2 Search 개선

```swift
// 검색 필드 최소화 (도구 모음 버튼으로)
.searchToolbarBehavior(.minimize)

// 검색이 주요 기능이 아닐 때 유용
```

### 4.3 @IncrementalState (성능 최적화)

```swift
// 1000+ 항목 리스트에서도 부드러운 성능
@IncrementalState var items: [Item]

ForEach(items) { item in
    ItemRow(item: item)
        .incrementalID(item.id)
}
```

### 4.4 3D Charts

```swift
import Charts

Chart3D {
    SurfacePlot(data: surfaceData) { point in
        point.value
    }
}
```

### 4.5 기타

- Rich TextEditor (AttributedString 지원)
- 새로운 SF Symbols 애니메이션
- Toolbar spacer API
- Widget → visionOS, CarPlay 지원

---

## 5. Backward Compatibility (Fallback 패턴)

### 5.1 필수 Fallback 패턴

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

### 5.2 버전별 분기 구조

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
    // iOS 18 이하 Fallback
    fallbackFeature
  }
}
```

### 5.3 Foundation Models Fallback

```swift
if #available(iOS 26.0, *), FoundationModels.isAvailable {
    // On-Device AI 사용
    let response = try await session.respond(to: prompt)
} else {
    // 클라우드 API 또는 비 AI 로직
    let response = try await cloudAPI.complete(prompt)
}
```

---

## 6. Promiso 프로젝트 iOS 26 적용 현황

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

### Promiso 코드 참조

- `Projects/Shared/Sources/UI/View+GlassBackground.swift`
- `Projects/Shared/Sources/UI/Components/GlassExpandableMenu.swift`
- `Projects/Features/RootTabFeature/Sources/RootTabFeature.swift`
- `Projects/Features/CalendarFeature/Sources/Views/GlassEffectModifiers.swift`

---

## 7. Swift 6 Concurrency

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
@MainActor
func updateUI() {
  // UI 관련 작업
}

// TCA Effect에서
Effect.run { send in
  await MainActor.run {
    // UI 관련 작업
  }
}
```

---

## 8. 자주 묻는 질문

### Q: iOS 26의 Glass Effect가 iOS 18 이하에서 크래시하나요?
A: 네. 반드시 `#available(iOS 26.0, *)` 분기 처리가 필요합니다.

### Q: adaptiveGlassBackground vs 직접 glassEffect 사용?
A: Promiso에서는 `adaptiveGlassBackground()` 사용을 권장합니다. 자동으로 Fallback이 적용됩니다.

### Q: tabViewBottomAccessory iOS 26.0 vs 26.1 차이?
A: iOS 26.1에서 `isEnabled` 파라미터가 추가되어, 조건부 표시가 가능합니다.

### Q: GlassEffectContainer는 언제 사용하나요?
A: Morphing 애니메이션 (shape 변경)이 필요하거나 여러 glass 요소를 블렌딩할 때 사용합니다.

### Q: Foundation Models는 모든 기기에서 작동하나요?
A: 아니오. Apple Silicon + Apple Intelligence 지원 기기에서만 작동합니다 (iPhone 15 Pro 이상).

### Q: Liquid Glass를 끌 수 있나요?
A: iOS 26.2부터 잠금 화면에서 롤백 가능. 설정 > 접근성 > "Show Borders"로 명확한 경계 표시 가능.

---

## 참고 자료

### 공식 문서
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [WWDC25](https://developer.apple.com/wwdc25/)

### 커뮤니티 자료
- [What's new in SwiftUI for iOS 26 – Hacking with Swift](https://www.hackingwithswift.com/articles/278/whats-new-in-swiftui-for-ios-26)
- [Designing custom UI with Liquid Glass – Donny Wals](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Understanding GlassEffectContainer – DEV Community](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [Getting Started with Foundation Models – AppCoda](https://www.appcoda.com/foundation-models/)
- [iOS 26 by Examples – GitHub](https://github.com/artemnovichkov/iOS-26-by-Examples)
- [LiquidGlassReference – GitHub](https://github.com/conorluddy/LiquidGlassReference)

---

*마지막 업데이트: 2025-01-29 (WWDC 2025 + 웹 검색 기반)*
