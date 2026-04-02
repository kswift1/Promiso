# ADR-004: 서버 호스팅으로 Cloud Run 선택

## 상태

확정

## 맥락

Rust(Axum) 서버를 어디서 실행할지 결정해야 한다. 현재 상황:

- 솔로 개발자 — 인프라에 시간 쓰면 손해
- 한국 대상 서비스 — 레이턴시가 UX에 직결
- LiveActivity는 APNs 기반 — WebSocket 장시간 연결 불필요
- 초기 트래픽 적음 — 비용 최소화 필요
- Firebase에서 점진 전환 중 — 환경별 배포 필요 (Dev/Stage/Prod)

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 한국 레이턴시 | 높음 | 서울 리전 유무, 한국 사용자 응답 시간 |
| 비용 구조 | 높음 | 초기 저트래픽에서 비용, scale-to-zero 여부 |
| 배포 난이도 | 높음 | 솔로 개발자가 얼마나 신경 안 쓰고 배포할 수 있는가 |
| DB 연결 | 중간 | 같은 리전/VPC 내 PostgreSQL 연결 가능 여부 |
| Rust 지원 | 중간 | Rust 바이너리 배포 지원 수준 |
| 확장성 | 중간 | 트래픽 증가 시 자동 스케일링 |

> LiveActivity가 APNs 기반이므로 WebSocket 지원 수준은 평가 기준에서 제외했다.

## 비교

| 기준 | Cloud Run | Fly.io | Railway | Render |
|------|-----------|--------|---------|--------|
| 한국 레이턴시 | **~5ms (서울 리전)** | ~30ms (도쿄) | ~80ms (싱가포르만) | ~80ms (싱가포르만) |
| 비용 구조 | **$0 (scale-to-zero)** | ~$4/월 (항상 켜짐) | ~$5/월 (Hobby) | ~$7/월 (Starter) |
| 배포 난이도 | 쉬움 — Docker + `gcloud run deploy` | 중간 — Dockerfile + `flyctl deploy` | **가장 쉬움** — git push | 쉬움 — git push |
| DB 연결 | **Cloud SQL 같은 VPC (~1ms)** | Neon만 가능 (~70ms) | 같은 플랫폼 PG (~1ms) | 같은 플랫폼 PG (~1ms) |
| Rust 지원 | Docker 컨테이너 | 공식 Axum 템플릿 | Nixpack 자동 감지 | 공식 지원 |
| 확장성 | **자동 (0→N 인스턴스)** | 수동 스케일 | Pro 플랜 확장 | 수동 스케일 |

### 주요 고민 과정

**1차 판단: Fly.io + Neon 유력**
- WebSocket 무제한이 LiveActivity에 최적이라 판단
- Fly.io의 Rust 공식 지원, Neon의 관대한 Free tier

**전환점: LiveActivity는 APNs 기반**
- WebSocket 장시간 연결이 불필요해지면서 Fly.io의 최대 장점 소멸
- 서버-DB 간 70ms(Tokyo↔Singapore) 레이턴시가 오히려 약점으로 부각

**2차 판단: Cloud Run 재평가**
- 서울 리전으로 한국 레이턴시 최소
- Scale-to-zero로 초기 비용 $0
- Rust 바이너리의 cold start가 ~100ms 이내로 사실상 무시 가능
- Cloud SQL(서울)과 같은 VPC 연결 시 서버-DB 레이턴시 ~1ms

**Railway는 왜 탈락했나**
- DX는 압도적이지만 서울/도쿄 리전 없음
- 싱가포르만 가능 → 한국 사용자에게 ~80ms 기본 레이턴시

## 결정

**Cloud Run을 서버 호스팅으로 선택한다.**

핵심 이유: 서울 리전 + scale-to-zero + Cloud SQL VPC 연결. "얼마나 신경 안 쓰고 개발할 수 있냐"에서 Railway에 약간 뒤지지만, 한국 서비스에서 레이턴시 차이(5ms vs 80ms)가 결정적이다.

### 배포 구조

```
iOS (Swift + TCA)
      ↓ HTTPS
Cloud Run (Seoul, Rust + Axum)
      ↓ VPC
Cloud SQL PostgreSQL (Prod)
Neon PostgreSQL (Dev)
```

### 환경별 배포

| 환경 | Cloud Run | DB |
|------|-----------|-----|
| Dev | Cloud Run (Seoul) | Neon (Singapore) — 무료 |
| Stage | Cloud Run (Seoul) | Cloud SQL (Seoul) — Prod 동일 |
| Prod | Cloud Run (Seoul) | Cloud SQL (Seoul) |

## 결과

- **얻는 것**: 서울 리전 최저 레이턴시, 초기 비용 $0, 자동 스케일링, Cloud SQL과 VPC 내부 연결
- **잃는 것**: Railway 대비 약간 높은 배포 설정 난이도 (Docker 작성 필요)
- **후속 결정**: Cloud SQL 인스턴스 스펙 (→ ADR-005), Docker 빌드 최적화 (cargo-chef 등)
