# Codex Working Rules

## Always Check
- Before starting any task, review relevant documents in `.ai/` (load only what is needed).
- Treat `.ai/CONVENTIONS.md` as the source of truth for code style and architecture.
- If business rules or tests are affected, read the relevant `.ai/domain-rules/*.md` and `.ai/TEST_POLICY.md`.
- When editing, follow existing code style and project conventions.

## Guide/Test Alignment
- `DEEPLINK_GUIDE.md` 변경 시 `Projects/Features/AppEntryFeature/Tests/Sources/DeeplinkRoutingTests.swift` 정합 확인 및 필요 시 업데이트.
- `PUSH_NOTIFICATION_GUIDE.md` 변경 시 `infra/firebase/functions/openapi.yaml` 및 NotificationType 정의(서버/클라이언트) 정합 확인.
- `FIRESTORE_SCHEMA.md` 변경 시 `infra/firebase/functions/openapi.yaml`에 명시된 관련 스키마 범위 내 정합 확인.

## Workflow

> **작업 시작 전 반드시 `.ai/AI_WORKFLOW.md`를 읽고 따른다.**

핵심 원칙:
- ❌ 탐색 없이 구현 금지
- ❌ 검증 없이 커밋 금지
- ❌ 유저 승인 없이 커밋 금지
- ❌ `.ai/DOMAIN_RULES.md` 및 `.ai/domain-rules/` 사용자 허락 없이 수정 금지

Codex 추가 규칙:
- 현재 Conductor workspace/worktree를 기본 작업 공간으로 사용한다.
- 사용자가 요청하지 않았고 이미 격리된 workspace가 있으면 추가 worktree를 만들지 않는다.
- 브랜치 관련 정책은 현재 환경 지시를 우선한다.

## Safety
- 변경은 요청 범위에 한정하고, 모호하면 먼저 확인한다.
- 관련 없는 변경은 사용자 확인 없이 버리지 않는다.
- 예상치 못한 변경을 발견하면 멈추고 진행 방향을 확인한다.
- 명시적 요청이 없으면 amend commit을 하지 않는다.
