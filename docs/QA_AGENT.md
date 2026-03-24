# Promiso QA Agent 가이드

> Promiso 저장소에서 QA 전담 에이전트를 운영할 때 사용하는 공용 기준 문서

## 문서 메타

- 목적: QA 에이전트의 역할, 검증 범위, 실행 절차, 보고 형식을 정의
- 대상 독자: 코드 리뷰 담당자, QA 에이전트 운영자, 릴리즈 검증 담당자
- 최종 수정일: 2026-03-25
- 관련 문서: [DEVELOPMENT.md](DEVELOPMENT.md) · [CI_CD.md](CI_CD.md) · [TESTING_DEPENDENCY_RULES.md](TESTING_DEPENDENCY_RULES.md)

## 범위 안내

- 이 문서: QA 에이전트 운영 기준, diff 기반 리뷰, 스모크 검증, 보고 형식
- 기능 구현 규칙: `.ai/CONVENTIONS.md`
- 테스트 시나리오 기준: `.ai/TEST_POLICY.md`, 관련 `.ai/domain-rules/*.md`
- GitHub Actions 동작: [CI_CD.md](CI_CD.md)

## 1. 목표

QA 에이전트는 구현 담당과 분리되어 다음 역할을 맡습니다.

- 변경분을 독립적으로 검토
- 가장 작은 유효 검증을 실행
- 회귀 위험, 테스트 누락, 문서/스키마 불일치를 우선 보고
- 필요 시 릴리즈 전 최종 smoke gate 역할 수행

기본 원칙:
- 코드 수정은 명시적으로 요청받은 경우에만 수행
- 전체 테스트보다 변경 영향 기준의 선택 검증을 우선
- 이 워크스페이스의 기본 비교 기준은 `release/v1.3.1`

## 2. 시작 전 필수 확인

결론을 내리기 전에 아래 문서를 먼저 읽습니다.

- `.ai/AI_WORKFLOW.md`
- `.ai/CONVENTIONS.md`
- `.ai/TEST_POLICY.md`

다음 문서는 변경 범위에 포함될 때만 추가로 읽습니다.

- 관련 `.ai/domain-rules/*.md`
- `.ai/DEEPLINK_GUIDE.md`와 `Projects/Features/AppEntryFeature/Tests/Sources/DeeplinkRoutingTests.swift`
- `.ai/PUSH_NOTIFICATION_GUIDE.md`, `infra/firebase/functions/openapi.yaml`, NotificationType 정의
- `.ai/FIRESTORE_SCHEMA.md`와 관련 OpenAPI 스키마

## 3. QA 에이전트 책임

### 3.1 Diff 기반 리뷰

- 변경 파일을 먼저 확인하고 영향 모듈을 식별합니다.
- 버그, 회귀, 테스트 누락, 규칙 위반, 잘못된 가정을 찾습니다.
- 리뷰 결과는 요약보다 findings를 우선합니다.

### 3.2 실행 검증

- 빠른 smoke: `./scripts/run-qa-smoke.sh build`
- 동작 검증 포함: `./scripts/run-qa-smoke.sh test`
- 특정 모듈 재검증: `make test-module MODULE=<Module>`
- 광범위 변경이나 릴리즈 검증: `make test`

### 3.3 테스트 갭 분석

`.ai/TEST_POLICY.md`를 기준으로 다음 누락을 우선 찾습니다.

- 제약 조건: 경계값 테스트 누락
- 권한 규칙: 허용/거부 쌍 테스트 누락
- 동작 규칙: 상태 전이/입출력 테스트 누락
- 표시 규칙: 최대 개수, 정렬, 필터링 검증 누락

### 3.4 가이드/스키마 정합성 확인

문서 또는 계약이 바뀌면 구현과 테스트가 같이 바뀌었는지 확인합니다.

- Deeplink 문서 변경 시 라우팅 테스트 정합
- Push 문서 변경 시 OpenAPI 및 NotificationType 정합
- Firestore schema 변경 시 OpenAPI 스키마 정합

## 4. 리뷰 우선순위

QA 에이전트는 아래 순서로 findings를 정렬합니다.

1. 크래시, 데이터 손실, 보안/권한 문제, 복구 불가 상태 오염
2. 비즈니스 규칙 위반, 릴리즈 차단 이슈, 문서 계약 파손
3. 위험한 변경에 대한 테스트 누락
4. 컨벤션 위반과 유지보수 리스크

## 5. Promiso 전용 체크리스트

- 의존성 방향이 `App -> Features -> Clients -> Shared`를 지키는가
- Feature가 Firebase를 직접 호출하지 않는가
- 테스트가 Swift Testing을 사용하고 있는가
- TCA reducer가 `view/internal/delegate` 분리를 지키는가
- `Spacer()`가 포함된 탭 영역에 `.contentShape(Rectangle())`가 있는가
- 도메인 규칙 변경 시 관련 테스트가 같이 바뀌었는가

## 6. 실행 절차

### 6.1 빠른 리뷰

1. diff 확인
2. 관련 `.ai` 문서 확인
3. `./scripts/run-qa-smoke.sh build`
4. findings 작성

### 6.2 동작 변경 리뷰

1. diff 확인
2. 관련 domain rule 확인
3. `./scripts/run-qa-smoke.sh test`
4. 필요 시 `make test-module MODULE=<Module>`
5. 테스트 누락 여부까지 보고

### 6.3 릴리즈 전 리뷰

1. 주요 변경 범위 식별
2. smoke test 실행
3. 필요한 모듈 재검증
4. broad regression risk를 별도 기록

## 7. 보고 형식

아래 템플릿을 그대로 사용합니다.

```md
## Findings
- [high|medium|low] path:line - 문제 요약과 실제 위험

## Verification
- Base branch: `release/v1.3.1`
- Commands run:
  - `./scripts/run-qa-smoke.sh build`
  - `./scripts/run-qa-smoke.sh test`
- Result:
  - Build: `pass|fail|not run`
  - Test: `pass|fail|not run`

## Coverage Gaps
- 빠진 테스트
- 환경 제약으로 확인하지 못한 범위

## Notes
- 확인한 domain rule / guide
- 남은 가정, 블로커, 후속 권장사항
```

findings가 없을 때도 다음은 반드시 남깁니다.

- `No findings`
- 실행한 검증 범위
- 남은 위험 또는 미검증 영역

## 8. 스모크 스크립트

공용 smoke 검증 래퍼는 `scripts/run-qa-smoke.sh`입니다.

기본 동작:
- `PROMISO_BASE_BRANCH`가 없으면 `origin/release/v1.3.1`을 우선 사용
- 없으면 `release/v1.3.1`, 마지막으로 `origin/main` 순서로 fallback
- 내부적으로 `scripts/run-changed-tests.sh`를 호출

예시:

```bash
./scripts/run-qa-smoke.sh build
./scripts/run-qa-smoke.sh test
PROMISO_BASE_BRANCH=origin/staging ./scripts/run-qa-smoke.sh test
```

## 9. 운영 메모

- Conductor 병렬 작업에서는 QA 결과를 `.context/`에 별도 메모로 남겨 공유해도 됩니다.
- 예상치 못한 사용자 변경과 충돌하면 검증을 멈추고 먼저 보고합니다.
- QA 에이전트는 구현 속도보다 false negative를 줄이는 쪽을 우선합니다.
