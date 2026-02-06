# 환경 설정 가이드

Promiso는 Dev/Stage/Prod 3개 환경으로 분리되어 있으며, 각 환경마다 독립적인 Firebase 프로젝트와 API 키를 사용합니다.

## 문서 메타

- 목적: 환경 파일 구성과 로컬 빌드 환경 설정 기준 제공
- 대상 독자: 로컬 실행/환경 구성 담당자
- 최종 수정일: 2026-02-06
- 관련 문서: [README.md](README.md) · [SETUP_GUIDE.md](SETUP_GUIDE.md) · [DEVELOPMENT.md](DEVELOPMENT.md)

## 범위 안내

- 이 문서: Dev/Stage/Prod 환경 구성과 xcconfig/plist 설정
- 새 컴퓨터 온보딩 절차: [SETUP_GUIDE.md](SETUP_GUIDE.md)
- 기능 개발 실무 규칙: [DEVELOPMENT.md](DEVELOPMENT.md)

## 📋 목차

1. [환경 개요](#환경-개요)
2. [로컬 개발 설정](#로컬-개발-설정)
3. [환경별 빌드](#환경별-빌드)
4. [API 키 발급](#api-키-발급)
5. [문제 해결](#문제-해결)

---

## 환경 개요

### 환경 구분

| 환경 | Bundle ID | Firebase 프로젝트 | 용도 |
|------|-----------|-------------------|------|
| **Dev** | `com.promiso.dev` | `promiso-dev` | 로컬 개발, 빠른 테스트 |
| **Stage** | `com.promiso.stage` | `promiso-stage` | QA, 통합 테스트 |
| **Prod** | `com.promiso` | `promiso-prod` | 프로덕션, App Store |

### 환경별 구성 요소

각 환경은 다음 파일들로 구성됩니다:

```
Config/
├── Dev.xcconfig                        # Dev 환경 API 키
├── Stage.xcconfig                      # Stage 환경 API 키
├── Prod.xcconfig                       # Prod 환경 API 키
├── GoogleService-Info-Dev.plist        # Dev Firebase 설정
├── GoogleService-Info-Stage.plist      # Stage Firebase 설정
└── GoogleService-Info-Prod.plist       # Prod Firebase 설정

Projects/App/
├── Resources-Dev/                      # Dev 리소스 (AppIcon, Assets)
├── Resources-Stage/                    # Stage 리소스
├── Resources-Prod/                     # Prod 리소스
├── PromisoDev.entitlements             # Dev Entitlements
├── PromisoStage.entitlements           # Stage Entitlements
└── Promiso.entitlements                # Prod Entitlements
```

---

## 로컬 개발 설정

### 방법 1: 자동 생성 스크립트 (권장 ⭐)

#### 1. .env 파일 생성

```bash
# 템플릿 복사
cp .env.template .env

# .env 파일 편집
# 각 환경별 API 키 입력
```

**.env 파일 예시**:
```bash
# Dev 환경
GOOGLE_CLIENT_ID_DEV=your-dev-client-id
GOOGLE_REVERSED_CLIENT_ID_DEV=com.googleusercontent.apps.your-dev-id
KAKAO_NATIVE_APP_KEY_DEV=your-dev-kakao-key
KAKAO_REST_API_KEY_DEV=your-dev-kakao-rest-key

# Stage 환경
GOOGLE_CLIENT_ID_STAGE=your-stage-client-id
GOOGLE_REVERSED_CLIENT_ID_STAGE=com.googleusercontent.apps.your-stage-id
KAKAO_NATIVE_APP_KEY_STAGE=your-stage-kakao-key
KAKAO_REST_API_KEY_STAGE=your-stage-kakao-rest-key

# Prod 환경
GOOGLE_CLIENT_ID_PROD=your-prod-client-id
GOOGLE_REVERSED_CLIENT_ID_PROD=com.googleusercontent.apps.your-prod-id
KAKAO_NATIVE_APP_KEY_PROD=your-prod-kakao-key
KAKAO_REST_API_KEY_PROD=your-prod-kakao-rest-key
```

#### 2. xcconfig 파일 자동 생성

```bash
./scripts/generate-xcconfig.sh
```

생성된 파일:
- `Config/Dev.xcconfig`
- `Config/Stage.xcconfig`
- `Config/Prod.xcconfig`

#### 3. Firebase plist 파일 배치

```bash
# Firebase Console에서 다운로드 후 복사
./scripts/copy-firebase-config.sh
```

또는 수동으로:
```bash
# Firebase Console에서 각 프로젝트의 GoogleService-Info.plist 다운로드
cp ~/Downloads/GoogleService-Info-Dev.plist Config/
cp ~/Downloads/GoogleService-Info-Stage.plist Config/
cp ~/Downloads/GoogleService-Info-Prod.plist Config/

# 스크립트 실행
./scripts/copy-firebase-config.sh
```

### 방법 2: 수동 생성

#### 1. xcconfig 파일 생성

```bash
# 템플릿 복사
cp Config/Dev.xcconfig.template Config/Dev.xcconfig
cp Config/Stage.xcconfig.template Config/Stage.xcconfig
cp Config/Prod.xcconfig.template Config/Prod.xcconfig

# 각 파일 편집하여 실제 API 키 입력
```

**Dev.xcconfig 예시**:
```
// Google OAuth
GOOGLE_CLIENT_ID = 306291841913-abc123.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.306291841913-abc123

// Kakao Login
KAKAO_NATIVE_APP_KEY = a1b2c3d4e5f6g7h8i9j0
KAKAO_REST_API_KEY = k1l2m3n4o5p6q7r8s9t0
```

#### 2. Firebase plist 수동 배치

```bash
# 다운로드한 plist 파일을 직접 복사
cp ~/Downloads/GoogleService-Info.plist Config/GoogleService-Info-Dev.plist
cp ~/Downloads/GoogleService-Info.plist Config/GoogleService-Info-Stage.plist
cp ~/Downloads/GoogleService-Info.plist Config/GoogleService-Info-Prod.plist

# 스크립트로 자동 배치
./scripts/copy-firebase-config.sh
```

---

## 환경별 빌드

### Tuist 환경 변수

Tuist는 `TUIST_ENV` 환경 변수로 빌드 환경을 선택합니다:

```bash
# Dev 환경 (기본값)
tuist generate
# 또는
TUIST_ENV=dev tuist generate

# Stage 환경
TUIST_ENV=stage tuist generate

# Prod 환경
TUIST_ENV=prod tuist generate
```

### 환경별 빌드 명령어

```bash
# Dev 빌드
tuist build PromisoDev

# Stage 빌드
TUIST_ENV=stage tuist generate
tuist build PromisoStage

# Prod 빌드
TUIST_ENV=prod tuist generate
tuist build Promiso
```

### Xcode에서 환경 전환

1. Xcode에서 Scheme 선택:
   - **PromisoDev**: Dev 환경
   - **PromisoStage**: Stage 환경
   - **Promiso**: Prod 환경

2. Build Configuration:
   - Debug: 개발 중
   - Release: 배포용

---

## API 키 발급

### Google OAuth Client ID

#### 1. Google Cloud Console 접속

[Google Cloud Console](https://console.cloud.google.com/) → Firebase 프로젝트 선택

#### 2. OAuth Client ID 생성

1. **APIs & Services > Credentials**
2. **+ CREATE CREDENTIALS > OAuth client ID**
3. **Application type**: iOS
4. **Bundle ID** 입력:
   - Dev: `com.promiso.dev`
   - Stage: `com.promiso.stage`
   - Prod: `com.promiso`

#### 3. 값 복사

- **Client ID**: `GOOGLE_CLIENT_ID`로 사용
- **iOS URL scheme**: `GOOGLE_REVERSED_CLIENT_ID`로 사용

### Kakao API Keys

#### 1. Kakao Developers 접속

[Kakao Developers](https://developers.kakao.com/) → 앱 생성

#### 2. 플랫폼 추가

1. **내 애플리케이션 > 앱 설정 > 플랫폼**
2. **iOS 플랫폼 추가**
3. Bundle ID 입력 (`com.promiso.dev` 등)

#### 3. 키 확인

1. **앱 설정 > 요약 정보**
   - **네이티브 앱 키**: `KAKAO_NATIVE_APP_KEY`
2. **앱 설정 > 앱 키**
   - **REST API 키**: `KAKAO_REST_API_KEY`

### Firebase GoogleService-Info.plist

#### 1. Firebase Console 접속

[Firebase Console](https://console.firebase.google.com/) → 프로젝트 선택

#### 2. iOS 앱 추가 (없는 경우)

1. **프로젝트 개요 > iOS 앱 추가**
2. Bundle ID 입력
3. GoogleService-Info.plist 다운로드

#### 3. 기존 앱에서 다운로드

1. **프로젝트 설정 > 일반**
2. iOS 앱 선택
3. **GoogleService-Info.plist 다운로드**

---

## 문제 해결

### "xcconfig file not found" 에러

**원인**: xcconfig 파일이 생성되지 않음

**해결**:
```bash
# 스크립트로 자동 생성
./scripts/generate-xcconfig.sh

# 또는 수동 생성
cp Config/Dev.xcconfig.template Config/Dev.xcconfig
# API 키 입력 후 저장
```

### "GoogleService-Info.plist not found" 에러

**원인**: Firebase plist 파일이 배치되지 않음

**해결**:
```bash
# Firebase Console에서 다운로드 후
cp ~/Downloads/GoogleService-Info.plist Config/GoogleService-Info-Dev.plist
./scripts/copy-firebase-config.sh
```

### OAuth 로그인 실패

**원인**: Google Client ID가 잘못됨

**확인 사항**:
1. Google Cloud Console에서 Client ID 재확인
2. Bundle ID가 정확한지 확인
3. `.env` 또는 `xcconfig` 파일에 올바르게 입력되었는지 확인

```bash
# 현재 설정 확인
cat Config/Dev.xcconfig | grep GOOGLE_CLIENT_ID
```

### Kakao 로그인 실패

**원인**: Kakao Native App Key가 잘못됨

**확인 사항**:
1. Kakao Developers에서 앱 키 재확인
2. 플랫폼 설정에 Bundle ID가 등록되었는지 확인
3. URL Scheme이 `kakao${KAKAO_NATIVE_APP_KEY}` 형식인지 확인

### 환경이 바뀌지 않음

**원인**: Tuist 캐시

**해결**:
```bash
# Tuist 캐시 삭제
rm -rf .build
rm -rf ~/Library/Caches/tuist

# 프로젝트 재생성
TUIST_ENV=stage tuist generate
```

---

## 보안 주의사항

### ⚠️ 절대 커밋하지 말 것

```
# xcconfig 파일 (실제 API 키 포함)
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig

# 환경변수 파일
.env
.env.local

# Firebase plist
Config/GoogleService-Info-*.plist
Projects/App/Resources-*/GoogleService-Info.plist
```

### ✅ 커밋 가능

```
# 템플릿 파일만
Config/*.xcconfig.template
.env.template
scripts/generate-xcconfig.sh
scripts/copy-firebase-config.sh
```

### Google Drive 백업 (권장)

백업/복원 운영 절차는 온보딩 문서 기준으로 관리합니다.

- 백업/복원 절차: [SETUP_GUIDE.md](SETUP_GUIDE.md#2-config-폴더-백업복원)
- 이 문서에서는 환경 파일의 생성/검증 규칙만 다룹니다.

---

## 관련 문서

- [🚀 초기 설정 가이드](SETUP_GUIDE.md) - 새 환경 구성
- [🚀 배포 가이드](DEPLOYMENT.md) - GitHub Secrets 설정
- [⚙️ CI/CD](CI_CD.md) - GitHub Actions 워크플로우
