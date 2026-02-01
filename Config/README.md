# Config 폴더

환경별 설정 파일들을 관리합니다.

## 환경 구성

Promiso는 3개의 Firebase 프로젝트로 분리되어 있습니다:
- **Dev**: 개발 환경 (`promiso-dev`)
- **Stage**: 스테이징 환경 (`promiso-stage`)
- **Prod**: 프로덕션 환경 (`promiso-prod`)

## 초기 설정

### 1. xcconfig 파일 생성

템플릿 파일을 복사하여 실제 설정 파일을 생성하세요:

```bash
# Dev 환경
cp Config/Dev.xcconfig.template Config/Dev.xcconfig

# Stage 환경
cp Config/Stage.xcconfig.template Config/Stage.xcconfig

# Prod 환경
cp Config/Prod.xcconfig.template Config/Prod.xcconfig
```

### 2. API 키 입력

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

## Build Configuration

Xcode에서 환경별로 빌드할 수 있습니다:

- **Debug-Dev**: 개발 환경 (Dev.xcconfig 사용)
- **Debug-Stage**: 스테이징 환경 (Stage.xcconfig 사용)
- **Release-Prod**: 프로덕션 환경 (Prod.xcconfig 사용)

## 보안

⚠️ **중요**: 다음 파일들은 절대 커밋하지 마세요!

```
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig
Config/GoogleService-Info-*.plist
```

이 파일들은 `.gitignore`에 포함되어 있습니다.

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
