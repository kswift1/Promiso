# ADR-008: 스키마, API 스펙, 매핑 문서 관리 전략

## 상태

확정

## 맥락

Firebase → Rust 마이그레이션을 진행하면서 세 가지 문서 관리 방식을 결정해야 한다:

1. PostgreSQL 스키마를 어디서 관리할 것인가
2. REST API 스펙을 어떤 형태로 유지할 것인가
3. Firebase → Rust 전환 매핑을 어떻게 추적할 것인가

현재 Firebase 쪽은 이미 정리되어 있다:
- `infra/firebase/functions/openapi.yaml` — API 스펙
- `.ai/FIRESTORE_SCHEMA.md` — DB 스키마

## 결정

### 1. PostgreSQL 스키마: migrations(SSOT) + `.ai/POSTGRES_SCHEMA.md`(사람용 요약)

| 역할 | 파일 | 설명 |
|------|------|------|
| SSOT (실행 가능) | `infra/rust-backend/migrations/*.sql` | 실제 DB에 적용되는 마이그레이션 |
| 사람용 요약 | `.ai/POSTGRES_SCHEMA.md` | 현재 전체 스키마를 한눈에 파악 |

- 마이그레이션 파일이 누적되면 현재 상태 파악이 어려워지므로 `.md` 요약이 필요
- `.md`는 `/rust-migrate` 실행 시 AI가 자동 업데이트하여 이중 부담 제거
- 실제 DB 상태와 `.md`가 불일치하면 migrations이 진실

### 2. REST API 스펙: `.ai/` 마크다운

| 역할 | 파일 | 설명 |
|------|------|------|
| API 목록 | `.ai/REST_API.md` | 엔드포인트 테이블 + 요청/응답 형식 |

- 솔로 개발 + AI가 주 소비자 → OpenAPI yaml은 과함
- 마크다운이면 AI가 바로 참조 가능하고 유지도 쉬움
- 팀이 커지면 OpenAPI로 전환 가능 (마크다운에서 변환 용이)

**탈락 사유:**
- OpenAPI: yaml 작성/관리 번거로움, 솔로 개발에 과도한 투자
- 코드만: 전체 API 조감 불가, 코드를 일일이 열어봐야 함

### 3. 매핑 문서: 도메인별 전환 추적 문서

| 역할 | 파일 | 설명 |
|------|------|------|
| 도메인별 매핑 | `docs/migration/{domain}.md` | Firebase Function → REST 엔드포인트 매핑 + 전환 상태 |

- 8개 도메인 전환 기간 동안 "이 Function이 어디로 갔는지" 추적 필수
- `/rust-migrate` 실행 시 Step 1(분석)과 Step 6(API 설계) 결과를 자동 저장
- 전환 완료 후 `docs/migration/` → archive

## 문서 구조 요약

```
.ai/
├── POSTGRES_SCHEMA.md          # 현재 PostgreSQL 전체 스키마 (사람용)
├── REST_API.md                 # REST 엔드포인트 목록
├── FIRESTORE_SCHEMA.md         # 기존 Firestore 스키마 (참조용)
└── ...

infra/rust-backend/migrations/  # 스키마 SSOT (SQL)

docs/migration/
├── users.md                    # Firebase users.ts → Rust 매핑
├── groups.md                   # Firebase groups.ts → Rust 매핑
└── ...                         # 도메인별 추가
```

## 결과

- **얻는 것**: 스키마/API/매핑 각각에 적합한 문서 형태, AI가 자동 유지보수, 전환 진행률 추적
- **잃는 것**: OpenAPI 도구 생태계 (Swagger UI, 코드 생성 등) — 현 시점에서는 불필요
- **후속 작업**: `/rust-migrate` 스킬에 문서 자동 업데이트 단계 추가
