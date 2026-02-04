# 로컬 환경 설정 가이드

> **Promiso iOS App** - 처음 개발 환경을 설정하는 가이드

---

## 📋 목차

1. [시작하기 전에](#시작하기-전에)
2. [필수 도구 설치](#필수-도구-설치)
3. [저장소 클론](#저장소-클론)
4. [Config 설정](#config-설정)
5. [Firebase 설정](#firebase-설정)
6. [의존성 설치](#의존성-설치)
7. [빌드 및 실행](#빌드-및-실행)
8. [문제 해결](#문제-해결)

---

## 🚀 시작하기 전에

### 필요한 것

- **Mac**: macOS 14.0 (Sonoma) 이상
- **Xcode**: 26.0 이상
- **Apple Developer Account**: 디바이스 테스트 시 필요
- **팀 권한**: GitHub Repository 접근 권한
- **API Keys**: Notion 백업 페이지 또는 팀 관리자에게 요청

### 예상 소요 시간

- **신규 설정**: 약 30분
- **기존 백업 복원**: 약 10분

---

## 🛠️ 필수 도구 설치

### 1. Homebrew

```bash
# Homebrew 설치 (없는 경우)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 설치 확인
brew --version
```

### 2. Tuist

```bash
# Tuist 설치
curl -Ls https://install.tuist.io | bash

# 설치 확인
tuist version
# 출력: 4.65.7 이상
```

### 3. Firebase CLI (선택사항)

Firebase Functions 개발 시 필요:

```bash
# Firebase CLI 설치
brew install firebase-cli

# 또는 npm으로 설치
npm install -g firebase-tools

# 설치 확인
firebase --version
```

---

## 📦 저장소 클론

### 1. Git 클론

```bash
# 저장소 클론
git clone https://github.com/YOUR_ORG/Promiso.git
cd Promiso

# 브랜치 확인
git branch -a

# 특정 브랜치로 체크아웃 (필요시)
git checkout develop
```

### 2. 디렉토리 구조 확인

```bash
# 프로젝트 구조 확인
ls -la

# 주요 디렉토리:
# - Projects/         : 앱 모듈들
# - Config/           : 환경 설정 (설정 필요)
# - infra/firebase/   : Firebase Functions
# - scripts/          : 빌드 스크립트
# - .claude/          : AI 개발 도구
```

---

## ⚙️ Config 설정

### 옵션 A: 템플릿에서 생성 (처음 설정)

**1단계: 환경 변수 파일 생성**

```bash
# .env 파일 생성
cp .env.template .env

# 편집기로 열기
nano .env
# 또는
code .env
```

**2단계: API Keys 입력**

`.env` 파일에 실제 API Keys 입력:

```bash
# Dev Environment
GOOGLE_CLIENT_ID_DEV=809932911903-ugv4efpvkv09e3fq4hs4ccnv33mtj936.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID_DEV=com.googleusercontent.apps.809932911903-ugv4efpvkv09e3fq4hs4ccnv33mtj936
KAKAO_NATIVE_APP_KEY_DEV=9351400ec18c40be1006b22747d7216a
KAKAO_REST_API_KEY_DEV=[팀원에게 요청]

# Stage Environment
GOOGLE_CLIENT_ID_STAGE=[팀원에게 요청]
GOOGLE_REVERSED_CLIENT_ID_STAGE=[팀원에게 요청]
KAKAO_NATIVE_APP_KEY_STAGE=[팀원에게 요청]
KAKAO_REST_API_KEY_STAGE=[팀원에게 요청]

# Production Environment
GOOGLE_CLIENT_ID_PROD=367716701610-efrvms6v48eldljh34falbhclkvsrqvt.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID_PROD=com.googleusercontent.apps.367716701610-efrvms6v48eldljh34falbhclkvsrqvt
KAKAO_NATIVE_APP_KEY_PROD=85c9fc88501e426b848242e7c02d20af
KAKAO_REST_API_KEY_PROD=[팀원에게 요청]
```

**3단계: xcconfig 파일 자동 생성**

```bash
# 자동 생성 스크립트 실행
./scripts/generate-xcconfig.sh

# 생성 확인
ls -la Config/
# Dev.xcconfig, Stage.xcconfig, Prod.xcconfig 파일 생성됨
```

---

### 옵션 B: 백업에서 복원 (기존 팀원)

```bash
# 1. 백업 zip 파일 압축 해제
unzip ~/Downloads/Promiso-Config-Backup.zip

# 2. Config 디렉토리로 복사
cp -r Promiso-Config/*.xcconfig Config/
cp -r Promiso-Config/GoogleService-Info-*.plist Config/

# 3. .env 파일 복사 (있는 경우)
cp Promiso-Config/.env .

# 4. Firebase Functions .env 복사
cp Promiso-Config/functions.env infra/firebase/functions/.env

# 5. 파일 확인
ls -la Config/
```

---

## 🔥 Firebase 설정

### 1. GoogleService-Info.plist 다운로드

**각 환경별로 Firebase Console에서 다운로드:**

#### Dev 환경
1. [Firebase Console - promiso-dev](https://console.firebase.google.com/project/promiso-dev) 접속
2. 프로젝트 설정 (톱니바퀴 아이콘) → 일반
3. "내 앱" 섹션에서 iOS 앱 선택
4. `GoogleService-Info.plist` 다운로드
5. 파일명을 `GoogleService-Info-Dev.plist`로 변경
6. `Config/` 디렉토리에 배치

#### Stage 환경
1. [Firebase Console - promiso-stage](https://console.firebase.google.com/project/promiso-stage) 접속
2. 동일한 과정 반복
3. `GoogleService-Info-Stage.plist`로 저장

#### Prod 환경
1. [Firebase Console - promiso-prod](https://console.firebase.google.com/project/promiso-prod) 접속
2. 동일한 과정 반복
3. `GoogleService-Info-Prod.plist`로 저장

### 2. Firebase Functions 환경 변수 (선택사항)

Functions 개발 시에만 필요:

```bash
# infra/firebase/functions 디렉토리로 이동
cd infra/firebase/functions

# .env 파일 생성
cp .env.template .env

# 편집
nano .env
```

`.env` 파일에 입력:
```
GEMINI_API_KEY=[팀원에게 요청]
NOTION_FAQ_API_KEY=[팀원에게 요청]
KAKAO_REST_API_KEY=[팀원에게 요청]
```

---

## 📥 의존성 설치

### 1. Tuist 의존성 설치

```bash
# 루트 디렉토리에서 실행
tuist install

# 출력:
# Installing dependencies...
# Dependencies installed successfully
```

### 2. Xcode 프로젝트 생성

```bash
# Tuist로 Xcode 프로젝트 생성
tuist generate

# 출력:
# Generating workspace Promiso.xcworkspace
# Generating project Projects/App/Promiso.xcodeproj
# ...
```

### 3. Firebase Functions 의존성 (선택사항)

Functions 개발 시:

```bash
cd infra/firebase/functions

# Node.js 의존성 설치
npm install

# 또는 yarn
yarn install

cd ../../..
```

---

## 🏃 빌드 및 실행

### 1. Xcode에서 열기

```bash
# Workspace 열기
open Promiso.xcworkspace
```

또는 Finder에서 `Promiso.xcworkspace` 더블 클릭

### 2. 환경 선택

Xcode 상단 스킴 선택:
- **PromisoDev**: Dev 환경 (개발용)
- **PromisoStage**: Stage 환경 (테스트용)
- **Promiso**: Prod 환경 (프로덕션)

![Scheme Selector](https://via.placeholder.com/400x100?text=Xcode+Scheme+Selector)

### 3. 시뮬레이터 빌드

```bash
# 터미널에서 빌드 (선택사항)
tuist build PromisoDev

# 또는 Xcode에서 Cmd+B
```

### 4. 앱 실행

- Xcode에서 **Cmd+R** 또는 재생 버튼 클릭
- 시뮬레이터가 실행되고 앱이 설치됨

### 5. 실제 디바이스 테스트

**Apple Developer 계정 필요**:

1. Xcode → Settings → Accounts
2. Apple ID 추가
3. Signing & Capabilities에서 Team 선택
4. 디바이스 연결 후 실행

---

## ✅ 설정 확인 체크리스트

모든 설정이 완료되었는지 확인:

- [ ] Tuist 설치됨 (`tuist version`)
- [ ] 저장소 클론됨
- [ ] `.env` 파일 생성 및 API Keys 입력
- [ ] `Config/*.xcconfig` 파일 생성됨
- [ ] `Config/GoogleService-Info-*.plist` 배치됨
- [ ] `tuist install` 실행 완료
- [ ] `tuist generate` 실행 완료
- [ ] `Promiso.xcworkspace` 열림
- [ ] Dev 환경 빌드 성공
- [ ] 시뮬레이터 실행 성공

---

## 🔧 문제 해결

### 빌드 에러: "xcconfig file not found"

**원인**: Config 파일이 생성되지 않음

**해결**:
```bash
# 파일 존재 확인
ls -la Config/

# 없으면 생성
./scripts/generate-xcconfig.sh

# 또는 수동 복사
cp Config/Dev.xcconfig.template Config/Dev.xcconfig
```

### 빌드 에러: "GoogleService-Info.plist not found"

**원인**: Firebase 설정 파일이 없음

**해결**:
```bash
# Config 디렉토리 확인
ls -la Config/GoogleService-Info-*.plist

# 없으면 Firebase Console에서 다운로드
# (위 "Firebase 설정" 섹션 참고)
```

### 빌드 에러: "Tuist command not found"

**원인**: Tuist가 설치되지 않음

**해결**:
```bash
# Tuist 설치
curl -Ls https://install.tuist.io | bash

# 또는 Homebrew로
brew install tuist
```

### 런타임 에러: "Google Sign In failed"

**원인**: 잘못된 Google Client ID

**해결**:
1. `.env` 파일 확인
2. Notion 백업 페이지에서 올바른 Client ID 복사
3. `./scripts/generate-xcconfig.sh` 재실행
4. Xcode Clean Build (Cmd+Shift+K)
5. 재빌드

### 런타임 에러: "Kakao Login failed"

**원인**: 잘못된 Kakao App Key

**해결**:
1. [Kakao Developers](https://developers.kakao.com/) 접속
2. 앱 선택 → 앱 키 확인
3. `.env` 파일의 `KAKAO_NATIVE_APP_KEY` 업데이트
4. xcconfig 재생성 및 재빌드

### 빌드 느림 / 캐시 문제

**해결**:
```bash
# Tuist 캐시 정리
tuist clean

# Xcode Derived Data 정리
rm -rf ~/Library/Developer/Xcode/DerivedData

# 재생성
tuist generate
```

### Firebase Functions 에러

**원인**: Node.js 의존성 문제

**해결**:
```bash
cd infra/firebase/functions

# node_modules 삭제 후 재설치
rm -rf node_modules
npm install

# 또는
yarn install
```

---

## 🚀 다음 단계

설정이 완료되었다면:

1. **개발 가이드 읽기**: [DEVELOPMENT.md](DEVELOPMENT.md)
2. **TCA 아키텍처 이해**: [ARCHITECTURE.md](ARCHITECTURE.md)
3. **Feature 만들기**: `make feature FEATURE_NAME=MyFeature`
4. **Git 컨벤션 확인**: [.claude/CLAUDE.md](../.claude/CLAUDE.md)
5. **AI 개발 도구 활용**: Claude Code 사용

---

## 📚 관련 문서

- [Config 설정](../Config/README.md)
- [보안 가이드](../SECURITY.md)
- [Notion 백업 템플릿](SECRETS_BACKUP_NOTION.md)
- [개발 가이드](DEVELOPMENT.md)
- [환경별 설정](ENVIRONMENT.md)

---

## 💬 도움 받기

문제가 해결되지 않으면:

- **Slack**: #promiso-dev 채널
- **GitHub Issues**: [링크](https://github.com/YOUR_ORG/Promiso/issues)
- **팀 관리자**: [이름] (@username)

---

**작성자**: Claude Sonnet 4.5
**마지막 업데이트**: 2026-02-04
