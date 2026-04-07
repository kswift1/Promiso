# Firebase에서 Rust로 - LiveActivity, 푸시 직접 구현하기

*iOS 앱 서버 마이그레이션기 #6 - APNs HTTP/2 직접 발송 + Broadcast Channel + DB 기반 예약 실행*

---

Promiso에는 잠금 화면에서 동작하는 기능이 두 개 있다. 하나는 실시간 현황 공유 - 약속 시간이 다가오면 LiveActivity가 뜨고, 그룹 멤버들의 도착 예정 시간이 실시간으로 갱신된다. 누가 먼저 도착했는지, 누가 아직 오는 중인지 한눈에 보인다. 다른 하나는 일정 제안 응답 - 호스트가 일정을 제안하면 멤버들이 잠금 화면의 LiveActivity에서 바로 수락하거나 거절한다.

이 기능의 핵심은 APNs(Apple Push Notification service)다. Firebase가 아니라 Apple에 직접 HTTP/2 요청을 보내야 하는데, Firebase Functions에서 이미 Node.js `http2` 모듈로 그렇게 하고 있었다.

Rust로 옮기면서 세 가지를 결정해야 했다. FCM이 LiveActivity Push를 지원하지 않으니 APNs를 직접 호출할 방법이 필요했고, Firebase Cloud Tasks가 해주던 "약속 30분 전 자동 시작" 같은 예약 실행을 대체할 방법이 필요했고, iOS 18에서 바뀐 Broadcast Channel 방식을 서버에서 지원해야 했다.

---

## FCM이 아니라 APNs

일반 푸시 알림은 FCM을 거친다. 서버 → FCM → APNs → 디바이스. LiveActivity는 다르다. APNs에 직접 보낸다. FCM은 LiveActivity Push를 지원하지 않는다.

더 정확히 말하면, iOS 18부터 LiveActivity는 "Broadcast Channel" 방식을 쓴다. 예전에는 참가자마다 개별 토큰으로 보냈다. 10명이면 10번. 지금은 채널을 하나 만들고, 모든 참가자가 그 채널을 구독한다. 서버는 채널에 한 번만 보내면 된다.

```
[Before — iOS 17]
서버 → APNs → 디바이스1 (토큰 A)
서버 → APNs → 디바이스2 (토큰 B)
서버 → APNs → 디바이스3 (토큰 C)

[After — iOS 18 Broadcast]
서버 → APNs (채널 X) → 디바이스1, 디바이스2, 디바이스3
```

Firebase Functions에서는 이미 Broadcast를 쓰고 있었다. `apns.ts`에 채널 생성, Push to Start, Broadcast 발송이 구현되어 있었다. 이걸 Rust로 옮기면 된다.

---

## APNs 라이브러리 선택: a2 vs reqwest

Rust에 [`a2`](https://crates.io/crates/a2)라는 APNs 전용 crate가 있다. 처음엔 이걸 쓰려고 했다. 문서를 읽다가 멈췄다. iOS 18 [Broadcast Channel API](https://developer.apple.com/documentation/usernotifications/sending-channel-management-requests-to-apns)를 지원하지 않는다. `/1/apps/{bundleId}/channels`로 채널을 생성하는 것, `/4/broadcasts/apps/{bundleId}`로 [브로드캐스트를 보내는 것](https://developer.apple.com/documentation/usernotifications/sending-broadcast-push-notification-requests-to-apns) - 이 API들이 없다. 최신 버전(v0.10.0, 2024년 5월)에서도 마찬가지다.

[`reqwest`](https://docs.rs/reqwest/latest/reqwest/struct.ClientBuilder.html)는 이미 프로젝트에 있었다. `http2` feature만 켜면 APNs HTTP/2 통신이 된다. Apple이 새 API를 추가하면 직접 구현하면 된다. 라이브러리 업데이트를 기다릴 필요 없다.

---

## APNs 인증: .p8 키로 JWT 서명하기

APNs는 매 요청마다 JWT 토큰을 보내야 한다. Apple Developer에서 `.p8` 키 파일을 받고, 이걸로 ES256(ECDSA + SHA-256) 서명을 한다. Firebase Functions에서는 `jsonwebtoken` npm 패키지로 했는데, Rust에서도 같은 이름의 `jsonwebtoken` crate가 있다.

```rust
fn generate_jwt(&self) -> Result<String, AppError> {
    let mut header = Header::new(Algorithm::ES256);
    header.kid = Some(self.key_id.clone());  // .p8 Key ID

    let claims = json!({
        "iss": self.team_id,  // Apple Team ID
        "iat": Utc::now().timestamp(),
    });

    let key = EncodingKey::from_ec_pem(self.auth_key.as_bytes())?;
    encode(&header, &claims, &key)
}
```

토큰은 1시간 동안 유효하다. 매번 생성하는 건 낭비이므로 Mutex로 캐시해두고 만료 5분 전에 갱신한다.

Swift에서 JWT를 직접 다룰 일은 거의 없지만 Rust에서는 한 줄도 안 되는 boilerplate다.

```swift
// Swift에서 JWT를 만들 일은 보통 없다
// 서버가 해주니까

// Rust에서는 서버가 자기가 한다
let token = encode(&header, &claims, &key)?;
```

---

## 세 가지 APNs 호출

LiveActivity에는 세 종류의 APNs 요청이 필요하다.

**Push to Start** - 참가자의 디바이스에 LiveActivity를 시작시킨다. 개별 디바이스 토큰으로 보낸다.
```
POST /3/device/{token}
apns-push-type: liveactivity
apns-topic: {bundleId}.push-type.liveactivity
```

**Channel 생성** - Broadcast 채널을 만든다. 응답 헤더에서 `apns-channel-id`를 받는다.
```
POST /1/apps/{bundleId}/channels
Body: { "push-type": "LiveActivity", "message-storage-policy": 1 }
```

**Broadcast** - 채널에 상태 업데이트를 보낸다. 구독 중인 모든 디바이스가 동시에 받는다.
```
POST /4/broadcasts/apps/{bundleId}
apns-channel-id: {channelId}
```

Firebase Functions에서 이 세 개는 `sendAPNsPush`, `createAPNsChannel`, `sendAPNsBroadcast`라는 함수였다. Rust에서는 `ApnsSender` trait의 세 메서드가 됐다.

```rust
#[async_trait]
pub trait ApnsSender: Send + Sync {
    async fn send_push_to_start(&self, tokens: &[String], payload: &ApnsPayload) -> ApnsResult;
    async fn create_channel(&self) -> Result<String, AppError>;
    async fn send_broadcast(&self, channel_id: &str, payload: &ApnsPayload) -> ApnsResult;
}
```

#5에서 FCM용으로 만든 `PushSender` trait과 같은 패턴이다. 프로덕션에서는 `RealApnsSender`가 실제 HTTP/2 요청을 보내고, 테스트에서는 `MockApnsSender`가 호출 기록만 쌓는다. 42개 테스트가 이 Mock으로 돌아간다.

---

## Cloud Tasks를 뭘로 바꿀까

LiveActivity에는 "나중에 실행해야 하는 일"이 있다. 약속 30분 전에 자동 시작. 약속 시간 + 30분에 자동 종료. 시작 후 15분에 "실시간 현황을 공유해주세요" 넛지 알림. Firebase에서는 Cloud Tasks가 이걸 했다. "2:30에 이 함수를 호출해줘"라고 예약하면 Google이 알아서 실행한다.

세 가지 방법을 검토했다.

**메모리 타이머** (`tokio::time::sleep`) - 서버 프로세스 안에서 대기한다. Cloud Run이 재시작되면 타이머가 사라진다. 배포할 때마다 예약이 날아간다. 탈락.

**Cloud Tasks API** - Firebase 탈피 프로젝트에서 GCP 서비스를 하나 더 추가하는 건 방향에 맞지 않다. Cloud Run은 이미 쓰고 있지만 Cloud Tasks는 새로운 종속이다.

**DB polling** - `scheduled_tasks` 테이블에 "언제 뭘 실행할지" 적어두고, 서버가 30초마다 "지금 실행할 게 있나?" 확인한다. 서버가 재시작되면? DB에 남아있으니까 다시 시작하면 밀린 작업을 바로 처리한다.

```sql
CREATE TABLE scheduled_tasks (
    id            UUID PRIMARY KEY,
    task_type     TEXT NOT NULL,           -- 'start_live_activity', 'end_live_activity', 'nudge'
    schedule_id   UUID NOT NULL,
    execute_at    TIMESTAMPTZ NOT NULL,    -- 이 시각에 실행
    status        task_status NOT NULL DEFAULT 'pending',
    retry_count   SMALLINT NOT NULL DEFAULT 0,
    max_retries   SMALLINT NOT NULL DEFAULT 3
);

-- 30초마다 이 쿼리를 실행
SELECT * FROM scheduled_tasks
WHERE execute_at <= NOW() AND status = 'pending'
FOR UPDATE SKIP LOCKED;
```

`FOR UPDATE SKIP LOCKED`는 서버가 여러 대일 때 같은 task를 두 번 실행하는 걸 막는다. "약속 30분 전 시작"에서 최대 30초 오차는 아무도 모른다.

---

## ETA 업데이트는 DB를 안 거친다

ETA 업데이트는 재밌는 구조다. 참가자가 "나 15분 남았어"를 보내면 서버는 DB에 아무것도 쓰지 않는다. APNs Broadcast로 바로 전달한다. Firestore에서도 같았다 - iOS 18 Broadcast로 전환하면서 `liveActivities` 컬렉션 쓰기를 완전히 제거했다.

```rust
pub async fn update_eta(
    pool: &PgPool, apns: &dyn ApnsSender,
    user_uid: &str, schedule_id: Uuid, req: UpdateETARequest,
) -> Result<LiveActivityResponse, AppError> {
    // DB 쓰기 없음 - 상태 분석만
    let arrived_count = req.participants.iter()
        .filter(|p| p.estimated_arrival_minutes == Some(0))
        .count();
    let total_count = req.participants.len();

    // APNs Broadcast로 바로 전달
    let payload = ApnsPayload {
        event: "update".to_string(),
        content_state: serde_json::to_value(&req.participants)?,
        channel_id: Some(req.channel_id.clone()),
        alert: if arrived_count == 1 && total_count > 1 {
            Some(ApnsAlert { title: "도착 알림".into(), body: format!("{}님이 도착했습니다!", ...) })
        } else { None },
        ..
    };
    apns.send_broadcast(&req.channel_id, &payload).await;

    // 모두 도착하면 5분 후 종료 예약
    if arrived_count == total_count && total_count > 1 {
        scheduled_task_service::create_task(pool, "delayed_end", schedule_id, now + 5min, ..).await?;
    }

    Ok(response)
}
```

DB를 안 쓰면 뭐가 좋은가? 레이턴시. ETA 업데이트는 초 단위로 반복될 수 있다. 매번 DB에 썼다가 읽으면 불필요한 I/O다. Broadcast 한 번이면 끝이다.

---

## 일정 제안도 LiveActivity다

일정 제안 응답도 LiveActivity를 쓴다. 호스트가 일정을 제안하면 멤버들이 잠금 화면에서 바로 수락하거나 거절한다. 구조는 실시간 현황 공유와 비슷하지만 차이가 있다.

일정 제안은 DB에 써야 한다. 누가 수락했고 누가 거절했는지 영속해야 한다. 전원이 응답하면 자동 마감된다. 호스트가 강제 마감할 수도 있다.

동시 응답이 문제가 된다. 두 사람이 동시에 마지막 투표를 보내면? 양쪽 다 "나만 응답 안 했으니 전원 응답 완료"로 판단할 수 있다. Firebase에서는 Firestore 트랜잭션으로 막았다. Rust에서도 PostgreSQL 트랜잭션으로 막는다.

```rust
let mut tx = pool.begin().await?;

// UPSERT + 전체 조회 + 마감 판단을 한 트랜잭션 안에서
sqlx::query("INSERT INTO schedule_votes (...) ON CONFLICT DO UPDATE ...")
    .execute(&mut *tx).await?;
let (accepted, declined) = get_vote_lists(&mut *tx, schedule_id).await?;
let total = count_group_members(&mut *tx, group_id).await?;
let is_finalized = (accepted.len() + declined.len()) >= total;

if is_finalized {
    sqlx::query("UPDATE schedules SET vote_finalized = true WHERE id = $1")
        .execute(&mut *tx).await?;
}
tx.commit().await?;
```

Swift로 비유하면 이런 차이다.

```swift
// Swift: 여러 비동기 작업을 순서대로 실행하지만, 앞의 실패가 뒤를 취소하지 않는다
let voteResult = try await db.upsertVote(scheduleId, userId, response)
let allVotes = try await db.getVotes(scheduleId)  // 앞이 실패해도 이건 별개
let memberCount = try await db.getMemberCount(groupId)
```

```rust
// Rust: 트랜잭션 안에서 실행. 중간에 실패하면 전부 되돌린다
let mut tx = pool.begin().await?;
sqlx::query("INSERT ...").execute(&mut *tx).await?;  // 실패 → 전부 롤백
let votes = sqlx::query("SELECT ...").fetch_all(&mut *tx).await?;
tx.commit().await?;  // 여기서 한 번에 확정
```

---

## 사라진 것들

- Cloud Tasks 3개 (`executeLiveActivityStart`, `executeLiveActivityEnd`, `executeETASharingNudge`) - `scheduled_tasks` 테이블 + 폴링 루프로 대체
- `liveActivities` Firestore 컬렉션 - ETA 업데이트가 DB를 안 거치므로 불필요
- `liveActivitySchedule` Firestore Map 필드 - `schedules` 테이블 컬럼으로 합침
- Node.js `http2` 모듈 - `reqwest` HTTP/2로 대체
- 5개의 Cloud Function onCall (`startLiveActivity`, `updateETA`, `startVoteLiveActivity`, `updateVoteResponse`, `finalizeVote`) - REST 엔드포인트 6개로 재구성
- Widget 전용 Cloud Function 2개 (`widgetUpdateETA`, `widgetVoteResponse`) - Widget 전용 라우트로 대체

새로 생긴 것.

- `ApnsSender` trait - APNs 발송을 추상화. 테스트에서 Mock, 프로덕션에서 Real
- `scheduled_tasks` 테이블 + 폴링 루프 - 외부 서비스 없는 예약 실행
- `VoteMember` 구조체 - 투표 결과에 이름 포함 (Firestore에서는 Map으로 관리하던 것)
- Widget 엔드포인트 - Firebase Auth 없이 `X-User-Id` 헤더로 인증하는 완화된 경로

---

## 마무리

LiveActivity는 FCM이 해주지 않는 영역이다. APNs에 직접 HTTP/2 요청을 보내고, 채널을 만들고, 브로드캐스트를 쏜다. Firebase Functions에서 Node.js `http2` 모듈로 하던 걸 Rust `reqwest`로 바꿨다. 결정적으로 달라진 건 없다. 같은 Apple API를 다른 언어로 호출할 뿐이다.

달라진 건 "나중에 실행"하는 방식이다. Cloud Tasks라는 외부 서비스 대신 DB 테이블 하나와 30초 폴링으로 해결했다. 서버가 재시작되면 DB에서 밀린 작업을 꺼내 실행한다. 외부 의존이 하나 줄었다.

*다음 글: #7 구독과 Entitlements - StoreKit 검증, 쿠폰/오버라이드, read model 재구성*

*Promiso - [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
