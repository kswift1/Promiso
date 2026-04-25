# ADR-002: 마이그레이션 전략으로 Branch by Abstraction 선택

## 상태

확정

## 맥락

Firebase 백엔드 전체를 Rust 서버로 교체해야 한다. 라이브 서비스 중인 앱이므로 유저 영향을 최소화하면서 안전하게 전환해야 한다.

앱은 Dev / Stage / Prod 3개 환경으로 분리되어 있다.
iOS 앱은 TCA 아키텍처를 사용하며, `@DependencyClient` 패턴으로 Feature → Client 레이어가 추상화되어 있다.

## 비교

| 방법론 | 설명 | 전환 안전성 | 롤백 | 운영 복잡도 | 전환 기간 |
|--------|------|------------|------|------------|----------|
| **완전 빅뱅** | 전부 개발 후 한 번에 전환 | 낮음 — 전환일에 전체 위험 집중 | 어려움 — 전체 롤백만 가능 | 낮음 | 짧음 (1일) |
| **Strangler Fig** | API 하나씩 새 시스템으로 라우팅 | 높음 | 쉬움 | 높음 — API Gateway 필요, 두 시스템 동시 운영 | 길음 |
| **Parallel Run** | 양쪽에 같은 요청, 결과 비교 | 매우 높음 | 쉬움 | 매우 높음 — 인프라 2배, 비교 로직 | 길음 |
| **Branch by Abstraction** | 추상화 레이어 내부에서 구현 분기 | 높음 | 매우 쉬움 — flag만 끔 | 낮음 — 기존 TCA 구조 활용 | 조절 가능 |

## 결정

**Branch by Abstraction + 환경별 점진 전환**을 선택한다.

### 1. Branch by Abstraction

TCA `@DependencyClient`가 이미 추상화 레이어 역할을 한다. Client의 `liveValue` 내부에서 Feature Flag로 Firebase/Rust API를 분기한다.

```swift
// GroupClient liveValue 내부
createGroup: { group in
    if FeatureFlags.useRustAPI(.groups) {
        return try await apiClient.post("/groups", body: group)
    } else {
        return try await functions.httpsCallable("createGroup").call(data)
    }
}
```

- Feature 레이어 변경 없음
- 엔드포인트 단위로 개별 전환/롤백 가능
- 새 추상화 레이어나 API Gateway 불필요

### 2. 환경별 점진 전환

기능별 전환을 환경 순서대로 진행한다:

```
Dev 환경에서 전환 & 테스트
  → 문제 없으면 Stage 환경 전환 & 테스트
    → 문제 없으면 Prod 환경 전환
```

각 환경에서 충분히 검증한 후 다음 환경으로 넘어간다.

### 3. 전환 순서 (기능별)

위험도가 낮은 기능부터 전환하여 경험을 쌓는다:

```
Phase A — 읽기 전용 API (위험 낮음)
  유저 조회, 그룹 조회, 약속 목록 등

Phase B — 쓰기 API (위험 중간)
  유저 수정, 그룹 생성/수정, 약속 생성/수정 등

Phase C — 인증 (위험 높음)
  Apple/Google Sign In → JWT 전환

Phase D — 실시간 & 고급 기능 (위험 높음)
  WebSocket, LiveActivity, 구독 검증 등
```

### 4. 롤백 전략

- **기능 단위**: Feature Flag를 끄면 해당 기능만 즉시 Firebase로 복귀
- **환경 단위**: Prod에서 문제 발생 시 Prod만 Firebase로 롤백, Dev/Stage는 Rust 유지
- **전체 롤백**: 최악의 경우 모든 Flag를 끄면 완전히 Firebase로 복귀

## 결과

- **얻는 것**: 유저 영향 최소화, 즉시 롤백, 환경별 검증, 기존 아키텍처 활용
- **잃는 것**: 전환 기간 동안 Firebase와 Rust를 동시 운영 (비용 중복)
- **후속 결정**: Feature Flag 구현 방식, 환경별 API 엔드포인트 관리
