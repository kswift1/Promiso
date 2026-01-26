# Promiso 프로젝트 컨벤션

> 모든 개발 작업은 이 컨벤션을 따라야 합니다.

## 📋 필수 체크리스트

### ✅ Git 커밋 메시지

```
<type>: <subject>

<body>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Type**: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`
**Subject**: 50자 이내, 한글, 명령형, 마침표 없음

**예시**:
```
feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI
- 알림 타입별 토글 기능

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

### ✅ Swift 코드

#### 필수 사항
- ✅ 들여쓰기: 2 spaces
- ✅ `@ObservableState` (TCA 1.22.2)
- ✅ `ViewAction` / `InternalAction` / `DelegateAction` 분리
- ✅ `Sendable` 프로토콜 준수
- ✅ SwiftUI Preview 포함
- ✅ `async/await` 사용

#### 금지 사항
- ❌ `@BindingState` (deprecated)
- ❌ `.task { }` (deprecated)
- ❌ `.fireAndForget { }` (deprecated)
- ❌ 강제 언래핑 (`!`)
- ❌ 축약 네이밍 (`btn`, `lbl`)
- ❌ 하드코딩 색상

---

### ✅ UI 스타일

#### 필수 적용
```swift
// Aurora Background (모든 주요 화면)
.auroraBackground()

// Glass Effect (iOS 26+)
@available(iOS 26.0, *)
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

// Fallback (iOS 26 미만)
if #available(iOS 26.0, *) {
  glassEffect(...)
} else {
  background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}
```

#### 금지
- ❌ Aurora 미적용 (주요 화면)
- ❌ Glass Effect Fallback 누락
- ❌ 하드코딩 색상 (Theme.swift 사용)

---

## 🔍 자동 검사 항목

### Critical (발견 시 즉시 수정)
```bash
# TCA Deprecated API
grep -rn "@BindingState\|\.task\s*{\|\.fireAndForget" --include="*.swift" .

# Glass Effect Fallback 누락
grep -l "\.glassEffect" --include="*.swift" . | xargs grep -L "#available(iOS 26"
```

### Warning (수정 권장)
```bash
# 강제 언래핑
grep -rn "!" --include="*.swift" . | grep -v "// swiftlint:disable\|!="

# 하드코딩 색상
grep -rn "Color(red:\|Color(UIColor" --include="*.swift" .

# 축약 네이밍
grep -rn "\(btn\|lbl\|txt\|img\)" --include="*.swift" .

# Aurora Background 누락 (View 파일)
grep -L "\.auroraBackground()" --include="*View.swift" .

# print 문 (디버그 코드)
grep -rn "print(" --include="*.swift" .
```

---

## 🚀 컨벤션 강제 방법

### 1. 자동 검증 (기본)
5단계 워크플로우의 Step 4에서 자동 실행:
```
탐색 → 계획 → 구현 → 검증 → 커밋
                        ↑
                  컨벤션 체크
                  code-reviewer agent
```

### 2. Hook 설정 (강력 추천)
`.claude/settings.local.json`에 추가:
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "f=\"$(jq -r '.tool_input.file_path' <<< \"$STDIN\")\"; if [[ $f == *.swift ]]; then .claude/hooks/check-conventions.sh \"$f\"; fi"
          }
        ]
      }
    ]
  }
}
```

### 3. 수동 검사
```bash
# 특정 파일 체크
.claude/hooks/check-conventions.sh Projects/Features/SomeFeature/Sources/SomeView.swift

# 전체 프로젝트 체크
find Projects -name "*.swift" -exec .claude/hooks/check-conventions.sh {} \;
```

---

## 📚 참고 문서

- `.claude/CLAUDE.md` - 전체 워크플로우 및 규칙
- `.ai/PROJECT_CONTEXT.md` - 상세 코딩 컨벤션
- `.claude/agents/code-reviewer.md` - 리뷰 기준
- `.claude/hooks/check-conventions.sh` - 자동 검사 스크립트

---

## ❓ FAQ

### Q: Critical 에러가 발생하면?
**A**: 즉시 수정해야 합니다. 커밋이 차단됩니다.

### Q: Warning은 무시해도 되나요?
**A**: 커밋은 가능하지만, 수정을 강력히 권장합니다.

### Q: Hook이 너무 엄격해요
**A**: `settings.local.json`의 `hooks` 섹션을 제거하거나 비활성화하세요.

### Q: 기존 코드가 컨벤션을 위반하는데?
**A**: 새 코드만 컨벤션을 따르면 됩니다. 기존 코드는 점진적으로 개선하세요.

---

## 🎯 핵심 요약

**3가지만 기억하세요:**

1. **Git 커밋**: `type: subject` + `Co-Authored-By`
2. **Swift 코드**: TCA 1.22.2 API + 강제 언래핑 금지
3. **UI**: Aurora Background + Glass Effect + Fallback

**컨벤션 위반 시 5단계 워크플로우의 검증 단계에서 자동으로 잡힙니다.**
