# Codex Working Rules

## Always Check
- Before starting any task, review relevant documents in `.ai/` (load only what is needed).
- When editing, follow existing code style and project conventions.

## Guide/Test Alignment
- `DEEPLINK_GUIDE.md` 변경 시 `Projects/Features/AppEntryFeature/Tests/Sources/DeeplinkRoutingTests.swift` 정합 확인 및 필요 시 업데이트.
- `PUSH_NOTIFICATION_GUIDE.md` 변경 시 `infra/firebase/functions/openapi.yaml` 및 NotificationType 정의(서버/클라이언트) 정합 확인.
- `FIRESTORE_SCHEMA.md` 변경 시 `infra/firebase/functions/openapi.yaml`에 명시된 관련 스키마 범위 내 정합 확인.

## Workflow
- Summarize planned changes briefly before editing if the task is non-trivial.
- Prefer minimal, targeted edits; avoid broad refactors unless requested.
- Keep changes scoped to the request; ask if something is ambiguous.

## Commits
- Follow existing commit conventions in this repo.
- Do not amend commits unless explicitly requested.

## Safety
- Never discard unrelated changes without asking.
- If you notice unexpected changes, stop and ask how to proceed.
