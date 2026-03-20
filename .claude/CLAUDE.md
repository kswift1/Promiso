# Promiso - Claude Code 컨텍스트

## 절대 규칙 (메인 Claude 전용)

> 아래 규칙은 **메인 Claude에만 적용**됩니다.
> sub-agent(implementer, reviewer, test-writer, researcher)는 각자의 `.claude/agents/*.md` 프롬프트를 따릅니다.

```
❌ 즉시 코드 작성 금지 — 반드시 워크플로우 실행 (XS 제외)
❌ 탐색 없이 구현 금지 (XS 제외)
❌ 검증 없이 커밋 금지 (XS 제외)
❌ 유저 승인 없이 커밋 금지
```

> **XS 예외**: 1파일 5줄 이내 수정(오타, import, 1줄 수정 등)은 메인 Claude가 직접 처리 가능. 에이전트 위임 불필요.

---

## 프로젝트 개요

**Promiso** — 그룹 기반 약속 관리 iOS 앱
- iOS 18.0+ | TCA 1.22.2 | SwiftUI + iOS 26 Glass Effect
- Firebase (Auth, Firestore, Functions, Storage) | Tuist 4.65.7

---

## 컨벤션

**모든 컨벤션은 `.ai/CONVENTIONS.md`에 정의되어 있습니다.**

에이전트와 메인 Claude 모두 이 파일을 기준으로 판단합니다.
핵심 항목 (상세는 CONVENTIONS.md 참조):
- 아키텍처: `App → Features → Clients → Shared` (단방향)
- TCA: Namespace 패턴, Action 3분할, @ObservableState, @Dependency
- UI: `Color.pm*`, `.auroraBackground()`, Glass Effect + Fallback, `.contentShape(Rectangle())`
- Git: `<type>: <한글 subject>` + `Co-Authored-By`
- 테스트: Swift Testing (@Test, #expect), XCTest 금지
- PR: 최신 `release/` 브랜치를 base로

---

## 워크플로우

> **작업 시작 전 반드시 `.ai/AI_WORKFLOW.md`를 읽고 따른다.**

핵심 원칙:
- ❌ 탐색 없이 구현 금지
- ❌ 검증 없이 커밋 금지
- ❌ 유저 승인 없이 커밋 금지
- ❌ `.ai/DOMAIN_RULES.md` 및 `.ai/domain-rules/` 사용자 허락 없이 수정 금지

Claude Code 추가 규칙:
- XS: 메인 Claude가 직접 Edit/Write 처리 (에이전트 위임 불필요)
- S 이상: 구현 단계에서 implementer agent에게 위임 (직접 Edit/Write 금지)
- 검증 단계에서 reviewer agent로 컨벤션 체크 (Critical 시 Step 3 복귀, 3회 초과 시 에스컬레이션)

---

## 에이전트 (4개 + Explore)

| 에이전트 | 역할 | 트리거 |
|----------|------|--------|
| `implementer` | 코드 작성 (Feature, View, Firebase, 리팩터링) | "만들어줘", "수정해줘" |
| `reviewer` | 리뷰 (코드 품질, 성능, 접근성, Firebase, 보안) | "리뷰해줘", 검증 단계 |
| `test-writer` | Swift Testing 테스트 작성 | "테스트 작성" |
| `researcher` | 조사 (UI 레퍼런스, 최신 기술, App Store) | "조사해줘", "레퍼런스" |
| `Explore` | 코드베이스 탐색 (읽기 전용) | 탐색 단계 |

### 모델 선택 가이드라인

에이전트 호출 시 메인 Claude가 작업 복잡도에 따라 모델을 런타임 선택한다:

| 모델 | 사용 기준 |
|------|----------|
| **haiku** | 단순 컨벤션 체크, 1-2파일 리뷰, 단순 테스트, 키워드 기반 조사 |
| **sonnet** | 복잡한 구현, 멀티파일 리뷰, TCA 패턴 테스트, 심층 분석 |

기본값: 판단이 어려우면 **sonnet** 사용.

### 자동 호출 규칙
- Feature/View/API 코드 작성 → `implementer`
- 코드 리뷰, 검증 → `reviewer`
- 테스트 작성 → `test-writer`
- UI 레퍼런스, 최신 기술 조사 → `researcher`
- 코드베이스 분석 → `Explore`
- 빌드 수정 → 에이전트 없이 직접 처리

### researcher 자동 트리거 (명시적 요청 없이도 호출)
- deprecated API 사용 감지 시 → 대체 API 조사
- iOS 버전별 분기(`#available`) 추가가 필요한 상황 → 최신 HIG/API 확인
- 외부 라이브러리 버전 업데이트 관련 작업 시 → 마이그레이션 가이드 조사

### 플러그인 에이전트 사용 금지
```
❌ pr-review-toolkit:code-reviewer  → ✅ reviewer
❌ feature-dev:code-reviewer        → ✅ reviewer
❌ feature-dev:code-architect       → ✅ implementer
```

---

## Slash Commands

| 커맨드 | 역할 |
|--------|------|
| `/new-feature` | Feature 생성 (Reducer + View + Tests) |
| `/new-screen` | 화면 생성 (Feature + UI) |
| `/review-pr` | PR 코드 리뷰 |
| `/fix-reviews` | PR 리뷰 자동 수정 |
| `/release-notes` | 릴리스 노트 자동 생성 |
| `/next-release` | 릴리스 후 다음 버전 준비 (머지, 태그, 브랜치, 버전 업데이트) |

---

## Makefile 명령어

```bash
make setup                          # 프로젝트 초기 설정 (Tuist 의존성 + xcconfig + generate)
make feature FEATURE_NAME=X        # Feature 생성
make remove-feature FEATURE_NAME=X  # Feature 삭제
make test-module MODULE=X           # 모듈 단위 테스트
make test-changed                   # 변경 모듈 자동 감지 테스트
make deps                           # 의존성 그래프
make emulator-start                 # Firebase 에뮬레이터
make functions-build                # Functions 빌드
```

> **주의**: `.xcworkspace`가 없으면 `make setup` 먼저 실행. `Config/Dev.xcconfig`가 없으면 템플릿에서 복사 필요.

---

## 주요 경로

| 경로 | 설명 |
|------|------|
| `Projects/Features/` | Feature 모듈 |
| `Projects/Clients/` | 데이터/네트워크 레이어 |
| `Projects/Shared/` | 공통 컴포넌트, 디자인 시스템 |
| `infra/firebase/functions/` | Firebase Functions (TypeScript) |
| `infra/firebase/firestore.rules` | Firestore 보안 규칙 |

---

## 참조 문서

| 문서 | 설명 |
|------|------|
| `.ai/AI_WORKFLOW.md` | 공통 워크플로우 SSOT |
| `.ai/CONVENTIONS.md` | 컨벤션 Single Source of Truth |
| `.ai/templates/*.swift` | 코드 템플릿 (Feature/View/Test) |
| `.ai/DOMAIN_RULES.md` | 도메인 비즈니스 규칙 (수정 금지) |
| `.ai/domain-rules/*.md` | 도메인별 상세 규칙 |
| `.ai/FIRESTORE_SCHEMA.md` | Firestore 데이터 스키마 |
| `.ai/TEST_POLICY.md` | 테스트 설계 기준 |
| `.ai/PROJECT_CONTEXT.md` | 프로젝트 상세 컨텍스트 |
