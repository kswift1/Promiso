# ADR-010: 예약 실행 메커니즘으로 DB polling 선택

## 상태

확정

## 맥락

LiveActivity 도메인에서 미래 시점에 자동 실행해야 하는 작업이 3가지 있다:

1. `executeLiveActivityStart` — 약속 N분 전 LiveActivity 자동 시작
2. `executeLiveActivityEnd` — 약속 + 30분 후 또는 모두 도착 + 5분 후 자동 종료
3. `executeETASharingNudge` — LiveActivity 시작 후 trackingMinutes/2 경과 시 넛지 알림

현재 Firebase에서는 Cloud Tasks로 처리하고 있다. Rust 서버에서 이를 대체할 메커니즘이 필요하다.

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 안정성 | 높음 | 서버 재시작 시 예약 보존, 장애 복구 |
| 락인 | 높음 | Firebase 탈피 취지와의 정합성 |
| 확장성 | 중간 | 수평 확장 시 중복 실행 방지 |
| 스케일 비용 | 낮음 | 두 선택지 모두 Promiso 규모에서 무료 |
| 성능 | 낮음 | 30초 지연이 유스케이스에서 무의미 |

## 비교

| 기준 | A. tokio in-process | B. Cloud Tasks API | C. DB polling |
|------|--------------------|--------------------|---------------|
| 안정성 | 낮음 — 서버 재시작 시 소실 | 높음 — Google SLA | 높음 — DB 영속 |
| 락인 | 없음 | GCP 종속 추가 | 없음 |
| 확장성 | 낮음 — 중복 실행 위험 | 높음 — Google 관리 | 중간 — SKIP LOCKED |
| 스케일 비용 | 무료 | 무료 (100만/월) | 무료 |
| 성능 | 최고 (지연 없음) | 높음 (초 단위) | 중간 (최대 30초 지연) |
| 테스트 용이성 | 중간 | 낮음 (API 목킹 필요) | 높음 (기존 테스트 DB 활용) |

## 결정

**C. DB polling**을 선택한다.

`scheduled_tasks` 테이블에 예약 정보를 저장하고, tokio interval로 30초마다 폴링하여 실행한다.

핵심 이유:
1. **마이그레이션 취지**: Firebase 탈피 프로젝트에서 GCP 서비스(Cloud Tasks)를 추가하는 것은 방향에 맞지 않음
2. **테스트 용이성**: 기존 PostgreSQL 테스트 인프라를 그대로 활용 가능
3. **자체 완결**: 외부 서비스 없이 PostgreSQL만으로 해결
4. **30초 지연 무의미**: "약속 30분 전 시작"에서 최대 30초 오차는 사용자가 인지 불가

수평 확장 시 `SELECT FOR UPDATE SKIP LOCKED`로 중복 실행을 방지한다.

## 결과

- **얻는 것**: 외부 서비스 의존 제거, 테스트 용이, 서버 재시작 후 자동 복구, 이식성
- **잃는 것**: Cloud Tasks 대비 시간 정밀도 (최대 30초 지연), 재시도 로직 직접 구현 필요
- **후속 결정**: `scheduled_tasks` 테이블 스키마 설계, polling interval 설정, 재시도 정책 구현
