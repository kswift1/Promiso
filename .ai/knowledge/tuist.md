---
updated: 2025-01-29
expires: 2025-04-29
version: 4.x
source: https://github.com/tuist/tuist/releases
---

# Tuist 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.
> 2025년 1월 검색 결과 기반.

## 현재 버전 정보

- **최신 메이저**: 4.x (안정)
- **확인 일자**: 2025-01-29
- **출처**: [Tuist Docs](https://docs.tuist.dev), [GitHub Releases](https://github.com/tuist/tuist/releases)

## Promiso 프로젝트 상태

- **사용 중인 버전**: 4.65.7
- **설정 파일**: `Tuist/Config.swift`, `Project.swift`
- **빌드 캐시**: 활성화

---

## Tuist 4.x 주요 변경사항

### Dependencies.swift → Package.swift 통합

> Tuist 4에서 가장 큰 변화

**이전 (Tuist 3)**:
```swift
// Tuist/Dependencies.swift (deprecated)
import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
        .remote(url: "...", requirement: .exact("1.0.0"))
    ]
)
```

**이후 (Tuist 4)**:
```swift
// Package.swift (루트 디렉토리)
// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescriptionHelpers
import ProjectDescription

let packageSettings = PackageSettings(
    // Tuist 전용 설정
)
#endif

let package = Package(
    name: "Promiso",
    dependencies: [
        .package(url: "...", exact: "1.0.0")
    ]
)
```

**장점**:
- Dependabot, Renovatebot 호환
- 표준 Swift Package Manager 형식
- 불필요한 간접 참조 제거

### Carthage 지원 제거

Tuist 4에서는 Carthage 직접 지원이 제거되었습니다.
- Carthage 사용 시 별도로 pre-compiled frameworks 가져오기 필요
- Swift Package Manager가 권장 방식

### Cache 명령어 변경

```bash
# Tuist 3
tuist cache warm
tuist cache print-hashes

# Tuist 4
tuist cache
tuist cache --print-hashes
```

---

## 주요 명령어

### 프로젝트 생성 및 빌드

```bash
# Xcode 프로젝트 생성
tuist generate

# 빌드
tuist build Promiso-Workspace

# 특정 스킴 빌드
tuist build --scheme PromisoApp

# 테스트
tuist test

# 특정 테스트 타겟
tuist test --target MyFeatureTests

# 캐시 정리
tuist clean

# 의존성 그래프 시각화
tuist graph
```

### 캐시 관리

```bash
# 캐시 워밍 (의존성 미리 빌드)
tuist cache

# 캐시 해시 확인
tuist cache --print-hashes

# 캐시 초기화
tuist clean
rm -rf ~/.tuist/Cache
```

### 프로젝트 검사

```bash
# 린트
tuist lint

# 의존성 그래프 (PNG 출력)
tuist graph --format png

# 의존성 그래프 (DOT 출력)
tuist graph --format dot
```

---

## 성능 최적화 사례 (Back Market, 2025)

### 실제 적용 결과

Back Market이 2025년 11월에 공유한 Tuist 마이그레이션 사례:

| 항목 | 개선 |
|------|------|
| Xcode 실행 | 더 빠르게 (resolving dependencies 없음) |
| Clean Build (서드파티 캐시) | 35-40% 빠름 |
| Clean Build (전체 캐시) | 90% 빠름 |
| Incremental Build | 크게 개선 |

### 동적/정적 프레임워크 전략

```swift
// 개발 시: 동적 프레임워크 (빠른 incremental build)
// 릴리즈 시: 정적 프레임워크 (작은 앱 크기)

// Project.swift
let isRelease = Environment.isRelease.getBoolean(default: false)

let product: Product = isRelease ? .staticFramework : .framework
```

---

## Promiso 프로젝트 구조

```
Promiso/
├── Tuist/
│   ├── Config.swift           # Tuist 전역 설정
│   ├── Package.swift          # 외부 의존성
│   └── ProjectDescriptionHelpers/
│       └── Project+Templates.swift
├── Projects/
│   ├── App/                   # 앱 타겟
│   │   ├── Project.swift
│   │   └── Sources/
│   ├── Features/              # Feature 모듈들
│   │   └── {Name}Feature/
│   │       ├── Project.swift
│   │       ├── Sources/
│   │       └── Tests/
│   ├── Clients/               # 데이터/네트워크 레이어
│   │   └── {Name}Client/
│   │       ├── Project.swift
│   │       ├── Sources/
│   │       └── Tests/
│   ├── Shared/                # 공통 컴포넌트
│   │   ├── Project.swift
│   │   └── Sources/
│   └── ExternalDependency/    # 외부 의존성 래퍼
├── Workspace.swift            # 워크스페이스 정의
└── Package.swift              # SPM 의존성
```

### 의존성 방향

```
App → Features → Clients → Shared
         ↓
    ExternalDependency
```

---

## Project.swift 예시

### Feature 모듈

```swift
// Projects/Features/MyFeature/Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.feature(
    name: "MyFeature",
    dependencies: [
        .project(target: "Shared", path: "../../Shared"),
        .project(target: "FirestoreClient", path: "../../Clients/FirestoreClient"),
    ]
)
```

### Client 모듈

```swift
// Projects/Clients/FirestoreClient/Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.client(
    name: "FirestoreClient",
    dependencies: [
        .project(target: "Shared", path: "../../Shared"),
        .external(name: "FirebaseFirestore"),
        .external(name: "FirebaseFirestoreSwift"),
    ]
)
```

### ProjectDescriptionHelpers 템플릿

```swift
// Tuist/ProjectDescriptionHelpers/Project+Templates.swift
import ProjectDescription

public extension Project {
    static func feature(
        name: String,
        dependencies: [TargetDependency] = []
    ) -> Project {
        Project(
            name: "\(name)Feature",
            targets: [
                .target(
                    name: "\(name)Feature",
                    destinations: .iOS,
                    product: .framework,
                    bundleId: "com.promiso.\(name.lowercased())feature",
                    deploymentTargets: .iOS("18.0"),
                    sources: ["Sources/**"],
                    dependencies: dependencies + [
                        .external(name: "ComposableArchitecture"),
                    ]
                ),
                .target(
                    name: "\(name)FeatureTests",
                    destinations: .iOS,
                    product: .unitTests,
                    bundleId: "com.promiso.\(name.lowercased())feature.tests",
                    deploymentTargets: .iOS("18.0"),
                    sources: ["Tests/**"],
                    dependencies: [
                        .target(name: "\(name)Feature"),
                    ]
                ),
            ]
        )
    }

    static func client(
        name: String,
        dependencies: [TargetDependency] = []
    ) -> Project {
        Project(
            name: "\(name)Client",
            targets: [
                .target(
                    name: "\(name)Client",
                    destinations: .iOS,
                    product: .framework,
                    bundleId: "com.promiso.\(name.lowercased())client",
                    deploymentTargets: .iOS("18.0"),
                    sources: ["Sources/**"],
                    dependencies: dependencies
                ),
                .target(
                    name: "\(name)ClientTests",
                    destinations: .iOS,
                    product: .unitTests,
                    bundleId: "com.promiso.\(name.lowercased())client.tests",
                    deploymentTargets: .iOS("18.0"),
                    sources: ["Tests/**"],
                    dependencies: [
                        .target(name: "\(name)Client"),
                    ]
                ),
            ]
        )
    }
}
```

---

## Makefile 명령어

```makefile
# Makefile

# Feature 모듈 생성
feature:
	@mkdir -p Projects/Features/$(FEATURE_NAME)Feature/Sources
	@mkdir -p Projects/Features/$(FEATURE_NAME)Feature/Tests/Sources
	@echo "Feature $(FEATURE_NAME) created"

# Feature 모듈 삭제
remove-feature:
	@rm -rf Projects/Features/$(FEATURE_NAME)Feature
	@echo "Feature $(FEATURE_NAME) removed"

# 의존성 그래프
deps:
	tuist graph --format png --output-path ./graph.png
	open ./graph.png

# Firebase 에뮬레이터 시작
emulator-start:
	cd infra/firebase && firebase emulators:start

# Functions 빌드
functions-build:
	cd infra/firebase/functions && npm run build
```

사용법:
```bash
make feature FEATURE_NAME=Notification
make remove-feature FEATURE_NAME=Notification
make deps
```

---

## 외부 의존성 관리

### Package.swift 설정

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

#if TUIST
import ProjectDescriptionHelpers
import ProjectDescription

let packageSettings = PackageSettings(
    productTypes: [
        "ComposableArchitecture": .framework,
        "FirebaseFirestore": .framework,
    ]
)
#endif

let package = Package(
    name: "Promiso",
    dependencies: [
        // TCA
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.22.2"),

        // Firebase
        .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "12.1.0"),

        // 기타
        .package(url: "https://github.com/onevcat/Kingfisher", exact: "8.1.0"),
    ]
)
```

### 의존성 사용

```swift
// Project.swift에서
dependencies: [
    .external(name: "ComposableArchitecture"),
    .external(name: "FirebaseAuth"),
    .external(name: "Kingfisher"),
]
```

---

## 트러블슈팅

### 캐시 문제

```bash
# 증상: 빌드 에러, 모듈 못 찾음

# 해결
tuist clean
rm -rf ~/Library/Developer/Xcode/DerivedData
tuist generate
tuist build
```

### SPM 의존성 동기화 문제

```bash
# 증상: Package.swift 변경 후 반영 안 됨

# 해결
tuist clean
tuist generate --no-cache
```

### 빌드 설정 충돌

```bash
# 증상: SPM 의존성의 빌드 설정이 프로젝트와 충돌

# 확인
tuist graph --format dot | grep -i "conflict"

# 해결: PackageSettings에서 productTypes 명시
```

### Xcode 버전 불일치

```bash
# 증상: 다른 Xcode 버전으로 생성된 프로젝트 충돌

# 해결
sudo xcode-select -s /Applications/Xcode.app
tuist clean
tuist generate
```

---

## 자주 묻는 질문

### Q: Feature 모듈 추가 방법?
A: Makefile 사용:
```bash
make feature FEATURE_NAME=NewFeature
```
그 후 `Projects/Features/NewFeature/Project.swift` 작성.

### Q: 의존성 추가 방법?
A: `Package.swift`에 의존성 추가 후, `Project.swift`의 `dependencies`에 `.external(name: "...")` 추가.

### Q: 빌드 에러 시 캐시 문제?
A:
```bash
tuist clean
tuist generate
tuist build Promiso-Workspace
```

### Q: Tuist 3에서 4로 마이그레이션?
A: [공식 마이그레이션 가이드](https://docs.tuist.dev/en/references/migrations/from-v3-to-v4) 참조.
- `Dependencies.swift` → `Package.swift` 이동
- `tuist cache warm` → `tuist cache` 변경
- Carthage 사용 시 별도 처리 필요

### Q: 동적 vs 정적 프레임워크?
A:
- 개발: 동적 (빠른 incremental build)
- 릴리즈: 정적 (작은 앱 크기, 빠른 실행)
- `PackageSettings`에서 `productTypes` 설정으로 제어

### Q: 의존성 그래프가 너무 복잡해요
A:
```bash
# 특정 타겟만 표시
tuist graph --targets MyFeature

# 외부 의존성 제외
tuist graph --skip-external-dependencies
```

---

## 참고 자료

### 공식 자료
- [Tuist Documentation](https://docs.tuist.dev)
- [Tuist GitHub](https://github.com/tuist/tuist)
- [Tuist Releases](https://github.com/tuist/tuist/releases)
- [v3 to v4 Migration](https://docs.tuist.dev/en/references/migrations/from-v3-to-v4)
- [PackageSettings](https://docs.tuist.dev/generated/manifest/structs/PackageSettings)

### 커뮤니티 자료
- [Back Market Tuist Case Study (2025)](https://engineering.backmarket.com/back-market-x-tuist-part-i-why-we-moved-our-ios-project-to-tuist-f161cf914700)
- [Getting Started with Tuist - DEV Community](https://dev.to/arshtechpro/getting-started-with-tuist-manage-ios-projects-with-ease-3omg)
- [Swift Package Index - Tuist](https://swiftpackageindex.com/tuist/tuist)

### Promiso 프로젝트 참조
- `Tuist/Config.swift`
- `Tuist/ProjectDescriptionHelpers/`
- `Workspace.swift`
- `Projects/*/Project.swift`

---

*마지막 업데이트: 2025-01-29 (웹 검색 기반)*
