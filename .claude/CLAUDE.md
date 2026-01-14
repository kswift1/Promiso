# Promiso - Claude Code 컨텍스트

## 프로젝트 개요

**Promiso**는 그룹 기반 약속 관리 iOS 앱입니다.

- **플랫폼**: iOS 18.0+
- **아키텍처**: TCA (The Composable Architecture) 1.22.2
- **UI**: SwiftUI + iOS 26 Glass Effect
- **백엔드**: Firebase (Auth, Firestore, Functions, Storage)
- **모듈화**: Tuist 4.65.7

## TCA 1.22.2 필수 API

```swift
// ✅ 사용할 것
@Reducer struct MyFeature { }
@ObservableState struct State { }
enum Action: ViewAction { }
@Dependency(\.client) var client
Effect.run { } / Effect.send()

// ❌ 사용하지 말 것 (deprecated)
@BindingState
.task { }
.fireAndForget { }
```

## Makefile 명령어

```bash
make feature FEATURE_NAME=X       # Feature 생성
make remove-feature FEATURE_NAME=X # Feature 삭제
make deps                          # 의존성 그래프
make emulator-start                # Firebase 에뮬레이터
make functions-build               # Functions 빌드
```

## 상세 문서 참조

> 아래 문서들을 반드시 참조하세요.

| 문서 | 설명 |
|------|------|
| [.ai/PROJECT_CONTEXT.md](../.ai/PROJECT_CONTEXT.md) | 아키텍처, 코딩 컨벤션, 의존성 규칙 |
| [.ai/FIRESTORE_SCHEMA.md](../.ai/FIRESTORE_SCHEMA.md) | Firestore 데이터 스키마 |
| [.ai/CHECKLIST.md](../.ai/CHECKLIST.md) | 개발 체크리스트 |
| [.ai/PROMPTS.md](../.ai/PROMPTS.md) | 프롬프트 템플릿 모음 |

## 핵심 규칙 요약

### 의존성 방향
```
App → Features → Clients → Shared
         ↓
    ExternalDependency, ResourceKit
```

### Feature 구조
```
Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift   # TCA Reducer
│   └── {Name}View.swift      # SwiftUI View
└── Tests/
```

### TCA 패턴
- `@ObservableState` for State
- `ViewAction` / `InternalAction` / `DelegateAction` 분리
- `@Dependency` for 외부 의존성

### UI 스타일
- iOS 26: `.glassEffect()` 적극 활용
- Fallback: `.ultraThinMaterial`
- 색상: `Color.pmindigo` (Primary)

## 에이전트 사용법

```bash
# 새 Feature 생성
/new-feature NotificationSettings

# 새 화면 생성 (UI 포함)
/new-screen PrivacySettings

# 에이전트 직접 호출
"feature-generator로 알림 설정 Feature 만들어줘"
"backend-developer로 새 API 엔드포인트 추가해줘"
```

## 주요 경로

| 경로 | 설명 |
|------|------|
| `Projects/Features/` | Feature 모듈들 |
| `Projects/Clients/` | 데이터/네트워크 레이어 |
| `Projects/Shared/` | 공통 컴포넌트, 디자인 시스템 |
| `infra/firebase/functions/` | Firebase Functions (TypeScript) |
| `infra/firebase/firestore.rules` | Firestore 보안 규칙 |
