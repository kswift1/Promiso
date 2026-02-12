# 약속 (Promise) 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 제약 조건 (Constraints)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| P1 | 제목 필수 | 비어있지 않은 문자열 (trim) | ✅ | ✅ |
| P2 | 제목 최대 길이 | 30자 | ✅ `prefix(30)` | — |
| P3 | 설명 최대 길이 | 500자 | ✅ `prefix(500)` | — |
| P4 | 시작 시간 | 현재보다 미래 | ✅ | ✅ |
| P5 | 종료 시간 | 설정 시 시작 시간 이후 | ✅ | — |
| P6 | 최소 참여 인원 | 2명 이상 | ✅ | ✅ |
| P7 | 그룹 멤버 수 조건 | 2명 이상 (약속 생성 시) | ✅ | — |
| P8 | 장소 선택 | useLocation 토글 ON 시 필수 | ✅ | — |

---

## 2. 권한 (Permissions)

| ID | 규칙 | 조건 | iOS | Backend |
|----|------|------|:---:|:-------:|
| P9 | 생성 = 그룹 멤버만 | `memberIds.includes(userId)` | — | ✅ |
| P10 | 수정 권한 | 약속 호스트 또는 그룹 호스트 | ✅ | ✅ |
| P11 | 삭제 권한 | 약속 호스트 또는 그룹 호스트 | ✅ | ✅ |
| P12 | 수정 시간 제한 | 시작 전만 가능 | ✅ | ✅ |
| P13 | 삭제 시간 제한 | 시작 전만 가능 | — | ✅ |
| P14 | LiveActivity 실행 중 수정 불가 | `liveActivityScheduled && scheduledAt <= now` | — | ✅ |
| P15 | 투표 응답 = 같은 그룹 멤버만 | group membership 확인 | — | ✅ |

---

## 3. 동작 규칙 (Behaviors)

### 3-1. 생성 기본값

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| P16 | 호스트 자동 수락 | 생성자는 자동 accepted | — | ✅ |
| P17 | 기본 최소참석인원 | `ceil(memberCount / 2)`, 2인 그룹이면 고정 2 | ✅ | — |
| P18 | 기본 종료시간 | 시작시간 + 2시간 | ✅ | — |
| P19 | 투표 마감 기본값 | startAt과 동일 | — | ✅ |
| P20 | 기본 이모지 (미설정 시) | iOS: "📌" / Backend: "📅" | ✅ | ✅ |
| P21 | isConfirmed 비정규화 필드 | `accepted.length >= minimumParticipants` 자동 계산 | — | ✅ |

### 3-2. 확정/불발 판정

| ID | 규칙 | 조건 |
|----|------|------|
| P22 | 확정 | `accepted.count >= minimumParticipants` |
| P23 | 불발 조건 1 | 투표 마감 + 미확정 |
| P24 | 불발 조건 2 | 전원 응답 + 미확정 |
| P25 | 불발 조건 3 | 남은 인원 전원 수락해도 최소인원 도달 불가 |
| P26 | 응답 상태 우선순위 | `failed > needResponse > confirmed > responded` |

### 3-3. 투표 동작

| ID | 규칙 | 상세 | iOS | Backend |
|----|------|------|:---:|:-------:|
| P27 | 동일 상태 중복 투표 | no-op (변경 없이 반환) | — | ✅ |
| P28 | 투표 pending 응답 | accepted/declined 양쪽에서 제거 | — | ✅ |
| P29 | 투표 시 isConfirmed 재계산 | 트랜잭션 내 실시간 계산 | — | ✅ |

### 3-4. 수정 연동

| ID | 규칙 | 상세 | iOS | Backend |
|----|------|------|:---:|:-------:|
| P30 | 시작 시간 변경 → votes.until 동기화 | 투표 마감도 함께 변경 | — | ✅ |
| P31 | 시작 시간 변경 → LiveActivity 예약 리셋 | `liveActivityScheduled = false` | — | ✅ |
| P32 | 위치(location) 수정 불가 | 생성 후 변경 불가, 읽기 전용 | ✅ | — |
| P33 | 변경 감지 필드 (7개) | title, emoji, description, startAt, endAt, minimumParticipants, trackingStartMinutesBefore | ✅ | — |

### 3-5. 시간 기반 상태

| ID | 규칙 | 조건 |
|----|------|------|
| P34 | 진행 중 (isOngoing) | `now >= startAt && now <= endAt` (endAt 없으면 startAt 이후 무한) |
| P35 | 지난 약속 (isPast) | `now > endAt` (endAt 없으면 `now > startAt`) |
| P36 | 다가오는 약속 (isUpcoming) | `now < startAt` |
| P37 | departureSoon 기준 | 시작 30분 전 |

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| P38 | 이모지 AI 추천 디바운스 | 1초 | ✅ | — |
| P39 | 오늘 약속 최대 표시 | 5개 | ✅ | — |
| P40 | 대기 중 약속 최대 표시 | 5개 | ✅ | — |
| P41 | 다가오는 약속 최대 표시 | 5개 (서버 10개) | ✅ | ✅ |
| P42 | 참가자 아바타 최대 표시 | 5명, 초과 시 "+N" | ✅ | — |
| P43 | 설명 텍스트 접기 줄 수 | 3줄 | ✅ | — |
| P44 | 캘린더 조회 최대 | 50개 | — | ✅ |
| P45 | CriticalZone 우선순위 | liveActivity(1) > inProgress(2) > departureSoon(3) | ✅ | — |

---

## 5. 코드 매핑 (Code Mapping)

> 마지막 매핑: 2026-02-12 | iOS 구현 없는 규칙(Backend only)은 `—` 표시

### 제약 조건

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| P1 | `PromiseModel.swift` `isTitleValid` | `PromiseModelValidationTests` 4개 | ✅ |
| P2 | `TitleInputTextField.swift` `prefix(30)` | Preview만 | ⚠️ |
| P3 | `CreatePromiseFeature.swift` `prefix(500)` | — | ❌ |
| P4 | `PromiseModel.swift` `isStartTimeValid` | `PromiseModelValidationTests` 2개 | ✅ |
| P5 | `PromiseModel.swift` `isEndTimeValid` | `PromiseModelValidationTests` 4개 | ✅ |
| P6 | `PromiseModel.swift` `isMinimumParticipantsValid` | `PromiseModelValidationTests` 4개 | ✅ |
| P7 | `CreatePromiseFeature.swift` `firstButtonDisabled` | `CreatePromiseReducerTests` 2개 | ✅ |
| P8 | `CreatePromiseFeature.swift` `secondButtonDisabled` | — | ❌ |

### 권한

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| P9 | — | — | — |
| P10 | `PromiseDetailFeature.swift` `canManage` | — | ❌ |
| P11 | `PromiseDetailFeature.swift` `canManage` | — | ❌ |
| P12 | `PromiseDetailFeature.swift` `canEdit` | — | ❌ |
| P13~P15 | — | — | — |

### 동작 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| P16 | — | — | — |
| P17 | `CreatePromiseFeature.swift` `.groupSelected` | `CreatePromiseReducerTests` 1개 | ✅ |
| P18 | `CreatePromiseFeature.swift` `.toggleUseEndTime` | — | ❌ |
| P19 | — | — | — |
| P20 | `PromiseModel.swift` `displayEmoji` | `PromiseModelTests` 3개 | ✅ |
| P21 | — | — | — |
| P22 | `PromiseModel.swift` `responseStatus` | `PromiseModelTests` 8개 (P22-P26 공통) | ✅ |
| P23 | ↑ | ↑ | ✅ |
| P24 | ↑ | ↑ | ✅ |
| P25 | ↑ | ↑ | ✅ |
| P26 | ↑ | ↑ | ✅ |
| P27~P31 | — | — | — |
| P32 | `EditPromiseFeature.swift` location 필드 없음 (read-only) | — | ❌ |
| P33 | `EditPromiseFeature.swift` `hasChanges` | — | ❌ |
| P34 | `PromiseModel.swift` `isOngoing` | `PromiseModelTests` 5개 | ✅ |
| P35 | `PromiseModel.swift` `isPast` | `PromiseModelTests` 3개 | ✅ |
| P36 | `PromiseModel.swift` `isUpcoming` | `PromiseModelTests` 2개 | ✅ |
| P37 | 구현 미확인 (departureSoon 30분) | — | ❌ |

### 표시 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| P38 | `CreatePromiseFeature.swift` `.setTitle` 디바운스 1000ms | — | ❌ |
| P39 | `GroupPromiseListFeature.swift` 필터링 | — | ❌ |
| P40 | `GroupPromiseListFeature.swift` 필터링 | — | ❌ |
| P41 | `GroupPromiseListFeature.swift` 필터링 | — | ❌ |
| P42 | UI 컴포넌트 | — | ❌ |
| P43 | View `lineLimit` ⚠️ 코드=2줄, 규칙=3줄 | — | ❌ |
| P44 | — | — | — |
| P45 | HomeFeature / RootTabFeature | — | ❌ |

### ⚠️ 불일치 발견

| ID | 내용 |
|----|------|
| P43 | 규칙=3줄, 코드=`lineLimit(2)` — 확인 필요 |

### 핵심 파일

| 구현 파일 | 경로 | 관련 규칙 |
|----------|------|----------|
| PromiseModel.swift | `Clients/Sources/Domain/Models/` | P1,P4-P6,P20,P22-P26,P34-P36 |
| CreatePromiseFeature.swift | `Features/GroupFeature/Sources/CreatePromise/Core/` | P2-P3,P7-P8,P17-P18,P38 |
| PromiseDetailFeature.swift | `Features/SharedFeature/Sources/PromiseDetail/` | P10-P12 |
| EditPromiseFeature.swift | `Features/SharedFeature/Sources/EditPromise/` | P3,P32-P33 |

| 테스트 파일 | 경로 | 테스트 수 |
|------------|------|:--------:|
| PromiseModelValidationTests.swift | `Clients/Tests/` | 22개 |
| PromiseModelTests.swift | `Clients/Tests/` | 48개 |
| CreatePromiseReducerTests.swift | `Features/GroupFeature/Tests/Sources/` | 일부 |
