# Push Notification 메시지 가이드

## 개요

Promiso 앱의 푸시 알림 메시지 규격을 정의합니다.

---

## 알림 타입 (NotificationType)

| 타입 | 설명 | 트리거 |
|------|------|--------|
| `promise_invitation` | 새 약속 초대 | `onPromiseCreated` |
| `promise_reminder` | 약속 시작 전 리마인더 | 미구현 (Scheduler) |
| `promise_confirmed` | 약속 확정 (최소 인원 충족) | `onPromiseVotesUpdated` |
| `promise_cancelled` | 약속 무산 (인원 부족) | `onPromiseVotesUpdated` |
| `group_invitation` | 그룹 초대 | 미구현 |
| `group_update` | 그룹 업데이트 (새 멤버 등) | `onGroupMemberJoined` |
| `attendance_response` | 참석 응답 변경 | 추후 (설정에서 on/off) |
| `system` | 시스템 공지 | 수동 전송 |

---

## 메시지 템플릿

### 1. promise_invitation (새 약속 도착)

새 약속이 생성되었을 때 그룹 멤버들에게 전송

| 항목 | 값 |
|------|-----|
| **Title** | `새 약속 도착 📩` |
| **Body** | `{hostName}님이 {promiseTitle}을 제안했어요. 확인해주세요!` |
| **수신자** | 그룹 멤버 (호스트 제외) |

**예시:**
```
새 약속 도착 📩
성원님이 영화 관람을 제안했어요. 확인해주세요!
```

---

### 2. promise_confirmed (약속 확정)

최소 인원 충족으로 약속이 확정될 때

| 항목 | 값 |
|------|-----|
| **Title** | `약속 확정! 🎉` |
| **Body** | `{promiseTitle} 약속 확정! {date}에 만나요` |
| **수신자** | votes.accepted (수락한 멤버만) |

**예시:**
```
약속 확정! 🎉
영화 관람 약속 확정! 1월 20일에 만나요
```

---

### 3. promise_cancelled (약속 무산)

참여 인원 부족으로 약속이 확정되지 못했을 때

| 항목 | 값 |
|------|-----|
| **Title** | `약속 무산 😢` |
| **Body** | `{promiseTitle}의 참여 인원이 부족해서 확정되지 않았어요` |
| **수신자** | votes.accepted (수락한 멤버만) |

**예시:**
```
약속 무산 😢
영화 관람의 참여 인원이 부족해서 확정되지 않았어요
```

---

### 4. promise_reminder (응답 리마인더)

아직 응답하지 않은 멤버에게 리마인더

| 항목 | 값 |
|------|-----|
| **Title** | `응답 대기 중 ⏰` |
| **Body** | `{promiseTitle} 아직 답변 안 했어요!` |
| **수신자** | 미응답 멤버 |

**예시:**
```
응답 대기 중 ⏰
영화 관람 아직 답변 안 했어요!
```

---

### 5. promise_reminder_day_before (약속 하루 전 리마인더)

약속 하루 전 알림

| 항목 | 값 |
|------|-----|
| **Title** | `내일 약속 🔔` |
| **Body** | `{promiseTitle} 내일 {time}이에요. 잊지 마세요!` |
| **수신자** | 참여 확정한 멤버 (votes.accepted) |

**예시:**
```
내일 약속 🔔
영화 관람 내일 오후 2시에요. 잊지 마세요!
```

---

### 6. group_update (새 멤버 합류)

그룹에 새 멤버가 참여했을 때

| 항목 | 값 |
|------|-----|
| **Title** | `새 멤버 합류 👋` |
| **Body** | `{memberName}님이 {groupName}에 들어왔어요` |
| **수신자** | 기존 그룹 멤버 (새 멤버 제외) |

**예시:**
```
새 멤버 합류 👋
민수님이 대학 친구들에 들어왔어요
```

---

### 7. attendance_response (참석 응답) - 추후 설정 가능

다른 멤버가 약속에 응답했을 때 호스트에게 알림 (추후 알림 설정에서 on/off)

| 항목 | 값 |
|------|-----|
| **Title (참여)** | `✅ 참여 확정` |
| **Title (불참)** | `❌ 참여 불가` |
| **Body** | `{userName}님이 {promiseTitle}에 응답했어요` |
| **수신자** | 약속 호스트 |

**예시:**
```
✅ 참여 확정
민수님이 영화 관람에 응답했어요
```

---

### 8. system (시스템 알림)

공지사항, 업데이트 안내 등

| 항목 | 값 |
|------|-----|
| **Title** | `📢 Promiso` |
| **Body** | (내용에 따라 다름) |
| **수신자** | 대상 사용자 |

---

## 딥링크 데이터

모든 알림에 포함되는 데이터:

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
| `promise_reminder` | 약속 상세 |
| `promise_confirmed` | 약속 상세 |
| `promise_cancelled` | 그룹 상세 |
| `group_invitation` | 그룹 상세 |
| `group_update` | 그룹 상세 |
| `attendance_response` | 약속 상세 |
| `system` | 앱 홈 |

---

## 구현 상태

| 타입 | Functions | iOS 딥링크 |
|------|-----------|-----------|
| `promise_invitation` | ✅ | ❌ |
| `promise_reminder` | ❌ | ❌ |
| `promise_confirmed` | ✅ | ❌ |
| `promise_cancelled` | ✅ | ❌ |
| `group_invitation` | ❌ | ❌ |
| `group_update` | ✅ | ❌ |
| `attendance_response` | ❌ (추후) | ❌ |
| `system` | ❌ | ❌ |

---

## 메시지 작성 원칙

1. **간결하게**: 한 눈에 파악할 수 있도록
2. **이모지 활용**: Title에 이모지로 유형 구분
3. **행동 유도**: "~했어요" 형태로 자연스럽게
4. **개인화**: 이름, 그룹명, 약속명 포함
5. **한국어 자연스럽게**: "님이", "에", "을/를" 조사 주의
