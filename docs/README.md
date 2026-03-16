# Promiso 문서 인덱스

Promiso 저장소의 공식 개발 문서를 빠르게 찾기 위한 인덱스입니다.

## 문서 운영 원칙

- `docs/`는 팀의 공식 개발/운영 문서 기준점입니다.
- `.ai/`는 AI 에이전트 작업 보조 문서이며, 공식 정책은 `docs/`를 우선합니다.
- 문서 내용이 겹치면 범위가 더 좁고 전문화된 문서를 우선 참조합니다.

## 빠른 경로

| 상황 | 먼저 볼 문서 |
|------|-------------|
| 새 개발 환경 세팅 | [SETUP_GUIDE.md](SETUP_GUIDE.md) |
| 로컬 환경값/xcconfig 구성 | [ENVIRONMENT.md](ENVIRONMENT.md) |
| 아키텍처 이해 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 제품 정체성/메시지 정렬 | [PRODUCT_STRATEGY.md](PRODUCT_STRATEGY.md) |
| 운영 콘솔 계획 확인 | [ADMIN_CONSOLE_PLAN.md](ADMIN_CONSOLE_PLAN.md) |
| 기능 개발/테스트 규칙 | [DEVELOPMENT.md](DEVELOPMENT.md) |
| 테스트 의존성/Unimplemented/중복링킹 대응 | [TESTING_DEPENDENCY_RULES.md](TESTING_DEPENDENCY_RULES.md) |
| 브랜치 운영 규칙 | [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) |
| GitHub Actions 파이프라인 이해 | [CI_CD.md](CI_CD.md) |
| 실제 배포 절차 수행 | [DEPLOYMENT.md](DEPLOYMENT.md) |

## 문서 범위 맵

| 문서 | 핵심 범위 | 제외 범위 |
|------|----------|----------|
| [PRODUCT_STRATEGY.md](PRODUCT_STRATEGY.md) | 제품 카테고리, 포지셔닝, Free/Pro 가치, 온보딩/Paywall 메시지 기준 | 구현 세부 아키텍처, 배포 절차 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 모듈 구조, 의존성 규칙, 데이터 흐름 | 배포 절차 상세 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Feature 개발, 테스트, 코딩 컨벤션 | CI/CD 운영 정책 |
| [TESTING_DEPENDENCY_RULES.md](TESTING_DEPENDENCY_RULES.md) | TestStore 의존성 규칙, `testValue`, 중복링킹 대응 | 일반 기능 구현 컨벤션 전체 |
| [SETUP_GUIDE.md](SETUP_GUIDE.md) | 새 컴퓨터/온보딩 초기 세팅 | 환경별 빌드 전략 상세 |
| [ENVIRONMENT.md](ENVIRONMENT.md) | Dev/Stage/Prod 구성과 로컬 환경 파일 | 브랜치 운영 정책 |
| [BRANCH_STRATEGY.md](BRANCH_STRATEGY.md) | 브랜치 역할, 병합 흐름, 릴리즈 흐름 | 워크플로우 job 상세 |
| [CI_CD.md](CI_CD.md) | GitHub Actions 워크플로우 동작/시크릿/트러블슈팅 | 수동 배포의 운영 절차 전체 |
| [DEPLOYMENT.md](DEPLOYMENT.md) | iOS/Firebase 실제 배포 실행 절차와 체크리스트 | 아키텍처 설계 설명 |

## 편집 규칙

- 문서 수정 시 상단 `문서 메타`의 `최종 수정일`을 함께 갱신합니다.
- 내용 변경이 다른 문서 범위와 충돌하면, 중복 서술 대신 링크로 연결합니다.
- 배포/브랜치/CI 변경 시 `BRANCH_STRATEGY.md`, `CI_CD.md`, `DEPLOYMENT.md` 정합을 함께 확인합니다.
