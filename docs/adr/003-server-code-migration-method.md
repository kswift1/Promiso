# ADR-003: 서버 코드 마이그레이션 방법으로 레이어 우선 + 도메인 단위 재설계 선택

## 상태

확정

## 맥락

Firebase Cloud Functions 50개+ (TypeScript)를 Rust API 서버로 전환해야 한다. 함수들은 도메인별로 나뉘어 있다:

- users.ts (6개), groups.ts (9개), promises.ts (5개), notifications.ts (5개)
- liveActivity.ts (8개), voteLiveActivity.ts (5개), scheduleConflicts.ts (7개)
- subscription.ts (2개), briefing.ts (1개), 기타 (widget, emoji, faq, kakaoMap 등)

Firestore의 비정규화 구조(scheduleSlots, users.groups Map 등)와 트리거 기반 로직(13개+)이 혼재되어 있다.

## 비교

| 방법 | 설명 | 코드 품질 | 위험도 | 효율 |
|------|------|----------|--------|------|
| **A. 함수 단위 1:1** | 각 Function을 그대로 Rust 함수로 변환 | 낮음 — Firebase 구조적 한계를 그대로 계승. 비정규화 로직이 Rust에도 남음 | 낮음 — 변환이 기계적 | 높음 — 단순 반복 |
| **B. 도메인 단위 재설계** | 도메인별로 묶어서 비즈니스 로직 재설계. SQL 장점 활용 | 높음 — 정규화, JOIN 활용, 트리거 흡수 | 중간 — 재설계 과정에서 로직 누락 가능 | 중간 |
| **C. 레이어 우선** | 공통 인프라(DB, 인증, 에러) 먼저 구축 후 핸들러 얹기 | 높음 — 일관된 구조 | 낮음 — 토대가 안정적 | 초반 느림, 후반 빠름 |

## 결정

**C (레이어 우선) + B (도메인 단위 재설계)** 를 결합한다.

### Step 1 — 레이어 우선으로 토대 구축

```
1층: 공통 인프라
  - DB 연결 (SQLx + PostgreSQL)
  - JWT 인증 미들웨어
  - 에러 처리 (AppError → HTTP 응답)
  - 응답 포맷 표준화

2층: 도메인 모델
  - User, Group, Promise 등 구조체 정의
  - PostgreSQL 스키마와 1:1 매핑
```

### Step 2 — 도메인 단위로 마이그레이션 (반복)

각 도메인마다 동일한 과정을 반복한다:

```
1) Firebase Functions 코드를 읽고 비즈니스 로직 추출
2) Firestore 비정규화 → PostgreSQL 정규화로 재설계
3) Firestore 트리거 → 핸들러 내부 로직 or DB 수준으로 흡수
4) httpsCallable → RESTful 엔드포인트로 재구성
5) Rust 핸들러 구현
```

### 도메인 전환 예시 (groups)

```
[Firebase: groups.ts 9개 함수]
  createGroup         → POST   /groups
  previewGroup        → GET    /groups/preview?code=XXX
  joinGroup           → POST   /groups/:id/join
  leaveGroup          → POST   /groups/:id/leave
  updateGroup         → PATCH  /groups/:id
  deleteGroup         → DELETE /groups/:id
  transferGroupHost   → POST   /groups/:id/transfer-host
  expelMember         → POST   /groups/:id/members/:uid/expel
  onGroupImageUpdated → 트리거 제거, 이미지 업로드 API에 썸네일 로직 포함

[비정규화 제거]
  users.groups Map → groups_members 조인 테이블
  groups.memberIds 배열 → groups_members 조인 테이블
```

### 도메인 전환 순서

토대 의존도가 낮은 것부터:

```
1. users    — 가장 기본, 다른 도메인이 의존
2. groups   — users 다음으로 기본
3. promises — groups에 의존
4. personalEvents — 독립적
5. notifications — 다른 도메인 이벤트에 반응
6. subscription — 독립적이나 StoreKit 연동 복잡
7. liveActivity — promises + APNs 의존
8. briefing — 외부 API 의존 (Gemini, 날씨, 교통)
```

## 결과

- **얻는 것**: SQL 장점 활용 (JOIN, 정규화), 일관된 서버 구조, 비정규화 유지보수 제거
- **잃는 것**: 1:1 변환 대비 시간 소요 (재설계 필요)
- **후속 작업**: 첫 도메인(users) 전환 후 마이그레이션 플레이북 작성 (반복 패턴 문서화)
