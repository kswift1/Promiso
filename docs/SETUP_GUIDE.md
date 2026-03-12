# Promiso 프로젝트 초기 설정 가이드

`git clone` 이후 바로 빌드할 수 있도록 만드는 방법입니다.

## 문서 메타

- 목적: 신규/교체 장비에서 개발 시작까지의 온보딩 절차 제공
- 대상 독자: 신규 팀원, 개발 환경 재설치 사용자
- 최종 수정일: 2026-03-12
- 관련 문서: [README.md](README.md) · [ENVIRONMENT.md](ENVIRONMENT.md) · [DEVELOPMENT.md](DEVELOPMENT.md)

## 범위 안내

- 이 문서: 새 컴퓨터 기준 초기 세팅 순서
- 환경별 파일 구조/빌드 전환: [ENVIRONMENT.md](ENVIRONMENT.md)
- 세팅 완료 후 개발 규칙: [DEVELOPMENT.md](DEVELOPMENT.md)

## 📋 목차

1. [새 컴퓨터에서 설정하기](#1-새-컴퓨터에서-설정하기)
2. [Config 폴더 백업/복원](#2-config-폴더-백업복원)
3. [CI/CD 서버 설정](#3-cicd-서버-설정)

---

## 1. 새 컴퓨터에서 설정하기

### ✅ 권장 경로: `make setup`

신규 clone 기준 표준 시작점은 아래 명령입니다.

```bash
git clone https://github.com/kswift1/promiso.git
cd promiso

# 실제 xcconfig까지 한 번에 받을 때
export NOTION_API_KEY="YOUR_NOTION_API_KEY"

make setup
```

`make setup`이 수행하는 작업:
- `tuist install`
- `Config/*.xcconfig` 준비 (`NOTION_API_KEY`가 있으면 동기화, 없으면 template 복사)
- `infra/firebase/functions` 의존성 설치
- `tuist generate`
- Git hooks 설치

부분 복구만 필요할 때는 `make setup`보다 `make ensure-config`를 사용합니다.
특히 이미 준비된 `Config/*.xcconfig`를 유지하면서 누락 파일만 보완하고 싶을 때는 `make ensure-config`가 더 안전합니다.

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

#### Step 3: 환경값/설정 파일 준비

아래 문서를 기준으로 `.env`, `xcconfig`, `GoogleService-Info.plist`를 준비합니다.

- 환경 파일 구성/명령어: [ENVIRONMENT.md](ENVIRONMENT.md)
- API 키 발급 절차: [ENVIRONMENT.md](ENVIRONMENT.md#api-키-발급)

#### Step 4: 설정 반영 스크립트 실행

```bash
./scripts/generate-xcconfig.sh
./scripts/copy-firebase-config.sh
```

#### Step 5: 빌드

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

GitHub Actions 시크릿 등록과 배포 워크플로우는 아래 문서를 기준으로 관리합니다.

- 시크릿 항목/등록 방법: [DEPLOYMENT.md](DEPLOYMENT.md)
- 워크플로우 동작/트러블슈팅: [CI_CD.md](CI_CD.md)

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
- [ ] [ENVIRONMENT.md](ENVIRONMENT.md) 기준으로 `.env`/`xcconfig`/plist 준비
- [ ] `./scripts/generate-xcconfig.sh` 실행
- [ ] `./scripts/copy-firebase-config.sh` 실행
- [ ] `tuist generate && tuist build PromisoDev` 성공
- [ ] Config 폴더 Google Drive에 백업

**총 10분 소요**

---

## 🆘 문제 해결

### "xcconfig file not found" 에러

```bash
# 깨끗한 clone 직후라면
make setup

# 기존 설정을 유지한 채 누락만 보완하려면
make ensure-config
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
# 해결: 아래 문서를 기준으로 점검
# - docs/DEPLOYMENT.md (시크릿 등록)
# - docs/CI_CD.md (워크플로우 로그 확인)
```

---

## 📚 관련 문서

- [Config/README.md](../Config/README.md) - 설정 파일 상세 설명
- [docs/ENVIRONMENT.md](ENVIRONMENT.md) - 로컬 환경 구성/키 발급
- [docs/DEPLOYMENT.md](DEPLOYMENT.md) - CI 배포/시크릿 기준
- [docs/CI_CD.md](CI_CD.md) - GitHub Actions 워크플로우
- [.env.template](../.env.template) - 환경변수 템플릿
