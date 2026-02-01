# Promiso 프로젝트 초기 설정 가이드

`git clone` 이후 바로 빌드할 수 있도록 만드는 방법입니다.

## 📋 목차

1. [새 컴퓨터에서 설정하기](#1-새-컴퓨터에서-설정하기)
2. [Config 폴더 백업/복원](#2-config-폴더-백업복원)
3. [CI/CD 서버 설정](#3-cicd-서버-설정)

---

## 1. 새 컴퓨터에서 설정하기

### ⚡ 방법 1: Google Drive 사용 (가장 빠름)

새 컴퓨터에서 개발을 시작할 때 Google Drive에 백업해둔 Config 폴더를 가져오면 됩니다.

#### Step 1: 저장소 Clone

```bash
git clone https://github.com/kswift1/promiso.git
cd promiso
```

#### Step 2: 필수 도구 설치

```bash
# Tuist 설치
curl -Ls https://install.tuist.io | bash

# Xcode 설치 확인 (16.0+)
xcode-select --install
```

#### Step 3: Google Drive에서 Config 다운로드

```bash
# Google Drive "Promiso-Config.zip" 다운로드
# 압축 해제 후 프로젝트 루트에 복사

unzip ~/Downloads/Promiso-Config.zip -d .
# 또는
cp -r ~/Downloads/Promiso-Config/* Config/
```

**Config 폴더 내용:**
```
Config/
├── Dev.xcconfig
├── Stage.xcconfig
├── Prod.xcconfig
├── GoogleService-Info-Dev.plist
├── GoogleService-Info-Stage.plist
└── GoogleService-Info-Prod.plist
```

#### Step 4: Firebase 설정 파일 복사

```bash
./scripts/copy-firebase-config.sh
```

#### Step 5: 빌드

```bash
tuist generate
tuist build PromisoDev
```

**완료! 총 5분 소요**

---

### 🔧 방법 2: 처음부터 설정 (Google Drive 없을 때)

#### Step 1-2: 동일 (Clone, 도구 설치)

#### Step 3: Firebase Console에서 plist 다운로드

각 Firebase 프로젝트에서 GoogleService-Info.plist 다운로드:

1. **Dev 환경**
   - https://console.firebase.google.com/project/promiso-dev
   - 프로젝트 설정 → iOS 앱 → GoogleService-Info.plist 다운로드
   - `Config/GoogleService-Info-Dev.plist`로 저장

2. **Stage 환경**
   - https://console.firebase.google.com/project/promiso-stage
   - `Config/GoogleService-Info-Stage.plist`로 저장

3. **Prod 환경**
   - https://console.firebase.google.com/project/promiso-prod
   - `Config/GoogleService-Info-Prod.plist`로 저장

#### Step 4: .env 파일 생성

```bash
cp .env.template .env
vim .env
```

`.env` 파일에 API 키 입력:
```bash
# Dev
GOOGLE_CLIENT_ID_DEV=306291841913-...
GOOGLE_REVERSED_CLIENT_ID_DEV=com.googleusercontent.apps.306291841913-...
KAKAO_NATIVE_APP_KEY_DEV=85c9fc88501e426b848242e7c02d20af
KAKAO_REST_API_KEY_DEV=eacdef419fafb30e112e6ca22219ee4d

# Stage (동일 구조)
# Prod (동일 구조)
```

#### Step 5: xcconfig 자동 생성

```bash
./scripts/generate-xcconfig.sh
```

#### Step 6: Firebase 설정 파일 복사

```bash
./scripts/copy-firebase-config.sh
```

#### Step 7: 빌드

```bash
tuist generate
tuist build PromisoDev
```

**완료! 총 10분 소요**

---

## 2. Config 폴더 백업/복원

### 📦 백업하기 (현재 컴퓨터 → Google Drive)

로컬에서 개발 중일 때 Config 폴더를 백업해두면 나중에 편합니다.

```bash
# 1. Config 폴더 압축
cd /path/to/promiso
zip -r Promiso-Config.zip Config/

# 2. Google Drive에 업로드
# - 브라우저에서 Google Drive 열기
# - "Promiso 개발" 폴더 만들기
# - Promiso-Config.zip 업로드

# 3. 날짜별로 백업하면 더 좋음
zip -r "Promiso-Config-$(date +%Y-%m-%d).zip" Config/
```

### 🔄 복원하기 (Google Drive → 새 컴퓨터)

```bash
# 1. Google Drive에서 Promiso-Config.zip 다운로드

# 2. 프로젝트 루트에서 압축 해제
cd /path/to/promiso
unzip ~/Downloads/Promiso-Config.zip

# 3. Firebase 설정 복사
./scripts/copy-firebase-config.sh

# 4. 빌드
tuist generate
tuist build PromisoDev
```

### ⚠️ 주의사항

```bash
# Config 폴더에 들어있는 것:
Config/
├── Dev.xcconfig                     # ✅ API 키 포함 (민감)
├── Stage.xcconfig                   # ✅ API 키 포함 (민감)
├── Prod.xcconfig                    # ✅ API 키 포함 (민감)
├── GoogleService-Info-*.plist       # ✅ Firebase 설정 (민감)
├── Dev.xcconfig.template            # ❌ 템플릿 (공개 OK)
├── Stage.xcconfig.template          # ❌ 템플릿 (공개 OK)
├── Prod.xcconfig.template           # ❌ 템플릿 (공개 OK)
└── README.md                        # ❌ 문서 (공개 OK)

# Google Drive 보안 설정:
# - 본인만 접근 가능하도록 설정 (비공개)
# - 절대 Public 링크로 공유하지 말 것
```

---

## 3. CI/CD 서버 설정 (GitHub Actions)

GitHub Actions에서 자동 빌드하려면 Secrets 설정이 필요합니다.

### 📝 GitHub Secrets 등록

**GitHub 레포지토리 → Settings → Secrets and variables → Actions**

#### 1. API 키 Secrets (12개)

```
GOOGLE_CLIENT_ID_DEV
GOOGLE_REVERSED_CLIENT_ID_DEV
KAKAO_NATIVE_APP_KEY_DEV
KAKAO_REST_API_KEY_DEV

GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE
KAKAO_REST_API_KEY_STAGE

GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
KAKAO_REST_API_KEY_PROD
```

**값 확인 방법:**
```bash
# 로컬 Config 폴더에서 확인
cat Config/Dev.xcconfig
cat Config/Stage.xcconfig
cat Config/Prod.xcconfig
```

#### 2. GoogleService-Info.plist Secrets (3개)

```bash
# Base64 인코딩해서 등록
base64 -i Config/GoogleService-Info-Dev.plist | pbcopy
# → GOOGLE_SERVICE_INFO_DEV

base64 -i Config/GoogleService-Info-Stage.plist | pbcopy
# → GOOGLE_SERVICE_INFO_STAGE

base64 -i Config/GoogleService-Info-Prod.plist | pbcopy
# → GOOGLE_SERVICE_INFO_PROD
```

### 🔄 워크플로우 예시

상세한 워크플로우는 `.github/workflows/README.md` 참고

---

## 4. API 키 직접 발급 받기

처음부터 설정해야 하는 경우:

### 🔑 Google OAuth Client ID

#### 새로 생성하는 경우:

1. **Firebase Console** 접속
   - Dev: https://console.firebase.google.com/project/promiso-dev
   - Stage: https://console.firebase.google.com/project/promiso-stage
   - Prod: https://console.firebase.google.com/project/promiso-prod

2. **좌측 메뉴** → 프로젝트 설정 (⚙️)

3. **일반 탭** → iOS 앱 선택

4. **GoogleService-Info.plist 다운로드** 클릭

5. **Google Cloud Console로 이동**
   - 프로젝트 선택 → APIs & Services → Credentials

6. **OAuth 2.0 Client ID 생성**
   - Application type: iOS
   - Bundle ID 입력:
     - Dev: `com.promiso.dev`
     - Stage: `com.promiso.stage`
     - Prod: `com.promiso`

7. **생성된 Client ID 복사**
   ```
   GOOGLE_CLIENT_ID = 306291841913-...apps.googleusercontent.com
   GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.306291841913-...
   ```

### 🟡 Kakao API Keys

#### 새로 생성하는 경우:

1. **Kakao Developers** 접속
   - https://developers.kakao.com/

2. **내 애플리케이션** → 앱 만들기

3. **환경별로 3개 앱 생성**
   - Promiso Dev
   - Promiso Stage
   - Promiso

4. **앱 설정 → 요약 정보**
   ```
   KAKAO_NATIVE_APP_KEY = [네이티브 앱 키]
   ```

5. **앱 설정 → 앱 키**
   ```
   KAKAO_REST_API_KEY = [REST API 키]
   ```

6. **플랫폼 설정**
   - iOS 플랫폼 추가
   - Bundle ID 입력:
     - Dev: `com.promiso.dev`
     - Stage: `com.promiso.stage`
     - Prod: `com.promiso`

---

## 📊 빠른 체크리스트

### 🚀 새 컴퓨터 설정 (Google Drive 있음)

- [ ] `git clone` 완료
- [ ] Tuist 설치
- [ ] Google Drive에서 `Promiso-Config.zip` 다운로드
- [ ] Config 폴더에 압축 해제
- [ ] `./scripts/copy-firebase-config.sh` 실행
- [ ] `tuist generate && tuist build PromisoDev` 성공

**총 5분 소요**

### 🔧 처음부터 설정 (Google Drive 없음)

- [ ] `git clone` 완료
- [ ] Tuist 설치
- [ ] Firebase Console에서 plist 3개 다운로드
- [ ] `.env` 파일 생성 및 API 키 입력
- [ ] `./scripts/generate-xcconfig.sh` 실행
- [ ] `./scripts/copy-firebase-config.sh` 실행
- [ ] `tuist generate && tuist build PromisoDev` 성공
- [ ] Config 폴더 Google Drive에 백업

**총 10분 소요**

---

## 🆘 문제 해결

### "xcconfig file not found" 에러

```bash
# 해결: xcconfig 파일 생성
./scripts/generate-xcconfig.sh
```

### "No such file or directory: GoogleService-Info.plist"

```bash
# 해결: 파일 배치 확인
ls Projects/App/Resources-Dev/GoogleService-Info.plist
ls Projects/App/Resources-Stage/GoogleService-Info.plist
ls Projects/App/Resources-Prod/GoogleService-Info.plist
```

### 빌드는 되지만 OAuth 로그인 실패

```bash
# 해결: Client ID 확인
cat Config/Dev.xcconfig
# GOOGLE_CLIENT_ID가 올바른 환경에 맞는지 확인
```

### CI/CD에서 빌드 실패

```bash
# 해결: GitHub Secrets 확인
# - 12개 API 키 Secrets가 모두 설정되었는지
# - 3개 GoogleService-Info Base64 Secrets가 설정되었는지
# - Secret 이름이 정확한지 (대소문자 구분)
```

---

## 📚 관련 문서

- [Config/README.md](../Config/README.md) - 설정 파일 상세 설명
- [.github/workflows/README.md](../.github/workflows/README.md) - CI/CD 워크플로우 가이드
- [.env.template](../.env.template) - 환경변수 템플릿
