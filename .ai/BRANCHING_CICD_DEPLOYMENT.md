# Promiso - 브랜치 전략, CI/CD, 배포 가이드

> **작성일**: 2026-02-06
> **대상**: iOS 앱 (Tuist + TCA) + Firebase 백엔드
> **환경**: Dev / Stage / Prod

---

## 목차

1. [브랜치 전략 (Git Flow 기반)](#1-브랜치-전략-git-flow-기반)
2. [CI/CD 파이프라인](#2-cicd-파이프라인)
3. [배포 프로세스](#3-배포-프로세스)
4. [환경별 설정](#4-환경별-설정)
5. [버전 관리](#5-버전-관리)
6. [롤백 전략](#6-롤백-전략)
7. [체크리스트](#7-체크리스트)

---

## 1. 브랜치 전략 (Git Flow 기반)

Promiso는 **Git Flow 변형** 전략을 사용합니다.

```
main
  └─ release/v1.0.0
       └─ feat/feature-name
       └─ fix/bug-name
       └─ refactor/refactor-name
```

### 브랜치 종류

| 브랜치 | 용도 | 수명 | 배포 환경 |
|--------|------|------|-----------|
| `main` | 프로덕션 배포용 | 영구 | Prod (App Store) |
| `release/v{version}` | 릴리즈 준비 및 QA | 릴리즈 기간 | Stage (TestFlight) |
| `feat/*` | 새 기능 개발 | 임시 | Dev (로컬) |
| `fix/*` | 버그 수정 | 임시 | Dev (로컬) |
| `refactor/*` | 리팩터링 | 임시 | Dev (로컬) |
| `hotfix/*` | 긴급 수정 | 임시 | Stage → Prod |

---

### 브랜치 워크플로우

#### 1️⃣ 새 기능 개발

```bash
# 1. 최신 release 브랜치에서 feature 브랜치 생성
git checkout release/v1.0.0
git pull origin release/v1.0.0
git checkout -b feat/notification-settings

# 2. 개발 및 커밋
git add .
git commit -m "feat: 알림 설정 Feature 추가"

# 3. PR 생성 (base: release/v1.0.0)
gh pr create --base release/v1.0.0 \
  --title "feat: 알림 설정 Feature 추가" \
  --body "..."

# 4. PR 리뷰 후 머지
# 5. feature 브랜치 삭제
git branch -d feat/notification-settings
```

**중요**: PR의 base 브랜치는 항상 **최신 release 브랜치**입니다.

#### 2️⃣ 릴리즈 배포 (Stage → Prod)

```bash
# 1. release 브랜치에서 Stage 배포 (TestFlight)
# GitHub Actions: workflow_dispatch로 수동 트리거

# 2. QA 완료 후 main으로 PR 생성
git checkout main
git pull origin main
gh pr create --base main --head release/v1.0.0 \
  --title "Release v1.0.0" \
  --body "릴리즈 노트..."

# 3. main 머지 후 태그 생성
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 4. Prod 배포 (App Store)
# GitHub Actions: workflow_dispatch로 수동 트리거
```

#### 3️⃣ Hotfix (긴급 수정)

```bash
# 1. main에서 hotfix 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/critical-crash-fix

# 2. 수정 및 커밋
git add .
git commit -m "fix: 앱 크래시 긴급 수정"

# 3. main으로 PR 생성 (리뷰 간소화)
gh pr create --base main \
  --title "hotfix: 앱 크래시 긴급 수정" \
  --body "..."

# 4. main 머지 후 즉시 Prod 배포
git tag -a v1.0.1 -m "Hotfix v1.0.1"
git push origin v1.0.1

# 5. release 브랜치에도 백포트
git checkout release/v1.1.0
git cherry-pick <hotfix-commit-hash>
git push origin release/v1.1.0
```

---

### 브랜치 명명 규칙

| 타입 | 포맷 | 예시 |
|------|------|------|
| Feature | `feat/{기능명}` | `feat/notification-settings` |
| Bug Fix | `fix/{버그명}` | `fix/group-list-crash` |
| Refactor | `refactor/{대상}` | `refactor/firestore-client` |
| Hotfix | `hotfix/{문제명}` | `hotfix/critical-crash-fix` |
| Release | `release/v{version}` | `release/v1.0.0` |

**규칙**:
- 소문자 + 하이픈(`-`) 사용
- 명확하고 간결한 이름 (3-5 단어)
- 한글 브랜치명 금지

---

## 2. CI/CD 파이프라인

GitHub Actions를 사용한 자동화 파이프라인입니다.

### 전체 흐름도

```
┌───────────────────────────────────────────────────────┐
│                    PR 생성 (feat/*)                     │
│                          ↓                             │
│                 PR Check Workflow                      │
│         (빌드 + 테스트 + 코드 리뷰 자동화)                │
│                          ↓                             │
│                    PR 승인 + 머지                        │
│                          ↓                             │
│              release 브랜치에 자동 반영                   │
│                          ↓                             │
│        ✨ Firebase Stage 자동 배포 (NEW!)               │
│         (infra/firebase/** 변경 감지 시)                │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│               release 브랜치 (QA 준비)                   │
│                          ↓                             │
│          Deploy iOS Stage (수동 트리거)                  │
│              TestFlight Stage 배포                      │
│                          ↓                             │
│                    QA 테스트 진행                        │
│                          ↓                             │
│                   main으로 PR 생성                       │
│                          ↓                             │
│                    PR 승인 + 머지                        │
│                          ↓                             │
│                     태그 생성 (v1.0.0)                   │
│                          ↓                             │
│           Deploy Prod Workflow (수동 트리거)             │
│         (iOS: TestFlight, Firebase: Functions/Rules)   │
│                          ↓                             │
│                  App Store 심사 제출                     │
└───────────────────────────────────────────────────────┘
```

### 배포 자동화 전략

| 환경 | iOS 앱 | Firebase | 트리거 |
|------|--------|----------|--------|
| **Dev** | 수동 (로컬) | 수동 (로컬/CLI) | 개발자 직접 실행 |
| **Stage** | 수동 (GitHub Actions) | **✨ 자동 (release 머지 시)** | release/* 브랜치 push |
| **Prod** | 수동 (GitHub Actions) | 수동 (GitHub Actions) | workflow_dispatch |

**자동화 이점**:
- Stage는 QA 전용 → 자동 배포로 QA 준비 시간 단축
- Prod는 실사용자 영향 → 수동 트리거로 안전성 확보

---

### 워크플로우 상세

#### 📌 PR Check (자동 실행)

**트리거**: PR 생성/업데이트 (base: `release/*` 또는 `main`)

```yaml
# .github/workflows/pr-check.yml
on:
  pull_request:
    branches:
      - 'release/**'
      - main
```

**실행 단계**:
1. ✅ **빌드 테스트** (PromisoDev)
2. ✅ **단위 테스트 실행** (tuist test)
3. ✅ **코드 린트** (SwiftLint - 선택)
4. ✅ **컨벤션 체크** (TCA 1.22.2 API, 강제 언래핑 등)
5. ✅ **PR 코멘트** (결과 요약)

**실패 시**: PR 머지 불가

---

#### 📌 Deploy Firebase Stage (✨ 자동 실행)

**트리거**: `push` to `release/**` (infra/firebase/** 변경 시)

```yaml
# .github/workflows/deploy-firebase-stage-auto.yml
on:
  push:
    branches:
      - 'release/**'
    paths:
      - 'infra/firebase/**'
```

**실행 단계**:
1. ✅ **Functions 테스트** (npm test)
2. ✅ **Lint 검사** (npm run lint)
3. ✅ **빌드** (npm run build)
4. ✅ **Functions 배포** (Stage)
5. ✅ **Firestore Rules 배포** (Stage)
6. ✅ **Storage Rules 배포** (Stage)
7. ✅ **헬스체크** (선택)
8. ✅ **Slack 알림** (성공/실패)

**안전장치**:
- Lint 실패 시 배포 중단
- 빌드 실패 시 배포 중단
- 배포 실패 시 Slack 알림 + 롤백 가이드

**실패 시 롤백**:
```bash
git checkout <previous-commit>
firebase deploy --only functions --project promiso-stage
```

---

#### 📌 Deploy iOS - Stage (수동 실행)

**트리거**: `workflow_dispatch` (수동)

```yaml
# .github/workflows/deploy-ios.yml
on:
  workflow_dispatch:
    inputs:
      environment: stage
      changelog: "TestFlight 수정사항"
```

**실행 단계**:
1. ✅ **환경 설정** (Stage)
2. ✅ **xcconfig 생성** (API 키)
3. ✅ **Firebase plist 복사** (Stage)
4. ✅ **Tuist 프로젝트 생성**
5. ✅ **Fastlane 빌드 + 업로드** (TestFlight Stage)
6. ✅ **Slack 알림** (배포 완료)

**실행 방법**:
```bash
# GitHub UI에서 Actions → Deploy iOS → Run workflow 선택
# 또는 gh CLI 사용
gh workflow run deploy-ios.yml \
  -f environment=stage \
  -f changelog="Stage 배포 테스트"
```

---

#### 📌 Deploy iOS - Prod (수동 실행)

**트리거**: `workflow_dispatch` (수동)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment: prod
      changelog: "프로덕션 릴리즈 노트"
```

**실행 단계**:
1. ✅ **환경 설정** (Prod)
2. ✅ **xcconfig 생성** (API 키)
3. ✅ **Firebase plist 복사** (Prod)
4. ✅ **Tuist 프로젝트 생성**
5. ✅ **Fastlane 빌드 + 업로드** (TestFlight Prod)
6. ✅ **Slack 알림** (배포 완료)
7. ✅ **App Store Connect 심사 제출** (선택)

**실행 조건**:
- main 브랜치에 태그(`v*.*.*`)가 생성된 후
- QA 완료 후

---

#### 📌 Deploy Firebase Prod (수동 실행)

**트리거**: `workflow_dispatch` (수동)

```yaml
# .github/workflows/deploy-firebase.yml
on:
  workflow_dispatch:
    inputs:
      environment: [stage, prod]
```

**실행 단계**:
1. ✅ **Functions 빌드** (TypeScript)
2. ✅ **Functions 배포** (`firebase deploy --only functions`)
3. ✅ **Firestore Rules 배포** (`firebase deploy --only firestore:rules`)
4. ✅ **Storage Rules 배포** (`firebase deploy --only storage`)
5. ✅ **Slack 알림**

**사용 시점**:
- **Stage**: Dev 환경 수동 배포가 필요한 경우 (드물게 사용)
- **Prod**: main 머지 후 프로덕션 배포 (항상 수동)

**실행 방법**:
```bash
# Prod 배포 (수동 트리거 필수)
gh workflow run deploy-firebase.yml \
  -f environment=prod

# Stage 배포 (수동 트리거 - 드물게 사용)
# 대부분의 경우 release 머지 시 자동 배포됨
gh workflow run deploy-firebase.yml \
  -f environment=stage
```

---

## 3. 배포 프로세스

### 배포 타입별 프로세스

#### 📦 **Stage 배포** (TestFlight - 내부 테스터)

**목적**: QA 테스트 및 릴리즈 검증

```bash
# 1. release 브랜치에서 최신 코드 확인
git checkout release/v1.0.0
git pull origin release/v1.0.0

# 2. Firebase Stage 배포
# ✨ 자동: release 브랜치에 PR 머지 시 자동 배포됨
# 수동: 필요한 경우에만 아래 명령 실행
gh workflow run deploy-firebase.yml \
  -f environment=stage

# 3. iOS 앱 Stage 배포 (수동)
gh workflow run deploy-ios.yml \
  -f environment=stage \
  -f changelog="QA 테스트용 빌드 v1.0.0-beta.1"

# 4. TestFlight에서 내부 테스터 그룹에 배포됨
# 5. QA 테스트 진행
```

**배포 주기**: 주 2-3회 (개발 완료 시)

**자동화 사항**:
- ✅ Firebase (Functions, Rules): **release 머지 시 자동 배포**
- ⚠️ iOS 앱: 수동 트리거 필요 (빌드 시간 고려)

---

#### 🚀 **Prod 배포** (TestFlight - 외부 테스터 → App Store)

**목적**: 프로덕션 릴리즈

```bash
# 1. QA 완료 후 main으로 PR 생성
gh pr create --base main --head release/v1.0.0 \
  --title "Release v1.0.0" \
  --body "$(cat CHANGELOG.md)"

# 2. PR 리뷰 및 승인 (최소 1명)

# 3. main 머지 후 태그 생성
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 4. iOS 앱 Prod 배포
gh workflow run deploy-ios.yml \
  -f environment=prod \
  -f changelog="$(git log --oneline v0.9.0..v1.0.0 | sed 's/^/- /')"

# 5. Firebase Prod 배포 (필요 시)
gh workflow run deploy-firebase.yml \
  -f environment=prod

# 6. TestFlight 외부 테스터 배포 → App Store 심사 제출
```

**배포 주기**: 2-4주마다 (메이저/마이너 버전)

---

#### 🔥 **Hotfix 배포** (긴급 수정)

**목적**: 프로덕션 긴급 버그 수정

```bash
# 1. main에서 hotfix 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/critical-crash-fix

# 2. 버그 수정 및 커밋
git add .
git commit -m "fix: 앱 크래시 긴급 수정"

# 3. main으로 PR 생성 (리뷰 간소화)
gh pr create --base main \
  --title "hotfix: 앱 크래시 긴급 수정" \
  --body "..."

# 4. 승인 후 즉시 머지

# 5. 패치 버전 태그 생성
git checkout main
git pull origin main
git tag -a v1.0.1 -m "Hotfix v1.0.1"
git push origin v1.0.1

# 6. Prod 배포 (최대한 빠르게)
gh workflow run deploy-ios.yml \
  -f environment=prod \
  -f changelog="긴급 버그 수정: 앱 크래시 해결"

# 7. release 브랜치에 백포트
git checkout release/v1.1.0
git cherry-pick <hotfix-commit-hash>
git push origin release/v1.1.0
```

**배포 주기**: 즉시 (긴급 상황 발생 시)

---

## 4. 환경별 설정

Promiso는 3개의 배포 환경을 사용합니다.

| 환경 | 용도 | Firebase Project | App Bundle ID | TestFlight |
|------|------|------------------|---------------|------------|
| **Dev** | 로컬 개발 | `promiso-dev` | `com.kswift.Promiso.dev` | ❌ |
| **Stage** | QA 테스트 | `promiso-stage` | `com.kswift.Promiso.stage` | ✅ (내부) |
| **Prod** | 프로덕션 | `promiso-prod` | `com.kswift.Promiso` | ✅ (외부) |

---

### 환경별 파일 구조

```
Projects/App/
├── Resources-Dev/
│   ├── GoogleService-Info.plist      # Dev Firebase
│   └── Assets.xcassets/               # Dev 아이콘
├── Resources-Stage/
│   ├── GoogleService-Info.plist      # Stage Firebase
│   └── Assets.xcassets/               # Stage 아이콘
├── Resources-Prod/
│   ├── GoogleService-Info.plist      # Prod Firebase
│   └── Assets.xcassets/               # Prod 아이콘
└── xcconfig/
    ├── Dev.xcconfig                   # Dev API 키
    ├── Stage.xcconfig                 # Stage API 키
    └── Prod.xcconfig                  # Prod API 키
```

---

### 환경 전환 방법

**로컬 개발 (Dev)**:
```bash
# Tuist로 Dev 타겟 생성
TUIST_ENV=dev tuist generate

# Xcode에서 PromisoDev 스킴 선택 후 실행
```

**CI/CD (Stage/Prod)**:
```yaml
# GitHub Actions에서 환경 변수 설정
env:
  TUIST_ENV: stage  # 또는 prod
run: tuist generate --no-open
```

---

## 5. 버전 관리

Promiso는 **Semantic Versioning 2.0.0**을 따릅니다.

### 버전 포맷

```
v{MAJOR}.{MINOR}.{PATCH}

예시:
v1.0.0    # 메이저 릴리즈
v1.1.0    # 마이너 릴리즈 (새 기능)
v1.1.1    # 패치 릴리즈 (버그 수정)
```

---

### 버전 증가 규칙

| 변경 타입 | 버전 | 예시 |
|----------|------|------|
| **Breaking Change** (API 변경, 호환성 깨짐) | MAJOR | `1.0.0 → 2.0.0` |
| **New Feature** (하위 호환 유지) | MINOR | `1.0.0 → 1.1.0` |
| **Bug Fix** (버그 수정, Hotfix) | PATCH | `1.0.0 → 1.0.1` |

---

### 버전 업데이트 프로세스

#### 1️⃣ 새 릴리즈 준비

```bash
# 1. main에서 release 브랜치 생성
git checkout main
git pull origin main
git checkout -b release/v1.1.0

# 2. 버전 파일 업데이트 (Info.plist 또는 설정 파일)
# CFBundleShortVersionString: 1.1.0
# CFBundleVersion: 빌드 번호 (자동 증가)

# 3. CHANGELOG.md 업데이트
echo "## [1.1.0] - 2026-02-10

### Added
- 알림 설정 기능

### Fixed
- 그룹 목록 크래시 수정

" >> CHANGELOG.md

# 4. 커밋 및 푸시
git add .
git commit -m "chore: v1.1.0 릴리즈 준비"
git push origin release/v1.1.0
```

#### 2️⃣ 태그 생성 (main 머지 후)

```bash
git checkout main
git pull origin main
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

---

### 빌드 번호 자동 증가

Fastlane이 자동으로 빌드 번호를 증가시킵니다:

```ruby
# fastlane/Fastfile
lane :beta_stage do
  increment_build_number(
    xcodeproj: "Promiso.xcodeproj",
    build_number: latest_testflight_build_number + 1
  )
  # ...
end
```

**결과**:
- `CFBundleShortVersionString`: `1.1.0` (수동)
- `CFBundleVersion`: `123` (자동)

---

## 6. 롤백 전략

배포 후 문제 발생 시 롤백 방법입니다.

### 📱 iOS 앱 롤백

#### TestFlight 롤백

TestFlight은 **이전 빌드로 즉시 전환** 가능합니다.

```bash
# App Store Connect에서 수동 작업
# 1. App Store Connect → TestFlight → iOS → Builds
# 2. 이전 정상 빌드 선택
# 3. "Submit for Beta Review" 클릭 (외부 테스터용)
```

**예상 시간**: 5-10분

---

#### App Store 롤백

App Store는 **이전 버전 재심사** 필요합니다.

```bash
# 1. App Store Connect에서 현재 버전 제거
# 2. 이전 버전(v1.0.0) 다시 제출
# 3. 심사 대기 (1-3일)

# 또는 Hotfix 배포 (더 빠름)
git checkout main
git checkout -b hotfix/revert-v1.1.0
git revert <commit-hash>  # v1.1.0 변경사항 되돌리기
git push origin hotfix/revert-v1.1.0
# → PR → main 머지 → v1.0.1 태그 → Prod 배포
```

**예상 시간**:
- Hotfix 배포: 1-2시간
- 이전 버전 재심사: 1-3일

---

### 🔥 Firebase 롤백

Firebase는 **이전 버전으로 즉시 배포** 가능합니다.

#### Functions 롤백

```bash
# 1. 이전 Functions 버전 확인
firebase functions:log --project promiso-prod

# 2. Git에서 이전 커밋으로 체크아웃
git checkout <previous-commit-hash> -- infra/firebase/functions

# 3. 재배포
cd infra/firebase/functions
npm run build
cd ..
firebase deploy --only functions --project promiso-prod
```

**예상 시간**: 5-10분

---

#### Firestore Rules 롤백

```bash
# 1. Firebase Console에서 이전 버전 복원
# Firebase Console → Firestore → Rules → History → Restore

# 또는 Git에서 이전 버전 배포
git checkout <previous-commit-hash> -- infra/firebase/firestore.rules
firebase deploy --only firestore:rules --project promiso-prod
```

**예상 시간**: 1-2분

---

## 7. 체크리스트

### 🟢 PR 생성 전

- [ ] **브랜치 최신화** (`git pull origin release/v1.0.0`)
- [ ] **로컬 빌드 성공** (`tuist build PromisoDev`)
- [ ] **로컬 테스트 통과** (`tuist test`)
- [ ] **커밋 메시지 컨벤션** (`.claude/CLAUDE.md` 참조)
- [ ] **코드 리뷰 완료** (`/review-pr` 또는 code-reviewer)
- [ ] **PR base 브랜치 확인** (`release/v*.*.*`)

---

### 🟡 Stage 배포 전

**Firebase (자동 배포)**:
- [ ] **release 브랜치 최신화**
- [ ] **PR Check 통과** (모든 PR 머지됨)
- [ ] **Firebase 변경사항 확인** (infra/firebase/**)
- [ ] ✨ **자동 배포 완료 확인** (Slack 알림 또는 GitHub Actions)
- [ ] **Firebase Console 확인** (Functions, Rules 정상 동작)

**iOS 앱 (수동 배포)**:
- [ ] **수동 빌드 테스트** (로컬에서 Stage 타겟)
- [ ] **TestFlight 수정사항 작성** (changelog)
- [ ] **내부 테스터 그룹 지정**
- [ ] **수동 트리거 실행** (deploy-ios.yml)

---

### 🔴 Prod 배포 전

- [ ] **Stage QA 완료** (버그 없음)
- [ ] **main으로 PR 생성** (리뷰 1명 이상)
- [ ] **CHANGELOG.md 업데이트** (릴리즈 노트)
- [ ] **버전 번호 확인** (`CFBundleShortVersionString`)
- [ ] **태그 생성** (`v*.*.*`)
- [ ] **Firebase Prod 배포** (Functions, Rules)
- [ ] **TestFlight 외부 테스터 배포**
- [ ] **App Store 심사 제출** (스크린샷, 설명 업데이트)
- [ ] **Slack 알림 확인** (배포 완료 메시지)

---

### 🔥 Hotfix 배포 전

- [ ] **긴급도 확인** (정말 hotfix가 필요한가?)
- [ ] **main 브랜치에서 생성** (`hotfix/*`)
- [ ] **최소한의 변경** (버그 수정만)
- [ ] **리뷰 간소화** (1명 승인으로 즉시 머지)
- [ ] **패치 버전 태그** (`v1.0.1`)
- [ ] **Prod 즉시 배포**
- [ ] **release 브랜치 백포트** (cherry-pick)

---

## 자동화 스크립트

### 최신 release 브랜치 자동 감지

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
latest_release() {
  git branch -r | grep 'origin/release/' | sort -V | tail -1 | sed 's/.*origin\///'
}

# 사용 예시
git checkout $(latest_release)
gh pr create --base $(latest_release) --title "..." --body "..."
```

---

### PR 템플릿 자동 생성

```bash
# .github/pull_request_template.md
## 변경 사항

<!-- 무엇을 변경했나요? -->

## 관련 이슈

<!-- 관련 이슈 번호 (예: #123) -->

## 체크리스트

- [ ] 로컬 빌드 성공
- [ ] 로컬 테스트 통과
- [ ] 코드 리뷰 완료 (/review-pr)
- [ ] 컨벤션 준수 (.claude/CLAUDE.md)

## 스크린샷 (선택)

<!-- 변경된 UI가 있다면 스크린샷 첨부 -->
```

---

## Firebase Stage 자동 배포 FAQ

### Q1. Stage 자동 배포가 실패하면 어떻게 하나요?

**A**: Slack 알림에 롤백 가이드가 포함되어 있습니다.

```bash
# 1. 이전 커밋으로 체크아웃
git checkout <previous-commit>

# 2. 수동 배포
cd infra/firebase
firebase deploy --only functions --project promiso-stage

# 또는 GitHub Actions로 재배포
gh workflow run deploy-firebase.yml -f environment=stage
```

---

### Q2. Firebase만 변경하고 iOS는 변경 안 했을 때도 자동 배포되나요?

**A**: 네, Firebase 파일(`infra/firebase/**`)만 변경되어도 자동 배포됩니다.

```yaml
# .github/workflows/deploy-firebase-stage-auto.yml
paths:
  - 'infra/firebase/**'
```

iOS 앱은 **수동 트리거만 가능**하므로 Firebase만 필요하면 iOS 배포를 건너뛸 수 있습니다.

---

### Q3. Dev 환경에서 Firebase를 직접 테스트하고 싶어요.

**A**: 로컬에서 Firebase CLI 또는 에뮬레이터를 사용하세요.

```bash
# Dev 환경 배포 (수동)
cd infra/firebase
firebase use dev
firebase deploy --only functions

# 또는 에뮬레이터 사용 (추천)
make emulator-start
```

---

### Q4. Stage 자동 배포를 일시적으로 비활성화하려면?

**A**: 워크플로우 파일을 임시로 비활성화하세요.

```bash
# 1. 워크플로우 파일 이름 변경
git mv .github/workflows/deploy-firebase-stage-auto.yml \
       .github/workflows/deploy-firebase-stage-auto.yml.disabled

# 2. 커밋 및 푸시
git commit -m "chore: Stage 자동 배포 임시 비활성화"
git push

# 재활성화 시
git mv .github/workflows/deploy-firebase-stage-auto.yml.disabled \
       .github/workflows/deploy-firebase-stage-auto.yml
```

---

### Q5. Prod 배포도 자동화하면 안 되나요?

**A**: 안전상의 이유로 **Prod는 수동 배포를 권장**합니다.

**이유**:
- 실사용자에게 직접 영향
- AI 코드 변경 시 즉시 반영되면 위험
- 수동 검토 후 배포가 안전

**대안**:
- Stage QA 완료 후 승인 게이트 추가
- 태그 기반 자동 배포 (v*.*.* 태그 생성 시)

현재는 **수동 배포 유지**가 가장 안전합니다.

---

## 실전 시나리오

### 시나리오 1: Firebase Functions 수정 후 배포

```bash
# 1. feat 브랜치에서 개발
git checkout -b feat/add-notification-function
# ... Functions 코드 수정 ...
git commit -m "feat: 알림 발송 Function 추가"
git push origin feat/add-notification-function

# 2. release로 PR 생성
gh pr create --base release/v1.0.0 \
  --title "feat: 알림 발송 Function 추가"

# 3. PR 리뷰 및 승인

# 4. PR 머지
# → ✨ 자동: Firebase Stage 배포 시작 (GitHub Actions)
# → ✨ 자동: Slack 알림 도착 (성공/실패)

# 5. Stage에서 테스트
# Firebase Console → Functions → 로그 확인

# 6. QA 완료 후 main으로 릴리즈
gh pr create --base main --head release/v1.0.0
# → 승인 후 머지

# 7. Prod 배포 (수동)
gh workflow run deploy-firebase.yml -f environment=prod
```

---

### 시나리오 2: Firestore Rules만 수정

```bash
# 1. feat 브랜치에서 Rules 수정
git checkout -b feat/update-firestore-rules
# ... infra/firebase/firestore.rules 수정 ...
git commit -m "feat: Firestore Rules 권한 업데이트"
git push origin feat/update-firestore-rules

# 2. release로 PR 생성 및 머지
# → ✨ 자동: Firebase Stage 배포 (Rules만)

# 3. Stage에서 검증
# Firebase Console → Firestore → Rules 탭 확인

# 4. Prod 배포 (수동)
gh workflow run deploy-firebase.yml -f environment=prod
```

---

### 시나리오 3: iOS + Firebase 동시 변경

```bash
# 1. feat 브랜치에서 개발
git checkout -b feat/notification-settings
# ... iOS 코드 + Firebase Functions 수정 ...
git commit -m "feat: 알림 설정 Feature 추가"
git push origin feat/notification-settings

# 2. release로 PR 생성 및 머지
# → ✨ 자동: Firebase Stage 배포
# → ⚠️ iOS 앱은 수동 배포 필요

# 3. iOS 앱 Stage 배포 (수동)
gh workflow run deploy-ios.yml \
  -f environment=stage \
  -f changelog="알림 설정 기능 추가"

# 4. QA 완료 후 Prod 배포 (둘 다 수동)
gh workflow run deploy-firebase.yml -f environment=prod
gh workflow run deploy-ios.yml -f environment=prod -f changelog="..."
```

---

## 추가 리소스

- [Git Flow 공식 문서](https://nvie.com/posts/a-successful-git-branching-model/)
- [Semantic Versioning 2.0.0](https://semver.org/)
- [GitHub Actions 문서](https://docs.github.com/en/actions)
- [Fastlane 문서](https://docs.fastlane.tools/)
- [Firebase CLI 문서](https://firebase.google.com/docs/cli)

---

## 문의 및 피드백

브랜치 전략, CI/CD, 배포 프로세스에 대한 문의사항은:
- GitHub Discussions
- Slack #dev-promiso 채널
