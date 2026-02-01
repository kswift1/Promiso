# 배포 가이드 (Deployment Guide)

Promiso iOS 앱 및 Firebase 백엔드의 자동/수동 배포 전체 가이드입니다.

## 📋 목차

1. [개요](#개요)
2. [초기 설정](#초기-설정)
   - [Fastlane Match 설정](#fastlane-match-설정)
   - [GitHub Secrets 설정](#github-secrets-설정)
3. [iOS TestFlight 배포](#ios-testflight-배포)
   - [자동 배포 (CI/CD)](#자동-배포-cicd)
   - [수동 배포 (로컬)](#수동-배포-로컬)
4. [Firebase 배포](#firebase-배포)
   - [Functions 배포](#functions-배포)
   - [Security Rules 배포](#security-rules-배포)
5. [문제 해결](#문제-해결)
6. [베스트 프랙티스](#베스트-프랙티스)

---

## 개요

### 배포 환경

Promiso는 3개의 배포 환경을 지원합니다:

| 환경 | Bundle ID | Firebase Project | TestFlight Track | 용도 |
|------|-----------|------------------|------------------|------|
| **Dev** | `com.promiso.dev` | `promiso-dev` | Internal Only | 개발 테스트 (자동 배포 없음) |
| **Stage** | `com.promiso.stage` | `promiso-stage` | Stage Testers | QA 및 통합 테스트 |
| **Production** | `com.promiso` | `promiso-prod` | Production Testers | 프로덕션, App Store 제출 |

### 배포 도구

- **Fastlane**: iOS 앱 빌드 및 TestFlight 업로드 자동화
- **Fastlane Match**: 코드 사이닝 인증서 관리
- **GitHub Actions**: CI/CD 자동화
- **Firebase CLI**: Firebase Functions, Firestore Rules, Storage Rules 배포

---

## 초기 설정

### 전제 조건

1. **Apple Developer Program** 멤버십 (년간 $99)
2. **App Store Connect** 접근 권한
3. **GitHub** Private 저장소 접근 권한
4. **Firebase** 프로젝트 소유자/편집자 권한

### Fastlane Match 설정

Match는 팀원 간 인증서/프로비저닝 프로파일을 Git 저장소에 암호화하여 공유하는 도구입니다.

#### 1. Fastlane 설치

```bash
# Homebrew로 설치 (권장)
brew install fastlane

# 또는 Bundler 사용
bundle install
```

#### 2. Apple Developer 정보 확인

**Apple ID**:
```
App Store Connect에 로그인하는 Apple ID
예: yourname@example.com
```

**Team ID 확인**:
```bash
# Apple Developer Portal에서 확인
# https://developer.apple.com/account

# 또는 명령어로 확인
fastlane fastlane-credentials check

# Team ID 예시: A1B2C3D4E5
```

#### 3. Private Git 저장소 생성

**GitHub에서 새 Private 레포지토리 생성**:

```
레포지토리 이름: promiso-certificates
설정: Private ✅
README 추가: 체크 해제
```

**주소 예시**:
```
https://github.com/kswift1/promiso-certificates
```

#### 4. Appfile 및 Matchfile 수정

**`fastlane/Appfile` 편집**:
```ruby
# ← 실제 정보로 변경
apple_id("your-apple-id@example.com")
team_id("YOUR_TEAM_ID")
itc_team_id("YOUR_ITC_TEAM_ID") # 선택 (팀이 여러 개인 경우)
```

**`fastlane/Matchfile` 편집**:
```ruby
# ← 실제 정보로 변경
git_url("https://github.com/kswift1/promiso-certificates")
username("your-apple-id@example.com")
team_id("YOUR_TEAM_ID")
```

#### 5. Match 초기화

```bash
cd /path/to/Promiso

# Match 초기화 및 인증서 생성
fastlane match init

# App Store용 인증서/프로파일 생성
fastlane match appstore
```

**실행 중 입력 항목**:

1. **Passphrase**: 강력한 비밀번호 입력 (저장 필수!)
   ```
   예: ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b
   ```

2. **App Identifier 선택**:
   ```
   1. com.promiso.dev
   2. com.promiso.stage
   3. com.promiso
   ```

3. **Apple ID 인증**: Apple ID 비밀번호 입력

#### 6. 생성 확인

**promiso-certificates 저장소 확인**:
```
promiso-certificates/
├── certs/
│   ├── distribution/
│   │   └── A1B2C3D4E5.cer
├── profiles/
│   └── appstore/
│       ├── AppStore_com.promiso.dev.mobileprovision
│       ├── AppStore_com.promiso.stage.mobileprovision
│       └── AppStore_com.promiso.mobileprovision
└── README.md
```

#### 7. CI/CD용 Git 인증 설정

**방법 1: Deploy Key (권장)**

```bash
# SSH 키 생성
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/promiso_match_deploy_key

# Public 키 복사
cat ~/.ssh/promiso_match_deploy_key.pub

# GitHub → promiso-certificates → Settings → Deploy keys
# - Title: GitHub Actions
# - Key: (위 public 키 붙여넣기)
# - Allow write access: ✅
```

**Private 키를 GitHub Secrets에 등록**:
```bash
# Private 키 복사
cat ~/.ssh/promiso_match_deploy_key

# GitHub → promiso (메인 레포) → Secrets
Name:  MATCH_DEPLOY_KEY
Value: (Private 키 전체 내용)
```

**Matchfile 수정** (SSH URL 사용):
```ruby
git_url("git@github.com:kswift1/promiso-certificates.git") # HTTPS → SSH
```

**방법 2: Personal Access Token**

```bash
# GitHub → Settings → Developer settings → Personal access tokens
# - repo (전체 체크)
# - Generate token

# Base64 인코딩
echo -n "username:ghp_XXXXXXXXXXXX" | base64

# GitHub Secrets 등록
Name:  MATCH_GIT_BASIC_AUTHORIZATION
Value: (Base64 인코딩된 값)
```

---

### GitHub Secrets 설정

총 **20개의 필수 Secrets**를 등록해야 합니다.

#### Secrets 등록 방법

1. GitHub 레포지토리 → **Settings**
2. **Secrets and variables** → **Actions**
3. **New repository secret** 클릭
4. Name과 Value 입력 후 **Add secret**

#### 필수 Secrets 목록 (20개)

##### 1. iOS 빌드 Secrets (12개)

**Dev 환경 (4개)**:

```bash
# Config/Dev.xcconfig에서 값 확인
cat Config/Dev.xcconfig
```

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_DEV` | `306291841913-08gm6rkpklh6k7qqfim1bkc92uji6bcg.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_DEV` | `com.googleusercontent.apps.306291841913-08gm6rkpklh6k7qqfim1bkc92uji6bcg` |
| `KAKAO_NATIVE_APP_KEY_DEV` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_DEV` | `eacdef419fafb30e112e6ca22219ee4d` |

**Stage 환경 (4개)**:

```bash
cat Config/Stage.xcconfig
```

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_STAGE` | `511041416523-bek4g2m6qojqcoecd17mvft1kvn7vogt.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_STAGE` | `com.googleusercontent.apps.511041416523-bek4g2m6qojqcoecd17mvft1kvn7vogt` |
| `KAKAO_NATIVE_APP_KEY_STAGE` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_STAGE` | `eacdef419fafb30e112e6ca22219ee4d` |

**Prod 환경 (4개)**:

```bash
cat Config/Prod.xcconfig
```

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_PROD` | `367716701610-efrvms6v48eldljh34falbhclkvsrqvt.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_PROD` | `com.googleusercontent.apps.367716701610-efrvms6v48eldljh34falbhclkvsrqvt` |
| `KAKAO_NATIVE_APP_KEY_PROD` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_PROD` | `eacdef419fafb30e112e6ca22219ee4d` |

##### 2. Firebase plist Secrets (3개)

**Base64 인코딩**:

```bash
# Dev
base64 -i Config/GoogleService-Info-Dev.plist | pbcopy
# → GitHub Secret: GOOGLE_SERVICE_INFO_DEV에 붙여넣기

# Stage
base64 -i Config/GoogleService-Info-Stage.plist | pbcopy
# → GitHub Secret: GOOGLE_SERVICE_INFO_STAGE에 붙여넣기

# Prod
base64 -i Config/GoogleService-Info-Prod.plist | pbcopy
# → GitHub Secret: GOOGLE_SERVICE_INFO_PROD에 붙여넣기
```

| Name | Value |
|------|-------|
| `GOOGLE_SERVICE_INFO_DEV` | (Base64 인코딩된 plist) |
| `GOOGLE_SERVICE_INFO_STAGE` | (Base64 인코딩된 plist) |
| `GOOGLE_SERVICE_INFO_PROD` | (Base64 인코딩된 plist) |

##### 3. Fastlane Match Secrets (1개)

**Match Password 생성**:

```bash
# 강력한 비밀번호 생성
openssl rand -base64 32
# 출력: ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b
```

| Name | Value |
|------|-------|
| `MATCH_PASSWORD` | `ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b` (위에서 설정한 비밀번호) |

##### 4. App Store Connect Secrets (3개)

**API Key 생성**:

1. **App Store Connect** 접속: https://appstoreconnect.apple.com/
2. **Users and Access** → **Integrations** → **App Store Connect API**
3. **Generate API Key**
   - Name: `GitHub Actions`
   - Access: `App Manager` (권한)
4. **Key ID**, **Issuer ID**, **Download API Key (.p8)** 저장

**Secrets 등록**:

```bash
# API Key를 Base64로 인코딩
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy
```

| Name | Value |
|------|-------|
| `APP_STORE_CONNECT_API_KEY_ID` | `ABC123XYZ` (Key ID) |
| `APP_STORE_CONNECT_API_ISSUER_ID` | `12345678-1234-1234-1234-123456789012` (Issuer ID) |
| `APP_STORE_CONNECT_API_KEY` | (Base64 인코딩된 .p8 내용) |

##### 5. Firebase 배포 Secrets (1개)

**Firebase Token 생성**:

```bash
# Firebase CLI 로그인
firebase login:ci

# 출력:
# ✔  Success! Use this token to login on a CI server:
#
# 1//0gABC123...XYZ (매우 긴 토큰)
```

| Name | Value |
|------|-------|
| `FIREBASE_TOKEN` | `1//0gABC123...XYZ` (위에서 생성한 토큰) |

##### 6. 선택 사항 (Slack 알림 등)

| Name | Value | 용도 |
|------|-------|------|
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/...` | Slack 알림 (선택) |

---

## iOS TestFlight 배포

### 자동 배포 (CI/CD)

GitHub Actions를 통해 자동으로 TestFlight에 배포합니다.

#### 워크플로우 트리거

**`.github/workflows/deploy-ios.yml`** 워크플로우는 **수동 트리거**만 지원합니다:

```bash
# GitHub Actions 탭에서 "Deploy iOS" 워크플로우 선택
# → "Run workflow" 클릭
# → Environment 선택 (stage 또는 prod)
# → Changelog 입력
# → "Run workflow" 실행
```

#### 배포 과정

자동 배포 워크플로우는 다음 단계를 수행합니다:

```
1. 환경 설정 (Xcode, Tuist, Ruby)
2. xcconfig 파일 생성 (환경별)
3. Firebase plist 파일 복사 (환경별)
4. App Store Connect API Key 설정
5. 프로젝트 생성 (tuist generate)
6. Fastlane 실행 (beta_stage 또는 beta_prod)
   ├─ Match로 인증서/프로파일 다운로드
   ├─ 빌드 번호 자동 증가
   ├─ Archive 및 Export
   └─ TestFlight 업로드
7. 빌드 아티팩트 업로드 (실패 시)
```

**예상 시간**: 15-25분

#### Stage 배포

**브랜치**: `staging`

```bash
# GitHub Actions 탭
# → "Deploy iOS" 워크플로우
# → "Run workflow"
# → Environment: stage
# → Changelog: "Stage 빌드 - QA 테스트용"
# → "Run workflow" 클릭
```

**TestFlight 설정**:
- 배포 대상: `Stage Testers` 그룹
- 외부 테스터 알림: ✅
- 자동 심사 제출: ✅

#### Production 배포

**브랜치**: `main`

```bash
# GitHub Actions 탭
# → "Deploy iOS" 워크플로우
# → "Run workflow"
# → Environment: prod
# → Changelog: "v1.2.0 - 새 기능 추가"
# → "Run workflow" 클릭
```

**TestFlight 설정**:
- 배포 대상: `Production Testers` 그룹
- 외부 테스터 알림: ✅
- App Store 제출 대기

---

### 수동 배포 (로컬)

로컬 Mac에서 Fastlane을 사용해 수동으로 배포할 수 있습니다.

#### 사전 준비

```bash
# 1. Fastlane 설치
brew install fastlane

# 또는 Bundler 사용
bundle install

# 2. Match로 인증서 동기화 (최초 1회)
fastlane match appstore --readonly

# 3. MATCH_PASSWORD 환경변수 설정
export MATCH_PASSWORD="ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b"
```

#### Dev 환경 배포 (내부 테스트)

```bash
# PromisoDev → TestFlight (Dev Track)
fastlane beta_dev
```

**실행 과정**:
1. Match에서 인증서/프로파일 다운로드
2. 빌드 번호 자동 증가
3. Archive 및 Export
4. TestFlight 업로드 (내부 테스터만)

**예상 시간**: 5-10분

#### Stage 환경 배포 (QA)

```bash
# PromisoStage → TestFlight (Stage Track)
fastlane beta_stage
```

**실행 과정**:
1. Match에서 인증서/프로파일 다운로드
2. 빌드 번호 자동 증가
3. Archive 및 Export
4. TestFlight 업로드
5. `Stage Testers` 그룹에 알림

**예상 시간**: 5-10분

#### Production 환경 배포 (출시)

```bash
# Promiso → TestFlight (Prod Track)
fastlane beta_prod
```

**실행 과정**:
1. Match에서 인증서/프로파일 다운로드
2. 빌드 번호 자동 증가
3. Archive 및 Export
4. TestFlight 업로드
5. `Production Testers` 그룹에 알림
6. App Store 제출 준비 완료

**예상 시간**: 5-10분

#### App Store 심사 제출 (수동)

```bash
# TestFlight → App Store 심사 제출
fastlane release
```

**주의**: 이 명령어는 TestFlight에서 최신 빌드를 App Store 심사에 제출합니다. 신중하게 실행하세요.

---

## Firebase 배포

### 자동 배포 (CI/CD)

GitHub Actions를 통해 자동으로 Firebase에 배포합니다.

#### 워크플로우 트리거

**`.github/workflows/deploy-firebase.yml`** 워크플로우는 **수동 트리거**만 지원합니다:

```bash
# GitHub Actions 탭에서 "Deploy Firebase" 워크플로우 선택
# → "Run workflow" 클릭
# → Environment 선택 (stage 또는 prod)
# → "Run workflow" 실행
```

#### 배포 과정

```
1. 환경 설정 (Node.js)
2. Functions 의존성 설치 (npm ci)
3. Lint 검사 (npm run lint)
4. Functions 빌드 (npm run build)
5. Firebase 배포
   ├─ Hosting 배포
   ├─ Functions 배포
   ├─ Firestore Rules 배포
   └─ Storage Rules 배포
6. Slack 알림
```

**예상 시간**: 5-10분

#### Stage 배포

```bash
# GitHub Actions 탭
# → "Deploy Firebase" 워크플로우
# → "Run workflow"
# → Environment: stage
# → "Run workflow" 클릭
```

**배포 대상**:
- Firebase Project: `promiso-stage`
- Functions, Firestore Rules, Storage Rules

#### Production 배포

```bash
# GitHub Actions 탭
# → "Deploy Firebase" 워크플로우
# → "Run workflow"
# → Environment: prod
# → "Run workflow" 클릭
```

**배포 대상**:
- Firebase Project: `promiso-prod`
- Functions, Firestore Rules, Storage Rules

---

### 수동 배포 (로컬)

로컬에서 Firebase CLI를 사용해 수동으로 배포할 수 있습니다.

#### 사전 준비

```bash
# 1. Firebase CLI 설치
npm install -g firebase-tools

# 2. Firebase 로그인
firebase login

# 3. 프로젝트 디렉토리로 이동
cd infra/firebase
```

#### Functions 배포

**Dev 환경**:
```bash
cd infra/firebase

# 환경 선택
firebase use dev

# Functions 의존성 설치
cd functions
npm install
npm run build
cd ..

# Functions 배포
firebase deploy --only functions
```

**Stage 환경**:
```bash
firebase use stage
firebase deploy --only functions
```

**Production 환경**:
```bash
firebase use prod
firebase deploy --only functions
```

**예상 시간**: 2-5분

#### Security Rules 배포

**Firestore Rules**:
```bash
cd infra/firebase

# 환경 선택
firebase use stage

# Firestore Rules 배포
firebase deploy --only firestore:rules
```

**Storage Rules**:
```bash
# Storage Rules 배포
firebase deploy --only storage
```

**예상 시간**: 30초 - 1분

#### 전체 배포

```bash
# 모든 Firebase 서비스 동시 배포
firebase use stage
firebase deploy
```

**배포 대상**:
- Functions
- Firestore Rules
- Storage Rules
- Hosting (있는 경우)

**예상 시간**: 5-10분

---

## 문제 해결

### iOS 배포 문제

#### Q: "Could not decrypt the repo"

**A**: MATCH_PASSWORD가 틀림

```bash
# 환경변수로 설정
export MATCH_PASSWORD="your-password"
fastlane beta_dev
```

#### Q: "User credentials invalid"

**A**: App Store Connect API Key 사용 (권장)

```bash
# docs/GITHUB_SECRETS.md 참고
# 또는 2FA 인증
fastlane spaceauth -u your-apple-id@example.com
# 출력된 세션 값을 FASTLANE_SESSION 환경변수로 설정
```

#### Q: "No code signing identity found"

**A**: Match로 인증서 재생성

```bash
# 인증서 삭제 후 재생성
fastlane match nuke distribution
fastlane match appstore
```

#### Q: "Provisioning profile doesn't include signing certificate"

**A**: Match 저장소와 로컬 불일치

```bash
# Match 재동기화
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
fastlane match appstore --readonly
```

#### Q: "Build number already exists on TestFlight"

**A**: 빌드 번호 자동 증가 실패

```bash
# 수동으로 빌드 번호 증가
fastlane run increment_build_number build_number:123
```

#### Q: "Could not find action, lane or variable 'match'"

**A**: Fastlane이 설치되지 않음

```bash
bundle install
bundle exec fastlane beta_dev
```

---

### Firebase 배포 문제

#### Q: "Permission denied" (Functions 배포 실패)

**A**: Firebase Token 갱신 필요

```bash
# 새 토큰 생성
firebase login:ci

# GitHub Secrets에 새 토큰 등록
Name:  FIREBASE_TOKEN
Value: (새 토큰)
```

#### Q: "Invalid project" 에러

**A**: Firebase 프로젝트 선택 확인

```bash
# 현재 프로젝트 확인
firebase projects:list

# 올바른 프로젝트 선택
firebase use dev  # 또는 stage, prod
```

#### Q: Functions 빌드 실패

**A**: TypeScript 컴파일 에러 확인

```bash
cd infra/firebase/functions

# 의존성 재설치
rm -rf node_modules package-lock.json
npm install

# 빌드
npm run build
```

#### Q: Firestore Rules 검증 실패

**A**: Rules 문법 확인

```bash
# Rules 검증
firebase deploy --only firestore:rules --dry-run
```

---

### GitHub Actions 문제

#### Q: "Secret not found" 에러

**A**: Secret 이름 대소문자 확인

```yaml
# ❌ 틀림
${{ secrets.google_client_id_dev }}

# ✅ 맞음
${{ secrets.GOOGLE_CLIENT_ID_DEV }}
```

#### Q: Base64 디코딩 실패

**A**: 줄바꿈 제거 후 재인코딩

```bash
# 줄바꿈 없이 한 줄로 인코딩
base64 -i Config/GoogleService-Info-Dev.plist | tr -d '\n' | pbcopy
```

#### Q: Workflow가 실행되지 않음

**A**: 트리거 조건 확인

```yaml
# workflow_dispatch는 수동 실행만 가능
on:
  workflow_dispatch:
    inputs:
      environment:
        # ...
```

**해결**: GitHub Actions 탭에서 "Run workflow" 버튼 클릭

---

## 베스트 프랙티스

### iOS 배포

#### ✅ DO

- ✅ Match 저장소는 반드시 Private로 설정
- ✅ MATCH_PASSWORD는 강력한 무작위 문자열 사용 (32자 이상)
- ✅ App Store Connect API Key 사용 (2FA 문제 해결)
- ✅ CI/CD에서는 readonly 모드로 Match 사용
- ✅ 인증서 만료 시 `fastlane match renew` 실행
- ✅ 버전 번호 규칙 준수 (Semantic Versioning)
- ✅ TestFlight Changelog 작성 (사용자에게 변경사항 전달)

#### ❌ DON'T

- ❌ Match 저장소를 Public으로 설정하지 말 것
- ❌ 인증서를 수동으로 생성하지 말 것 (Match 사용)
- ❌ Xcode에서 "Automatically manage signing" 활성화 금지 (Match와 충돌)
- ❌ MATCH_PASSWORD를 코드에 하드코딩 금지
- ❌ 여러 Mac에서 동시에 `match appstore` 실행 금지
- ❌ Production 빌드를 테스트 없이 배포 금지

---

### Firebase 배포

#### ✅ DO

- ✅ 배포 전 로컬에서 Functions 테스트
- ✅ Firestore Rules 변경 시 dry-run으로 먼저 검증
- ✅ Stage 환경에서 충분히 테스트 후 Production 배포
- ✅ Functions 배포 후 로그 확인 (`firebase functions:log`)
- ✅ 중요한 변경사항은 점진적 배포 (canary deployment)

#### ❌ DON'T

- ❌ Production 환경에서 직접 테스트 금지
- ❌ 검증되지 않은 Rules를 Production에 배포 금지
- ❌ Functions 코드에 민감 정보 하드코딩 금지 (환경변수 사용)
- ❌ 배포 후 로그 확인 없이 방치 금지
- ❌ 모든 Functions를 동시에 배포 금지 (단계적 배포 권장)

---

### 보안 권장사항

#### ✅ DO

- ✅ 모든 민감 정보는 GitHub Secrets 사용
- ✅ Base64 인코딩으로 줄바꿈 문제 방지
- ✅ Match Password는 강력한 무작위 문자열 사용
- ✅ API Key는 최소 권한만 부여
- ✅ Secret 값은 절대 로그에 출력하지 않음
- ✅ Deploy Key에 쓰기 권한 최소화
- ✅ Firebase Token 정기 갱신 (3개월마다)

#### ❌ DON'T

- ❌ Secret 값을 코드에 하드코딩
- ❌ Secret 값을 PR 코멘트/이슈에 게시
- ❌ Match Password를 간단한 단어로 설정
- ❌ App Store Connect API Key에 Admin 권한 부여
- ❌ 디버깅 목적으로 Secret 출력
- ❌ Firebase Token을 Public 저장소에 커밋

---

## 체크리스트

### 초기 설정 체크리스트

- [ ] Fastlane 설치 (`brew install fastlane`)
- [ ] Appfile 수정 (Apple ID, Team ID)
- [ ] Matchfile 수정 (Git URL, Apple ID, Team ID)
- [ ] Private Git 저장소 생성 (promiso-certificates)
- [ ] `fastlane match appstore` 실행
- [ ] MATCH_PASSWORD 저장
- [ ] GitHub Secrets 등록 (20개)
  - [ ] iOS 빌드 Secrets (12개)
  - [ ] Firebase plist Secrets (3개)
  - [ ] Match Password (1개)
  - [ ] App Store Connect Secrets (3개)
  - [ ] Firebase Token (1개)
- [ ] Deploy Key 또는 Personal Access Token 설정
- [ ] Firebase CLI 설치 및 로그인

---

### 배포 전 체크리스트

#### iOS 배포

- [ ] `fastlane test` 통과 확인
- [ ] 빌드 번호 확인
- [ ] 버전 번호 확인 (CFBundleShortVersionString)
- [ ] TestFlight Changelog 작성
- [ ] 새 기능/버그 수정 테스트 완료
- [ ] UI 테스트 실행 (수동 또는 자동)
- [ ] Stage 환경에서 QA 완료 (Production 배포 시)

#### Firebase 배포

- [ ] Functions 로컬 테스트 완료
- [ ] Firestore Rules 검증 (`--dry-run`)
- [ ] Storage Rules 검증
- [ ] Stage 환경에서 충분히 테스트 완료
- [ ] 데이터 마이그레이션 필요 여부 확인
- [ ] Functions 로그 모니터링 준비

---

### 배포 후 체크리스트

#### iOS 배포

- [ ] TestFlight에서 빌드 확인
- [ ] 내부 테스터에게 알림
- [ ] 외부 테스터 그룹 지정 (Stage/Prod)
- [ ] 테스터 피드백 수집
- [ ] Crashlytics 에러 모니터링
- [ ] App Store Connect에서 빌드 상태 확인

#### Firebase 배포

- [ ] Functions 로그 확인 (`firebase functions:log`)
- [ ] Firestore 데이터 정합성 확인
- [ ] Storage 파일 업로드/다운로드 테스트
- [ ] Firebase Console에서 배포 상태 확인
- [ ] 에러 발생 시 즉시 롤백 준비

---

## 참고 문서

- [Fastlane 공식 문서](https://docs.fastlane.tools/)
- [Match 가이드](https://docs.fastlane.tools/actions/match/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Firebase CLI 문서](https://firebase.google.com/docs/cli)
- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [docs/FASTLANE_SETUP.md](FASTLANE_SETUP.md) - Fastlane 상세 설정
- [docs/GITHUB_SECRETS.md](GITHUB_SECRETS.md) - GitHub Secrets 상세 설정
- [docs/BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) - 브랜치 전략
- [docs/CI_CD.md](CI_CD.md) - GitHub Actions 워크플로우

---

## 버전 관리 및 릴리즈 노트

### 버전 번호 규칙

**Semantic Versioning** 사용:

```
MAJOR.MINOR.PATCH

예: 1.2.3
```

- **MAJOR**: 주요 기능 추가, 호환성 깨지는 변경
- **MINOR**: 새 기능 추가 (하위 호환)
- **PATCH**: 버그 수정, 사소한 개선

### 릴리즈 노트 작성

**TestFlight Changelog 예시**:

```markdown
## v1.2.0 (Stage)

### 새 기능
- 그룹 초대 기능 추가
- 프로필 사진 업로드 개선

### 버그 수정
- 알림 중복 표시 문제 해결
- 로그인 화면 깜빡임 수정

### 개선사항
- 앱 시작 속도 30% 개선
- UI 애니메이션 부드럽게 개선
```

**App Store 제출 시**:

```markdown
## v1.2.0 - 그룹 초대 및 성능 개선

이번 업데이트에서는 친구를 그룹에 초대할 수 있는 새로운 기능과
앱 성능 개선이 포함되어 있습니다.

### 새로운 기능
- 그룹 초대 링크 생성 및 공유
- 프로필 사진 업로드 및 편집

### 개선사항
- 앱 시작 속도 30% 향상
- UI 애니메이션 부드럽게 개선
- 알림 안정성 향상

버그 리포트 및 피드백은 support@promiso.app으로 보내주세요.
```

---

## 긴급 대응 (Rollback)

### iOS Rollback

**TestFlight 이전 빌드로 롤백**:

1. TestFlight → 빌드 목록
2. 이전 안정 버전 선택
3. `Production Testers` 그룹에 재배포

**App Store 긴급 업데이트**:

```bash
# 긴급 패치 빌드
fastlane beta_prod

# App Store Connect에서 심사 제출
# "긴급 심사 요청" 옵션 선택
```

### Firebase Rollback

**Functions 롤백**:

```bash
# 이전 버전으로 롤백
firebase functions:rollback --only functionName

# 또는 전체 롤백
firebase functions:rollback
```

**Firestore Rules 롤백**:

```bash
# Firebase Console → Firestore → Rules
# → 이전 버전 선택 → "Publish"
```

**예상 시간**: 5-10분

---

이 가이드를 통해 Promiso 앱을 안전하고 효율적으로 배포할 수 있습니다.
추가 질문이나 문제가 발생하면 팀원에게 문의하세요.
