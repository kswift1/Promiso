# Promiso 프로젝트 컨벤션

> 모든 개발 작업은 이 컨벤션을 따라야 합니다.

---

## 🔴 Critical (즉시 수정 필수)

### Git 커밋 메시지
```
<type>: <subject>    ← 한글, 50자 이내

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

**Type**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`

**예시**:
```
feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

---

### Swift 코드

| 항목 | 규칙 |
|-----|-----|
| 강제 언래핑 (!) | ❌ 금지 → `guard let` 사용 |
| @BindingState | ❌ 금지 → `@ObservableState` 사용 |
| .task { } | ❌ 금지 → `Effect.run { }` 사용 |
| .fireAndForget { } | ❌ 금지 → `Effect.run { }` 사용 |
| 하드코딩 색상 | ❌ 금지 → `Color.pm*` 사용 |
| Feature에서 Firebase 직접 호출 | ❌ 금지 → Client 레이어 통과 |
| Glass Effect Fallback 누락 | ❌ 금지 → `#available(iOS 26)` 분기 |
| XCTest 사용 | ❌ 금지 → Swift Testing 사용 |

---

### 아키텍처

```swift
// Namespace 패턴 필수
public enum FeatureName {}

extension FeatureName {
    @Reducer
    public struct Feature { ... }
}

// Action 분리 필수
enum Action {
    case view(ViewAction)
    case `internal`(InternalAction)
    case delegate(DelegateAction)
}

// Sendable 필수
enum ViewAction: Sendable { ... }
enum InternalAction: Sendable { ... }

// 의존성 주입 필수
@Dependency(\.firestoreClient) var firestoreClient
```

---

### 색상 시스템

```swift
// ✅ 올바른 사용
Color.pmindigo.n500
Color.pmaurora.purple
Color.pmbrand.primary

// ❌ 금지
Color(red: 0.5, green: 0.3, blue: 0.8)
Color(UIColor.systemBlue)
```

**위치**: `Projects/ResourceKit/Sources/Generated/Color+Generated.swift`

---

### UI

```swift
// Glass Effect Fallback 필수
if #available(iOS 26.0, *) {
    content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
    content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}

// ⚠️ Glass Effect 탭 영역 필수
// 콘텐츠 없는 부분도 탭 가능하게 .contentShape 추가
Button {
    // action
} label: {
    HStack {
        Text("Label")
        Spacer()  // ← 이 부분도 탭 가능하게
    }
    .contentShape(Rectangle())  // ← 필수!
}
```

---

## 🟡 Warning (권장 수정)

| 항목 | 규칙 |
|-----|-----|
| 축약 네이밍 (btn, lbl) | 전체 단어 사용 권장 |
| print() 문 | 제거 권장 |
| SwiftUI Preview 누락 | 추가 권장 |
| 500라인 이상 파일 | 파일 분리 권장 |
| Aurora Background 누락 | 주요 화면에 적용 권장 |

---

## ℹ️ Info (허용)

| 항목 | 규칙 |
|-----|-----|
| TODO/FIXME 주석 | 허용 (정보 표시만) |

---

## ✅ 필수 사항

### 코드 스타일
- 들여쓰기: **2 spaces**
- 네이밍: camelCase (변수/함수), PascalCase (타입)

### TCA 구조
- @ObservableState for State
- ViewAction / InternalAction / DelegateAction 분리
- @Dependency for 외부 의존성
- Sendable 프로토콜 준수

### 테스트
- Swift Testing 사용 (@Test, #expect)

### 워크플로우
- 계획 단계: **사용자 승인 후 진행**
- 커밋 단계: **사용자 확인 후 커밋**

---

## 📋 빠른 체크리스트

### 코드 작성 전
- [ ] 기존 패턴 확인 (탐색 단계)
- [ ] 계획 수립 및 승인

### 코드 작성 중
- [ ] Namespace 패턴 사용
- [ ] Action 분리 (View/Internal/Delegate)
- [ ] @Dependency로 의존성 주입
- [ ] Color.pm* 사용
- [ ] Glass Effect + Fallback

### 코드 작성 후
- [ ] 빌드 성공
- [ ] 테스트 통과 (Swift Testing)
- [ ] 코드 리뷰 통과
- [ ] 사용자 확인 후 커밋

---

## 🔍 자동 검사 명령어

```bash
# Critical 검사
grep -rn "@BindingState\|\.task\s*{\|\.fireAndForget" --include="*.swift" .
grep -rn "Color(red:\|Color(UIColor" --include="*.swift" .
grep -l "\.glassEffect" --include="*.swift" . | xargs grep -L "#available(iOS 26"

# Warning 검사
grep -rn "!" --include="*.swift" . | grep -v "!="
grep -rn "\(btn\|lbl\|txt\|img\)" --include="*.swift" .
grep -rn "print(" --include="*.swift" .
```

---

## 📚 참고 문서

- `.claude/CLAUDE.md` - 전체 워크플로우
- `.ai/PROJECT_CONTEXT.md` - 상세 아키텍처
- `.claude/agents/code-reviewer.md` - 리뷰 기준
- `Projects/ResourceKit/Sources/Generated/Color+Generated.swift` - 색상 시스템
