# Promiso - Claude Code 컨텍스트

## ⚠️ 절대 규칙 (CRITICAL)

**사용자가 "~~해줘" 라고 개발 요청을 하면:**

```
❌ 즉시 코드 작성 금지
❌ 탐색 없이 구현 금지
❌ 검증 없이 커밋 금지

✅ 반드시 5단계 워크플로우 실행
   탐색 → 계획 → 구현 → 검증 → 커밋
```

**이 규칙을 위반하면 안 됩니다. 예외 없음.**

### 🔒 도메인 규칙 수정 금지

**`.ai/DOMAIN_RULES.md` 및 `.ai/domain-rules/` 하위 모든 파일은 사용자의 명시적 허락 없이 절대 수정할 수 없습니다.**

- 도메인 규칙 추가/변경/삭제 시 반드시 사용자 확인 후 진행
- 코드 수정 시 도메인 규칙과 충돌이 발생하면 즉시 사용자에게 알림
- 규칙 위반이 의심되는 코드 발견 시 경고 표시

---

## 프로젝트 개요

**Promiso**는 그룹 기반 약속 관리 iOS 앱입니다.

- **플랫폼**: iOS 18.0+
- **아키텍처**: TCA (The Composable Architecture) 1.22.2
- **UI**: SwiftUI + iOS 26 Glass Effect
- **백엔드**: Firebase (Auth, Firestore, Functions, Storage)
- **모듈화**: Tuist 4.65.7

## 🚨 필수 컨벤션 (위반 시 자동 수정)

### Git 커밋 메시지 (절대 규칙)

**포맷**:
```
<type>: <subject>

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

**Type 규칙** (소문자):
- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 리팩터링 (기능 변경 없음)
- `test`: 테스트 추가/수정
- `docs`: 문서 변경
- `chore`: 빌드/설정 변경
- `style`: 코드 포맷팅 (로직 변경 없음)

**Subject 규칙**:
- 50자 이내
- 명령형 (동사원형) "추가한다" ❌ → "추가" ✅
- 마침표 없음
- **한글 사용** (코드/기술용어는 영어)

**예시**:
```
✅ 올바른 예시:
feat: 알림 설정 Feature 추가
fix: 그룹 목록 중복 렌더링 버그 수정
refactor: FirestoreClient 쿼리 로직 개선

❌ 잘못된 예시:
Add notification settings feature (영어 금지)
feat: 알림 설정 기능을 추가했습니다 (명령형 아님)
알림 설정 추가 (type 없음)
```

### PR (Pull Request) 생성 규칙

**Base 브랜치 지정 (필수)**:
- PR 생성 시 **반드시 최신 release/ 브랜치를 base로 지정**
- main 브랜치로 직접 PR 금지

**방법**:
```bash
# 1. 최신 release 브랜치 확인
git branch -r | grep 'origin/release/' | sort -V | tail -1

# 2. PR 생성 시 base 지정
gh pr create --base release/v{version} --title "..." --body "..."

# 예시
gh pr create --base release/v1.0.0 --title "feat: 새 기능 추가" --body "..."
```

**자동화**:
```bash
# 최신 release 브랜치 자동 감지 및 PR 생성
latest_release=$(git branch -r | grep 'origin/release/' | sort -V | tail -1 | sed 's/.*origin\///')
gh pr create --base "$latest_release" --title "..." --body "..."
```

---

### Swift 코드 컨벤션

**🔴 Critical (즉시 수정)**:
```swift
// ❌ 금지
강제 언래핑 (!) → guard let 사용
@BindingState → @ObservableState 사용
.task { } → Effect.run { } 사용
.fireAndForget { } → Effect.run { } 사용
하드코딩 색상 → Color.pm* 사용 (Color.pmindigo.n500 등)
Feature에서 직접 Firebase 호출 → Client 레이어 통과 필수
Glass Effect Fallback 누락 → #available(iOS 26) 분기 필수
```

**🟡 Warning (권장 수정)**:
```swift
// 경고
축약 네이밍 (btn, lbl) → 전체 단어 사용 권장
print() 문 → 제거 권장
SwiftUI Preview 누락 → 추가 권장
500라인 이상 파일 → 분리 권장
```

**✅ 필수 사항**:
```swift
// 코드 스타일
- 들여쓰기: 2 spaces
- 네이밍: camelCase (변수/함수), PascalCase (타입)

// TCA 구조
- Namespace 패턴: enum FeatureName {} + extension
- Action 분리: ViewAction / InternalAction / DelegateAction
- Sendable 준수: enum ViewAction: Sendable
- 의존성 주입: @Dependency(\.client) var client

// 테스트
- Swift Testing 사용 (@Test, #expect)
```

---

### TCA 1.22.2 필수 API

```swift
// ✅ 사용할 것
@Reducer struct MyFeature { }
@ObservableState struct State { }
enum Action: ViewAction { }
@Dependency(\.client) var client
Effect.run { } / Effect.send()

// ❌ 사용하지 말 것 (Critical)
@BindingState
.task { }
.fireAndForget { }
```

---

### UI 스타일

**🔴 Critical**:
```swift
// 색상 - Color.pm* 필수
Color.pmindigo.n500       // ✅
Color.pmaurora.purple     // ✅
Color(red: 0.5, ...)      // ❌ 금지

// Glass Effect Fallback 필수
if #available(iOS 26.0, *) {
  glassEffect(...)
} else {
  background(.ultraThinMaterial, ...)
}
```

**✅ 필수**:
```swift
// Aurora Background (주요 화면)
.auroraBackground()

// Glass Effect (iOS 26+)
.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

// ⚠️ 탭 영역 확보 (Spacer 등 빈 영역도 탭 가능하게)
Button { ... } label: {
    HStack {
        Text("Label")
        Spacer()
    }
    .contentShape(Rectangle())  // ← 필수!
}
```

---

### 아키텍처 규칙

**🔴 Critical**:
```
Feature → Client → Firebase/API (직접 호출 금지)
         ↑
    @Dependency 주입
```

**파일 분리**:
```
- 500라인 이상: 파일 분리 권장
- View/Reducer 분리: FeatureName.swift + FeatureNameView.swift
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
| [.ai/DOMAIN_RULES.md](../.ai/DOMAIN_RULES.md) | 🔒 도메인 비즈니스 규칙 (**수정 금지**) |
| [.ai/DOMAIN_RULES_BACKLOG.md](../.ai/DOMAIN_RULES_BACKLOG.md) | 도메인 규칙 백로그 (충돌/누락/예정 변경) |
| [.ai/TEST_POLICY.md](../.ai/TEST_POLICY.md) | 테스트 설계 기준 및 작성 규칙 |
| [.ai/archive/CHECKLIST.md](../.ai/archive/CHECKLIST.md) | 개발 체크리스트 |
| [.ai/archive/PROMPTS.md](../.ai/archive/PROMPTS.md) | 프롬프트 템플릿 모음 |

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

## 🔒 필수 워크플로우 (MANDATORY)

**모든 개발 작업은 반드시 다음 5단계를 순차적으로 진행하세요.**

```
탐색 → 계획 → 구현 → 검증 → 커밋
```

### 절대 규칙

사용자가 "~~해줘" 라고 요청하면:
1. ❌ **즉시 코드 작성 금지**
2. ✅ **반드시 5단계 워크플로우 실행**
3. ✅ **각 단계 완료 후 다음 단계로 이동**

---

## 📋 5단계 워크플로우 상세

### 1️⃣ 탐색 (Explore)

**목적**: 기존 코드 패턴, 구조, 컨벤션 파악

**실행 방법**:
```
- Explore agent 사용 (읽기 전용)
- 관련 파일 Read
- 기존 Feature 패턴 분석
- ⚠️ 수정 대상에 관련된 domain-rules/*.md 읽기 (필수)
```

**도메인 규칙 확인 (필수)**:
```
수정 대상 도메인 → 읽어야 할 파일:
- 그룹 관련     → .ai/domain-rules/group.md
- 약속 관련     → .ai/domain-rules/promise.md
- 사용자 관련   → .ai/domain-rules/user.md
- 알림 관련     → .ai/domain-rules/notification.md
- LiveActivity  → .ai/domain-rules/liveactivity.md
- 위젯 관련     → .ai/domain-rules/widget.md
- 보안/권한     → .ai/domain-rules/security.md
```

**예시**:
```
사용자: "알림 설정 Feature 만들어줘"

Step 1 - 탐색:
→ .ai/domain-rules/notification.md 읽기 (규칙 확인)
→ Explore agent로 기존 Settings 관련 Feature 찾기
→ SettingsFeature.swift 읽어서 패턴 파악
→ 의존성 구조 확인
```

---

### 2️⃣ 계획 (Plan)

**목적**: 구현 전략 수립 및 사용자 승인

**실행 방법**:
```
- 탐색 결과 기반으로 상세 계획 작성
- 생성할 파일 목록
- 수정할 파일 목록
- 의존성 추가 필요 여부
- 예상 작업 범위
```

**사용자 확인**:
```
계획을 보여주고 "이대로 진행할까요?" 물어보기
또는 AskUserQuestion으로 선택지 제공
```

**예시**:
```
Step 2 - 계획:

## 구현 계획

### 생성할 파일
- Projects/Features/NotificationSettingsFeature/Sources/NotificationSettingsFeature.swift
- Projects/Features/NotificationSettingsFeature/Sources/NotificationSettingsView.swift
- Projects/Features/NotificationSettingsFeature/Tests/Sources/NotificationSettingsFeatureTests.swift

### 수정할 파일
- Projects/App/Sources/AppFeatureDeps.swift (의존성 추가)

### 작업 순서
1. make feature FEATURE_NAME=NotificationSettings
2. Feature 파일 작성 (TCA 1.22.2)
3. View 파일 작성 (Aurora + Glass Effect)
4. 테스트 작성
5. 빌드 및 테스트 실행
6. 커밋

이대로 진행할까요?
```

---

### 3️⃣ 구현 (Implement)

**목적**: 계획대로 코드 작성

**실행 방법**:
```
- 적절한 agent에게 작업 위임
- feature-generator: Feature 생성
- ui-designer: View 작성
- backend-developer: Firebase/API
- 병렬 작업 가능하면 동시 실행
```

**예시**:
```
Step 3 - 구현:

→ feature-generator: NotificationSettingsFeature 생성
→ ui-designer: NotificationSettingsView 디자인
→ (병렬 실행)

✅ 완료: 모든 파일 생성됨
```

---

### 4️⃣ 검증 (Verify)

**목적**: 코드 품질 및 동작 확인

**실행 방법** (순서대로 필수 실행):
```
1. 컨벤션 체크 (최우선) ⚠️
   - code-reviewer agent 호출
   - 필수 컨벤션 위반 확인 (.claude/CLAUDE.md 참조)
   - Critical 발견 시 즉시 수정 요구

2. 빌드 확인
   - tuist build Promiso-Workspace
   - 컴파일 에러 확인

3. 테스트 실행
   - tuist test (또는 swift test)
   - 모든 테스트 통과 확인

4. 정적 분석 (선택)
   - Swift 문법 체크 (swift -typecheck)
   - SwiftLint (설정된 경우)
```

**컨벤션 체크 항목**:
```bash
# 자동 검사 스크립트 실행
# 1. TCA Deprecated API
grep -rn "@BindingState\|\.task\s*{\|\.fireAndForget" --include="*.swift" .

# 2. 강제 언래핑
grep -rn "!" --include="*.swift" . | grep -v "// swiftlint:disable"

# 3. 하드코딩 색상
grep -rn "Color(red:\|Color(UIColor" --include="*.swift" .

# 4. Aurora Background 누락
grep -L "\.auroraBackground()" --include="*View.swift" .

# 5. Glass Effect Fallback 누락
grep -l "\.glassEffect" --include="*.swift" . | xargs grep -L "#available(iOS 26"
```

**예시**:
```
Step 4 - 검증:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. 컨벤션 체크 (code-reviewer)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ code-reviewer agent 호출

검사 결과:
✅ TCA 1.22.2 API 사용
✅ ViewAction / InternalAction 분리
✅ Aurora + Glass Effect 적용
✅ Sendable 프로토콜 준수
❌ Critical 0건
🟡 Warning 2건:
   - 줄 45: TODO 주석 제거 권장
   - 줄 78: print 문 제거 (디버그 코드)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
2. 빌드 확인
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ tuist build Promiso-Workspace
✅ 빌드 성공

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
3. 테스트 실행
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$ tuist test NotificationSettingsFeatureTests
✅ 5/5 테스트 통과

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
검증 결과: ✅ 통과 (Warning 2건은 커밋 가능)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Critical 발견 시 처리**:
```
❌ Critical 발견:
- 줄 23: @BindingState 사용 (deprecated)
- 줄 45: 강제 언래핑 (!) 사용

→ 즉시 Step 3 (구현)으로 복귀
→ 문제 수정 후 다시 검증
```

---

### 5️⃣ 커밋 (Commit)

**목적**: Git 커밋 및 정리

**⚠️ 중요: 사용자 확인 후 커밋**

**실행 방법**:
```
1. git status 확인
2. git diff 확인
3. 커밋 메시지 초안 작성
4. 사용자에게 확인 요청 ← 필수!
5. 승인 후 git add + git commit
```

**커밋 메시지 포맷**:
```
feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI
- 알림 타입별 토글 기능
- Swift Testing 기반 테스트

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

**예시**:
```
Step 5 - 커밋:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
변경 사항:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
+ Projects/Features/NotificationSettingsFeature/...
+ Projects/Features/NotificationSettingsFeature/...
M Projects/App/Sources/AppFeatureDeps.swift

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
커밋 메시지 초안:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI
- 알림 타입별 토글 기능

이대로 커밋할까요? (또는 수정사항 알려주세요)
```

---

## 🤖 에이전트 목록

### 사용자 정의 에이전트 (17개)

| 에이전트 | 역할 | 모델 | 트리거 |
|----------|------|------|--------|
| `feature-generator` | TCA Feature 생성 | sonnet | "Feature 만들어줘" |
| `ui-designer` | SwiftUI View 디자인 | sonnet | "View 만들어줘", "UI 디자인" |
| `ui-researcher` | UI/UX 레퍼런스 조사 | sonnet | "UI 개선", "레퍼런스" |
| `test-writer` | Swift Testing 테스트 작성 | haiku | "테스트 작성" |
| `code-reviewer` | 코드 품질/컨벤션 검토 | opus | "리뷰해줘", "코드 검토" |
| `refactorer` | 코드 구조 개선 | sonnet | "리팩터링", "구조 개선" |
| `backend-developer` | Firebase/API 개발 | sonnet | "Firebase", "API" |
| `firebase-cost-advisor` | Firebase 비용 최적화 | sonnet | "비용 최적화" |
| `security-auditor` | Firebase Rules 검증, 보안 분석 | opus | "보안", "Security Rules" |
| `knowledge-updater` | 최신 기술 정보 검색 | sonnet | 버전/API 질문, "최신" |
| `policy-generator` | 개인정보처리방침, 이용약관 생성 | sonnet | "정책", "약관", 출시 준비 |
| `skill-suggester` | 반복 작업 감지, Skill 자동 제안 | sonnet | "자동화", 반복 패턴 감지 |
| `app-store-reviewer` | App Store 심사 가이드라인 검사 | sonnet | "심사", "출시", "앱스토어" |
| `release-manager` | 버전 관리, 체인지로그, 배포 | sonnet | "배포", "버전", "릴리즈" |
| `accessibility-auditor` | 접근성 검사 (VoiceOver, Dynamic Type) | sonnet | "접근성", "VoiceOver", UI 완료 시 |
| `performance-analyzer` | 성능 이슈 감지 (메모리, 렌더링, TCA) | sonnet | "성능", "느려", 코드 리뷰 시 |
| `orchestrator` | 복잡한 작업 조율 | opus | 3개 이상 작업 |

### 커맨드 (Slash Commands, 4개)

| 커맨드 | 역할 | 호출 에이전트 |
|--------|------|--------------|
| `/new-feature` | Feature 생성 (Reducer + View + Tests) | feature-generator → test-writer → code-reviewer |
| `/new-screen` | 화면 생성 (Feature + UI 디자인) | feature-generator → ui-designer → test-writer → code-reviewer |
| `/review-pr` | PR/변경사항 코드 리뷰 | code-reviewer (+firebase-cost-advisor) |
| `/fix-reviews` | PR 리뷰 자동 수정 | 리뷰 분석 → 수정 → 커밋 |

### ⚠️ 플러그인 에이전트 사용 규칙

**중복 방지**: 아래 플러그인 에이전트는 **사용하지 않습니다** (사용자 정의로 대체):

```
❌ pr-review-toolkit:code-reviewer  → ✅ code-reviewer (사용자 정의)
❌ feature-dev:code-reviewer        → ✅ code-reviewer (사용자 정의)
❌ feature-dev:code-architect       → ✅ feature-generator (사용자 정의)
```

**사용 가능한 플러그인 에이전트**:
- `Explore` - 코드베이스 탐색 (5단계 워크플로우 1단계)
- `commit-commands:commit` - Git 커밋 (/commit)

---

## 🤖 자동 에이전트 호출 규칙

### 필수 호출 규칙

| 사용자 요청 패턴 | 자동 호출 에이전트 | 예시 |
|----------------|------------------|------|
| **"Feature 만들어줘"** | `feature-generator` | "알림 설정 Feature 만들어줘" |
| **"View 만들어줘"** / **"UI 디자인"** | `ui-designer` | "프로필 편집 화면 만들어줘" |
| **"UI 개선"** / **"레퍼런스"** / **"다른 앱 참고"** | `ui-researcher` | "그룹 목록 화면 개선하고 싶어" |
| **"테스트 작성"** / **"테스트 추가"** | `test-writer` | "GroupFeature 테스트 작성해줘" |
| **"리뷰해줘"** / **"코드 검토"** | `code-reviewer` | "이 PR 리뷰해줘" |
| **"리팩터링"** / **"구조 개선"** | `refactorer` | "중복 코드 제거해줘" |
| **"Firebase"** / **"API 엔드포인트"** | `backend-developer` | "알림 발송 Functions 추가" |
| **"비용 최적화"** / **"Firestore 쿼리"** | `firebase-cost-advisor` | "이 쿼리 비용 줄여줘" |
| **3개 이상 작업** / **복잡한 요청** | `orchestrator` | "Settings 관련 3개 Feature 만들어줘" |

### "빌드 수정해줘" 요청 시

에이전트 호출 없이 직접 처리:

```
1. tuist build Promiso-Workspace 실행
2. 에러 메시지 분석
3. 해당 파일 수정
4. 다시 빌드 확인
5. 성공할 때까지 반복
```

💡 **Tip**: Xcode 에러 스크린샷이나 메시지를 공유해주면 더 정확히 수정 가능

### 자동 호출 예시

#### ❌ 잘못된 응답 (직접 작업)
```
사용자: "알림 설정 Feature 만들어줘"
Claude: (직접 코드 작성 시작...) ← 비효율적!
```

#### ✅ 올바른 응답 (에이전트 호출)
```
사용자: "알림 설정 Feature 만들어줘"
Claude: feature-generator 에이전트를 사용하겠습니다.
        [Task tool로 feature-generator 호출]
```

### 복잡한 작업 = orchestrator 우선

**3개 이상 작업이거나 여러 에이전트가 필요하면 orchestrator 사용:**

```
사용자: "Settings 관련 Feature 3개 만들고 테스트까지 작성해줘"
Claude: 복잡한 작업이므로 orchestrator를 사용하겠습니다.
        [Task tool로 orchestrator 호출]
        → orchestrator가 feature-generator 3번 + test-writer 호출
```

### 병렬 실행 원칙

**독립적인 작업은 병렬로 실행:**

```
사용자: "NotificationSettings, PrivacySettings, AccountSettings Feature 만들어줘"
Claude: 3개의 feature-generator를 병렬로 실행합니다.
        [한 메시지에 Task 3개 동시 호출]
```

---

## 🎯 실전 워크플로우 예시

### 예시 1: Feature 개발

```
사용자: "알림 설정 Feature 만들어줘"

Claude 실행 과정:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 Step 1: 탐색 (Explore)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Explore agent를 사용해서 기존 코드를 분석하겠습니다.

[Explore agent 실행]

✅ 탐색 완료:
- 기존 SettingsFeature 패턴 확인
- TCA 1.22.2 구조 파악
- 필요한 의존성: UserDefaultsClient

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Step 2: 계획 (Plan)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## 구현 계획

### 생성할 파일
1. Projects/Features/NotificationSettingsFeature/Sources/NotificationSettingsFeature.swift
2. Projects/Features/NotificationSettingsFeature/Sources/NotificationSettingsView.swift
3. Projects/Features/NotificationSettingsFeature/Tests/Sources/NotificationSettingsFeatureTests.swift

### 수정할 파일
- Projects/App/Sources/AppFeatureDeps.swift

### 작업 순서
1. make feature FEATURE_NAME=NotificationSettings
2. Feature 작성 (TCA 1.22.2)
3. View 작성 (Aurora + Glass Effect)
4. 테스트 작성 (Swift Testing)
5. 빌드 및 테스트 실행
6. 커밋

이대로 진행할까요?

[사용자 승인 대기 또는 자동 진행]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚙️ Step 3: 구현 (Implement)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

feature-generator, ui-designer, test-writer를 병렬로 실행합니다.

[Task tools 병렬 실행]

✅ 구현 완료:
- NotificationSettingsFeature.swift 생성
- NotificationSettingsView.swift 생성 (Aurora + Glass)
- NotificationSettingsFeatureTests.swift 생성

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Step 4: 검증 (Verify)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. 빌드 테스트
   $ tuist build Promiso-Workspace
   ✅ 빌드 성공

2. 테스트 실행
   $ tuist test NotificationSettingsFeatureTests
   ✅ 5/5 테스트 통과

3. 코드 리뷰
   [code-reviewer agent 실행]
   ✅ 문제 없음

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💾 Step 5: 커밋 (Commit)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ git add Projects/Features/NotificationSettingsFeature
$ git add Projects/App/Sources/AppFeatureDeps.swift
$ git commit -m "feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI
- 알림 타입별 토글 기능
- Swift Testing 기반 테스트 5개

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

✅ 커밋 완료: abc123d

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 작업 완료!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NotificationSettings Feature가 성공적으로 추가되었습니다.
```

### 예시 2: 복잡한 작업 (여러 Feature)

```
사용자: "Settings 관련 3개 Feature 만들어줘: NotificationSettings, PrivacySettings, AccountSettings"

Claude:
복잡한 작업이므로 orchestrator를 사용하겠습니다.

[orchestrator가 5단계 워크플로우를 3번 반복]
- 각 Feature마다 탐색 → 계획 → 구현 → 검증 → 커밋
- 가능한 작업은 병렬로 실행 (3개 feature-generator 동시)

✅ 모든 작업 완료:
- 커밋 3개 생성
- 총 9개 파일 생성
```

---

## 에이전트 직접 호출 (선택)

사용자가 명시적으로 요청한 경우에만 사용:

```bash
# Slash 커맨드
/new-feature NotificationSettings
/new-screen PrivacySettings

# 명시적 요청
"feature-generator로 알림 설정 Feature 만들어줘"
"backend-developer로 새 API 엔드포인트 추가해줘"
```

## 🔐 컨벤션 강제 (Hook 설정 - 선택사항)

**더 강력한 컨벤션 강제를 원한다면 Hook을 설정하세요.**

### Hook이란?
코드 작성 후 자동으로 실행되는 검사 스크립트입니다.
- Critical 에러 발견 시 작업 중단
- Warning만 있으면 작업 계속

### Hook 활성화 방법

**.claude/settings.local.json**에 추가:

```json
{
  "permissions": {
    "allow": [
      // ... 기존 권한들 ...
    ]
  },
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

### Hook 동작 방식

```
코드 작성 (Edit/Write)
    ↓
Hook 자동 실행
    ↓
┌─────────────────────────┐
│ 컨벤션 체크             │
│ - TCA Deprecated API    │
│ - 강제 언래핑           │
│ - 하드코딩 색상         │
│ - Aurora Background     │
│ - Glass Effect Fallback │
└─────────────────────────┘
    ↓
Critical 발견?
    ├─ Yes → ❌ 작업 중단 (수정 요구)
    └─ No  → ✅ 작업 계속 (Warning만 표시)
```

### Hook 비활성화

Hook이 너무 엄격하다면:
```json
// hooks 섹션을 제거하거나 빈 배열로 설정
"hooks": {
  "PostToolUse": []
}
```

### 테스트

Hook이 제대로 작동하는지 테스트:
```bash
# 직접 실행
.claude/hooks/check-conventions.sh Projects/Features/SomeFeature/Sources/SomeView.swift
```

---

## 주요 경로

| 경로 | 설명 |
|------|------|
| `Projects/Features/` | Feature 모듈들 |
| `Projects/Clients/` | 데이터/네트워크 레이어 |
| `Projects/Shared/` | 공통 컴포넌트, 디자인 시스템 |
| `infra/firebase/functions/` | Firebase Functions (TypeScript) |
| `infra/firebase/firestore.rules` | Firestore 보안 규칙 |
| `.claude/hooks/check-conventions.sh` | 컨벤션 체크 Hook 스크립트 |
