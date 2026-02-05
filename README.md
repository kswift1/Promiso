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

## 📁 프로젝트 구조

프로젝트는 Tuist 기반 모듈화 구조로 되어 있습니다.

```
Promiso/
├── Projects/
│   ├── App/                    # 메인 앱
│   ├── Features/               # 기능별 Feature 모듈 (TCA)
│   ├── Clients/                # 데이터/API 레이어 (TCA Dependencies)
│   ├── Shared/                 # 공통 컴포넌트, 모델, UI
│   ├── ResourceKit/            # 리소스 (Colors, Images, Fonts)
│   └── ExternalDependency/     # 외부 라이브러리 집약
│
├── Config/                     # 환경별 설정 (⚠️ Git 제외)
├── infra/firebase/             # Firebase Functions, Rules
├── docs/                       # 프로젝트 문서
└── scripts/                    # 빌드/배포 스크립트
```

**아키텍처 상세 문서**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## 🏗️ 개발

### Feature 생성

```bash
# 새 Feature 자동 생성
make feature FEATURE_NAME=Notification

# 생성되는 파일:
# - Features/NotificationFeature/Sources/NotificationFeature.swift (Reducer)
# - Features/NotificationFeature/Sources/NotificationView.swift (View)
# - Features/NotificationFeature/Tests/NotificationFeatureTests.swift (Tests)
```

### 빌드 및 테스트

```bash
# 전체 빌드
tuist build

# 특정 타겟 빌드
tuist build PromisoDev

# 테스트 실행
tuist test

# 의존성 그래프 확인
tuist graph
```

### Firebase 개발

```bash
# Firebase 에뮬레이터 실행 (로컬 개발)
make emulator-start

# Functions 빌드
make functions-build

# OpenAPI 문서 미리보기
make functions-api-preview
```

## 🧰 Make 명령어

```bash
make help                              # 전체 명령어 보기
make setup                             # 프로젝트 초기 설정 (git clone 후)
make feature FEATURE_NAME=<Name>       # Feature 생성
make remove-feature FEATURE_NAME=<Name> # Feature 삭제
make emulator-start                    # Firebase 에뮬레이터 실행
make secrets-pull                      # Notion → xcconfig 동기화
```

## 🤖 AI 개발 도구 (Claude Code)

이 프로젝트는 [Claude Code](https://claude.com/claude-code)를 사용한 AI 기반 개발을 지원합니다.

### Slash 커맨드

```bash
/new-feature NotificationSettings    # TCA Feature 생성 (Reducer + View + Tests)
/new-screen ProfileEdit              # 화면 생성 (Feature + UI 디자인)
/review-pr                           # PR/변경사항 코드 리뷰
/fix-reviews                         # PR 리뷰 자동 수정
```

**상세 가이드**: [.claude/CLAUDE.md](.claude/CLAUDE.md)

## 📚 문서

### 시작하기
- [🚀 초기 설정 가이드](docs/SETUP_GUIDE.md) - 새 개발 환경 셋업
- [🔧 환경 설정](docs/ENVIRONMENT.md) - Dev/Stage/Prod 환경 구성
- [🏗️ 아키텍처](docs/ARCHITECTURE.md) - TCA 기반 아키텍처 상세

### 개발
- [💻 개발 가이드](docs/DEVELOPMENT.md) - Feature 개발, 테스트, 컨벤션
- [🔥 Firebase 가이드](docs/FIREBASE.md) - Firestore, Functions, Rules

### CI/CD 및 배포
- [⚙️ CI/CD](docs/CI_CD.md) - GitHub Actions 워크플로우
- [🚀 배포 가이드](docs/DEPLOYMENT.md) - Fastlane, TestFlight
- [🌿 Git 브랜치 전략](docs/BRANCH_STRATEGY.md) - 브랜치 전략

### 보안
- [🔒 보안 정책](SECURITY.md) - API Keys 관리
- [📦 Config 설정](Config/README.md) - 환경별 설정 파일
- [💾 백업 체크리스트](docs/BACKUP_CHECKLIST.md) - 정기 백업

## 🚢 배포

### 환경별 타겟

| 타겟 | Bundle ID | Firebase | 용도 |
|------|-----------|----------|------|
| **PromisoDev** | `com.promiso.dev` | promiso-dev | 로컬 개발 |
| **PromisoStage** | `com.promiso.stage` | promiso-stage | QA/스테이징 |
| **Promiso** | `com.promiso` | promiso-prod | 프로덕션 |

### GitHub Actions 자동 배포

```
PR → main: 자동 빌드 및 테스트
Tag push: TestFlight 배포 (Stage/Prod)
```

자세한 내용: [📘 배포 가이드](docs/DEPLOYMENT.md)

## 🐛 Troubleshooting

### mise 경고 (Config files are not trusted)

```bash
# 프로젝트별 해결
mise trust

# 또는 전역 설정 (권장)
mise settings set yes true
```

### Tuist 프로젝트 생성 실패

```bash
# 캐시 삭제 후 재시도
tuist clean
tuist install
tuist generate
```

### Firebase 에뮬레이터 실행 안됨

```bash
# Functions 의존성 재설치
cd infra/firebase/functions
npm install
cd ../../..
make emulator-start
```

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.

## 👥 기여

현재 비공개 프로젝트로 외부 기여를 받지 않습니다.

---

**Made with ❤️ by Promiso Team**
