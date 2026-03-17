# WS5: 응답 독촉 자동화

**브랜치**: `feat/response-reminder` (release/v1.2.0에서 분기)
**의존성**: WS2 Push 문구 확정 후 카피 정렬. 5번째 머지.
**로직은 독립 진행 가능, Push 문구만 WS2 완료 후 최종 정렬**

---

## 개요

약속 생성 후 24시간이 지나도 미응답자가 있을 경우, 미응답자와 주최자에게 자동으로 FCM 알림을 발송한다. 최대 2회 발송 후 종료.

---

## 신규 파일

### responseReminder.ts

경로: `infra/firebase/functions/src/functions/responseReminder.ts`

파일 상단 JSDoc:
```typescript
/**
 * Response Reminder Functions
 *
 * 약속 생성 후 미응답자에게 자동으로 응답 독촉 알림을 발송합니다.
 *
 * @why 약속 응답률 향상 및 주최자 편의 제공
 * @triggers
 * - onPromiseCreatedScheduleReminder: 약속 생성 시 Cloud Task 예약
 * - executeResponseReminder: 예약된 시간에 미응답자 알림 발송
 */
```

---

#### 함수 1: onPromiseCreatedScheduleReminder

트리거: `onDocumentCreated("promises/{promiseId}")`

로직:
1. `startAt - now < 24h` → 스킵 (약속이 너무 임박한 경우 알림 불필요)
2. `startAt - now >= 24h` → Cloud Task 예약 (`scheduleDelaySeconds: 86400`)

페이로드: `ResponseReminderTaskPayload { promiseId, reminderCount: 0 }`

환경별 딜레이 분기:
- Dev (`process.env.FUNCTIONS_EMULATOR === "true"`): `scheduleDelaySeconds: 60` (1분)
- Prod/Stage: `scheduleDelaySeconds: 86400` (24시간)

Cloud Task 큐 이름: `locations/${REGION}/functions/executeResponseReminder`

참고 패턴: `liveActivity.ts`의 `onPromiseConfirmedScheduleLiveActivity` → `getFunctions().taskQueue().enqueue()` 패턴 동일하게 적용

---

#### 함수 2: executeResponseReminder

트리거: `onTaskDispatched<ResponseReminderTaskPayload>`

옵션:
```typescript
{
  region: REGION,
  retryConfig: {
    maxAttempts: 2,
    minBackoffSeconds: 10,
  },
  rateLimits: {
    maxConcurrentDispatches: 20,
  },
}
```

로직:
1. `promises/{promiseId}` 문서 조회. 없으면 종료.
2. `groups/{groupId}` 문서 조회 → `memberIds` 추출 (전체 그룹 멤버)
3. 미응답자 계산:
   ```
   미응답 = memberIds - votes.accepted - votes.declined - [hostId]
   ```
   - hostId는 미응답 대상에서 제외 (주최자는 응답 불필요)
4. `미응답.length === 0` → 종료
5. `startAt <= now` → 약속 시간이 지났으므로 종료
6. 미응답자에게 FCM 발송:
   - title: `"아직 {title} 응답 못 하셨나요?"`
   - body: `"Promiso가 대신 챙겨드릴게요"`
   - type: `NotificationType.ResponseReminder`
7. 주최자(`hostId`)에게 FCM 발송:
   - title: `"{title}, 아직 응답 안 한 {N}명에게 대신 알렸어요"`
   - body: `"응답 현황은 약속 상세에서 확인하실 수 있어요"`
   - type: `NotificationType.ResponseReminder`
8. 2차 Task 예약 조건: `reminderCount < 2 && startAt - now >= 24h`
   - 조건 충족 시 동일 큐에 `{ promiseId, reminderCount: reminderCount + 1 }` 재예약
   - 환경별 딜레이 동일 적용 (Dev: 60초, Prod: 86400초)

FCM 발송: `sendPushNotificationInternal` 재활용 (`notifications.ts` export)
- 미응답자 발송 시 `groupId` 전달 (그룹 알림 설정 필터링 적용)
- 주최자 발송 시 `groupId` 전달

---

## 수정 파일

### api.ts

경로: `infra/firebase/functions/src/types/api.ts`

**1. NotificationType enum에 케이스 추가** (기존 `System` 케이스 뒤에):
```typescript
/** 응답 독촉 알림 */
ResponseReminder = "response_reminder",
```

**2. ResponseReminderTaskPayload 인터페이스 추가** (Cloud Tasks 섹션 하단):
```typescript
/**
 * 응답 독촉 Task Payload
 */
export interface ResponseReminderTaskPayload {
  /** 약속 ID */
  promiseId: string;
  /** 발송 횟수 (0-based, 최대 2회) */
  reminderCount: number;
}
```

---

### index.ts

경로: `infra/firebase/functions/src/index.ts`

기존 Notification Functions 섹션 아래 새 섹션 추가:

```typescript
// ============================================================================
// Response Reminder Functions (응답 독촉 자동화)
// ============================================================================
export {
  onPromiseCreatedScheduleReminder,
  executeResponseReminder,
} from "./functions/responseReminder";
```

---

## Firestore 스키마 참고

### promises 컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `votes.accepted` | `string[]` | 수락한 userId 목록 |
| `votes.declined` | `string[]` | 거절한 userId 목록 |
| `groupId` | `string` | 그룹 ID |
| `hostId` | `string` | 주최자 userId |
| `startAt` | `Timestamp` | 약속 시작 시간 |
| `title` | `string` | 약속 제목 |

### groups 컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `memberIds` | `string[]` | 그룹 전체 멤버 userId 목록 |

---

## 재활용 패턴

### Cloud Task 큐 예약 (`liveActivity.ts` 참고)

```typescript
import {getFunctions} from "firebase-admin/functions";
import {onTaskDispatched} from "firebase-functions/v2/tasks";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";
import {ResponseReminderTaskPayload, NotificationType} from "../types/api";
import {sendPushNotificationInternal} from "./notifications";

// 예약 예시
const queue = getFunctions().taskQueue<ResponseReminderTaskPayload>(
  `locations/${REGION}/functions/executeResponseReminder`
);
await queue.enqueue(
  {promiseId, reminderCount: 0},
  {scheduleDelaySeconds: delaySeconds}
);
```

### FCM 멀티캐스트 (`notifications.ts` 참고)

```typescript
await sendPushNotificationInternal({
  userIds: nonRespondentIds,
  type: NotificationType.ResponseReminder,
  title: `아직 ${title} 응답 못 하셨나요?`,
  body: "Promiso가 대신 챙겨드릴게요",
  promiseId,
  groupId,
  relatedUserId: null,
  data: null,
});
```

### 환경 분기

```typescript
const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
const delaySeconds = isEmulator ? 60 : 86400;
```

---

## iOS 변경

없음 (서버 사이드 only).

기존 FCM 수신 경로로 알림이 도착한다. iOS 측에서 `NotificationType.ResponseReminder` 케이스 처리가 필요할 경우 별도 WS로 분리.

---

## Dev 환경 테스트

1. `make emulator-start`로 Firebase 에뮬레이터 실행
2. Firestore에 `startAt`이 24시간 이후인 promise 문서 생성
3. `FUNCTIONS_EMULATOR=true` 환경에서 1분 후 `executeResponseReminder` 실행 확인
4. 미응답자 / 주최자 FCM 수신 로그 확인
5. `reminderCount: 1`로 2차 Task 재예약 확인

---

## 카피 톤 (WS2 기준)

- 이모지 자제
- 존댓말 + 부드러운 톤
- "~하셨나요?", "~해드릴게요", "~하실 수 있어요" 패턴
- 제목은 약속 `title`을 그대로 사용 (XSS 방지: `title.replace(/[<>&'"\/]/g, "").slice(0, 100)`)
