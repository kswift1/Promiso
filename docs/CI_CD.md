# Promiso CI/CD 가이드

Promiso 프로젝트의 GitHub Actions 기반 CI/CD 파이프라인 설명입니다.

## 문서 메타

- 목적: GitHub Actions 워크플로우 동작과 운영 기준 정의
- 대상 독자: CI/CD 관리 담당자, 배포 자동화 작업자
- 최종 수정일: 2026-02-06
- 관련 문서: [README.md](README.md) · [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) · [DEPLOYMENT.md](DEPLOYMENT.md)

## 범위 안내

- 이 문서: 워크플로우 트리거/단계/시크릿/문제 해결
- 브랜치 정책: [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md)
- 수동 배포 실행 절차: [DEPLOYMENT.md](DEPLOYMENT.md)

## 개요

현재 저장소의 `.github/workflows/*.yml` 기준으로 다음 워크플로우가 동작합니다.

| 워크플로우 | 트리거 | 목적 | 환경 |
|-----------|--------|------|------|
| **PR Check** | PR → main | iOS 빌드 & 테스트 검증 | Dev |
| **Deploy iOS** | 수동 (workflow_dispatch) | TestFlight 배포 | Stage / Prod |
| **Deploy Firebase** | 수동 (workflow_dispatch) | Firebase 배포 (Functions/Rules) | Stage / Prod |
| **Deploy Firebase Stage (Auto)** | `push` to `release/**` + Firebase 경로 변경 | Stage 자동 배포 | Stage |
| **Gemini Review Slack** | `pull_request_review` submitted | Gemini 리뷰 Slack 알림 | N/A |

---

## 1. PR Check 워크플로우

### 목적
main 브랜치로의 PR 생성 시 자동으로 빌드 & 테스트를 실행하여 코드 품질을 검증합니다.

### 트리거
```yaml
on:
  pull_request:
    branches: [main]
```

### 실행 단계

```
1. 체크아웃 및 환경 설정
   ↓
2. xcconfig 파일 생성 (API 키)
   ↓
3. Firebase plist 파일 복사 (Dev/Stage/Prod)
   ↓
4. 프로젝트 생성 (tuist install & generate)
   ↓
5. 빌드 (PromisoDev 타겟)
   ↓
6. 테스트 실행
   ↓
7. 테스트 결과 업로드 (실패 시)
   ↓
8. PR 코멘트 (성공/실패 알림)
```

### 주요 특징

- **동시성 제어**: 같은 PR에서 새 커밋이 푸시되면 이전 빌드를 취소하고 새 빌드 실행
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```

- **캐싱**: Tuist 빌드 캐시를 활용하여 빌드 속도 향상
  ```yaml
  - uses: actions/cache@v4
    with:
      path: |
        ~/Library/Caches/tuist
        .build
      key: ${{ runner.os }}-tuist-${{ hashFiles('**/Package.resolved', '**/Project.swift', '**/Tuist/**') }}
  ```

- **자동 PR 코멘트**: 빌드/테스트 결과를 PR에 자동으로 코멘트

### 환경 설정

xcconfig 파일 생성을 위해 다음 환경변수가 필요합니다.

```yaml
env:
  # Dev 환경
  GOOGLE_CLIENT_ID_DEV: ${{ secrets.GOOGLE_CLIENT_ID_DEV }}
  GOOGLE_REVERSED_CLIENT_ID_DEV: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_DEV }}
  KAKAO_NATIVE_APP_KEY_DEV: ${{ secrets.KAKAO_NATIVE_APP_KEY_DEV }}

  # Stage 환경 (선택)
  GOOGLE_CLIENT_ID_STAGE: ${{ secrets.GOOGLE_CLIENT_ID_STAGE }}
  # ... (Stage 환경 나머지 키들)

  # Prod 환경 (선택)
  GOOGLE_CLIENT_ID_PROD: ${{ secrets.GOOGLE_CLIENT_ID_PROD }}
  # ... (Prod 환경 나머지 키들)
```

### 빌드 타겟

PR 체크에서는 **PromisoDev** 타겟만 빌드합니다.

```bash
tuist build PromisoDev -- \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -skipPackagePluginValidation
```

### 테스트 결과 업로드

테스트 실패 시 다음 파일들이 아티팩트로 업로드됩니다.

- `**/*.xcresult` - Xcode 테스트 결과
- `**/test_output/` - Fastlane 테스트 출력

### PR 코멘트 예시

```
✅ PR 체크 성공

**빌드**: 성공
**테스트**: 통과

<details>
<summary>상세 정보</summary>

- Workflow: PR Check
- Branch: feature/notification
- Commit: abc123d

</details>
```

---

## 2. Deploy iOS 워크플로우

### 목적
Stage 또는 Production 환경의 iOS 앱을 TestFlight에 배포합니다.

### 트리거 (수동)

GitHub Actions 페이지에서 **Actions** → **Deploy iOS** → **Run workflow**

**입력 파라미터:**

| 파라미터 | 설명 | 옵션 | 필수 |
|----------|------|------|------|
| `environment` | 배포 환경 | `stage` / `prod` | ✅ |
| `changelog` | TestFlight 수정사항 (Release notes) | 텍스트 | ✅ |

### 실행 단계

```
1. Setup Job (환경 결정)
   ├─ Stage: fastlane beta_stage
   └─ Prod: fastlane beta_prod
   ↓
2. 체크아웃 및 환경 설정
   - Xcode, Tuist, Ruby 설정
   - Tuist 캐시
   ↓
3. xcconfig 파일 생성 (환경별)
   - Stage: GOOGLE_CLIENT_ID_STAGE 등
   - Prod: GOOGLE_CLIENT_ID_PROD 등
   ↓
4. Firebase plist 파일 복사 (환경별)
   ↓
5. App Store Connect API Key 설정
   - ~/private_keys/AuthKey_*.p8
   ↓
6. 프로젝트 생성 (tuist install & generate)
   ↓
7. Fastlane 배포
   - match (인증서/프로비저닝 프로파일)
   - increment_build_number (빌드 번호 자동 증가)
   - build_app (Xcode 빌드)
   - upload_to_testflight (TestFlight 업로드)
   - Slack 알림
   ↓
8. 빌드 아티팩트 업로드 (실패 시)
```

### 환경별 차이점

#### Stage 환경

```ruby
lane :beta_stage do
  match(app_identifier: "com.promiso.stage")
  build_app(scheme: "PromisoStage")
  upload_to_testflight(
    app_identifier: "com.promiso.stage",
    distribute_external: true,
    groups: ["Stage Testers"],
    notify_external_testers: true
  )
end
```

- **Bundle ID**: `com.promiso.stage`
- **Scheme**: `PromisoStage`
- **TestFlight 그룹**: `Stage Testers`
- **외부 테스터 알림**: ✅ (자동)
- **목적**: QA 테스트

#### Production 환경

```ruby
lane :beta_prod do
  match(app_identifier: "com.promiso")
  build_app(scheme: "Promiso")
  upload_to_testflight(
    app_identifier: "com.promiso",
    skip_waiting_for_build_processing: false,
    distribute_external: true,
    groups: ["Production Testers"],
    notify_external_testers: true
  )
end
```

- **Bundle ID**: `com.promiso`
- **Scheme**: `Promiso`
- **TestFlight 그룹**: `Production Testers`
- **외부 테스터 알림**: ✅ (자동)
- **목적**: App Store 출시 전 최종 테스트

### 필수 Secrets

#### iOS 빌드 & 배포

```bash
# App Store Connect API (Fastlane 인증)
APP_STORE_CONNECT_API_KEY_ID       # API Key ID
APP_STORE_CONNECT_API_ISSUER_ID    # Issuer ID
APP_STORE_CONNECT_API_KEY          # .p8 파일 (base64 인코딩)

# Fastlane Match (코드 서명)
MATCH_PASSWORD                     # Match 암호화 비밀번호

# Apple 계정
FASTLANE_USER                      # Apple ID (이메일)
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD  # 앱 전용 비밀번호

# Stage 환경 API 키
GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE
GOOGLE_SERVICE_INFO_STAGE          # GoogleService-Info.plist (base64)

# Production 환경 API 키
GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
GOOGLE_SERVICE_INFO_PROD           # GoogleService-Info.plist (base64)

# Slack (선택)
SLACK_WEBHOOK_URL_DEPLOY           # iOS 배포 Slack 알림
```

### 동시성 제어

같은 환경에 대한 배포는 동시에 실행되지 않습니다.

```yaml
concurrency:
  group: ios-${{ github.event.inputs.environment }}
  cancel-in-progress: false  # 실행 중인 배포는 취소하지 않음
```

### 배포 환경 (GitHub Environments)

- **Stage**: `staging` 환경
- **Prod**: `production` 환경 (App Store URL 포함)

---

## 3. Deploy Firebase 워크플로우

### 목적
Firebase Functions, Firestore Rules, Storage Rules를 Stage 또는 Production 환경에 수동 배포합니다.

### 트리거 (수동)

GitHub Actions 페이지에서 **Actions** → **Deploy Firebase** → **Run workflow**

**입력 파라미터:**

| 파라미터 | 설명 | 옵션 | 필수 |
|----------|------|------|------|
| `environment` | 배포 환경 | `stage` / `prod` | ✅ |

### 실행 단계

```
1. Setup Job (환경 결정)
   ├─ Stage: promiso-stage
   └─ Prod: promiso-prod
   ↓
2. 체크아웃 및 환경 설정
   - Node.js 24 설정
   - npm 캐시
   ↓
3. Functions 의존성 설치
   - npm ci
   ↓
4. Lint 및 빌드
   - npm run lint
   - npm run build
   ↓
5. Firebase 배포
   ├─ Functions 배포 (firebase deploy --only functions)
   ├─ Firestore Rules 배포 (firebase deploy --only firestore:rules)
   └─ Storage Rules 배포 (firebase deploy --only storage)
   ↓
6. Slack 알림 (성공/실패)
```

### 환경별 Firebase 프로젝트

| 환경 | Firebase Project ID | GitHub Environment |
|------|---------------------|-------------------|
| Stage | `promiso-stage` | `staging` |
| Production | `promiso-prod` | `production` |

### 필수 Secrets

```bash
# Firebase CLI 토큰
FIREBASE_TOKEN

# Slack (선택)
SLACK_WEBHOOK_URL
```

### 배포 대상

#### 1. Functions

```bash
firebase use $environment
firebase deploy --only functions --token "$FIREBASE_TOKEN" --non-interactive
```

#### 2. Firestore Rules

```bash
firebase deploy --only firestore:rules --token "$FIREBASE_TOKEN" --non-interactive
```

#### 3. Storage Rules

```bash
firebase deploy --only storage --token "$FIREBASE_TOKEN" --non-interactive
```

### 동시성 제어

같은 환경에 대한 배포는 동시에 실행되지 않습니다.

```yaml
concurrency:
  group: firebase-${{ github.event.inputs.environment }}
  cancel-in-progress: false  # 실행 중인 배포는 취소하지 않음
```

### Slack 알림 예시

```
🟡 Firebase Stage 배포 성공
- Functions: ✅
- Firestore Rules: ✅
- Storage Rules: ✅
(QA 환경 준비 완료)
```

---

## 4. Deploy Firebase Stage (Auto) 워크플로우

### 목적
`release/**` 브랜치에서 Firebase 관련 변경이 푸시되면 Stage 환경에 자동 배포합니다.

### 트리거 (자동)

```yaml
on:
  push:
    branches:
      - 'release/**'
    paths:
      - 'infra/firebase/**'
      - '.github/workflows/deploy-firebase-stage-auto.yml'
```

### 실행 단계

```
1. 체크아웃 및 Node.js 설정
2. Functions 의존성 설치 (npm ci)
3. Lint / Test(if exists) / Build
4. Stage 배포
   ├─ functions
   ├─ firestore:rules
   └─ storage
5. Slack 알림 (성공/실패)
```

### 필수 Secrets

```bash
FIREBASE_TOKEN
SLACK_WEBHOOK_URL_DEPLOY
```

### 주의사항

- 이 워크플로우는 Stage 전용입니다.
- 자동 트리거 조건은 `release/**` + Firebase 경로 변경입니다.

---

## 5. Gemini Review Slack 워크플로우

### 목적
Gemini Code Assist 봇이 PR에 리뷰를 남기면 Slack으로 알림을 보냅니다.

### 트리거

```yaml
on:
  pull_request_review:
    types: [submitted]
```

### 조건

Gemini 봇의 리뷰만 알림

```yaml
if: github.event.review.user.login == 'gemini-code-assist[bot]'
```

### Slack 메시지 예시

```
🤖 Gemini Code Assist 리뷰가 등록되었습니다

PR: #42 알림 설정 Feature 추가
Author: sungwon-kim
Link: https://github.com/.../pull/42#discussion_r123
```

---

## 6. 로컬에서 테스트하기

### PR Check 워크플로우 재현

```bash
# 1. 환경변수 설정 (.env 파일)
cat > .env <<EOF
GOOGLE_CLIENT_ID_DEV=your_dev_client_id
GOOGLE_REVERSED_CLIENT_ID_DEV=com.googleusercontent.apps.xxx
KAKAO_NATIVE_APP_KEY_DEV=your_kakao_key
KAKAO_REST_API_KEY_DEV=your_kakao_rest_key
# ... (Stage, Prod 환경도 동일)
EOF

# 2. xcconfig 파일 생성
./scripts/generate-xcconfig.sh

# 3. Firebase plist 파일 복사
cp ~/Downloads/GoogleService-Info-Dev.plist Projects/App/Resources-Dev/GoogleService-Info.plist
cp ~/Downloads/GoogleService-Info-Stage.plist Projects/App/Resources-Stage/GoogleService-Info.plist
cp ~/Downloads/GoogleService-Info-Prod.plist Projects/App/Resources-Prod/GoogleService-Info.plist

# 4. 프로젝트 생성
tuist install
tuist generate --no-open

# 5. 빌드
tuist build PromisoDev -- \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -skipPackagePluginValidation

# 6. 테스트
tuist test -- \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
  -skipPackagePluginValidation
```

### Deploy iOS 워크플로우 재현 (Fastlane)

```bash
# 1. 환경변수 설정
export MATCH_PASSWORD="your_match_password"
export FASTLANE_USER="your_apple_id@example.com"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export CHANGELOG="로컬에서 테스트 빌드"

# Stage 환경 키 설정
export GOOGLE_CLIENT_ID_STAGE="..."
export GOOGLE_REVERSED_CLIENT_ID_STAGE="..."
export KAKAO_NATIVE_APP_KEY_STAGE="..."
export KAKAO_REST_API_KEY_STAGE="..."

# 2. xcconfig 파일 생성 (Stage만)
TARGET_ENV=stage ./scripts/generate-xcconfig.sh

# 3. Firebase plist 복사
cp ~/Downloads/GoogleService-Info-Stage.plist Projects/App/Resources-Stage/GoogleService-Info.plist

# 4. App Store Connect API Key 설정
mkdir -p ~/private_keys
cp ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/private_keys/

# 5. 프로젝트 생성
TUIST_ENV=stage tuist generate --no-open

# 6. Fastlane 배포 (Stage)
bundle install
bundle exec fastlane beta_stage
```

### Deploy Firebase 워크플로우 재현

```bash
# 1. Functions 디렉토리로 이동
cd infra/firebase/functions

# 2. 의존성 설치
npm ci

# 3. Lint & 빌드
npm run lint
npm run build

# 4. Firebase 환경 전환 (Stage)
cd ..
firebase use stage

# 5. 배포
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only storage

# Production 배포
firebase use prod
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only storage
```

---

## 7. 문제 해결

### PR Check 빌드 실패

#### 문제: xcconfig 파일 생성 실패

```
❌ 환경변수 GOOGLE_CLIENT_ID_DEV 가 설정되지 않았습니다.
```

**해결:**
1. GitHub Secrets에 모든 필수 환경변수가 설정되어 있는지 확인
2. Secret 이름이 정확한지 확인 (대소문자 구분)

#### 문제: Firebase plist 파일 누락

```
error: GoogleService-Info.plist not found
```

**해결:**
1. GitHub Secrets에 `GOOGLE_SERVICE_INFO_DEV` (base64 인코딩) 확인
2. base64 디코딩 명령어 확인

```bash
# 로컬에서 테스트
echo "$GOOGLE_SERVICE_INFO_DEV" | base64 --decode > test.plist
cat test.plist  # 유효한 XML인지 확인
```

#### 문제: Tuist 빌드 실패

```
error: The sandbox is not in sync with the Podfile.lock
```

**해결:**
1. `tuist clean` 실행 후 다시 빌드
2. GitHub Actions에서 캐시 제거 후 재실행

### Deploy iOS 빌드 실패

#### 문제: Fastlane Match 인증 실패

```
error: Failed to clone certificates repo
```

**해결:**
1. `MATCH_PASSWORD` Secret 확인
2. Match Git 레포지토리 접근 권한 확인
3. 로컬에서 테스트:

```bash
bundle exec fastlane match appstore --readonly
```

#### 문제: App Store Connect API 인증 실패

```
error: Could not authenticate with App Store Connect
```

**해결:**
1. `APP_STORE_CONNECT_API_KEY_ID` Secret 확인
2. `APP_STORE_CONNECT_API_ISSUER_ID` Secret 확인
3. `.p8` 파일이 올바르게 base64 인코딩되었는지 확인

```bash
# .p8 파일을 base64로 인코딩
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
# GitHub Secrets에 붙여넣기
```

#### 문제: 빌드 번호 증가 실패

```
error: Could not find a build on TestFlight
```

**해결:**
- 첫 배포인 경우 수동으로 빌드 번호 설정:

```ruby
# fastlane/Fastfile
increment_build_number(
  build_number: 1  # 첫 배포는 1로 고정
)
```

### Deploy Firebase 빌드 실패

#### 문제: Functions Lint 실패

```
error: Unexpected console statement  no-console
```

**해결:**
1. `console.log()` 제거 또는 주석 처리
2. 또는 `.eslintrc.js`에서 규칙 완화:

```javascript
rules: {
  'no-console': 'warn'  // error → warn으로 변경
}
```

#### 문제: Firebase 인증 실패

```
error: Failed to authenticate, invalid token
```

**해결:**
1. `FIREBASE_TOKEN` Secret 재생성:

```bash
firebase login:ci
# 출력된 토큰을 GitHub Secrets에 저장
```

#### 문제: Firestore Rules 배포 실패

```
error: Invalid security rules
```

**해결:**
1. 로컬에서 규칙 검증:

```bash
firebase deploy --only firestore:rules --debug
```

2. Firebase Console에서 수동으로 규칙 테스트

### 일반적인 문제

#### 문제: 타임아웃

```
error: The job running on runner macos-15 has exceeded the maximum execution time of 45 minutes
```

**해결:**
1. `timeout-minutes` 값 증가 (최대 360분)
2. Tuist 캐시가 제대로 작동하는지 확인
3. 불필요한 빌드 단계 제거

#### 문제: 동시성 충돌

```
Canceling since a higher priority waiting request for 'ios-stage' exists
```

**해결:**
- `cancel-in-progress: true`인 워크플로우에서 발생할 수 있는 메시지입니다.
- 현재 `Deploy iOS`/`Deploy Firebase`는 `cancel-in-progress: false`이므로 동일 환경 요청은 취소되지 않고 대기합니다.

---

## 8. 워크플로우 커스터마이징

### PR Check 워크플로우 수정

#### 다른 브랜치에서도 PR 체크 실행

```yaml
on:
  pull_request:
    branches: [main, develop]  # develop 브랜치 추가
```

#### 특정 경로 변경 시에만 실행

```yaml
on:
  pull_request:
    branches: [main]
    paths:
      - 'Projects/**'
      - 'Tuist/**'
      - '.github/workflows/pr-check.yml'
```

#### 다른 시뮬레이터 사용

```yaml
- name: Build PromisoDev
  run: |
    tuist build PromisoDev -- \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
      -skipPackagePluginValidation
```

### Deploy iOS 워크플로우 수정

#### Dev 환경 배포 추가

**Fastfile:**

```ruby
lane :beta_dev do
  setup_ci if ENV["CI"]

  match(app_identifier: "com.promiso.dev")

  increment_build_number(
    build_number: latest_testflight_build_number(
      app_identifier: "com.promiso.dev"
    ) + 1
  )

  build_app(
    scheme: "PromisoDev",
    configuration: "Release"
  )

  upload_to_testflight(
    app_identifier: "com.promiso.dev",
    distribute_external: false,
    changelog: ENV["CHANGELOG"] || "Dev build"
  )
end
```

**deploy-ios.yml:**

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options:
          - dev      # 추가
          - stage
          - prod
```

**setup job:**

```yaml
case "$ENV" in
  dev)
    FASTLANE_LANE="beta_dev"
    EMOJI="🔵"
    ENV_LABEL="Development"
    GITHUB_ENV="development"
    ;;
  # ... (stage, prod)
esac
```

#### 자동 배포 (브랜치 푸시 시)

```yaml
on:
  push:
    branches:
      - release/stage  # release/stage 브랜치 푸시 시 Stage 배포
      - release/prod   # release/prod 브랜치 푸시 시 Prod 배포
```

### Deploy Firebase 워크플로우 수정

#### Dev 환경 추가

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        options:
          - dev      # 추가
          - stage
          - prod
```

#### 특정 서비스만 배포

```yaml
on:
  workflow_dispatch:
    inputs:
      environment: ...
      targets:
        description: 'Deployment targets (functions, firestore:rules, storage)'
        required: false
        default: 'functions,firestore:rules,storage'
```

**배포 단계 수정:**

```yaml
- name: Deploy Firebase
  run: |
    firebase use ${{ needs.setup.outputs.environment }}
    firebase deploy --only ${{ github.event.inputs.targets }} --token "$FIREBASE_TOKEN"
```

---

## 9. GitHub Actions 사용 팁

### Secrets 관리

```bash
# Secrets 설정 경로
GitHub Repository → Settings → Secrets and variables → Actions

# Environment Secrets (환경별 분리)
Settings → Environments → [staging/production] → Add secret
```

### 워크플로우 디버깅

```yaml
- name: Debug Environment
  run: |
    echo "GitHub Event: ${{ github.event_name }}"
    echo "Branch: ${{ github.ref }}"
    echo "Environment: ${{ github.event.inputs.environment }}"
    env
```

### 재사용 가능한 워크플로우

공통 단계를 재사용 가능한 워크플로우로 분리:

**.github/workflows/reusable-build.yml:**

```yaml
name: Reusable Build

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string

jobs:
  build:
    runs-on: macos-15
    steps:
      # ... (공통 빌드 단계)
```

**사용:**

```yaml
jobs:
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: stage
```

### 수동 승인 추가

```yaml
deploy:
  needs: build
  runs-on: ubuntu-latest
  environment:
    name: production  # GitHub Environment에서 수동 승인 설정
```

**GitHub에서 설정:**
1. Settings → Environments → production
2. **Required reviewers** 체크
3. 승인자 추가

---

## 10. 참고 자료

- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [Fastlane 문서](https://docs.fastlane.tools)
- [Tuist 문서](https://docs.tuist.io)
- [Firebase CLI 문서](https://firebase.google.com/docs/cli)

### 관련 문서

- [DEPLOYMENT.md](DEPLOYMENT.md) - 배포/시크릿 운영 기준
- [ENVIRONMENT.md](ENVIRONMENT.md) - 환경별 설정 가이드
- [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) - 브랜치 전략

---

**마지막 업데이트**: 2026-02-06
