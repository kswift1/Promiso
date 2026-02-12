# LiveActivity 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 제약 조건 (Constraints)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| L1 | 추적 시간 입력 최대 자릿수 | 3자리 (최대 999분) | ✅ | — |
| L2 | 프리셋 옵션 | 15분, 30분, 60분 | ✅ | — |
| L3 | trackPosition 범위 | 0.05 ~ 0.95 (clamp) | ✅ | — |

---

## 2. 권한 (Permissions)

| ID | 규칙 | 조건 | iOS | Backend |
|----|------|------|:---:|:-------:|
| L4 | LiveActivity 시작 = 호스트만 | `userId === hostId` | — | ✅ |

---

## 3. 동작 규칙 (Behaviors)

### 3-1. 기본값

| ID | 규칙 | 값 |
|----|------|-----|
| L5 | 기본 추적 시간 | 30분 |
| L6 | 커스텀 입력 빈 값 폴백 | 30분으로 복원 |

### 3-2. 실시간 공유

| ID | 규칙 | 조건 |
|----|------|------|
| L7 | 실시간 공유 조건 | trackingMinutes 존재 && 추적 시간 내 && 시작 전 |
| L8 | ETA 의미 | nil = 대기중, 0 = 도착, > 0 = 남은 분 |
| L9 | 도착 판정 | ETA == 0 |

### 3-3. 자동 스케줄링

| ID | 규칙 | 상세 |
|----|------|------|
| L10 | 약속 확정 + tracking 설정 → 자동 예약 | `onPromiseConfirmedScheduleLiveActivity` 트리거 |
| L11 | 확정 취소 → 예약 리셋 | `liveActivityScheduled = false` |
| L12 | trackingMinutes null 변경 → 예약 리셋 | 라이브 액티비티 비활성화 |
| L13 | 예약 시작 시 확정 상태 재확인 | 미확정이면 스킵 |

### 3-4. 종료 조건

| ID | 규칙 | 값 |
|----|------|-----|
| L14 | 자동 종료: 시작 후 | 30분 |
| L15 | 모두 도착 시 지연 종료 | dev: 1분, stage: 3분, prod: 5분 |

### 3-5. 알림

| ID | 규칙 | 조건 |
|----|------|------|
| L16 | 첫 도착 알림 | `arrivedCount == 1 && totalCount > 1 && 본인이 방금 도착` |

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 |
|----|------|-----|
| L17 | 첫 사용 안내 팝오버 | `hasSeenLiveActivityInfo` UserDefaults 키로 최초 1회만 |
| L18 | ETA 업데이트 동시성 보호 | `isProcessingETAUpdate` guard |
