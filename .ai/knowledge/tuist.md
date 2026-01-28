---
updated:
expires:
version:
source: https://github.com/tuist/tuist/releases
---

# Tuist 지식 베이스

> 이 파일은 `knowledge-updater` 에이전트가 자동으로 관리합니다.

## 현재 버전 정보

- **최신 버전**: (검색 필요)
- **확인 일자**: -
- **출처**: [GitHub Releases](https://github.com/tuist/tuist/releases)

## Promiso 프로젝트 상태

- **사용 중인 버전**: 4.65.7
- **설정 파일**: `Tuist/Config.swift`, `Project.swift`

## 주요 명령어

```bash
# 프로젝트 생성
tuist generate

# 빌드
tuist build Promiso-Workspace

# 테스트
tuist test

# 캐시 정리
tuist clean

# 의존성 그래프
tuist graph
```

## 버전별 주요 변경 (AI 지식 기준)

### 4.x (2024-2025)
- Swift Package Manager 통합 개선
- 빌드 캐시 최적화
- Xcode 16 지원

## 자주 묻는 질문

### Q: Feature 모듈 추가 방법?
A: Makefile 사용:
```bash
make feature FEATURE_NAME=NewFeature
```

### Q: 의존성 추가 방법?
A: `Project.swift`에서 `dependencies` 배열에 추가:
```swift
.project(target: "SomeFeature", path: "../SomeFeature")
```

### Q: 빌드 에러 시 캐시 문제?
A:
```bash
tuist clean
tuist generate
tuist build Promiso-Workspace
```

## Promiso 프로젝트 구조

```
Projects/
├── App/                    # 앱 타겟
├── Features/               # Feature 모듈들
│   └── {Name}Feature/
├── Clients/                # 데이터/네트워크 레이어
├── Shared/                 # 공통 컴포넌트
└── ExternalDependency/     # 외부 의존성
```

## 참고 자료

- [Tuist Documentation](https://docs.tuist.io)
- [Tuist GitHub](https://github.com/tuist/tuist)

---

*마지막 검색: 아직 검색되지 않음*
