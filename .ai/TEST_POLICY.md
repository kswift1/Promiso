# Promiso 테스트 정책 (Test Policy)

> 테스트의 설계 기준은 [도메인 규칙](domain-rules/)입니다.
> 새 테스트 작성 시 관련 도메인 규칙을 먼저 확인하세요.

---

## 1. 핵심 원칙

- **도메인 규칙이 테스트 시나리오의 출처**다
- 테스트는 규칙이 코드에 올바르게 반영되었는지 증명한다
- 규칙 위반 코드가 들어오면 테스트가 실패하여 자동으로 막는다

---

## 2. 규칙 유형별 테스트 시나리오 도출

### 제약 조건 (Constraints) → 경계값 테스트

| 경계 유형 | 테스트 값 | 기대 결과 |
|----------|----------|----------|
| 최소값 미달 | min - 1 | 실패 |
| 최소값 정확 | min | 성공 |
| 최대값 정확 | max | 성공 |
| 최대값 초과 | max + 1 | 실패 |

```swift
// U1+U2: 닉네임 2~12자
@Test("닉네임 1자이면 tooShort")
@Test("닉네임 2자이면 성공")
@Test("닉네임 12자이면 성공")
@Test("닉네임 13자이면 tooLong")
```

### 권한 (Permissions) → 허용/거부 쌍 테스트

권한 규칙은 **허용 + 거부**를 반드시 쌍으로 검증한다.

```swift
// P10: 수정 권한 = 호스트 또는 그룹 호스트
@Test("약속 호스트는 수정 가능")
@Test("그룹 호스트는 수정 가능")
@Test("일반 멤버는 수정 불가")
```

### 동작 규칙 (Behaviors) → 입력/출력 테스트

```swift
// P22-P25: 확정/불발 판정
@Test("accepted >= minimumParticipants이면 confirmed")
@Test("전원 응답 + 미확정이면 failed")
@Test("남은 인원 전원 수락해도 최소인원 불가면 failed")
```

### 표시 규칙 (Display) → 값 일치 테스트

```swift
// P39: 오늘 약속 최대 5개
@Test("오늘 약속 10개 중 5개만 표시")
```

---

## 3. 프레임워크 및 작성 규칙

- **Swift Testing** (`import Testing`) 사용 필수, XCTest 금지
- TCA `TestStore` 기반 Reducer 테스트
- `@Suite` + `@Test` 한글 설명
- `#expect()` 사용

```swift
@Suite("약속 확정/불발 판정 테스트")
struct PromiseConfirmationTests {
  @Test("accepted >= minimumParticipants이면 confirmed")
  func responseStatus_whenEnoughAccepted_isConfirmed() {
    let promise = makePromise(
      minimumParticipants: 3,
      acceptedIds: ["a", "b", "c"]
    )
    #expect(promise.responseStatus == .confirmed)
  }
}
```

---

## 4. 테스트 우선순위

| 우선순위 | 대상 | 이유 |
|:-------:|------|------|
| 1 | 제약 조건 경계값 | 잘못된 데이터 유입 방지 |
| 2 | 권한 허용/거부 | 보안 위반 방지 |
| 3 | 상태 계산 로직 | 비즈니스 정확성 |
| 4 | 표시 규칙 | UI 일관성 |

---

## 관련 문서

- [DOMAIN_RULES.md](DOMAIN_RULES.md) — 도메인 규칙 인덱스
- [domain-rules/](domain-rules/) — 도메인별 상세 규칙
- [DOMAIN_RULES_BACKLOG.md](DOMAIN_RULES_BACKLOG.md) — 충돌/누락/예정 변경사항

---

*마지막 업데이트: 2026-02-12*
