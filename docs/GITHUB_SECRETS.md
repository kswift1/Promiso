# GitHub Secrets 설정 가이드

CI/CD 워크플로우에 필요한 GitHub Secrets 설정 방법입니다.

## 📋 목차

1. [필수 Secrets 목록](#필수-secrets-목록)
2. [Secrets 등록 방법](#secrets-등록-방법)
3. [iOS 빌드 Secrets](#ios-빌드-secrets)
4. [Firebase plist Secrets](#firebase-plist-secrets)
5. [Fastlane Match Secrets](#fastlane-match-secrets)
6. [App Store Connect Secrets](#app-store-connect-secrets)
7. [Firebase 배포 Secrets](#firebase-배포-secrets)
8. [검증 방법](#검증-방법)

---

## 필수 Secrets 목록

### ✅ 필수 (빌드/테스트)

| Secret 이름 | 용도 | 필요한 워크플로우 |
|-------------|------|------------------|
| `GOOGLE_CLIENT_ID_DEV` | Dev Google OAuth | PR 체크, Dev 배포 |
| `GOOGLE_REVERSED_CLIENT_ID_DEV` | Dev Google OAuth | PR 체크, Dev 배포 |
| `KAKAO_NATIVE_APP_KEY_DEV` | Dev Kakao Login | PR 체크, Dev 배포 |
| `KAKAO_REST_API_KEY_DEV` | Dev Kakao Login | PR 체크, Dev 배포 |
| `GOOGLE_SERVICE_INFO_DEV` | Dev Firebase plist (Base64) | PR 체크, Dev 배포 |

### ✅ 필수 (Stage/Prod 배포)

| Secret 이름 | 용도 | 필요한 워크플로우 |
|-------------|------|------------------|
| `GOOGLE_CLIENT_ID_STAGE` | Stage Google OAuth | Stage 배포 |
| `GOOGLE_REVERSED_CLIENT_ID_STAGE` | Stage Google OAuth | Stage 배포 |
| `KAKAO_NATIVE_APP_KEY_STAGE` | Stage Kakao Login | Stage 배포 |
| `KAKAO_REST_API_KEY_STAGE` | Stage Kakao Login | Stage 배포 |
| `GOOGLE_SERVICE_INFO_STAGE` | Stage Firebase plist (Base64) | Stage 배포 |
| `GOOGLE_CLIENT_ID_PROD` | Prod Google OAuth | Prod 배포 |
| `GOOGLE_REVERSED_CLIENT_ID_PROD` | Prod Google OAuth | Prod 배포 |
| `KAKAO_NATIVE_APP_KEY_PROD` | Prod Kakao Login | Prod 배포 |
| `KAKAO_REST_API_KEY_PROD` | Prod Kakao Login | Prod 배포 |
| `GOOGLE_SERVICE_INFO_PROD` | Prod Firebase plist (Base64) | Prod 배포 |

### ✅ 필수 (TestFlight 배포)

| Secret 이름 | 용도 | 필요한 워크플로우 |
|-------------|------|------------------|
| `APP_STORE_CONNECT_API_KEY_ID` | App Store Connect API | TestFlight 배포 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | App Store Connect API | TestFlight 배포 |
| `APP_STORE_CONNECT_API_KEY` | App Store Connect API Key (Base64) | TestFlight 배포 |
| `MATCH_PASSWORD` | Fastlane Match 암호화 비밀번호 | TestFlight 배포 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Match Git 저장소 인증 (선택) | TestFlight 배포 |

### ✅ 필수 (Firebase 배포)

| Secret 이름 | 용도 | 필요한 워크플로우 |
|-------------|------|------------------|
| `FIREBASE_TOKEN` | Firebase CLI 인증 | Firebase 배포 |

### 🔔 선택 (알림)

| Secret 이름 | 용도 | 필요한 워크플로우 |
|-------------|------|------------------|
| `SLACK_WEBHOOK_URL` | Slack 알림 | Gemini 리뷰 알림 (기존) |

**총 개수**: 22개 (필수 21개 + 선택 1개)

---

## Secrets 등록 방법

### 1. GitHub 레포지토리 접속

1. https://github.com/kswift1/promiso
2. **Settings** 탭 클릭
3. 좌측 메뉴: **Secrets and variables** → **Actions**
4. **New repository secret** 클릭

### 2. Secret 등록

```
Name:  GOOGLE_CLIENT_ID_DEV
Value: 306291841913-08gm6rkpklh6k7qqfim1bkc92uji6bcg.apps.googleusercontent.com

(Add secret 클릭)
```

---

## iOS 빌드 Secrets

### Dev 환경 (4개)

```bash
# 로컬 Config 파일에서 값 확인
cat Config/Dev.xcconfig
```

**등록할 Secrets**:

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_DEV` | `306291841913-08gm6rkpklh6k7qqfim1bkc92uji6bcg.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_DEV` | `com.googleusercontent.apps.306291841913-08gm6rkpklh6k7qqfim1bkc92uji6bcg` |
| `KAKAO_NATIVE_APP_KEY_DEV` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_DEV` | `eacdef419fafb30e112e6ca22219ee4d` |

### Stage 환경 (4개)

```bash
cat Config/Stage.xcconfig
```

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_STAGE` | `511041416523-bek4g2m6qojqcoecd17mvft1kvn7vogt.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_STAGE` | `com.googleusercontent.apps.511041416523-bek4g2m6qojqcoecd17mvft1kvn7vogt` |
| `KAKAO_NATIVE_APP_KEY_STAGE` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_STAGE` | `eacdef419fafb30e112e6ca22219ee4d` |

### Prod 환경 (4개)

```bash
cat Config/Prod.xcconfig
```

| Name | Value (예시) |
|------|-------------|
| `GOOGLE_CLIENT_ID_PROD` | `367716701610-efrvms6v48eldljh34falbhclkvsrqvt.apps.googleusercontent.com` |
| `GOOGLE_REVERSED_CLIENT_ID_PROD` | `com.googleusercontent.apps.367716701610-efrvms6v48eldljh34falbhclkvsrqvt` |
| `KAKAO_NATIVE_APP_KEY_PROD` | `85c9fc88501e426b848242e7c02d20af` |
| `KAKAO_REST_API_KEY_PROD` | `eacdef419fafb30e112e6ca22219ee4d` |

---

## Firebase plist Secrets

### Base64 인코딩

**로컬에서 Base64로 변환**:

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

### GitHub Actions에서 복원

워크플로우에서 자동으로 디코딩:

```yaml
- name: Setup Firebase plist (Dev)
  run: |
    echo "${{ secrets.GOOGLE_SERVICE_INFO_DEV }}" | base64 --decode > \
      Projects/App/Resources-Dev/GoogleService-Info.plist
```

---

## Fastlane Match Secrets

### 1. Match Password

**용도**: 인증서/프로비저닝 프로파일 암호화 비밀번호

**생성 방법**:
```bash
# 강력한 비밀번호 생성 (예시)
openssl rand -base64 32
# 출력: ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b
```

**등록**:
```
Name:  MATCH_PASSWORD
Value: ZqP8xR3vK9mN2wY6tL5hJ1cS4dF7gA0b
```

### 2. Match Git Authorization (선택)

**용도**: Private Git 저장소에 Match 인증서 저장 시 필요

**생성 방법**:
```bash
# Personal Access Token으로 인증
echo -n "username:personal_access_token" | base64
```

**등록**:
```
Name:  MATCH_GIT_BASIC_AUTHORIZATION
Value: dXNlcm5hbWU6cGVyc29uYWxfYWNjZXNzX3Rva2Vu
```

**또는 SSH 키 사용** (권장):
- Match 저장소를 SSH URL로 설정
- GitHub Actions에 Deploy Key 등록

---

## App Store Connect Secrets

### 1. API Key 생성

1. **App Store Connect** 접속
   - https://appstoreconnect.apple.com/

2. **Users and Access** → **Integrations** → **App Store Connect API**

3. **Generate API Key**
   - Name: `GitHub Actions`
   - Access: `App Manager` (권한)

4. **Key ID**, **Issuer ID**, **Download API Key (.p8)** 저장

### 2. Secrets 등록

#### API Key ID
```
Name:  APP_STORE_CONNECT_API_KEY_ID
Value: ABC123XYZ (Key ID)
```

#### Issuer ID
```
Name:  APP_STORE_CONNECT_API_ISSUER_ID
Value: 12345678-1234-1234-1234-123456789012 (Issuer ID)
```

#### API Key (Base64)
```bash
# .p8 파일을 Base64로 인코딩
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy
```

```
Name:  APP_STORE_CONNECT_API_KEY
Value: (Base64 인코딩된 .p8 내용)
```

### 3. 워크플로우에서 사용

```yaml
- name: Setup App Store Connect API Key
  run: |
    mkdir -p ~/private_keys
    echo "${{ secrets.APP_STORE_CONNECT_API_KEY }}" | base64 --decode > \
      ~/private_keys/AuthKey_${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}.p8
```

---

## Firebase 배포 Secrets

### 1. Firebase Token 생성

**로컬에서 실행**:

```bash
# Firebase CLI 로그인
firebase login:ci

# 출력:
# ✔  Success! Use this token to login on a CI server:
#
# 1//0gABC123...XYZ (매우 긴 토큰)
```

### 2. Secret 등록

```
Name:  FIREBASE_TOKEN
Value: 1//0gABC123...XYZ (위에서 생성한 토큰)
```

### 3. 워크플로우에서 사용

```yaml
- name: Deploy Firebase Functions
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
  run: |
    cd infra/firebase
    firebase use dev
    firebase deploy --only functions --token "$FIREBASE_TOKEN"
```

---

## 검증 방법

### 1. xcconfig 생성 검증

**로컬에서 스크립트 테스트**:

```bash
# 환경변수 설정
export GOOGLE_CLIENT_ID_DEV="306291841913-..."
export GOOGLE_REVERSED_CLIENT_ID_DEV="com.googleusercontent.apps.306291841913-..."
export KAKAO_NATIVE_APP_KEY_DEV="85c9fc88..."
export KAKAO_REST_API_KEY_DEV="eacdef419..."

# 스크립트 실행
./scripts/generate-xcconfig.sh

# 생성된 파일 확인
cat Config/Dev.xcconfig
```

### 2. Firebase plist 디코딩 검증

```bash
# Base64 디코딩 테스트
echo "$GOOGLE_SERVICE_INFO_DEV" | base64 --decode > /tmp/test.plist

# plist 파일 검증
plutil -lint /tmp/test.plist
# 출력: /tmp/test.plist: OK
```

### 3. GitHub Actions 테스트

**Dummy PR 생성**:

```bash
git checkout -b test/ci-secrets
echo "# Test" >> README.md
git add README.md
git commit -m "test: CI Secrets 검증"
git push origin test/ci-secrets
```

**PR 생성 후 Actions 탭에서 로그 확인**:
- ✅ xcconfig 생성됨
- ✅ Firebase plist 디코딩됨
- ✅ 빌드 성공

### 4. Secret 값 확인 (주의)

**절대 로그에 출력하지 말 것**:

```yaml
# ❌ 금지
- run: echo "${{ secrets.GOOGLE_CLIENT_ID_DEV }}"

# ✅ 디버깅이 필요하면 마스킹 확인
- run: |
    if [ -z "$GOOGLE_CLIENT_ID_DEV" ]; then
      echo "❌ GOOGLE_CLIENT_ID_DEV is not set"
      exit 1
    else
      echo "✅ GOOGLE_CLIENT_ID_DEV is set (length: ${#GOOGLE_CLIENT_ID_DEV})"
    fi
  env:
    GOOGLE_CLIENT_ID_DEV: ${{ secrets.GOOGLE_CLIENT_ID_DEV }}
```

---

## 빠른 등록 스크립트

모든 Secrets를 한 번에 확인할 수 있는 체크리스트:

```bash
#!/bin/bash

# Secrets 체크리스트
echo "📋 GitHub Secrets 체크리스트"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "iOS 빌드 (12개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat Config/Dev.xcconfig
cat Config/Stage.xcconfig
cat Config/Prod.xcconfig

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Firebase plist (3개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GOOGLE_SERVICE_INFO_DEV:"
base64 -i Config/GoogleService-Info-Dev.plist | head -c 50
echo "..."

echo ""
echo "GOOGLE_SERVICE_INFO_STAGE:"
base64 -i Config/GoogleService-Info-Stage.plist | head -c 50
echo "..."

echo ""
echo "GOOGLE_SERVICE_INFO_PROD:"
base64 -i Config/GoogleService-Info-Prod.plist | head -c 50
echo "..."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fastlane Match (1개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "MATCH_PASSWORD: (생성 필요)"
openssl rand -base64 32

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "App Store Connect (3개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "APP_STORE_CONNECT_API_KEY_ID: (App Store Connect에서 생성)"
echo "APP_STORE_CONNECT_API_ISSUER_ID: (App Store Connect에서 생성)"
echo "APP_STORE_CONNECT_API_KEY: (Base64 인코딩 필요)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Firebase 배포 (1개)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FIREBASE_TOKEN:"
firebase login:ci 2>/dev/null || echo "(firebase login:ci 실행 필요)"
```

**사용법**:
```bash
chmod +x scripts/check-secrets.sh
./scripts/check-secrets.sh
```

---

## 문제 해결

### Q: "Secret not found" 에러

**A**: Secret 이름 대소문자 확인

```yaml
# ❌ 틀림
${{ secrets.google_client_id_dev }}

# ✅ 맞음
${{ secrets.GOOGLE_CLIENT_ID_DEV }}
```

### Q: Base64 디코딩 실패

**A**: 줄바꿈 제거 후 재인코딩

```bash
# 줄바꿈 없이 한 줄로 인코딩
base64 -i Config/GoogleService-Info-Dev.plist | tr -d '\n' | pbcopy
```

### Q: Firebase plist가 잘못됨

**A**: 로컬에서 디코딩 테스트

```bash
# GitHub Secret 값 복사
echo "PASTE_SECRET_VALUE_HERE" | base64 --decode > /tmp/test.plist
plutil -lint /tmp/test.plist
```

### Q: Match 인증 실패

**A**: SSH 키 확인 또는 HTTPS + Token 사용

```ruby
# Matchfile
git_url("https://github.com/kswift1/promiso-certificates")
# GitHub Actions에서 MATCH_GIT_BASIC_AUTHORIZATION 사용
```

---

## 보안 권장사항

### ✅ DO

- ✅ 모든 민감 정보는 GitHub Secrets 사용
- ✅ Base64 인코딩으로 줄바꿈 문제 방지
- ✅ Match Password는 강력한 무작위 문자열 사용
- ✅ API Key는 최소 권한만 부여
- ✅ Secret 값은 절대 로그에 출력하지 않음

### ❌ DON'T

- ❌ Secret 값을 코드에 하드코딩
- ❌ Secret 값을 PR 코멘트/이슈에 게시
- ❌ Match Password를 간단한 단어로 설정
- ❌ App Store Connect API Key에 Admin 권한 부여
- ❌ 디버깅 목적으로 Secret 출력

---

## 참고 문서

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)
- [Fastlane Match](https://docs.fastlane.tools/actions/match/)
- [Firebase CI Documentation](https://firebase.google.com/docs/cli#cli-ci-systems)
- [docs/SETUP_GUIDE.md](SETUP_GUIDE.md) - 로컬 설정 가이드
