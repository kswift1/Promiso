# Fastlane 설정 가이드

Promiso iOS 앱의 자동 배포를 위한 Fastlane 설정 방법입니다.

## 📋 목차

1. [Fastlane이란?](#fastlane이란)
2. [초기 설정](#초기-설정)
3. [Match 설정 (인증서 관리)](#match-설정-인증서-관리)
4. [사용 방법](#사용-방법)
5. [문제 해결](#문제-해결)

---

## Fastlane이란?

**Fastlane**은 iOS/Android 앱 배포를 자동화하는 도구입니다.

### 주요 기능

- ✅ **Match**: 인증서/프로비저닝 프로파일 자동 관리
- ✅ **Gym**: 앱 빌드 및 아카이빙 자동화
- ✅ **Pilot**: TestFlight 업로드 자동화
- ✅ **Deliver**: App Store 제출 자동화
- ✅ **Snapshot**: 스크린샷 자동 생성 (선택)

### 왜 필요한가?

**Fastlane 없이**:
```bash
# 수동으로 해야 할 작업
1. Xcode에서 Archive
2. Organizer에서 Export
3. App Store Connect에 수동 업로드
4. 인증서/프로비저닝 관리 복잡
5. 팀원 간 코드 사이닝 문제 빈번
```

**Fastlane 사용 시**:
```bash
# 한 줄 명령어
fastlane beta_dev

# CI/CD에서 자동 배포
git push origin develop → TestFlight 자동 업로드
```

---

## 초기 설정

### 1. Fastlane 설치

```bash
# Homebrew로 설치 (권장)
brew install fastlane

# 또는 Bundler 사용
bundle install
```

### 2. 파일 구조 확인

```
Promiso/
├── fastlane/
│   ├── Fastfile          # 배포 워크플로우
│   ├── Matchfile         # 인증서 설정
│   └── Appfile           # 앱 기본 정보
├── Gemfile               # Ruby 의존성
└── .gitignore            # fastlane 무시 항목
```

### 3. Apple ID 및 Team ID 확인

#### Apple ID
```
App Store Connect에 로그인하는 Apple ID
예: yourname@example.com
```

#### Team ID
```bash
# Apple Developer Portal에서 확인
# https://developer.apple.com/account

# 또는 명령어로 확인
fastlane fastlane-credentials check

# Team ID 예시: A1B2C3D4E5
```

#### App Store Connect Team ID (선택)
```
팀이 여러 개인 경우 필요
App Store Connect → Users and Access → Team ID
```

### 4. Appfile 및 Matchfile 수정

#### `fastlane/Appfile` 편집
```ruby
# ← 실제 정보로 변경
apple_id("your-apple-id@example.com")
team_id("YOUR_TEAM_ID")
itc_team_id("YOUR_ITC_TEAM_ID") # 선택
```

#### `fastlane/Matchfile` 편집
```ruby
# ← 실제 정보로 변경
git_url("https://github.com/kswift1/promiso-certificates")
username("your-apple-id@example.com")
team_id("YOUR_TEAM_ID")
```

---

## Match 설정 (인증서 관리)

### Match란?

**Match**는 인증서와 프로비저닝 프로파일을 Git 저장소에 암호화해서 저장하고, 팀원들이 공유할 수 있게 해주는 도구입니다.

### 장점

- ✅ 팀원 간 코드 사이닝 문제 해결
- ✅ CI/CD에서 자동으로 인증서 사용 가능
- ✅ 인증서 만료 시 자동 갱신
- ✅ Git으로 버전 관리

### 1. Private Git 저장소 생성

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

### 2. Matchfile에 저장소 URL 설정

`fastlane/Matchfile`:
```ruby
git_url("https://github.com/kswift1/promiso-certificates")
```

### 3. Match 초기화

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

### 4. 생성 확인

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

### 5. GitHub Secrets에 MATCH_PASSWORD 등록

```bash
# GitHub 레포지토리 → Settings → Secrets and variables → Actions
Name:  MATCH_PASSWORD
Value: ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b (위에서 설정한 비밀번호)
```

### 6. CI/CD용 Git 인증 설정

#### 방법 1: Deploy Key (권장)

**promiso-certificates 저장소**:
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

**GitHub Secrets에 Private 키 등록**:
```bash
# Private 키 복사
cat ~/.ssh/promiso_match_deploy_key

# GitHub → promiso (메인 레포) → Secrets
Name:  MATCH_DEPLOY_KEY
Value: (Private 키 전체 내용)
```

**Matchfile 수정**:
```ruby
git_url("git@github.com:kswift1/promiso-certificates.git") # HTTPS → SSH
```

#### 방법 2: Personal Access Token

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

## 사용 방법

### 로컬에서 TestFlight 배포

#### Dev 환경

```bash
# PromisoDev → TestFlight (Dev Track)
fastlane beta_dev
```

**실행 과정**:
1. Match에서 인증서/프로파일 다운로드
2. 빌드 번호 자동 증가
3. Archive 및 Export
4. TestFlight 업로드

**예상 시간**: 5-10분

#### Stage 환경

```bash
# PromisoStage → TestFlight (Stage Track)
fastlane beta_stage
```

#### Production 환경

```bash
# Promiso → TestFlight (Prod Track)
fastlane beta_prod
```

### CI/CD에서 자동 배포

**GitHub Actions 워크플로우에서**:

```yaml
- name: Deploy to TestFlight (Dev)
  env:
    MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
    APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
  run: |
    bundle exec fastlane beta_dev
```

**자동 트리거**:
```bash
# develop 브랜치에 push → Dev 배포
git push origin develop

# staging 브랜치에 push → Stage 배포
git push origin staging

# main 브랜치에 push → Prod 배포
git push origin main
```

### 테스트만 실행

```bash
fastlane test
```

### 인증서 동기화

```bash
# 새 팀원이 합류하거나, 인증서 갱신 시
fastlane sync_certificates
```

---

## Lane 설명

| Lane | 용도 | 배포 대상 |
|------|------|-----------|
| `beta_dev` | Dev 빌드 → TestFlight | PromisoDev (com.promiso.dev) |
| `beta_stage` | Stage 빌드 → TestFlight | PromisoStage (com.promiso.stage) |
| `beta_prod` | Prod 빌드 → TestFlight | Promiso (com.promiso) |
| `release` | App Store 제출 | Promiso → App Store |
| `test` | 유닛 테스트 실행 | - |
| `sync_certificates` | 인증서 동기화 | - |

---

## 문제 해결

### Q: "Could not find action, lane or variable 'match'"

**A**: Fastlane이 설치되지 않음

```bash
bundle install
bundle exec fastlane beta_dev
```

### Q: "Could not decrypt the repo"

**A**: MATCH_PASSWORD가 틀림

```bash
# 환경변수로 설정
export MATCH_PASSWORD="your-password"
fastlane beta_dev
```

### Q: "User credentials invalid"

**A**: Apple ID 2FA 인증 필요

```bash
# App Store Connect API Key 사용 (권장)
# docs/GITHUB_SECRETS.md 참고

# 또는 2FA 인증
fastlane spaceauth -u your-apple-id@example.com
# 출력된 세션 값을 FASTLANE_SESSION 환경변수로 설정
```

### Q: "No code signing identity found"

**A**: Match로 인증서 재생성

```bash
# 인증서 삭제 후 재생성
fastlane match nuke distribution
fastlane match appstore
```

### Q: "Provisioning profile doesn't include signing certificate"

**A**: Match 저장소와 로컬 불일치

```bash
# Match 재동기화
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
fastlane match appstore --readonly
```

### Q: "Build number already exists on TestFlight"

**A**: 빌드 번호 자동 증가 실패

```bash
# 수동으로 빌드 번호 증가
fastlane run increment_build_number build_number:123
```

---

## 베스트 프랙티스

### ✅ DO

- ✅ Match 저장소는 반드시 Private로 설정
- ✅ MATCH_PASSWORD는 강력한 무작위 문자열 사용 (32자 이상)
- ✅ App Store Connect API Key 사용 (2FA 문제 해결)
- ✅ CI/CD에서는 readonly 모드로 Match 사용
- ✅ 인증서 만료 시 `fastlane match renew` 실행

### ❌ DON'T

- ❌ Match 저장소를 Public으로 설정하지 말 것
- ❌ 인증서를 수동으로 생성하지 말 것 (Match 사용)
- ❌ Xcode에서 "Automatically manage signing" 활성화 금지 (Match와 충돌)
- ❌ MATCH_PASSWORD를 코드에 하드코딩 금지
- ❌ 여러 Mac에서 동시에 `match appstore` 실행 금지

---

## 체크리스트

### 초기 설정

- [ ] Fastlane 설치 (`brew install fastlane`)
- [ ] Appfile 수정 (Apple ID, Team ID)
- [ ] Matchfile 수정 (Git URL, Apple ID, Team ID)
- [ ] Private Git 저장소 생성 (promiso-certificates)
- [ ] `fastlane match appstore` 실행
- [ ] MATCH_PASSWORD 저장
- [ ] GitHub Secrets 등록
  - [ ] MATCH_PASSWORD
  - [ ] APP_STORE_CONNECT_API_KEY_ID
  - [ ] APP_STORE_CONNECT_API_ISSUER_ID
  - [ ] APP_STORE_CONNECT_API_KEY
- [ ] Deploy Key 또는 Personal Access Token 설정

### 배포 전

- [ ] `fastlane test` 통과 확인
- [ ] 빌드 번호 확인
- [ ] 버전 번호 확인 (Info.plist 또는 project.pbxproj)
- [ ] 체인지로그 작성

### 배포 후

- [ ] TestFlight에서 빌드 확인
- [ ] 내부 테스터에게 알림
- [ ] 외부 테스터 그룹 지정 (Stage/Prod)

---

## 참고 문서

- [Fastlane 공식 문서](https://docs.fastlane.tools/)
- [Match 가이드](https://docs.fastlane.tools/actions/match/)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [docs/GITHUB_SECRETS.md](GITHUB_SECRETS.md) - GitHub Secrets 설정
- [docs/BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) - 브랜치 전략
