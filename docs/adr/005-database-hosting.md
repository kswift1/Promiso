# ADR-005: 데이터베이스로 Cloud SQL(Prod) + Neon(Dev) 선택

## 상태

확정

## 맥락

Rust 서버(Cloud Run, 서울)에 연결할 PostgreSQL을 어디서 호스팅할지 결정해야 한다.

환경별로 요구사항이 다르다:
- **Prod**: 안정성, 레이턴시, 백업이 중요. 비용은 합리적 수준이면 허용
- **Dev**: 비용 $0이 이상적. 빠른 반복, 스키마 실험이 중요

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 서버-DB 레이턴시 | 높음 | Cloud Run(서울)과의 연결 속도 |
| 비용 | 높음 | 초기 저트래픽 기준 월 비용 |
| 관리 부담 | 중간 | 백업, 스케일링, 모니터링 자동화 수준 |
| Dev 경험 | 중간 | 스키마 브랜칭, 무료 티어, scale-to-zero |
| 확장성 | 중간 | 트래픽 증가 시 대응 |

## 비교

| 기준 | Cloud SQL | Neon | Supabase | Railway PG |
|------|-----------|------|----------|------------|
| 서울 리전 | **있음** | 없음 (싱가포르) | **있음** | 없음 (싱가포르) |
| Cloud Run↔DB | **~1ms (VPC)** | ~70ms | ~1ms (서울) | ~70ms |
| Prod 월비용 | ~$10–15 (db-f1-micro) | $19+ (Launch) | $25 (Pro) | $5–10 |
| Dev 월비용 | ~$10 (항상 켜짐) | **$0 (scale-to-zero)** | $0 (7일 비활성 정지) | $5 |
| 관리 부담 | **자동 백업, 패치** | 자동 | 자동 | 수동 백업 |
| Dev 경험 | 보통 | **브랜칭, scale-to-zero** | Auth/Storage 번들 | 보통 |
| Connection Pooling | Cloud SQL Proxy | PgBouncer 내장 | PgBouncer 내장 | 없음 |
| 확장성 | 수직/수평 모두 | 자동 (serverless) | 수직 | 수직 |

### 주요 고민 과정

**단일 DB 호스팅의 한계**

처음에는 Neon 하나로 Prod/Dev 모두 커버하려 했다. 문제:
- Neon 아시아 리전이 싱가포르뿐 → Cloud Run(서울)에서 ~70ms
- API 하나에 쿼리 3–4개면 200–300ms 누적 → UX에 영향

Supabase는 서울 리전이 있지만:
- 순수 DB 용도로 Pro $25/월은 과함 (Auth, Storage 등 불필요한 번들)
- Free tier는 7일 비활성 시 자동 정지 → Dev에서도 불안정

**환경별 분리라는 해답**

Prod과 Dev의 요구사항이 다르다는 점에 착안:

| 환경 | 최우선 | 차선 |
|------|--------|------|
| Prod | 레이턴시, 안정성 | 비용 |
| Dev | 비용 $0, 실험 편의 | 레이턴시 (무관) |

→ Prod은 Cloud SQL(서울), Dev는 Neon(싱가포르)으로 분리하면 각각의 장점만 취할 수 있다.

**Cloud SQL이 Prod에 최적인 이유**
- Cloud Run과 같은 GCP 프로젝트 → VPC 내부 연결 (~1ms, 외부 노출 없음)
- 자동 백업, 자동 패치, 고가용성 옵션
- db-f1-micro로 시작해서 트래픽에 따라 스케일 업

**Neon이 Dev에 최적인 이유**
- 완전 무료 (100 CU-시간/월, 0.5GB)
- Scale-to-zero — 5분 유휴 시 자동 중지, 접속 시 자동 재시작
- 브랜칭 — feature별 DB 브랜치로 스키마 실험 가능
- Dev에서 싱가포르 70ms는 개발 중 체감 불가

## 결정

**Prod은 Cloud SQL(서울), Dev는 Neon(싱가포르)을 사용한다.**

### 구조

```
[Prod]
Cloud Run (Seoul) ──VPC──→ Cloud SQL (Seoul)
                            ~1ms, 자동 백업

[Dev]
Cloud Run (Seoul) ──HTTPS──→ Neon (Singapore)
                              ~70ms, 무료, scale-to-zero
```

### 코드 레벨 전환

SQLx는 `DATABASE_URL` 환경변수로 연결 대상을 결정한다. 코드 변경 없이 환경변수만 바꾸면 된다:

```bash
# Dev (.env.dev)
DATABASE_URL=postgresql://user:pass@ep-xxx.ap-southeast-1.aws.neon.tech/promiso

# Prod (Cloud Run 환경변수)
DATABASE_URL=postgresql://user:pass@/promiso?host=/cloudsql/PROJECT:asia-northeast3:promiso-db
```

### 비용 구조

| 환경 | 서버 (Cloud Run) | DB | 합계 |
|------|-----------------|-----|------|
| Dev | $0 (scale-to-zero) | $0 (Neon Free) | **$0** |
| Prod (초기) | $0–5 (저트래픽) | ~$10–15 (db-f1-micro) | **~$10–20/월** |
| Prod (성장) | 종량제 | 스케일 업 | 트래픽 비례 |

## 결과

- **얻는 것**: Prod 최저 레이턴시(~1ms), Dev 비용 $0, 환경별 최적화, 코드 변경 없는 전환
- **잃는 것**: 두 종류의 PostgreSQL 관리 (실제로는 표준 PG이므로 차이 미미)
- **후속 결정**: Cloud SQL 초기 인스턴스 스펙 (db-f1-micro vs db-g1-small), 마이그레이션 도구 설정 (SQLx migrate)
