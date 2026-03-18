# Push Notification 가이드

## 개요

Promiso 앱의 푸시 알림 메시지 규격을 정의합니다.

---

## 알림 타입 (NotificationType)

| 타입 | 설명 | 트리거 | 구현 |
|------|------|--------|------|
| `promise_invitation` | 새 약속 초대 | `onPromiseCreated` | ✅ |
| `promise_confirmed` | 약속 확정 | `onPromiseVotesUpdated` | ✅ |
| `promise_cancelled` | 약속 무산 | `onPromiseVotesUpdated` | ✅ |
| `promise_updated` | 약속 수정 | `onPromiseInfoUpdated` | ✅ |
| `promise_reminder` | 약속 리마인더 | Cloud Tasks | ❌ TODO |
| `location_sharing_reminder` | 실시간 공유 넛지 | `executeETASharingNudge` | ✅ |
| `group_update` | 그룹 업데이트 | `onGroupMemberJoined` / `updateGroup` | ✅ |
| `group_invitation` | 그룹 초대 | - | ❌ |
| `attendance_response` | 참석 응답 | - | ❌ |
| `system` | 시스템 공지 | 수동 전송 | ❌ |

---

## FCM 푸시 알림

### 1. promise_invitation (새 약속 도착)

| 항목 | 값 |
|------|-----|
| **트리거** | `promises/{promiseId}` 문서 생성 |
| **Title** | `새 약속 도착 📩` |
| **Body** | `{호스트명}님이 {약속제목}을 제안했어요. 확인해주세요!` |
| **수신자** | 그룹 멤버 (호스트 제외) |

**예시:**
```
새 약속 도착 📩
성원님이 영화 관람을 제안했어요. 확인해주세요!
```

---

### 2. promise_confirmed (약속 확정)

| 항목 | 값 |
|------|-----|
| **트리거** | `promises/{promiseId}` votes 변경 |
| **조건** | `accepted.length < min` → `accepted.length >= min` |
| **Title** | `{약속제목} 약속 확정! 🎉` |
| **Body** | `{오늘/내일/M월 D일} {오전/오후 H:MM}에 만나요!` |
| **수신자** | 수락한 사람들만 |

**시간 포맷:**
- 오늘이면 "오늘"
- 내일이면 "내일"
- 그 외 "M월 D일"
- 시간은 12시간제 "오전/오후 H:MM" (예: 오후 3:00)

**예시:**
```
영화 관람 약속 확정! 🎉
오늘 오후 2:00에 만나요!

점심 모임 약속 확정! 🎉
내일 오후 12:30에 만나요!

생일파티 약속 확정! 🎉
1월 25일 오후 6:00에 만나요!
```

---

### 3. promise_cancelled (약속 무산)

| 항목 | 값 |
|------|-----|
| **트리거** | `promises/{promiseId}` votes 변경 |
| **조건** | 남은 가능 인원 < 최소 인원 (새로 거절한 사람 있음) |
| **Title** | `{약속제목} 약속 무산 😢` |
| **Body** | `참여 인원이 부족해서 확정되지 않았어요` |
| **수신자** | 수락한 사람들만 |

**예시:**
```
영화 관람 약속 무산 😢
참여 인원이 부족해서 확정되지 않았어요
```

---

### 4. promise_updated (약속 수정)

| 항목 | 값 |
|------|-----|
| **트리거** | `promises/{promiseId}` 문서 업데이트 |
| **조건** | title, startAt, location, description, minimumParticipants 중 변경 |
| **Title** | `{약속제목} 변경 📝` |
| **Body** | `약속 정보가 수정됐어요. 확인해주세요!` |
| **수신자** | 수락한 사람들만 |

**예시:**
```
영화 관람 변경 📝
약속 정보가 수정됐어요. 확인해주세요!
```

---

### 5. group_update (그룹 업데이트)

| 항목 | 값 |
|------|-----|
| **트리거** | `groups/{groupId}` memberIds 변경 또는 그룹 정보 수정 |
| **조건** | 새로운 멤버 ID 추가됨 또는 description/imageUrl/maxMembers 변경 |
| **Title** | `새 멤버 합류 👋` 또는 `그룹 정보 업데이트 ✨` |
| **Body** | `{새멤버명}님이 {그룹명}에 들어왔어요` 또는 `{그룹명} 설정이 변경됐어요` |
| **수신자** | 기존 멤버들 (새 멤버 제외) |

**예시 (멤버 합류):**
```
새 멤버 합류 👋
민수님이 대학 친구들에 들어왔어요
```

**예시 (그룹 정보 변경):**
```
그룹 정보 업데이트 ✨
대학 친구들 설정이 변경됐어요
```

---

## LiveActivity 알림

### 1. 시작 (Push to Start)

| 항목 | 값 |
|------|-----|
| **트리거** | `executeLiveActivityStart` 또는 `startLiveActivity` |
| **Title** | `{이모지} {약속제목}` |
| **Body** | `실시간 공유가 시작되었습니다` |
| **수신자** | 수락한 참가자 전원 |

---

### 2. location_sharing_reminder (ETA 공유 넛지)

| 항목 | 값 |
|------|-----|
| **트리거** | `executeETASharingNudge` |
| **조건** | LiveActivity 시작 후 `trackingMinutes / 2` 경과 |
| **Title** | `⏰ {약속제목} {남은분}분 전!` |
| **Body** | `잘 오고 계신가요? 👋 잠금화면 또는 앱에서 실시간 도착 예정시간을 공유해주세요!` |
| **수신자** | 수락한 참가자 전원 |
| **비고** | 약속당 1회만 발송, 별도 알림 설정 없음 |

---

### 3. 첫 도착 (updateETA)

| 항목 | 값 |
|------|-----|
| **조건** | `arrivedCount === 1` && 본인이 도착 찍음 |
| **Title** | `🎉 첫 도착!` |
| **Body** | `가장 먼저 도착했어요!` |
| **수신자** | 채널 구독자 전원 (Broadcast) |

---

### 4. 모두 도착 (updateETA)

| 항목 | 값 |
|------|-----|
| **조건** | `arrivedCount === totalCount` |
| **Title** | `✅ 모두 도착!` |
| **Body** | `모든 멤버들이 도착했어요! 잠시 후 종료됩니다` |
| **수신자** | 채널 구독자 전원 (Broadcast) |
| **추가 동작** | End Task 예약 (dev: 1분, stage: 3분, prod: 5분) |

---

## 딥링크 데이터

모든 FCM 알림에 포함되는 데이터:

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | string | NotificationType 값 |
| `promiseId` | string? | 관련 약속 ID |
| `groupId` | string? | 관련 그룹 ID |
| `relatedUserId` | string? | 관련 사용자 ID |

### 딥링크 동작

| 타입 | 탭 시 이동 화면 |
|------|----------------|
| `promise_invitation` | 약속 상세 |
| `promise_confirmed` | 약속 상세 |
| `promise_cancelled` | 약속 상세 |
| `promise_updated` | 약속 상세 |
| `promise_reminder` | 약속 상세 |
| `attendance_response` | 약속 상세 |
| `location_sharing_reminder` | 약속 상세 |
| `group_invitation` | 그룹 상세 |
| `group_update` | 그룹 상세 |
| `system` | 이동 없음 |

---

## FCM Payload 구조

```typescript
{
  tokens: string[],
  notification: {
    title: "제목",
    body: "본문",
  },
  data: {
    type: NotificationType,
    promiseId?: string,
    groupId?: string,
    relatedUserId?: string,
  },
  apns: {
    payload: {
      aps: {
        sound: "default",
      }
    }
  }
}
```

---

## 메시지 작성 원칙

1. **간결하게**: 한 눈에 파악할 수 있도록
2. **이모지 활용**: Title에 이모지로 유형 구분
3. **행동 유도**: "~했어요" 형태로 자연스럽게
4. **개인화**: 이름, 그룹명, 약속명 포함
5. **한국어 자연스럽게**: "님이", "에", "을/를" 조사 주의

---

## TODO (가이드 레벨)

### 약속 리마인더 ⭐⭐⭐

| 항목 | 값 |
|------|-----|
| **트리거** | Cloud Tasks (약속 시작 1시간 전 예약) |
| **Title** | `{약속제목} 곧 시작! ⏰` |
| **Body** | `1시간 뒤 약속이 시작돼요!` |
| **수신자** | 수락자 |
| **구현 방식** | 약속 확정 시 Cloud Tasks 예약 |

---

### 투표 마감 임박 ⭐⭐⭐

| 항목 | 값 |
|------|-----|
| **트리거** | Cloud Tasks (투표 마감 3시간 전 예약) |
| **Title** | `{약속제목} 투표 마감 임박 ⏳` |
| **Body** | `투표 마감 3시간 전이에요! 아직 응답 안했어요` |
| **수신자** | 미응답자 |
| **구현 방식** | 약속 생성 시 Cloud Tasks 예약, 응답 시 취소 |

추후 각 알림 개인 활성화 도 구상하기
