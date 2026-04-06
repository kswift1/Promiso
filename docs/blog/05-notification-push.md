# Firebase에서 Rust로 -- 알림, 트리거에서 함수 호출로

*iOS 앱 서버 마이그레이션기 #5 -- FCM 푸시 + 배지 + 그룹별 알림 설정*

---

Firestore 트리거는 마법처럼 동작한다.

일정을 만들면 `onPromiseCreated`가 발동해서 그룹 멤버에게 푸시를 보낸다. 투표가 바뀌면 `onPromiseVotesUpdated`가 확정/취소 알림을 보낸다. 그룹에 누가 들어오면 `onGroupMemberJoined`가 기존 멤버에게 알린다. 문서가 바뀌면 알아서 반응한다. 편하다.

문제는 "알아서"라는 부분이다.

`onPromiseCreated`는 일정 생성 후 500ms에서 3초 사이에 발동한다. 콜드스타트를 맞으면 더 걸린다. 트리거가 실패하면? 재시도 정책에 따라 다시 발동하는데, 같은 알림을 두 번 보내지 않도록 직접 관리해야 한다. 트리거 안에서 또 다른 문서를 수정하면 또 다른 트리거가 발동할 수도 있다. 이 체인을 머릿속으로 따라가는 건 함수 호출 스택을 따라가는 것보다 훨씬 어렵다.

알림 시스템은 이 트리거 위에 쌓여 있었다. 5개의 Firestore 트리거, `notifications` 컬렉션 직접 읽기/쓰기, `users/{uid}.devices` Map에서 FCM 토큰 관리, `users/{uid}.groups.{gid}.hasNewActivity` Boolean으로 배지 관리. 알림 하나가 어떤 경로를 타는지 파악하려면 파일 네 개를 펼쳐놓고 봐야 했다.

Rust로 옮기면서 질문은 같다. 이 복잡도 중 얼마가 비즈니스 규칙이고 얼마가 Firestore의 이벤트 드리븐 모델에서 온 것인가.

---

## 트리거에서 함수 호출로

Firestore 트리거의 핵심은 "문서 변경에 반응한다"는 것이다. 일정 문서가 생기면 알림을 보내고, 투표가 바뀌면 확정/취소를 판단한다. 이건 편리하지만 한 가지 문제가 있다. 비즈니스 로직이 데이터 변경 이벤트에 묶인다.

```typescript
// Firebase: 일정 생성 트리거
export const onPromiseCreated = onDocumentCreated(
  "promises/{promiseId}", async (event) => {
    const promise = event.data?.data();
    const groupMembers = await getGroupMembers(promise.groupId);
    await sendPushNotificationInternal({
      userIds: groupMembers.filter(id => id !== promise.hostId),
      type: "promise_invitation",
      title: "새 약속 도착 📩",
      body: `${hostNickname}님이 ${promise.title}을 제안했어요.`,
    });
  }
);
```

이 코드는 문서 생성 이벤트의 핸들러다. `createPromise` Cloud Function이 문서를 만들면, Firestore가 변경을 감지하고, 별도 프로세스에서 이 트리거를 실행한다. 문서 생성과 알림 발송 사이에 네트워크 이벤트 전파가 끼어있다.

Rust에서는 이걸 함수 호출로 바꿨다.

```rust
pub async fn create_schedule(
    pool: &PgPool, push_sender: &dyn PushSender,
    user_id: &str, req: CreateScheduleRequest
) -> Result<CreateScheduleResponse, AppError> {
    // 1. 일정 생성
    let schedule = sqlx::query_as::<_, Schedule>(
        "INSERT INTO schedules (...) VALUES (...) RETURNING *"
    ).fetch_one(pool).await?;

    // 2. 알림 발송 -- 트리거가 아닌 직접 호출
    notify_schedule_created(pool, push_sender, schedule.id, group_id, user_id).await?;

    // 3. 배지 갱신
    sqlx::query("UPDATE groups SET last_activity_at = NOW() WHERE id = $1")
        .bind(group_id).execute(pool).await?;

    Ok(response)
}
```

일정 생성 → 알림 발송 → 배지 갱신이 한 함수 안에서 순서대로 실행된다. 트리거 발동 타이밍을 추측할 필요 없다. 알림이 실패하면 `?` 연산자가 에러를 상위로 전파한다. 디버깅할 때 콜 스택을 따라가면 된다.

Swift로 비유하면 이런 차이다.

```swift
// Firebase 방식: NotificationCenter (이벤트 기반)
NotificationCenter.default.post(name: .scheduleCreated, object: schedule)
// 어딘가에서 이걸 구독하고 있다... 어디서?

// Rust 방식: 직접 호출
let result = notificationService.notifyScheduleCreated(schedule)
// 호출 지점이 명확하다
```

---

## 알림은 항상 저장한다

알림 시스템에서 가장 중요한 규칙이 하나 있다. **알림은 푸시 전송 여부와 관계없이 항상 DB에 저장한다.**

유저가 그룹 알림을 꺼놨어도, FCM 토큰이 없어도, 알림 레코드는 생긴다. 나중에 알림함을 열면 거기 있다. 푸시는 "알려주기"이고, 알림 레코드는 "기록하기"다. 이 둘은 분리되어야 한다.

```rust
pub async fn send_push_internal(
    pool: &PgPool, push_sender: &dyn PushSender, params: SendPushRequest
) -> Result<PushResult, AppError> {
    // 1단계: DB에 무조건 저장 (모든 수신자)
    for user_id in &params.user_ids {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body, ...)
             VALUES ($1, $2, $3, $4, ...)"
        ).bind(user_id).bind(&params.notification_type)
         .execute(pool).await?;
    }

    // 2단계: 알림 설정 체크 (FCM 전송 대상 필터링)
    let eligible_tokens = collect_eligible_tokens(pool, &params).await?;

    // 3단계: FCM 전송 (토큰이 있는 사람만)
    if !eligible_tokens.is_empty() {
        let result = push_sender.send_multicast(&eligible_tokens, &message).await;
        // 전송 성공한 알림만 is_delivered = true
        update_delivered_status(pool, &delivered_notification_ids).await?;
    }

    Ok(push_result)
}
```

1단계가 2, 3단계보다 먼저 실행되는 게 핵심이다. FCM이 장애가 나도 알림 기록은 남는다.

---

## devices 테이블: Map에서 정규화로

Firestore에서 FCM 토큰은 유저 문서 안의 Map이다.

```
users/{uid}
  devices: {
    "0DCE63A4-...": {
      fcmToken: "dqccfrvq4UvQ...",
      platform: "ios",
      lastActiveAt: Timestamp,
      pushToStartToken: "80c820..."
    },
    "38A68EE5-...": { ... }
  }
```

한 유저가 여러 디바이스를 가질 수 있다. iPhone과 iPad를 동시에 쓰면 디바이스 entry가 두 개다. 문제는 계정을 전환할 때 생긴다. A가 로그아웃하고 B가 같은 기기에서 로그인하면, A의 디바이스 entry에 남아있는 FCM 토큰이 B에게도 등록된다. 같은 토큰이 두 유저에게 존재하면 A에게 가야 할 푸시가 B에게도 간다.

실제 Firestore 데이터를 조회해보니 이 상황이 이미 일어나고 있었다. 같은 `deviceId`가 두 유저의 `devices` Map에 존재했다.

PostgreSQL에서는 `UNIQUE` 제약으로 이 문제를 스키마 레벨에서 막는다.

```sql
CREATE TABLE devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios',
  push_to_start_token TEXT,
  live_activity_push_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT uq_devices_user_device UNIQUE (user_id, device_id),
  CONSTRAINT uq_devices_fcm_token UNIQUE (fcm_token)
);
```

`UNIQUE (fcm_token)` -- 같은 FCM 토큰은 DB에 하나만 존재할 수 있다. 새 유저가 같은 토큰으로 등록하면, 서비스 레이어에서 이전 소유자의 row를 삭제하고 새 row를 넣는다. "소유권 이전"이 자동으로 일어난다. 로그아웃 시에는 해당 유저의 전체 디바이스 entry를 삭제한다.

---

## 배지: Boolean에서 타임스탬프 비교로

Firebase에서 배지(빨간 점)는 `hasNewActivity`라는 Boolean이다.

```
users/{uid}.groups.{groupId}.hasNewActivity = true   // 일정 생성 시
users/{uid}.groups.{groupId}.hasNewActivity = false  // 읽음 처리 시
```

일정이 생기면 트리거가 그룹 멤버 전원의 `hasNewActivity`를 `true`로 바꾼다. 멤버가 10명이면 10번의 문서 쓰기다. 읽음 처리는 `clearGroupBadge` Cloud Function을 호출해서 `false`로 바꾼다. 쓰기 2번 (set + clear) × 멤버 수.

Rust 백엔드에서는 이미 그룹 마이그레이션(#3)에서 타임스탬프 기반으로 설계해뒀다.

```rust
// 그룹 목록 조회 시 배지를 계산
let has_new_activity = last_activity_at > last_read_at;
```

`groups.last_activity_at`은 그룹에 새 활동이 있을 때 한 번만 갱신한다. `group_members.last_read_at`은 유저가 그룹을 열 때 갱신한다. 배지 상태는 이 두 타임스탬프의 비교로 나온다. 별도 Boolean을 멤버 수만큼 쓰는 대신, 타임스탬프 하나를 갱신한다.

일정 생성 시 알림 함수가 하는 일:
```rust
// 배지 갱신 -- 그룹 row 하나만 업데이트
sqlx::query("UPDATE groups SET last_activity_at = NOW() WHERE id = $1")
    .bind(group_id).execute(pool).await?;
```

멤버가 100명이어도 쓰기는 1번이다.

---

## 알림 설정: 이미 있던 컬럼

알림 설정은 새로 만들 필요가 없었다. #3 그룹 마이그레이션에서 `group_members` 테이블에 이미 넣어뒀다.

```sql
-- 004_groups.sql에서 이미 정의
notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
schedule_invitation   BOOLEAN NOT NULL DEFAULT TRUE,
schedule_reminder     BOOLEAN NOT NULL DEFAULT TRUE,
schedule_confirmed    BOOLEAN NOT NULL DEFAULT TRUE,
schedule_cancelled    BOOLEAN NOT NULL DEFAULT TRUE,
schedule_updated      BOOLEAN NOT NULL DEFAULT TRUE,
attendance_response   BOOLEAN NOT NULL DEFAULT TRUE,
group_update          BOOLEAN NOT NULL DEFAULT TRUE,
calendar_sync         BOOLEAN NOT NULL DEFAULT TRUE,
```

Firestore에서는 `users/{uid}.groups.{gid}.notifications`라는 중첩 Map에 들어있었다. 이걸 읽으려면 유저 문서 전체를 가져와서 파싱해야 했다. PostgreSQL에서는 `group_members` 테이블의 컬럼이니까 알림 전송 시 JOIN 한 번이면 된다.

```rust
// 알림 전송 시 설정 체크 -- 한 쿼리로 대상 필터링
let should_send = match notification_type {
    ScheduleInvitation => member.schedule_invitation,
    ScheduleConfirmed  => member.schedule_confirmed,
    ScheduleCancelled  => member.schedule_cancelled,
    // ...
    LocationSharingReminder | System => true,  // 설정 무시
};
```

`LocationSharingReminder`와 `System` 타입은 설정을 무시하고 항상 전송한다. 이건 Firebase에서도 같은 로직이었는데, 트리거 코드에 묻혀있어서 찾기 어려웠다. Rust에서는 `match` 한 곳에 모여있다.

---

## PushSender: 테스트를 위한 추상화

FCM 전송을 어떻게 테스트할까? 실제로 푸시를 보낼 수는 없다.

Swift에서 프로토콜로 추상화하는 것과 같은 패턴을 Rust에서는 trait으로 쓴다.

```rust
// Rust: trait (Swift의 protocol)
#[async_trait]
pub trait PushSender: Send + Sync {
    async fn send_multicast(
        &self, tokens: &[String], message: &FcmMessage
    ) -> PushResult;
}
```

```swift
// Swift로 쓰면 이런 모양
protocol PushSending: Sendable {
    func sendMulticast(
        tokens: [String], message: FcmMessage
    ) async throws -> PushResult
}
```

프로덕션에서는 `FcmPushSender`가 Google FCM HTTP v1 API를 호출한다. 테스트에서는 `MockPushSender`가 호출 기록만 쌓는다.

```rust
// 테스트에서
let mock = MockPushSender::new();
notify_schedule_created(&pool, &mock, schedule_id, group_id, "host").await?;

assert_eq!(mock.call_count(), 1);           // 호출 1번
assert_eq!(mock.last_tokens().len(), 2);    // 토큰 2개에 전송
```

37개 테스트가 이 MockPushSender로 돌아간다. DB에 알림이 저장되었는지, 설정이 꺼진 유저에겐 FCM을 안 보내는지, 호스트는 제외되는지 -- 실제 푸시 없이 비즈니스 규칙을 전부 검증한다.

---

## 사라진 것들

- Firestore 트리거 5개 (`onPromiseCreated`, `onPromiseVotesUpdated`, `onPromiseInfoUpdated`, `onGroupMemberJoined`, `onPromiseCreatedBadges`)
- `notifications` 컬렉션 직접 읽기/쓰기 -- REST API로 대체
- `users/{uid}.devices` Map -- `devices` 테이블로 정규화
- `hasNewActivity` Boolean + 멤버 수만큼 배치 쓰기 -- 타임스탬프 비교로 대체
- `clearGroupBadge` Cloud Function -- 기존 `mark-read` API로 통합
- FCM 토큰 중복 문제 -- `UNIQUE(fcm_token)` + 소유권 이전으로 해결

새로 생긴 것.

- 소유권 이전 로직 (같은 FCM 토큰이 다른 유저에 등록되면 이전 소유자 삭제)
- 로그아웃 시 전체 디바이스 삭제 API
- `schedule_updated` 감지 필드를 5개로 명확히 고정 (title, startAt, location, description, minimumParticipants)
- `is_delivered` 플래그로 FCM 전송 성공 여부 추적

---

## 마무리

Firestore 트리거는 "문서가 바뀌면 알아서 반응한다"는 모델이다. 편하지만 추적이 어렵다. 어떤 트리거가 어떤 순서로 발동하는지, 실패하면 어떻게 재시도되는지, 체인이 얼마나 길어지는지 코드만 봐서는 알기 어렵다.

함수 호출로 바꾸면 마법이 사라지는 대신 흐름이 보인다. 일정 생성 → 알림 발송 → 배지 갱신이 한 함수에 있으니까 "이 API를 호출하면 무슨 일이 일어나는가"에 대한 답이 코드에 있다.

*다음 글: #6 실시간과 LiveActivity -- SSE + APNs 직접 발송 + ETA 공유*

*Promiso -- [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
