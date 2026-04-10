# Firestore → PostgreSQL 프로덕션 데이터 마이그레이션

## Context

Promiso의 Firebase → Rust(Axum+PostgreSQL) 코드 마이그레이션과 iOS cutover가 완료되었다.
Firestore에 남아있는 실 prod 데이터(유저 100명 이하)를 PostgreSQL(Neon)로 이관해야
Rust 백엔드가 실 데이터로 서비스할 수 있다.

## 인프라

| 환경 | DB | Neon 브랜치 |
|---|---|---|
| Dev | Neon Singapore | `dev` (root) |
| Stage | Neon Singapore | `stage` (prod 자식) |
| Prod | Neon Singapore | `prod` (default) |

추후 Stage/Prod를 Cloud SQL Seoul로 전환 예정 (ADR-005).

## 마이그레이션 파이프라인

```
Firestore → [TS Export] → JSONL 파일 → [Rust Import] → PostgreSQL
```

### Export (TypeScript)
- `infra/firebase/functions/src/scripts/exportFirestoreToJsonl.ts`
- Firebase Admin SDK로 14개 컬렉션 읽기 → JSONL 출력
- Timestamp → ISO 8601 변환
- `manifest.json` (컬렉션별 문서 수) 동시 생성

### Import (Rust)
- `infra/rust-backend/src/bin/data_migration.rs`
- `infra/rust-backend/src/services/data_migration_service.rs`
- UUID v5 결정적 ID 매핑 (매핑 테이블 불필요)
- `ON CONFLICT DO UPDATE` (멱등, 재실행 안전)

## Export 대상

| JSONL 파일 | Firestore 소스 |
|---|---|
| `users.jsonl` | `users/{uid}` (root doc + devices Map + groups Map) |
| `auth_accounts.jsonl` | `users/{uid}/auth/main` |
| `user_settings.jsonl` | `users/{uid}/settings/main` |
| `groups.jsonl` | `groups/{id}` |
| `promises.jsonl` | `promises/{id}` (votes 포함) |
| `personal_events.jsonl` | `users/{uid}/personalEvents/{id}` |
| `recurring_events.jsonl` | `users/{uid}/recurringEvents/{id}` |
| `notifications.jsonl` | `notifications/{id}` |
| `subscriptions.jsonl` | `subscriptions/{uid}` |
| `subscription_owners.jsonl` | `subscriptionOwners/{txnId}` |
| `entitlement_overrides.jsonl` | `entitlementOverrides/{uid}` |
| `briefing_subscriptions.jsonl` | `briefingSubscriptions/{uid}` |
| `admin_users.jsonl` | `admin/config/users/{uid}` |
| `admin_audit_logs.jsonl` | `admin/config/auditLogs/{id}` |

### Skip 대상
- `liveActivities` -- 임시 데이터
- `admin/config/coupons` -- deprecated
- `admin/config/pushJobs` -- deprecated
- `users/{uid}/cache` -- deprecated
- `entitlements/{uid}` -- PG에서 재계산

## ID 매핑 전략

| 엔티티 | Firestore ID | PG ID | 변환 |
|---|---|---|---|
| users | Firebase Auth UID | TEXT | 그대로 |
| groups | auto-generated string | UUID | UUID v5 |
| promises/schedules | auto-generated string | UUID | UUID v5 |
| personalEvents | auto-generated string | UUID | UUID v5 |
| recurringEvents | auto-generated string | UUID | UUID v5 |
| notifications | auto-generated string | UUID | UUID v5 |

UUID v5 namespace: `uuid_v5(NAMESPACE_DNS, "promiso.app/migration/{domain}")`

## 핵심 변환 규칙

| Firestore | PG | 변환 |
|---|---|---|
| `users.groups` Map | `group_members` rows | Map → 행, notification 프리셋 → boolean 컬럼 |
| `users.devices` Map | `devices` + `notification_endpoints` + `live_activity_endpoints` | 3테이블 정규화 |
| `promises.votes.accepted/declined[]` | `schedule_votes` rows | 배열 → 행 |
| `notifications.type` | `notification_type` | `promise_*` → `schedule_*` 프리픽스 |

## Import 순서 (FK 준수)

```
Phase A: users, auth_accounts, admin_users
Phase B: user_settings, groups, devices
Phase C: group_members, notification_endpoints, live_activity_endpoints
Phase D: schedules (group + personal)
Phase E: schedule_votes, recurring_schedules, notifications
Phase F: subscriptions, subscription_owners, entitlement_overrides → entitlements 재계산
Phase G: briefing_subscriptions, admin_audit_logs
```

## 실행 순서

### 1. Export
```bash
cd infra/firebase/functions
npx ts-node src/scripts/exportFirestoreToJsonl.ts --project promiso-dev --output ./export/
```

### 2. Import
```bash
cd infra/rust-backend
cargo run --bin data_migration -- \
  --users ../firebase/functions/export/users.jsonl \
  --auth-accounts ../firebase/functions/export/auth_accounts.jsonl \
  --user-settings ../firebase/functions/export/user_settings.jsonl \
  --groups ../firebase/functions/export/groups.jsonl \
  --promises ../firebase/functions/export/promises.jsonl \
  --personal-events ../firebase/functions/export/personal_events.jsonl \
  --recurring-events ../firebase/functions/export/recurring_events.jsonl \
  --notifications ../firebase/functions/export/notifications.jsonl \
  --subscriptions ../firebase/functions/export/subscriptions.jsonl \
  --subscription-owners ../firebase/functions/export/subscription_owners.jsonl \
  --entitlement-overrides ../firebase/functions/export/entitlement_overrides.jsonl \
  --briefing-subscriptions ../firebase/functions/export/briefing_subscriptions.jsonl \
  --admin-users ../firebase/functions/export/admin_users.jsonl \
  --admin-audit-logs ../firebase/functions/export/admin_audit_logs.jsonl
```

### 3. 검증
```bash
psql $DATABASE_URL -f scripts/validate_migration.sql
```

## 3단계 배포

### Dev
1. Dev Firestore Export → Dev Neon Import → 검증 → iOS 테스트

### Stage
1. Stage Firestore Export (또는 Prod 복사본) → Neon stage Import → Smoke Test

### Prod
1. Firestore Cloud Functions 비활성화
2. Prod Firestore 최종 Export → Neon prod Import
3. 검증 + Spot Check
4. Cloud Run `DATABASE_URL` → Neon prod, 재배포
5. Smoke Test + 모니터링

## Rollback

| 시나리오 | 대응 |
|---|---|
| Import 실패 | Neon TRUNCATE → 수정 → 재실행 |
| Prod 런타임 장애 | DATABASE_URL 롤백 → Cloud Run 재배포 |
| 데이터 누락 | Firestore 원본 보존 → 재 Export/Import (멱등) |

Firestore 데이터는 마이그레이션 완료 후 최소 30일간 유지.

## Post-Migration

1. Firestore 최종 백업 (`gcloud firestore export`)
2. Cloud Functions 삭제
3. `app_config.force_update_version` 설정
4. Firestore Spark 플랜 전환
5. iOS에서 FirebaseFirestore/Functions SDK 제거 (후속 릴리스)
