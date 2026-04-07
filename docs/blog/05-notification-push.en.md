# From Firebase to Rust -- Notifications: From Triggers to Function Calls

*An iOS App Server Migration #5 -- FCM Push + Badges + Per-Group Notification Settings*

---

Firestore triggers feel like magic.

Create a schedule and `onPromiseCreated` fires, sending push notifications to group members. A vote changes and `onPromiseVotesUpdated` figures out whether to send a "confirmed" or "cancelled" alert. Someone joins a group and `onGroupMemberJoined` notifies existing members. Documents change, things happen. Convenient.

The problem is the "things happen" part.

`onPromiseCreated` fires somewhere between 500ms and 3 seconds after the document is created. Longer if it hits a cold start. If the trigger fails, it retries -- and you have to make sure the same notification doesn't get sent twice. If a trigger modifies another document, that can fire yet another trigger. Following this chain in your head is much harder than following a call stack.

The notification system was built on top of these triggers. Five Firestore triggers, direct reads and writes to a `notifications` collection, FCM token management in a `users/{uid}.devices` Map, badge management via a `users/{uid}.groups.{gid}.hasNewActivity` Boolean. To trace how a single notification gets sent, I had to open four files side by side.

Moving to Rust, the question was the same as before. How much of this complexity is business logic, and how much comes from Firestore's event-driven model?

> Update (2026-04-07)
>
> We later split token storage into `devices` + `notification_endpoints` + `live_activity_endpoints` to make the boundary between general FCM alerts and APNs-based Live Activity tokens explicit. The current design follows [ADR-009](../adr/009-push-channel-separation.md). The rest of this post keeps the original #5 narrative intact.

---

## From Triggers to Function Calls

The core of Firestore triggers is "react to document changes." A schedule document gets created, send a notification. Votes change, decide if it's confirmed or cancelled. This is convenient, but there's a catch: business logic gets coupled to data change events.

```typescript
// Firebase: schedule creation trigger
export const onPromiseCreated = onDocumentCreated(
  "promises/{promiseId}", async (event) => {
    const promise = event.data?.data();
    const groupMembers = await getGroupMembers(promise.groupId);
    await sendPushNotificationInternal({
      userIds: groupMembers.filter(id => id !== promise.hostId),
      type: "promise_invitation",
      title: "New schedule 📩",
      body: `${hostNickname} proposed ${promise.title}.`,
    });
  }
);
```

This code is a handler for a document creation event. `createPromise` writes the document, Firestore detects the change, and runs this trigger in a separate process. There's a network event propagation step sitting between document creation and notification delivery.

In Rust, I replaced this with a function call.

```rust
pub async fn create_schedule(
    pool: &PgPool, push_sender: &dyn PushSender,
    user_id: &str, req: CreateScheduleRequest
) -> Result<CreateScheduleResponse, AppError> {
    // 1. Create the schedule
    let schedule = sqlx::query_as::<_, Schedule>(
        "INSERT INTO schedules (...) VALUES (...) RETURNING *"
    ).fetch_one(pool).await?;

    // 2. Send notification -- direct call, not a trigger
    notify_schedule_created(pool, push_sender, schedule.id, group_id, user_id).await?;

    // 3. Update badge
    sqlx::query("UPDATE groups SET last_activity_at = NOW() WHERE id = $1")
        .bind(group_id).execute(pool).await?;

    Ok(response)
}
```

Create schedule → send notification → update badge, all in one function, in order. No guessing when a trigger will fire. If the notification fails, the `?` operator propagates the error up. When debugging, you follow the call stack.

In Swift terms, it's this kind of difference:

```swift
// Firebase style: NotificationCenter (event-driven)
NotificationCenter.default.post(name: .scheduleCreated, object: schedule)
// Something somewhere is subscribed to this... where?

// Rust style: direct call
let result = notificationService.notifyScheduleCreated(schedule)
// The call site is right here
```

---

## Notifications Are Always Saved

The most important rule in the notification system: **notifications are always saved to the database, regardless of whether the push was sent.**

Even if a user turned off group notifications, even if there's no FCM token, the notification record gets created. When they open the notification inbox later, it's there. Push is "alerting." The notification record is "logging." These two should be separate.

```rust
pub async fn send_push_internal(
    pool: &PgPool, push_sender: &dyn PushSender, params: SendPushRequest
) -> Result<PushResult, AppError> {
    // Step 1: Always save to DB (all recipients)
    for user_id in &params.user_ids {
        sqlx::query(
            "INSERT INTO notifications (user_id, notification_type, title, body, ...)
             VALUES ($1, $2, $3, $4, ...)"
        ).bind(user_id).bind(&params.notification_type)
         .execute(pool).await?;
    }

    // Step 2: Check notification settings (filter FCM targets)
    let eligible_tokens = collect_eligible_tokens(pool, &params).await?;

    // Step 3: Send FCM (only to those with tokens)
    if !eligible_tokens.is_empty() {
        let result = push_sender.send_multicast(&eligible_tokens, &message).await;
        // Mark delivered only for successful sends
        update_delivered_status(pool, &delivered_notification_ids).await?;
    }

    Ok(push_result)
}
```

Step 1 runs before steps 2 and 3. If FCM goes down, the notification record survives.

---

## The devices Table: From Map to Normalized Table

In Firestore, FCM tokens live inside a Map on the user document.

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

One user can have multiple devices. iPhone and iPad at the same time means two device entries. The problem shows up when switching accounts. User A logs out, user B logs in on the same device. The FCM token from A's device entry gets registered under B too. Same token on two users means pushes meant for A also go to B.

I queried the actual Firestore data and found this was already happening. The same `deviceId` existed in two different users' `devices` Maps.

In PostgreSQL, a `UNIQUE` constraint prevents this at the schema level.

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

`UNIQUE (fcm_token)` -- the same FCM token can only exist once in the database. When a new user registers with the same token, the service layer deletes the previous owner's row and inserts a new one. Ownership transfer happens automatically. On logout, all device entries for that user are deleted.

---

## Badges: From Boolean to Timestamp Comparison

In Firebase, a badge (the red dot) is a `hasNewActivity` Boolean.

```
users/{uid}.groups.{groupId}.hasNewActivity = true   // on schedule creation
users/{uid}.groups.{groupId}.hasNewActivity = false  // on read
```

When a schedule is created, a trigger flips `hasNewActivity` to `true` for every group member. Ten members means ten document writes. Clearing the badge calls the `clearGroupBadge` Cloud Function to set it back to `false`. Two writes (set + clear) × number of members.

In the Rust backend, I'd already designed this as timestamp-based during the groups migration (#3).

```rust
// Badge is computed when listing groups
let has_new_activity = last_activity_at > last_read_at;
```

`groups.last_activity_at` gets updated once when something new happens in the group. `group_members.last_read_at` gets updated when a user opens the group. Badge state is derived from comparing these two timestamps. Instead of writing a separate Boolean for each member, one timestamp update covers everyone.

What the notification function does on schedule creation:
```rust
// Badge update -- just one row
sqlx::query("UPDATE groups SET last_activity_at = NOW() WHERE id = $1")
    .bind(group_id).execute(pool).await?;
```

Even with 100 members, that's one write.

---

## Notification Settings: Columns That Already Existed

Notification settings didn't need to be built from scratch. I'd already added them to the `group_members` table during the groups migration (#3).

```sql
-- Already defined in 004_groups.sql
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

In Firestore, these lived in a nested Map at `users/{uid}.groups.{gid}.notifications`. Reading them meant fetching the entire user document and parsing it. In PostgreSQL, they're columns on the `group_members` table -- one JOIN during notification delivery is all it takes.

```rust
// Setting check during notification delivery -- one query
let should_send = match notification_type {
    ScheduleInvitation => member.schedule_invitation,
    ScheduleConfirmed  => member.schedule_confirmed,
    ScheduleCancelled  => member.schedule_cancelled,
    // ...
    LocationSharingReminder | System => true,  // always send
};
```

`LocationSharingReminder` and `System` types bypass settings and always get sent. This was the same logic in Firebase, but it was buried in trigger code and hard to find. In Rust, it's all in one `match` block.

---

## PushSender: Abstraction for Testing

How do you test FCM delivery? You can't actually send pushes in tests.

The same pattern that Swift uses with protocols, Rust does with traits.

```rust
// Rust: trait (same idea as Swift protocol)
#[async_trait]
pub trait PushSender: Send + Sync {
    async fn send_multicast(
        &self, tokens: &[String], message: &FcmMessage
    ) -> PushResult;
}
```

```swift
// The Swift version would look like this
protocol PushSending: Sendable {
    func sendMulticast(
        tokens: [String], message: FcmMessage
    ) async throws -> PushResult
}
```

In production, `FcmPushSender` calls the Google FCM HTTP v1 API. In tests, `MockPushSender` just records what was called.

```rust
// In tests
let mock = MockPushSender::new();
notify_schedule_created(&pool, &mock, schedule_id, group_id, "host").await?;

assert_eq!(mock.call_count(), 1);           // called once
assert_eq!(mock.last_tokens().len(), 2);    // sent to 2 tokens
```

37 tests run on this MockPushSender. Whether notifications get saved to the DB, whether FCM is skipped for users with settings turned off, whether the host is excluded -- all business rules verified without sending a single real push.

---

## What Disappeared

- Five Firestore triggers (`onPromiseCreated`, `onPromiseVotesUpdated`, `onPromiseInfoUpdated`, `onGroupMemberJoined`, `onPromiseCreatedBadges`)
- Direct reads/writes to `notifications` collection -- replaced by REST API
- `users/{uid}.devices` Map -- normalized into a `devices` table
- `hasNewActivity` Boolean + batch writes per member -- replaced by timestamp comparison
- `clearGroupBadge` Cloud Function -- merged into existing `mark-read` API
- FCM token duplication issue -- solved with `UNIQUE(fcm_token)` + ownership transfer

What's new:

- Ownership transfer logic (same FCM token on a different user deletes the previous owner)
- Logout API that deletes all device entries
- `schedule_updated` detection fields explicitly fixed to five (title, startAt, location, description, minimumParticipants)
- `is_delivered` flag tracking whether FCM delivery actually succeeded

---

## Wrapping Up

Firestore triggers are "react automatically when documents change." Convenient, but hard to trace. Which trigger fires in what order, how retries work when they fail, how long the chain gets -- the code alone doesn't tell you.

Replacing triggers with function calls removes the magic, but makes the flow visible. Create schedule → send notification → update badge, all in one function. "What happens when this API is called?" The answer is in the code.

*Next: #6 Real-time and LiveActivity -- SSE + Direct APNs + ETA Sharing*

*Promiso -- [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
