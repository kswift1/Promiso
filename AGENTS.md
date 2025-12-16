# 에이전트 지침 (Promiso)

## 먼저 읽기 (코딩 시작 전)
- 레포 개요/워크플로우: `README.md`
- 프로젝트 아키텍처 개요: `docs/architecture/000-project-architecture.md`
- 의존성 규칙(ADR): `docs/architecture/001-dependency-architecture.md`

## 작업 원칙
- 4-Layer 의존성 방향을 유지한다(Feature → Clients → Domain, Core → Domain).
- 변경은 필요한 범위로 최소화하고, 기존 모듈 구조/Tuist 구성을 존중한다.
- 문서 작성 및 사용자 답변은 기본적으로 한국어로 작성한다(필요 시 기술 용어/코드는 원문 유지).
- 지침 충돌 시, 해당 경로에서 가장 가까운(하위 폴더) `AGENTS.md`가 우선한다.
