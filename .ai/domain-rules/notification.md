# 알림 + 배지 (Notification & Badge) 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 알림 카테고리 (9종)

| 카테고리 | 설명 | 트리거 |
|---------|------|--------|
| promiseInvitation | 새 약속 생성 알림 | onPromiseCreated |
| promiseReminder | 약속 리마인더 | (예약) |
| promiseConfirmed | 약속 확정 알림 | onPromiseVotesUpdated |
| promiseCancelled | 약속 미성사 알림 | onPromiseVotesUpdated |
| promiseUpdated | 약속 수정 알림 | onPromiseInfoUpdated |
| groupInvitation | 그룹 초대 알림 | — |
| groupUpdate | 그룹 수정 알림 | onGroupImageUpdated |
| attendanceResponse | 출석 응답 알림 | onPromiseVotesUpdated |
| system | 시스템 알림 | — |

---

## 2. 트리거 (5종)

| 트리거 | Firestore 이벤트 | 발동 조건 |
|--------|-----------------|----------|
| onPromiseCreated | promises 문서 생성 | 약속 생성 시 |
| onPromiseVotesUpdated | promises.votes 변경 | 투표 응답 시 |
| onGroupMemberJoined | groups.memberIds 변경 | 새 멤버 가입 시 |
| onPromiseInfoUpdated | promises 문서 수정 | 약속 정보 수정 시 |
| onGroupImageUpdated | groups.imageUrl 변경 | 그룹 이미지 변경 시 |

---

## 3. 동작 규칙 (Behaviors)

| ID | 규칙 | 상세 |
|----|------|------|
| N1 | 그룹별 카테고리별 on/off | 8종 세부 설정 (promise 6종 + group 1종 + calendarSync 1종) |
| N2 | 기본 설정 | 모든 알림 ON |
| N3 | 알림은 항상 저장 | FCM 전송 여부와 무관하게 Firestore에 기록 |
| N4 | 약속 확정 알림 수신자 | accepted 사용자에게만 |
| N5 | 약속 미성사 알림 수신자 | accepted 사용자에게만 |
| N6 | 약속 수정 알림 수신자 | accepted 참가자에게만 |
| N7 | 약속 수정 알림 감지 필드 | title, startAt, location, description, minimumParticipants (5종) |
| N8 | 그룹 수정 알림 수신자 | 호스트 제외, 나머지 멤버 |
| N9 | 알림 시간 포맷 | KST (Asia/Seoul) 기준 |
| N10 | 미성사 판정 조건 | 남은 가능 인원 < minimumParticipants |

---

## 4. 배지 (Badge)

| ID | 규칙 | 상세 | iOS | Backend |
|----|------|------|:---:|:-------:|
| B1 | 약속 생성 시 배지 ON | 그룹 멤버 전체 (생성자 제외) `hasNewActivity = true` | — | ✅ |
| B2 | 배지 해제 = 본인만 | `clearGroupBadge` API, 본인 문서만 수정 | ✅ | ✅ |
| B3 | 배지 해제 시 그룹 소속 확인 | 그룹 멤버인지 검증 | — | ✅ |

---

## 5. 표시 규칙 (Display)

| ID | 규칙 | 값 |
|----|------|-----|
| N11 | 알림 딥링크 | 약속 → `.promise(promiseId, groupId)`, 그룹 → `.group(groupId)`, system → `.none` |
| N12 | 알림 필터 | all, unread (2종) |
