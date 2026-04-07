# From Firebase to Rust - LiveActivity, Implementing Push Yourself

*An iOS App Server Migration #6 - APNs HTTP/2 Direct Push + Broadcast Channels + DB-Based Scheduled Execution*

---

Promiso has two features that live on the lock screen. One is real-time status sharing - as the meeting time approaches, a LiveActivity appears showing each group member's estimated arrival time, updating in real time. Who arrived first, who's still on their way - all visible at a glance. The other is schedule proposal responses - when a host proposes a schedule, members can accept or decline right from the LiveActivity on their lock screen.

The core of both features is APNs (Apple Push Notification service). You have to send HTTP/2 requests directly to Apple, not through Firebase. Firebase Functions was already doing this with Node.js's `http2` module.

Moving to Rust, I had three decisions to make. FCM doesn't support LiveActivity Push, so I needed a way to call APNs directly. Firebase Cloud Tasks had been handling scheduled execution like "auto-start 30 minutes before the meeting" - I needed a replacement. And I had to support the Broadcast Channel model that changed in iOS 18.

---

## APNs, Not FCM

Regular push notifications go through FCM. Server → FCM → APNs → device. LiveActivity is different. You send directly to APNs. FCM doesn't support LiveActivity Push.

More precisely, starting with iOS 18, LiveActivity uses a "Broadcast Channel" model. Before, you'd send to each participant's individual token. 10 people meant 10 requests. Now you create a single channel, all participants subscribe to it, and the server sends once.

```
[Before - iOS 17]
Server → APNs → Device1 (Token A)
Server → APNs → Device2 (Token B)
Server → APNs → Device3 (Token C)

[After - iOS 18 Broadcast]
Server → APNs (Channel X) → Device1, Device2, Device3
```

Firebase Functions was already using Broadcast. Channel creation, Push to Start, and Broadcast sending were all implemented in `apns.ts`. The job was to port this to Rust.

---

## APNs Library Choice: a2 vs reqwest

There's a Rust crate called [`a2`](https://crates.io/crates/a2) dedicated to APNs. I was going to use it. Then I read the docs and stopped. It doesn't support the iOS 18 [Broadcast Channel API](https://developer.apple.com/documentation/usernotifications/sending-channel-management-requests-to-apns) - creating channels at `/1/apps/{bundleId}/channels`, [sending broadcasts](https://developer.apple.com/documentation/usernotifications/sending-broadcast-push-notification-requests-to-apns) at `/4/broadcasts/apps/{bundleId}` - these APIs aren't there. Not even in the latest version (v0.10.0, May 2024).

[`reqwest`](https://docs.rs/reqwest/latest/reqwest/struct.ClientBuilder.html) was already in the project. Enable the `http2` feature and it speaks APNs HTTP/2. When Apple adds new APIs, I can implement them directly. No waiting for library updates.

---

## APNs Auth: Signing JWTs with a .p8 Key

APNs requires a JWT token with every request. You get a `.p8` key file from Apple Developer and sign with ES256 (ECDSA + SHA-256). Firebase Functions used the `jsonwebtoken` npm package. Rust has a crate with the same name.

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

Tokens are valid for one hour. Generating one every time is wasteful, so I cache it with a Mutex and refresh 5 minutes before expiry.

In Swift, you rarely deal with JWTs directly - the server handles it. In Rust, you are the server.

```swift
// In Swift, you usually don't create JWTs
// The server does it for you

// In Rust, you are the server
let token = encode(&header, &claims, &key)?;
```

---

## Three Types of APNs Calls

LiveActivity requires three types of APNs requests.

**Push to Start** - starts a LiveActivity on participants' devices. Uses individual device tokens.
```
POST /3/device/{token}
apns-push-type: liveactivity
apns-topic: {bundleId}.push-type.liveactivity
```

**Channel Creation** - creates a Broadcast channel. The `apns-channel-id` comes back in the response header.
```
POST /1/apps/{bundleId}/channels
Body: { "push-type": "LiveActivity", "message-storage-policy": 1 }
```

**Broadcast** - sends a state update to the channel. All subscribed devices receive it simultaneously.
```
POST /4/broadcasts/apps/{bundleId}
apns-channel-id: {channelId}
```

In Firebase Functions, these were three functions: `sendAPNsPush`, `createAPNsChannel`, `sendAPNsBroadcast`. In Rust, they became three methods on the `ApnsSender` trait.

```rust
#[async_trait]
pub trait ApnsSender: Send + Sync {
    async fn send_push_to_start(&self, tokens: &[String], payload: &ApnsPayload) -> ApnsResult;
    async fn create_channel(&self) -> Result<String, AppError>;
    async fn send_broadcast(&self, channel_id: &str, payload: &ApnsPayload) -> ApnsResult;
}
```

Same pattern as the `PushSender` trait I built for FCM in #5. In production, `RealApnsSender` makes actual HTTP/2 requests. In tests, `MockApnsSender` just records calls. 42 tests run on that mock.

---

## Replacing Cloud Tasks

LiveActivity has things that need to happen later. Auto-start 30 minutes before the meeting. Auto-end at meeting time + 30 minutes. A "share your status" nudge notification 15 minutes after start. In Firebase, Cloud Tasks handled this. "Call this function at 2:30" - and Google would.

I evaluated three approaches.

**In-memory timers** (`tokio::time::sleep`) - the server process holds the timer. Cloud Run restarts and the timer vanishes. Every deploy wipes all scheduled work. Out.

**Cloud Tasks API** - adding another GCP service in a project about leaving Firebase didn't feel right. Cloud Run is already a dependency, but Cloud Tasks would be a new one.

**DB polling** - write "what to execute and when" to a `scheduled_tasks` table, then check every 30 seconds: "anything due now?" If the server restarts, the tasks are still in the DB, and the next poll picks them up.

```sql
CREATE TABLE scheduled_tasks (
    id            UUID PRIMARY KEY,
    task_type     TEXT NOT NULL,           -- 'start_live_activity', 'end_live_activity', 'nudge'
    schedule_id   UUID NOT NULL,
    execute_at    TIMESTAMPTZ NOT NULL,    -- execute at this time
    status        task_status NOT NULL DEFAULT 'pending',
    retry_count   SMALLINT NOT NULL DEFAULT 0,
    max_retries   SMALLINT NOT NULL DEFAULT 3
);

-- Run this query every 30 seconds
SELECT * FROM scheduled_tasks
WHERE execute_at <= NOW() AND status = 'pending'
FOR UPDATE SKIP LOCKED;
```

`FOR UPDATE SKIP LOCKED` prevents two servers from picking up the same task. A 30-second margin on "start 30 minutes before the meeting" is invisible to users.

---

## ETA Updates Skip the Database

ETA updates have an interesting structure. When a participant sends "I'm 15 minutes away," the server writes nothing to the database. It forwards directly via APNs Broadcast. Firestore worked the same way - after switching to iOS 18 Broadcast, the `liveActivities` collection writes were completely eliminated.

```rust
pub async fn update_eta(
    pool: &PgPool, apns: &dyn ApnsSender,
    user_uid: &str, schedule_id: Uuid, req: UpdateETARequest,
) -> Result<LiveActivityResponse, AppError> {
    // No DB write - just analyze state
    let arrived_count = req.participants.iter()
        .filter(|p| p.estimated_arrival_minutes == Some(0))
        .count();
    let total_count = req.participants.len();

    // Forward directly via APNs Broadcast
    let payload = ApnsPayload {
        event: "update".to_string(),
        content_state: serde_json::to_value(&req.participants)?,
        channel_id: Some(req.channel_id.clone()),
        alert: if arrived_count == 1 && total_count > 1 {
            Some(ApnsAlert { title: "Arrival".into(), body: format!("{} has arrived!", ...) })
        } else { None },
        ..
    };
    apns.send_broadcast(&req.channel_id, &payload).await;

    // When everyone arrives, schedule end in 5 minutes
    if arrived_count == total_count && total_count > 1 {
        scheduled_task_service::create_task(pool, "delayed_end", schedule_id, now + 5min, ..).await?;
    }

    Ok(response)
}
```

Why skip the DB? Latency. ETA updates can repeat every few seconds. Writing to and reading from the DB each time is unnecessary I/O. One broadcast and done.

---

## Schedule Proposals Are LiveActivities Too

Schedule proposal responses also use LiveActivity. When a host proposes a schedule, members accept or decline right from their lock screen. The structure is similar to real-time status sharing, but with a key difference.

Proposals must be persisted. Who accepted, who declined - this needs to survive in the database. When everyone responds, it auto-finalizes. The host can also force-finalize.

Concurrent responses are the problem. Two people submit the last vote at the same time. Both might conclude "everyone has responded" independently. Firebase handled this with Firestore transactions. Rust does the same with PostgreSQL transactions.

```rust
let mut tx = pool.begin().await?;

// UPSERT + query all votes + finalize check in one transaction
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

In Swift terms, the difference looks like this.

```swift
// Swift: sequential async calls, but a failure in one doesn't undo the others
let voteResult = try await db.upsertVote(scheduleId, userId, response)
let allVotes = try await db.getVotes(scheduleId)  // independent of the above
let memberCount = try await db.getMemberCount(groupId)
```

```rust
// Rust: inside a transaction. If anything fails, everything rolls back
let mut tx = pool.begin().await?;
sqlx::query("INSERT ...").execute(&mut *tx).await?;  // fails → full rollback
let votes = sqlx::query("SELECT ...").fetch_all(&mut *tx).await?;
tx.commit().await?;  // commits everything at once
```

---

## What Disappeared

- 3 Cloud Tasks (`executeLiveActivityStart`, `executeLiveActivityEnd`, `executeETASharingNudge`) - replaced by `scheduled_tasks` table + polling loop
- `liveActivities` Firestore collection - unnecessary since ETA updates skip the DB
- `liveActivitySchedule` Firestore Map field - merged into `schedules` table columns
- Node.js `http2` module - replaced by `reqwest` HTTP/2
- 5 Cloud Function onCalls (`startLiveActivity`, `updateETA`, `startVoteLiveActivity`, `updateVoteResponse`, `finalizeVote`) - restructured into 6 REST endpoints
- 2 Widget-specific Cloud Functions (`widgetUpdateETA`, `widgetVoteResponse`) - replaced by widget-specific routes

What's new.

- `ApnsSender` trait - abstracts APNs delivery. Mock in tests, Real in production
- `scheduled_tasks` table + polling loop - scheduled execution without external services
- `VoteMember` struct - vote results include names (was a Map in Firestore)
- Widget endpoints - relaxed auth using `X-User-Id` header instead of Firebase Auth

---

## Wrapping Up

LiveActivity is where FCM can't help you. You send HTTP/2 requests directly to APNs, create channels, and broadcast. I replaced Node.js `http2` in Firebase Functions with Rust's `reqwest`. Fundamentally, nothing changed - it's the same Apple API called from a different language.

What did change is how "execute later" works. Instead of Cloud Tasks as an external service, a single DB table and 30-second polling does the job. When the server restarts, it picks up pending work from the database. One fewer external dependency.

*Next: #7 Subscription and Entitlements - StoreKit validation, coupon/override flows, and rebuilding the read model*

*Promiso - [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
