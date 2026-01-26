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

---

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
```

**예시**:
```
사용자: "알림 설정 Feature 만들어줘"

Step 1 - 탐색:
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

**실행 방법**:
```
필수 검증 항목:
1. 빌드 성공 확인 (tuist build 또는 xcodebuild)
2. 테스트 실행 (tuist test)
3. 코드 리뷰 (code-reviewer agent)
4. TCA 컨벤션 체크
5. Swift 문법 체크 (swift -typecheck)
```

**예시**:
```
Step 4 - 검증:

1. 빌드 확인
   → tuist build
   ✅ 빌드 성공

2. 테스트 실행
   → tuist test NotificationSettingsFeatureTests
   ✅ 모든 테스트 통과

3. 코드 리뷰
   → code-reviewer agent 호출
   ✅ 문제 없음 (또는 경고 2건)

4. 컨벤션 체크
   ✅ TCA 1.22.2 API 사용
   ✅ ViewAction 분리됨
   ✅ Aurora + Glass Effect 적용
```

---

### 5️⃣ 커밋 (Commit)

**목적**: Git 커밋 및 정리

**실행 방법**:
```
1. git status 확인
2. git diff 확인
3. 커밋 메시지 작성 (컨벤션 준수)
4. git add + git commit
5. (선택) PR 생성
```

**커밋 메시지 포맷**:
```
feat: 알림 설정 Feature 추가

- NotificationSettingsFeature 생성 (TCA 1.22.2)
- Aurora Background + Glass Effect UI
- 알림 타입별 토글 기능
- Swift Testing 기반 테스트

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**예시**:
```
Step 5 - 커밋:

→ git status (변경사항 확인)
→ git add Projects/Features/NotificationSettingsFeature
→ git add Projects/App/Sources/AppFeatureDeps.swift
→ git commit -m "..."

✅ 커밋 완료: abc123d
```

---

## 🤖 자동 에이전트 호출 규칙

### 필수 호출 규칙

| 사용자 요청 패턴 | 자동 호출 에이전트 | 예시 |
|----------------|------------------|------|
| **"Feature 만들어줘"** | `feature-generator` | "알림 설정 Feature 만들어줘" |
| **"View 만들어줘"** / **"UI 디자인"** | `ui-designer` | "프로필 편집 화면 만들어줘" |
| **"테스트 작성"** / **"테스트 추가"** | `test-writer` | "GroupFeature 테스트 작성해줘" |
| **"리뷰해줘"** / **"코드 검토"** | `code-reviewer` | "이 PR 리뷰해줘" |
| **"리팩터링"** / **"구조 개선"** | `refactorer` | "중복 코드 제거해줘" |
| **"Firebase"** / **"API 엔드포인트"** | `backend-developer` | "알림 발송 Functions 추가" |
| **"비용 최적화"** / **"Firestore 쿼리"** | `firebase-cost-advisor` | "이 쿼리 비용 줄여줘" |
| **3개 이상 작업** / **복잡한 요청** | `orchestrator` | "Settings 관련 3개 Feature 만들어줘" |

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
   $ tuist build
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

## 주요 경로

| 경로 | 설명 |
|------|------|
| `Projects/Features/` | Feature 모듈들 |
| `Projects/Clients/` | 데이터/네트워크 레이어 |
| `Projects/Shared/` | 공통 컴포넌트, 디자인 시스템 |
| `infra/firebase/functions/` | Firebase Functions (TypeScript) |
| `infra/firebase/firestore.rules` | Firestore 보안 규칙 |
