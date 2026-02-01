# Promiso

> 그룹 기반 약속 관리 iOS 애플리케이션

<p align="center">
  <img src="https://img.shields.io/badge/iOS-18.0+-blue.svg" />
  <img src="https://img.shields.io/badge/Swift-6.2+-orange.svg" />
  <img src="https://img.shields.io/badge/Xcode-26.0+-blue.svg" />
  <img src="https://img.shields.io/badge/TCA-1.22.2-purple.svg" />
</p>

## 📖 개요

Promiso는 **The Composable Architecture (TCA)** 기반의 모던 iOS 앱입니다.
- 그룹별 약속 관리
- 실시간 라이브 액티비티
- 홈 화면 위젯 지원
- Firebase 기반 백엔드

## 🚀 빠른 시작

### 필수 요구사항

- **Xcode**: 26.0+
- **Swift**: 6.2+
- **iOS**: 18.0+
- **Tuist**: 4.65.7+

### 설치 및 실행

```bash
# 1. 저장소 클론
git clone https://github.com/kswift1/Promiso.git
cd Promiso

# 2. Tuist 설치 (없는 경우)
curl -Ls https://install.tuist.io | bash

# 3. 환경 설정 파일 생성 (필수)
# 방법 1: 자동 생성 스크립트
cp .env.template .env
# .env 파일 편집 후 API 키 입력
./scripts/generate-xcconfig.sh

# 방법 2: 백업에서 복원 (iCloud Drive/Google Drive)
# unzip ~/Downloads/Promiso-Config.zip -d .
# ./scripts/copy-firebase-config.sh

# 4. 의존성 설치 및 프로젝트 생성
tuist install
tuist generate

# 5. Xcode에서 열기
open Promiso.xcworkspace
```

> **📘 자세한 설정 방법**: [초기 설정 가이드](docs/SETUP_GUIDE.md) 참고

### 환경별 타겟

| 타겟 | Bundle ID | Firebase | 용도 |
|------|-----------|----------|------|
| **PromisoDev** | `com.promiso.dev` | promiso-dev | 로컬 개발 |
| **PromisoStage** | `com.promiso.stage` | promiso-stage | QA/스테이징 |
| **Promiso** | `com.promiso` | promiso-prod | 프로덕션 |

```bash
# 환경별 빌드
tuist build PromisoDev    # Dev 환경
tuist build PromisoStage  # Stage 환경
tuist build Promiso       # Prod 환경
```

## 📦 프로젝트 구조

```
Promiso/
├── Projects/
│   ├── App/                    # 메인 애플리케이션
│   ├── Features/               # TCA Features (기능별 모듈)
│   ├── Clients/                # TCA Dependencies (외부 의존성)
│   ├── Shared/                 # 공통 모델, UI, 유틸리티
│   ├── ResourceKit/            # 리소스 관리
│   └── ExternalDependency/     # 외부 라이브러리 집약
│
├── infra/firebase/             # Firebase Functions, Rules
├── docs/                       # 프로젝트 문서
├── Config/                     # 환경별 설정 (xcconfig) ⚠️ 로컬 생성 필요
└── scripts/                    # 빌드/배포 스크립트
```

> **⚠️ 중요**: `Config/` 폴더의 실제 설정 파일(*.xcconfig, GoogleService-Info.plist)은 보안상 Git에 포함되지 않습니다.
> Clone 후 [초기 설정 가이드](docs/SETUP_GUIDE.md) 또는 [환경 설정](docs/ENVIRONMENT.md)을 참고하여 생성하세요.

### 아키텍처 계층

```
┌──────────────────────────┐
│     App (조립/통합)       │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│   Features (비즈니스)     │  ← TCA Reducers & Views
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│  Clients (외부 의존성)    │  ← TCA Dependencies
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│   Shared (공통 요소)      │  ← Models, UI, Utils
└──────────────────────────┘
```

**핵심 원칙**:
- 단방향 의존성: `App → Features → Clients → Shared`
- Features끼리는 서로 의존하지 않음
- 모든 외부 라이브러리는 `ExternalDependency`로 집약

## 🛠️ 개발

### Feature 생성

```bash
# 새 Feature 자동 생성
make feature FEATURE_NAME=Notification

# 생성되는 파일:
# - Features/NotificationFeature/Sources/NotificationFeature.swift
# - Features/NotificationFeature/Sources/NotificationView.swift
# - Features/NotificationFeature/Tests/NotificationFeatureTests.swift
```

### 빌드 및 테스트

```bash
# 전체 빌드
tuist build

# 특정 Feature 빌드
tuist build GroupFeature

# 테스트 실행
tuist test

# 의존성 그래프 확인
make deps
```

### TCA Feature 예시

```swift
import ComposableArchitecture

@Reducer
public struct MyFeature {
    @ObservableState
    public struct State: Equatable {
        var items: [Item] = []
    }

    public enum Action {
        case onAppear
        case itemsResponse([Item])
    }

    @Dependency(\.itemClient) var itemClient

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let items = try await itemClient.fetch()
                    await send(.itemsResponse(items))
                }
            case let .itemsResponse(items):
                state.items = items
                return .none
            }
        }
    }
}
```

## 🚢 CI/CD 및 배포

이 프로젝트는 GitHub Actions 기반 CI/CD를 사용합니다.

### 자동 빌드

- **PR → main**: 자동으로 빌드 및 테스트 실행
- **빌드 타겟**: PromisoDev
- **테스트**: Swift Testing

### 수동 배포

```bash
# GitHub Actions에서 수동 실행
# 1. Actions 탭 → Deploy iOS to TestFlight
# 2. 환경 선택 (Stage/Prod)
# 3. Changelog 입력
# 4. Run workflow
```

자세한 내용은 [📘 배포 가이드](docs/DEPLOYMENT.md) 참고

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
- [🚀 배포 가이드](docs/DEPLOYMENT.md) - Fastlane, TestFlight, 환경별 배포
- [🌿 Git 브랜치 전략](docs/BRANCH_STRATEGY.md) - 브랜치 전략 및 워크플로우

### 참고

- [.ai/PROJECT_CONTEXT.md](.ai/PROJECT_CONTEXT.md) - Claude Code용 프로젝트 컨텍스트
- [.claude/CLAUDE.md](.claude/CLAUDE.md) - Claude Code 설정 및 컨벤션

## 🤖 AI 개발 도구

이 프로젝트는 [Claude Code](https://claude.com/claude-code)를 사용한 AI 기반 개발을 지원합니다.

### 커스텀 에이전트 (17개)

- **feature-generator**: TCA Feature 자동 생성
- **ui-designer**: SwiftUI View 디자인
- **code-reviewer**: 코드 리뷰 및 컨벤션 체크
- **backend-developer**: Firebase Functions 개발
- **orchestrator**: 복잡한 작업 조율
- 기타 16개 전문 에이전트

### Slash 커맨드

| 커맨드 | 설명 |
|--------|------|
| `/new-feature <Name>` | TCA Feature 생성 (Reducer + View + Tests) |
| `/new-screen <Name>` | 화면 생성 (Feature + UI 디자인 포함) |
| `/review-pr` | PR 또는 현재 변경사항 코드 리뷰 |
| `/fix-reviews` | PR 리뷰 자동 수정 |

**예시**:
```bash
/new-feature NotificationSettings
/new-screen ProfileEdit
/review-pr
```

**자세한 내용**:
- [.claude/CLAUDE.md](.claude/CLAUDE.md) - AI 개발 가이드 및 워크플로우
- [.claude/commands/](.claude/commands/) - Slash 커맨드 상세 문서

## 🧰 Make 명령어

```bash
make help                              # 도움말
make feature FEATURE_NAME=Login        # Feature 생성
make remove-feature FEATURE_NAME=Login # Feature 삭제
make deps                              # 의존성 그래프
make clean                             # 캐시 정리
```
