---
name: rust-migrate
description: Firebase → Rust 도메인 마이그레이션 실행 (TDD, 9 Step)
---

# /rust-migrate $ARGUMENTS

Firebase 도메인을 Rust API로 마이그레이션합니다.
`$ARGUMENTS`에 도메인명(예: "groups") 또는 인프라 토픽(예: "서버 뼈대", "인증")을 받습니다.

## 실행 전 준비

1. `docs/adr/` 의 기존 ADR을 읽어 확정된 결정 확인
2. `docs/adr/003-server-code-migration-method.md`의 도메인 전환 순서 확인
3. `infra/rust-backend/`의 현재 상태 확인 (없으면 Step 3에서 생성)

## 실행 흐름

### Step 1 — 현행 분석

해당 도메인의 Firebase 구현을 전부 읽는다:

- `infra/firebase/functions/src/{domain}.ts` — Cloud Functions 코드
- `infra/firebase/firestore.rules` — 해당 컬렉션 보안 규칙
- `.ai/FIRESTORE_SCHEMA.md` — 해당 컬렉션 스키마
- `Projects/Clients/Sources/Data/DataSources/` — 해당 RemoteDataSource
- `Projects/Clients/Sources/Clients/{Domain}Client.swift` — Client 인터페이스

**결과물**: 현행 정리표 (유저에게 보여줌)

```
| 함수 | 호출 방식 | 입력 | 출력 | 권한 검증 | 사이드이펙트 |
```

### Step 2 — 비즈니스 규칙 추출

코드에 묻혀있는 규칙을 명시적으로 뽑는다:

- 권한 규칙 (누가 뭘 할 수 있는가)
- 유효성 검증 (입력 제약)
- 사이드이펙트 (알림 발송, 비정규화 갱신 등)
- 엣지 케이스 (호스트가 나가려고 하면? 등)

**결과물**: 비즈니스 규칙 목록 (유저에게 보여주고 누락 확인)

### Step 3 — 테스트 작성 (Red)

추출한 비즈니스 규칙을 Rust 테스트로 변환한다:

- 각 규칙 → 최소 1개 테스트
- 정상 케이스 + 실패 케이스 (권한 없음, 유효성 위반 등)
- `cargo test`로 전부 실패(Red) 확인

```rust
#[tokio::test]
async fn host_can_delete_group() { ... }

#[tokio::test]
async fn non_host_cannot_delete_group() { ... }
```

### Step 4 — 기술 결정 (ADR)

해당 도메인에서 기술 선택이 필요하면 ADR을 작성한다.

**ADR이 필요한 경우**: 라이브러리, 서비스, 아키텍처 패턴 등 2개 이상의 선택지가 있을 때
**ADR이 불필요한 경우**: 이전 ADR에서 이미 결정됨, 또는 사실상 선택지가 1개일 때

**ADR 작성 규칙**:
- `docs/adr/000-template.md` 포맷을 따름
- **반드시 6가지 평가 기준으로 비교** (해당 결정 맥락에서 가중치 조정):
  1. 스케일 비용
  2. 확장성
  3. 안정성
  4. 락인
  5. 성능
  6. 안전성
- 러닝커브, DX, 문서 품질은 평가 기준에서 제외 (AI 활용 전제)
- **유저에게 비교표를 보여주고, 유저가 이해한 후 결정을 확정**한다

### Step 5 — 스키마 재설계

Firestore 비정규화 → PostgreSQL 정규화:

- Map 필드 → 조인 테이블 또는 jsonb
- 서브컬렉션 → FK 관계
- 배열 필드 → 조인 테이블
- SQL 마이그레이션 파일 작성

유저에게 Before/After 스키마를 보여주고 확인받는다.

### Step 6 — API 설계

- `httpsCallable` → RESTful 엔드포인트로 재구성
- Firestore 트리거 → 핸들러 내부 로직 또는 DB 수준으로 흡수 결정
- 엔드포인트 목록을 유저에게 보여주고 확인받는다

### Step 7 — 구현 (Green)

테스트를 통과시키는 코드를 작성한다:

- SQL 마이그레이션 실행
- 도메인 모델 구조체
- 핸들러 (비즈니스 규칙 포함)
- `cargo test`로 전부 통과(Green) 확인
- `cargo build`로 빌드 확인
- **rust-implementer 에이전트에게 위임** (Rust 코드 작성)
- 새로 등장하는 Rust 개념은 유저에게 Swift 비교로 설명

### Step 8 — iOS 연결

Client의 `liveValue`에 Feature Flag 분기를 추가한다:

```swift
if FeatureFlags.useRustAPI(.{domain}) {
    // Rust API 호출
} else {
    // 기존 Firebase 호출
}
```

- iOS 코드 수정은 기존 워크플로우를 따름 (implementer 위임)

### Step 9 — 검증 (Dev 환경)

- Dev 환경에서 Feature Flag 활성화
- 핵심 시나리오 테스트
- 문제 시 flag 끄고 Firebase 복귀

## 참고 자료

- ADR 결정 기록: `docs/adr/`
- ADR 템플릿: `docs/adr/000-template.md`
- Firestore 스키마: `.ai/FIRESTORE_SCHEMA.md`
- 도메인 비즈니스 규칙: `.ai/DOMAIN_RULES.md`, `.ai/domain-rules/`
- Firebase Functions: `infra/firebase/functions/src/`
- iOS Client: `Projects/Clients/Sources/`
- Rust 프로젝트: `infra/rust-backend/`

## 주의사항

- Rust 코드 작성은 **rust-implementer** 에이전트에게 위임
- iOS 코드 (Projects/) 수정은 기존 **implementer** 에이전트에게 위임
- 매 Step에서 유저에게 결과를 보여주고 확인받은 후 다음 Step으로 진행
