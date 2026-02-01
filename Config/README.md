# Config 폴더

환경별 설정 파일들을 관리합니다.

## 환경 구성

Promiso는 3개의 Firebase 프로젝트로 분리되어 있습니다:
- **Dev**: 개발 환경 (`promiso-dev`)
- **Stage**: 스테이징 환경 (`promiso-stage`)
- **Prod**: 프로덕션 환경 (`promiso-prod`)

## 초기 설정 (로컬 개발)

### 방법 1: 자동 생성 스크립트 사용 (권장) ⭐

```bash
# 1. .env 파일 생성 및 API 키 입력
cp .env.template .env
# .env 파일을 열어 실제 API 키 입력

# 2. xcconfig 파일 자동 생성
./scripts/generate-xcconfig.sh
```

### 방법 2: 수동 생성

템플릿 파일을 복사하여 실제 설정 파일을 생성하세요:

```bash
# Dev 환경
cp Config/Dev.xcconfig.template Config/Dev.xcconfig

# Stage 환경
cp Config/Stage.xcconfig.template Config/Stage.xcconfig

# Prod 환경
cp Config/Prod.xcconfig.template Config/Prod.xcconfig
```

각 xcconfig 파일을 열어 실제 API 키를 입력하세요:

**Dev.xcconfig**
```
GOOGLE_CLIENT_ID = [Dev Google Client ID]
GOOGLE_REVERSED_CLIENT_ID = [Dev Google Reversed Client ID]
KAKAO_NATIVE_APP_KEY = [Dev Kakao Native App Key]
KAKAO_REST_API_KEY = [Dev Kakao REST API Key]
```

**Stage.xcconfig, Prod.xcconfig도 동일하게 설정**

### 3. GoogleService-Info.plist 배치

Firebase Console에서 각 환경별 GoogleService-Info.plist를 다운로드하여 배치:

```
Config/
├── GoogleService-Info-Dev.plist
├── GoogleService-Info-Stage.plist
└── GoogleService-Info-Prod.plist
```

## CI/CD 설정

GitHub Actions에서는 Secrets에 환경변수를 설정하면 `scripts/generate-xcconfig.sh`가 자동으로 xcconfig 파일을 생성합니다.

### 필요한 GitHub Secrets

```
# Dev Environment
GOOGLE_CLIENT_ID_DEV
GOOGLE_REVERSED_CLIENT_ID_DEV
KAKAO_NATIVE_APP_KEY_DEV
KAKAO_REST_API_KEY_DEV

# Stage Environment
GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE
KAKAO_REST_API_KEY_STAGE

# Production Environment
GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
KAKAO_REST_API_KEY_PROD
```

### GitHub Secrets 설정 방법

1. GitHub 레포지토리 → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. 위 목록의 각 변수명과 값을 입력

GitHub Actions 워크플로우에서는 다음과 같이 사용됩니다:

```yaml
- name: Generate xcconfig files
  env:
    GOOGLE_CLIENT_ID_DEV: ${{ secrets.GOOGLE_CLIENT_ID_DEV }}
    GOOGLE_REVERSED_CLIENT_ID_DEV: ${{ secrets.GOOGLE_REVERSED_CLIENT_ID_DEV }}
    # ... 나머지 secrets
  run: ./scripts/generate-xcconfig.sh
```

## Build Configuration

Xcode에서 환경별로 빌드할 수 있습니다:

- **Debug-Dev**: 개발 환경 (Dev.xcconfig 사용)
- **Debug-Stage**: 스테이징 환경 (Stage.xcconfig 사용)
- **Release-Prod**: 프로덕션 환경 (Prod.xcconfig 사용)

## 보안

⚠️ **중요**: 다음 파일들은 절대 커밋하지 마세요!

```
# xcconfig 파일들 (자동 생성됨)
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig

# 환경변수 파일 (로컬 개발용)
.env
.env.local

# GoogleService-Info.plist (환경별)
Config/GoogleService-Info-*.plist
Projects/App/Resources-Dev/GoogleService-Info.plist
Projects/App/Resources-Stage/GoogleService-Info.plist
Projects/App/Resources-Prod/GoogleService-Info.plist
```

이 파일들은 `.gitignore`에 포함되어 있습니다.

**커밋 가능한 파일**:
```
# 템플릿 파일들만 커밋
Config/*.xcconfig.template
.env.template
```

## API 키 얻는 방법

### Google OAuth Client ID

1. [Google Cloud Console](https://console.cloud.google.com/)에서 각 Firebase 프로젝트 선택
2. **APIs & Services > Credentials**
3. OAuth 2.0 Client ID 생성 (iOS)
4. Client ID와 iOS URL scheme 복사

### Kakao API Keys

1. [Kakao Developers](https://developers.kakao.com/)에서 앱 생성
2. **앱 설정 > 요약 정보**에서 Native App Key 확인
3. **앱 설정 > 앱 키**에서 REST API Key 확인

## 문제 해결

### "xcconfig file not found" 에러

→ 템플릿 파일을 복사하여 실제 xcconfig 파일을 생성했는지 확인하세요.

### 빌드는 되지만 OAuth 로그인 실패

→ Google Client ID가 올바른 환경에 맞게 설정되었는지 확인하세요.
