# Config 폴더

환경별 API Key와 Firebase 설정을 관리합니다.

## 📋 목차

1. [환경 구성](#환경-구성)
2. [Secret Config 시스템](#secret-config-시스템)
3. [초기 설정 방법](#초기-설정-방법)
4. [Secrets 관리 명령어](#secrets-관리-명령어)
5. [생성되는 파일](#생성되는-파일)
6. [CI/CD 설정](#cicd-설정)

---

## 환경 구성

Promiso는 **3개의 Firebase 프로젝트**로 분리되어 있습니다:

| 환경 | Firebase Project | Bundle ID | 용도 |
|------|------------------|-----------|------|
| **Dev** | `promiso-dev` | `com.promiso.dev` | 로컬 개발 |
| **Stage** | `promiso-stage` | `com.promiso.stage` | QA/스테이징 |
| **Prod** | `promiso-prod` | `com.promiso` | 프로덕션 |

---

## Secret Config 시스템

### 구조

```
API Keys 저장소
├─ Notion Database (팀 공유) ⭐ 추천
└─ .env 파일 (로컬 개발)
     ↓
[스크립트 실행]
     ↓
xcconfig 파일 생성
├─ Config/Dev.xcconfig
├─ Config/Stage.xcconfig
└─ Config/Prod.xcconfig
     ↓
Xcode 빌드 시 사용
```

### 관리되는 API Key

#### iOS 앱에서 사용 (xcconfig에 포함)

```
✅ GOOGLE_CLIENT_ID              (Google 로그인)
✅ GOOGLE_REVERSED_CLIENT_ID     (Google 로그인 URL Scheme)
✅ KAKAO_NATIVE_APP_KEY          (Kakao 로그인)
```

#### Firebase Functions에서만 사용 (xcconfig 제외)

```
❌ KAKAO_REST_API_KEY            (Functions 전용)
❌ NOTION_API_KEY                (Functions 전용)
```
→ 이들은 **Google Cloud Secret Manager**에서 별도 관리

---

## 초기 설정 방법

### 방법 1: Notion 동기화 (팀 협업, 추천) ⭐

**전제 조건**: 팀에서 Notion API Key 받기

```bash
# 1. Notion API Key 환경변수 설정
export NOTION_API_KEY="ntn_xxxxxxxxxxxxx"

# 또는 ~/.zshrc에 영구 저장
echo 'export NOTION_API_KEY="ntn_xxxxxxxxxxxxx"' >> ~/.zshrc
source ~/.zshrc

# 2. Notion → 로컬 동기화
make secrets-pull

# 생성됨:
# ✅ Config/Dev.xcconfig
# ✅ Config/Stage.xcconfig
# ✅ Config/Prod.xcconfig
```

**Notion Database 구조**:
```
┌─────────────────────────────────────────────┐
│ Key                  │ Dev    │ Stage │ Prod │
├─────────────────────────────────────────────┤
│ GOOGLE_CLIENT_ID     │ xxx-dev│ xxx-s │ xxx-p│
│ GOOGLE_REVERSED_...  │ com... │ com...│ com..│
│ KAKAO_NATIVE_APP_KEY │ yyy-dev│ yyy-s │ yyy-p│
└─────────────────────────────────────────────┘
```

**장점**:
- ✅ 팀원 모두 동일한 API Key 사용
- ✅ API Key 변경 시 자동 동기화
- ✅ 중앙 관리로 보안 강화
- ✅ 신입 개발자 온보딩 빠름

---

### 방법 2: .env 파일 (개인 개발)

**직접 API Key를 발급받은 경우**

```bash
# 1. 템플릿 복사
cp .env.template .env

# 2. .env 파일 편집 (총 12개 키)
# GOOGLE_CLIENT_ID_DEV=실제-dev-키.apps.googleusercontent.com
# GOOGLE_REVERSED_CLIENT_ID_DEV=com.googleusercontent.apps.실제-dev-키
# KAKAO_NATIVE_APP_KEY_DEV=실제-dev-카카오-키
# ... (Dev/Stage/Prod 각 3개씩)

# 3. xcconfig 파일 생성
./scripts/generate-xcconfig.sh

# 생성됨:
# ✅ Config/Dev.xcconfig
# ✅ Config/Stage.xcconfig
# ✅ Config/Prod.xcconfig
```

---

### 방법 3: 수동 생성 (비추천)

**템플릿에서 직접 복사**

```bash
# 템플릿 복사
cp Config/Dev.xcconfig.template Config/Dev.xcconfig
cp Config/Stage.xcconfig.template Config/Stage.xcconfig
cp Config/Prod.xcconfig.template Config/Prod.xcconfig

# 각 파일 열어서 API Key 수동 입력
# GOOGLE_CLIENT_ID = [실제 키 입력]
# ...
```

⚠️ 이 방법은 오타 위험이 있으므로 **스크립트 사용을 권장**합니다.

---

### GoogleService-Info.plist 배치

Firebase Console에서 각 환경별 파일을 다운로드하여 배치:

```bash
Config/
├── GoogleService-Info-Dev.plist
├── GoogleService-Info-Stage.plist
└── GoogleService-Info-Prod.plist
```

**다운로드 방법**:
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. 프로젝트 선택 (promiso-dev/stage/prod)
3. 프로젝트 설정 → iOS 앱 → `GoogleService-Info.plist` 다운로드
4. 파일명 변경 후 `Config/` 폴더에 배치

---

## Secrets 관리 명령어

### 기본 명령어

```bash
# Notion → 로컬 동기화
make secrets-pull

# 현재 시크릿 목록 보기
make secrets-list

# 새 시크릿 추가 (대화형)
make secrets-add

# Notion → GitHub Secrets 동기화 (CI/CD용)
make secrets-push
```

### 상세 예시

#### 1. 시크릿 목록 확인

```bash
$ make secrets-list

📋 Notion Secrets 목록

┌─ GOOGLE_CLIENT_ID
│  Dev:   123456-dev.apps.go...
│  Stage: 123456-stage.apps....
│  Prod:  123456-prod.apps.g...
└─
┌─ KAKAO_NATIVE_APP_KEY
│  Dev:   abc123dev
│  Stage: abc123stage
│  Prod:  abc123prod
└─
```

#### 2. 새 시크릿 추가

```bash
$ make secrets-add

➕ 새 시크릿 추가

Key 이름: NEW_SERVICE_API_KEY
Dev 값: dev-api-key-123
Stage 값: stage-api-key-456
Prod 값: prod-api-key-789
설명 (선택): 새로운 서비스 API 키

✅ 'NEW_SERVICE_API_KEY' 추가됨

xcconfig 파일도 업데이트할까요? (y/n): y
🔄 Notion에서 시크릿 동기화 중...
✅ Config/Dev.xcconfig 생성됨
✅ Config/Stage.xcconfig 생성됨
✅ Config/Prod.xcconfig 생성됨
🎉 xcconfig 파일 생성 완료!
```

#### 3. GitHub Secrets 동기화

```bash
$ make secrets-push

🔄 GitHub Secrets 업데이트 중...
  📤 GOOGLE_CLIENT_ID_DEV
  📤 GOOGLE_CLIENT_ID_STAGE
  📤 GOOGLE_CLIENT_ID_PROD
  ...
🎉 GitHub Secrets 업데이트 완료!
```

---

## 생성되는 파일

### xcconfig 파일 예시

**Config/Dev.xcconfig**:
```
// Dev Environment Configuration
// 자동 생성됨 - 수동 편집 금지
// Generated at: 2026-02-06 10:30:00

GOOGLE_CLIENT_ID = 123456-dev.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.123456-dev
KAKAO_NATIVE_APP_KEY = abc123dev

// Code Signing
CODE_SIGN_STYLE = Automatic
```

### 파일 목록

| 파일 | Git 추적 | 자동 생성 | 용도 |
|------|---------|----------|------|
| `.env.template` | ✅ | ❌ | 템플릿 |
| `.env` | ❌ | ❌ | 로컬 개발 (수동 작성) |
| `Config/*.xcconfig.template` | ✅ | ❌ | 템플릿 |
| `Config/Dev.xcconfig` | ❌ | ✅ | **Xcode 빌드 시 사용** |
| `Config/Stage.xcconfig` | ❌ | ✅ | **Xcode 빌드 시 사용** |
| `Config/Prod.xcconfig` | ❌ | ✅ | **Xcode 빌드 시 사용** |
| `Config/GoogleService-Info-*.plist` | ❌ | ❌ | Firebase 설정 |

---

## CI/CD 설정

### GitHub Secrets

GitHub Actions에서 사용하기 위해 Secrets를 설정:

```bash
# 자동 동기화
make secrets-push

# 또는 수동 설정
# GitHub 레포 → Settings → Secrets and variables → Actions
```

**필요한 Secrets**:
```
GOOGLE_CLIENT_ID_DEV
GOOGLE_REVERSED_CLIENT_ID_DEV
KAKAO_NATIVE_APP_KEY_DEV

GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE

GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
```

### GitHub Actions 워크플로우 예시

```yaml
- name: Generate xcconfig files
  env:
    GOOGLE_CLIENT_ID_DEV: ${{ secrets.GOOGLE_CLIENT_ID_DEV }}
    GOOGLE_REVERSED_CLIENT_ID_DEV: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_DEV }}
    KAKAO_NATIVE_APP_KEY_DEV: ${{ secrets.KAKAO_NATIVE_APP_KEY_DEV }}
    # ... 나머지
  run: ./scripts/generate-xcconfig.sh
```

---

## 보안

### ⚠️ 절대 커밋하지 말 것

```
# xcconfig 파일 (자동 생성)
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig

# 환경변수 파일
.env
.env.local

# Firebase 설정 파일
Config/GoogleService-Info-*.plist
```

이들은 `.gitignore`에 포함되어 있습니다.

### ✅ 커밋 가능

```
# 템플릿 파일만
Config/*.xcconfig.template
.env.template

# 스크립트
scripts/generate-xcconfig.sh
scripts/sync-secrets.sh
```

---

## API 키 얻는 방법

### Google OAuth Client ID

1. [Google Cloud Console](https://console.cloud.google.com/) 접속
2. Firebase 프로젝트 선택 (promiso-dev/stage/prod)
3. **APIs & Services → Credentials**
4. **Create Credentials → OAuth 2.0 Client ID**
5. Application type: **iOS**
6. Bundle ID 입력
7. Client ID와 iOS URL scheme 복사

### Kakao Native App Key

1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 앱 생성 또는 선택
3. **앱 설정 → 요약 정보**
4. **Native App Key** 확인 (iOS 앱용)
5. 복사

> **Note**: Kakao REST API Key는 Firebase Functions에서 사용하므로 xcconfig에 포함 안 함

---

## 문제 해결

### "xcconfig file not found" 에러

```bash
# 해결: xcconfig 파일 생성
make secrets-pull
# 또는
./scripts/generate-xcconfig.sh
```

### OAuth 로그인 실패

**원인**: Google Client ID가 환경에 맞지 않음

**확인**:
```bash
# Dev.xcconfig 내용 확인
cat Config/Dev.xcconfig | grep GOOGLE_CLIENT_ID
```

### Notion API 연결 실패

```bash
# NOTION_API_KEY 확인
echo $NOTION_API_KEY

# 설정되지 않았다면
export NOTION_API_KEY="ntn_xxxxx"
```

---

## 📚 관련 문서

- [📘 로컬 환경 설정](../docs/LOCAL_SETUP.md)
- [🔒 보안 정책](../SECURITY.md)
- [📦 Notion 백업](../docs/SECRETS_BACKUP_NOTION.md)
- [✅ 백업 체크리스트](../docs/BACKUP_CHECKLIST.md)

---

**마지막 업데이트**: 2026-02-06 (Notion 동기화 방식 추가)
