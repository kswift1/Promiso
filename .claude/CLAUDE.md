# Promiso - Claude Code 컨텍스트

## 절대 규칙 (메인 Claude 전용)

> 아래 규칙은 **메인 Claude에만 적용**됩니다.
> sub-agent(implementer, reviewer, test-writer, researcher)는 각자의 `.claude/agents/*.md` 프롬프트를 따릅니다.

```
❌ 즉시 코드 작성 금지 — 반드시 워크플로우 실행
❌ 탐색 없이 구현 금지
❌ 검증 없이 커밋 금지
❌ 유저 승인 없이 커밋 금지
```

### 도메인 규칙 수정 금지
`.ai/DOMAIN_RULES.md` 및 `.ai/domain-rules/` 하위 파일은 사용자의 명시적 허락 없이 수정 불가.

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

### 작업 규모 분류

| 규모 | 기준 | 워크플로우 |
|------|------|----------|
| **S** | 1~2 파일, 10줄 이내 | 탐색→구현→검증→커밋[🔒] |
| **M** | 3~5 파일, 1 모듈 | 전체 6단계 |
| **L** | 6+ 파일, 복수 모듈 | 전체 6단계 + 병렬 |

애매하면 **M으로 처리**.

### 6단계 워크플로우

```
0. 작업 공간 설정 [📋 유저 확인]
1. 탐색            🟢 자동
2. 계획            🔒 필수 승인 (M/L만)
3. 구현            🟢 자동
4. 검증            📋 유저 확인
5. 커밋            🔒 필수 승인
6. 후속            📋 선택
```

### 0. 작업 공간 설정
- 현재 브랜치 확인 (`git branch --show-current`)
- 진행 중 작업 있으면 Worktree 생성: `git worktree add ../Promiso-{브랜치명} -b {브랜치명} {base}`
- 브랜치 네이밍: `fix/`, `feat/`, `refactor/`

### 1. 탐색 — 🟢 자동
- Explore agent 또는 직접 Read로 기존 코드 패턴 파악
- 수정 대상 `.ai/domain-rules/*.md` 읽기 (필수)
- 영향받는 모듈/파일 식별 + 작업 규모 판단

### 2. 계획 — 🔒 필수 승인 (M/L)
계획서 포맷:
```
## 구현 계획
### 작업 규모: S / M / L
### 작업 브랜치: {브랜치명}
### 생성할 파일
### 수정할 파일
### 작업 분배
| 순서 | 담당 | 작업 내용 | 직렬/병렬 |
### 의존성 영향 범위
### 검증 대상
```

### 3. 구현 — 🟢 자동
- implementer agent에게 위임 (직접 Edit/Write 금지)
- 모듈 단위 빌드 확인: `make test-module MODULE={모듈명}`
- 빌드 실패 시 즉시 수정 후 재빌드
- 테스트 코드 작성 필수 (`.ai/TEST_POLICY.md` 준수)

### 4. 검증 — 📋 유저 확인
1. reviewer agent로 컨벤션 체크 (Critical 시 Step 3 복귀, 3회 초과 시 에스컬레이션)
2. Comprehensive 빌드: `make test-changed`
3. Comprehensive 테스트: 모든 테스트 통과 확인
4. 문서화 필요성 판단

보고 포맷:
```
## 구현 + 검증 결과
- 생성/수정 파일 목록
- 컨벤션: ✅/❌
- 빌드: ✅/❌
- 테스트: ✅/❌
커밋으로 진행할까요?
```

### 5. 커밋 — 🔒 필수 승인
```
1. git status + git diff 확인
2. 커밋 메시지 초안 작성 (CONVENTIONS.md Git 규칙 준수)
3. 유저 승인 후 git add + git commit
```

### 6. 후속 — 📋 선택
- PR 생성: 최신 `release/` 브랜치를 base로
- 다음 작업 제안

### 실패 복구
```
구현 ↔ 검증 최대 3회 반복
3회 초과 → 유저에게 에스컬레이션 (현재 상태 + 원인 + 시도한 해결 + 선택지)
```

---

## 에이전트 (4개 + Explore)

| 에이전트 | 역할 | 모델 | 트리거 |
|----------|------|------|--------|
| `implementer` | 코드 작성 (Feature, View, Firebase, 리팩터링) | sonnet | "만들어줘", "수정해줘" |
| `reviewer` | 리뷰 (코드 품질, 성능, 접근성, Firebase, 보안) | sonnet | "리뷰해줘", 검증 단계 |
| `test-writer` | Swift Testing 테스트 작성 | haiku | "테스트 작성" |
| `researcher` | 조사 (UI 레퍼런스, 최신 기술, App Store) | sonnet | "조사해줘", "레퍼런스" |
| `Explore` | 코드베이스 탐색 (읽기 전용) | - | 탐색 단계 |

### 자동 호출 규칙
- Feature/View/API 코드 작성 → `implementer`
- 코드 리뷰, 검증 → `reviewer`
- 테스트 작성 → `test-writer`
- UI 레퍼런스, 최신 기술 조사 → `researcher`
- 코드베이스 분석 → `Explore`
- 빌드 수정 → 에이전트 없이 직접 처리

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
| `.ai/CONVENTIONS.md` | 컨벤션 Single Source of Truth |
| `.ai/templates/*.swift` | 코드 템플릿 (Feature/View/Test) |
| `.ai/DOMAIN_RULES.md` | 도메인 비즈니스 규칙 (수정 금지) |
| `.ai/domain-rules/*.md` | 도메인별 상세 규칙 |
| `.ai/FIRESTORE_SCHEMA.md` | Firestore 데이터 스키마 |
| `.ai/TEST_POLICY.md` | 테스트 설계 기준 |
| `.ai/PROJECT_CONTEXT.md` | 프로젝트 상세 컨텍스트 |
