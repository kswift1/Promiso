# Promiso - Claude Code 컨텍스트

## 필수 워크플로우 (절대 규칙)

개발 요청 시 **반드시 6단계 순차 실행**. 예외 없음.

```
워크트리 → 탐색 → 계획 → 구현 → 검증 → 커밋
```

- **워크트리**: 기존 워크트리에서 작업할지, 새 워크트리를 생성할지 사용자에게 확인
- **탐색**: 기존 코드 패턴/구조 파악 (Explore agent 또는 직접 Read)
- **계획**: 구현 전략 수립 → 사용자 승인
- **구현**: 코드 작성
- **검증**: 컨벤션 체크 → 빌드 → 테스트
- **커밋**: 사용자 확인 후 커밋

❌ 즉시 코드 작성 금지 / ❌ 탐색 없이 구현 금지 / ❌ 검증 없이 커밋 금지

---

## 프로젝트 개요

**Promiso** — 그룹 기반 약속 관리 iOS 앱

- **플랫폼**: iOS 18.0+ / **아키텍처**: TCA 1.22.2 / **UI**: SwiftUI
- **백엔드**: Firebase (Auth, Firestore, Functions, Storage)
- **모듈화**: Tuist 4.65.7

## 필수 컨벤션

### Git 커밋 메시지

```
<type>: <subject (한글, 50자 이내, 명령형, 마침표 없음)>

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

Type: `feat` | `fix` | `refactor` | `test` | `docs` | `chore` | `style`

예시:
```
✅ feat: 알림 설정 Feature 추가
✅ fix: 그룹 목록 중복 렌더링 버그 수정
❌ Add notification settings feature  (영어 금지)
❌ feat: 알림 설정 기능을 추가했습니다  (명령형 아님)
```

### Git Worktree 규칙

**Base 브랜치**: 최신 `release/*` 브랜치 (자동 감지)
```bash
# 최신 release 브랜치 확인
BASE=$(git branch -r | grep 'origin/release/' | sort -V | tail -1 | sed 's/.*origin\///')
```

**워크트리 구조**:
```
Promiso-worktrees/
├── release/{version}/       # base branch
├── feature/{name}/          # feature 브랜치 워크트리
├── refactor/{name}/         # refactor 브랜치 워크트리
└── fix/{name}/              # fix 브랜치 워크트리
```

**워크트리 생성**: 항상 최신 release 브랜치에서 분기
```bash
git worktree add ../Promiso-worktrees/{type}/{name} -b {type}/{name} $BASE
```

**PR / 머지 대상**: 항상 최신 `release/*` 브랜치 (main 직접 PR 금지)
```bash
gh pr create --base "$BASE" --title "..." --body "..."
```

### Swift / TCA Critical (위반 즉시 수정)

```swift
// ❌ 금지
@BindingState              // → @ObservableState
.task { }                  // → Effect.run { }
.fireAndForget { }         // → Effect.run { }
강제 언래핑 (!)            // → guard let / if let
하드코딩 색상              // → Color.pm* (Color.pmindigo.n500 등)
Feature에서 Firebase 직접 호출 // → Client 레이어 통과 필수

// ✅ 필수
@Reducer struct Feature { }
@ObservableState struct State: Equatable, Sendable { }
enum Action: ViewAction, Sendable { case view(View); case `internal`(Internal); case delegate(Delegate) }
@Dependency(\.client) var client
```

### UI Critical

```swift
// Glass Effect → Fallback 필수
if #available(iOS 26.0, *) { glassEffect(...) } else { background(.ultraThinMaterial, ...) }

// 탭 영역 Spacer 포함 시
.contentShape(Rectangle())  // 필수

// 주요 화면
.auroraBackground()  // 권장
```

### Warning (권장 수정)
- 축약 네이밍 (`btn`, `lbl`) → 전체 단어 사용
- `print()` 문 → 제거 (디버그 코드)
- SwiftUI Preview 누락 → 추가 권장
- 500라인 이상 파일 → 분리 권장

### 색상 규칙
- `Color.pmindigo.n500` = 약속 (Primary)
- `Color.pmaurora.purple` = 개인 일정

## 아키텍처

```
App → Features → Clients → Shared
         ↓
    ExternalDependency, ResourceKit
```

Feature 구조:
```
Features/{Name}Feature/
├── Sources/
│   ├── {Name}Feature.swift   # Reducer (Namespace: enum {Name} {})
│   └── {Name}View.swift      # SwiftUI View
└── Tests/Sources/
```

## 주요 경로

| 경로 | 설명 |
|------|------|
| `Projects/Features/` | Feature 모듈들 |
| `Projects/Clients/` | 데이터/네트워크 레이어 |
| `Projects/Shared/` | 공통 컴포넌트, 디자인 시스템 |
| `infra/firebase/functions/` | Firebase Functions (TypeScript) |
| `.ai/PROJECT_CONTEXT.md` | 상세 아키텍처/컨벤션 |
| `.ai/FIRESTORE_SCHEMA.md` | Firestore 데이터 스키마 |

## Makefile

```bash
make feature FEATURE_NAME=X       # Feature 생성
make remove-feature FEATURE_NAME=X # Feature 삭제
make functions-build               # Functions 빌드
make emulator-start                # Firebase 에뮬레이터
```

## 테스트

- Swift Testing 사용 (`@Test`, `#expect`) — XCTest 금지

## 에이전트 규칙

코드 리뷰 시 커스텀 `code-reviewer` 에이전트 사용 (플러그인 `pr-review-toolkit:code-reviewer`, `feature-dev:code-reviewer` 사용 금지)
