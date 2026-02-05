# Promiso

> 약속이 많은 당신을 위한 가장 똑똑한 약속 앱

<p align="center">
  <img src="docs/images/app-preview.png" alt="Promiso App Preview" width="100%" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18.0+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
  <img src="https://img.shields.io/badge/Xcode-26.0+-blue.svg" />
  <img src="https://img.shields.io/badge/TCA-1.22.2-purple.svg" />
</p>

**Promiso**는 그룹 기반 약속 관리 iOS 앱입니다. 투표로 바로 확정된 약속을 만들고, 실시간 라이브 액티비티와 위젯으로 언제 뭐 있는지 달력을 한눈에 확인하세요.

## 🛠️ Tech Stack

### Frontend
- **Language**: Swift 6.2+
- **UI Framework**: SwiftUI
- **Architecture**: The Composable Architecture (TCA) 1.22.2
- **iOS Version**: 18.0+
- **Build System**: Tuist 4.65.7
- **Design**: iOS 26 Glass Effect + Aurora Background

### Backend
- **Platform**: Firebase
- **Services**:
  - Authentication (Apple, Google)
  - Cloud Firestore (Database)
  - Cloud Functions (TypeScript)
  - Cloud Storage
  - Cloud Messaging (Push Notifications)

### DevOps
- **CI/CD**: GitHub Actions
- **Deployment**: Fastlane
- **Distribution**: TestFlight (Stage/Prod)

## 🚀 Quick Start

### 1. 필수 도구 설치

```bash
# Xcode 26.0+ (App Store)
# Homebrew, mise, Tuist
brew install mise
curl -Ls https://install.tuist.io | bash
```

### 2. 프로젝트 Clone 및 초기 설정

```bash
git clone https://github.com/kswift1/Promiso.git
cd Promiso
make setup  # mise 신뢰 + 의존성 설치 + 프로젝트 생성
```

### 3. 환경 설정 (Secret Config)

```bash
# 방법 1: Notion 동기화 (팀원)
export NOTION_API_KEY="ntn_xxxxx"
make secrets-pull

# 방법 2: 로컬 생성 (개인)
cp .env.template .env  # API Key 입력
./scripts/generate-xcconfig.sh
```

> 📘 **상세 가이드**: [Config/README.md](Config/README.md)

### 4. Xcode에서 실행

```bash
# Xcode 열기
open Promiso.xcworkspace

# 또는 Xcode에서 직접 Promiso.xcworkspace 열기
```

**타겟 선택**:
- `PromisoDev` - 로컬 개발 (기본)
- `PromisoStage` - QA/스테이징
- `Promiso` - 프로덕션

## 📁 프로젝트 구조 & 아키텍처

```
Projects/
├── App/              메인 앱 (진입점)
├── Features/         TCA Feature 모듈 (비즈니스 로직)
├── Clients/          TCA Dependencies (데이터 레이어)
└── Shared/           공통 컴포넌트, 모델
```

**의존성 방향**: `App → Features → Clients → Shared`

> 📘 **상세 가이드**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
> - 계층 구조 및 모듈 설명
> - TCA 패턴 및 베스트 프랙티스
> - 데이터 흐름 및 Feature 예시

## 🛠️ 개발 명령어

### 초기 설정
```bash
make setup                        # 프로젝트 초기 설정 (mise + Tuist)
```

### Feature 개발
```bash
make feature FEATURE_NAME=Notification    # Feature 생성
make remove-feature FEATURE_NAME=Notification  # Feature 삭제
tuist build                       # 빌드
tuist test                        # 테스트
```

### Firebase
```bash
make emulator-start               # 에뮬레이터 실행
make functions-build              # Functions 빌드
make functions-api-preview        # OpenAPI 문서 미리보기
```

### Secrets 관리
```bash
make secrets-pull                 # Notion → xcconfig 동기화
make secrets-list                 # 시크릿 목록 보기
make secrets-add                  # 새 시크릿 추가
```

### 기타
```bash
make color                        # 컬러 에셋 재생성
make help                         # 전체 명령어 보기
```

> 📘 **개발 가이드**: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
> 📘 **Firebase 가이드**: [docs/FIREBASE.md](docs/FIREBASE.md)

## 📚 문서

| 카테고리 | 문서 |
|---------|------|
| **시작하기** | [초기 설정](docs/SETUP_GUIDE.md) · [환경 구성](docs/ENVIRONMENT.md) · [아키텍처](docs/ARCHITECTURE.md) |
| **개발** | [개발 가이드](docs/DEVELOPMENT.md) · [Firebase](docs/FIREBASE.md) · [Secret Config](Config/README.md) |
| **배포** | [CI/CD](docs/CI_CD.md) · [배포 가이드](docs/DEPLOYMENT.md) · [브랜치 전략](docs/BRANCH_STRATEGY.md) |
| **AI 도구** | [Claude Code](.claude/CLAUDE.md) - `/new-feature`, `/review-pr` 등 |

## 🚢 배포

```bash
# GitHub Actions (자동)
PR → main: 빌드 & 테스트
Tag push: TestFlight 배포
```

> 📘 **배포 가이드**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.

## 👥 기여

현재 비공개 프로젝트로 외부 기여를 받지 않습니다.

---

**Made with ❤️ by Promiso Team**
