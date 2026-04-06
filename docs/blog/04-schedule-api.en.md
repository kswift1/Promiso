# From Firebase to Rust -- Schedule API: The Vote State Machine and Three Collections

*An iOS App Server Migration #4 -- Merging Group Schedules, Personal Events, and Recurring Events into One Table*

---

In Firestore, schedule-related data is scattered across three locations.

`promises/{id}` -- group schedules. Votes (a Map), confirmation status, location, images.
`users/{uid}/personalEvents/{id}` -- personal events. Private schedules only visible to the owner.
`users/{uid}/scheduleSlots/{YYYY-MM-DD}` -- denormalized slots for conflict detection. Copies of schedule fragments, organized by date.

All three need to merge on the calendar screen. Group and personal schedules displayed together in chronological order, and when creating a new schedule, you need to check if it overlaps with existing ones. In Firestore, that means querying three separate collections, merging on the client, and sorting.

Conflict detection was particularly painful. Firestore can't do "query all schedules for this user within a time range" in a single call. So I built a denormalized collection called `scheduleSlots`. When a schedule is created, a trigger copies a slot entry into the corresponding date document. When a schedule changes, the old slot gets removed and a new one inserted. When deleted, the slot goes too. Three triggers for group schedules, three for personal events, one for querying. Seven Cloud Functions triggers maintaining this denormalization.

These triggers are fragile. When a schedule's time changes, you need to remove the slot from the old date and add it to the new one -- which means carrying both the previous and new `startAt` through the trigger. When vote status changes, only the accepting member's slot should be added or removed. Recurring events don't have slots at all -- they're expanded at query time. The result: three separate data paths just for conflict detection.

Moving to PostgreSQL, I had one question. Of all this complexity, how much is business logic and how much is a Firestore workaround?

---

## Three Collections, One Table

The short answer: I merged `promises` + `personalEvents` into a single `schedules` table. `scheduleSlots` was deleted entirely.

```sql
CREATE TABLE schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_type schedule_type NOT NULL,  -- 'group' | 'personal'
  user_id TEXT NOT NULL REFERENCES users(id),

  title TEXT NOT NULL,
  emoji TEXT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ,
  -- ... shared fields ...

  -- Group schedule only (NULL for personal)
  group_id UUID REFERENCES groups(id),
  minimum_participants SMALLINT,
  is_confirmed BOOLEAN,
  vote_deadline TIMESTAMPTZ,

  -- Personal schedule only (NULL for group)
  reminder_minutes_before SMALLINT,

  CONSTRAINT chk_schedule_type_fields CHECK (
    (schedule_type = 'group'
      AND group_id IS NOT NULL
      AND minimum_participants IS NOT NULL)
    OR
    (schedule_type = 'personal'
      AND group_id IS NULL
      AND minimum_participants IS NULL)
  )
);
```

A `schedule_type` enum distinguishes the two, and a CHECK constraint enforces type-specific fields. A group schedule without `group_id`? INSERT fails. A personal schedule with `minimum_participants`? Also fails. The database enforces the rules.

Why merge? Look at why they were separated in Firestore. `promises` is a top-level collection; `personalEvents` is a user subcollection. This split exists because of security rules. Firestore security rules are path-based. Putting events under `users/{uid}/personalEvents/{id}` lets you enforce "owner-only access" with a single path pattern. `promises` needs to be readable by all group members, so it sits in its own collection with a separate membership check.

In PostgreSQL, security isn't path-based -- it lives in the API layer. The service function checks "if personal, verify `user_id` matches; if group, verify group membership" in code. The reason for separation is gone, and a reason to merge has appeared: the calendar can query both types in a single SQL statement.

Recurring events (`recurringEvents`) stayed in a separate `recurring_schedules` table. Not because I was following Firestore's structure, but because they're fundamentally different entities. `schedules` stores concrete moments -- "Movie at 2pm on April 7th." `recurring_schedules` stores rules -- "Gym every Mon/Wed/Fri at 7pm." The field structures are completely different: one has `start_at: TIMESTAMPTZ`, the other has `start_time_hour: SMALLINT` + `start_time_minute: SMALLINT`.

---

## scheduleSlots, Gone

The seven triggers maintaining `scheduleSlots` are replaced by a single SQL query.

```sql
-- All schedules for a user within a time range (conflict detection)
SELECT s.id, s.title, s.start_at, s.end_at
FROM schedules s
JOIN schedule_votes sv ON sv.schedule_id = s.id
WHERE sv.user_id = $1 AND sv.status = 'accepted'
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL)
UNION ALL
SELECT s.id, s.title, s.start_at, s.end_at
FROM schedules s
WHERE s.schedule_type = 'personal' AND s.user_id = $1
  AND s.start_at < $3 AND (s.end_at > $2 OR s.end_at IS NULL);
```

Group schedules JOIN with `schedule_votes` to get only the ones I accepted. Personal schedules filter by `user_id` directly. Two indexes are enough.

```sql
CREATE INDEX idx_schedule_votes_user ON schedule_votes (user_id, status);
CREATE INDEX idx_schedules_personal_start ON schedules (user_id, start_at)
  WHERE schedule_type = 'personal';
```

The denormalization existed because Firestore can't do "range queries across multiple collections." SQL handles that with JOIN + WHERE. Seven triggers, slot creation/deletion/update logic, date key calculation code -- all gone.

---

## The Vote State Machine

The core of group schedules is voting. Members accept or decline, and when the minimum headcount is reached, the schedule is confirmed.

In Firestore, votes are a Map:

```json
{
  "votes": {
    "accepted": ["user_A", "user_B"],
    "declined": ["user_C"],
    "until": "2026-04-10T19:00:00+09:00"
  },
  "minimumParticipants": 2,
  "isConfirmed": true
}
```

`accepted` and `declined` are userId arrays. Pending isn't stored -- it's computed as "group members minus accepted minus declined." `isConfirmed` is a denormalized field: `accepted.length >= minimumParticipants`.

This structure was tailored for Firestore. `arrayUnion`/`arrayRemove` let you treat arrays as sets, and a single document listener catches all vote changes.

In PostgreSQL, it becomes a normalized table.

```sql
CREATE TABLE schedule_votes (
  schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  status vote_status NOT NULL,  -- 'accepted' | 'declined'
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (schedule_id, user_id)
);
```

Pending still isn't stored. If someone is in `group_members` but not in `schedule_votes`, they're pending. Same principle as Firebase.

The vote response logic runs inside a transaction.

```rust
let mut tx = pool.begin().await?;

match status {
    "accepted" | "declined" => {
        // UPSERT -- if already voted, just update the status
        sqlx::query(
            "INSERT INTO schedule_votes (schedule_id, user_id, status)
             VALUES ($1, $2, $3::vote_status)
             ON CONFLICT (schedule_id, user_id)
             DO UPDATE SET status = $3::vote_status, responded_at = NOW()"
        )
        .bind(schedule_id).bind(user_id).bind(status)
        .execute(&mut *tx).await?;
    }
    "pending" => {
        // Canceling a vote = deleting the row entirely
        sqlx::query(
            "DELETE FROM schedule_votes
             WHERE schedule_id = $1 AND user_id = $2"
        )
        .bind(schedule_id).bind(user_id)
        .execute(&mut *tx).await?;
    }
}

// Recalculate is_confirmed -- in the same transaction
let accepted_count: i64 = sqlx::query_scalar(
    "SELECT COUNT(*) FROM schedule_votes
     WHERE schedule_id = $1 AND status = 'accepted'"
)
.bind(schedule_id)
.fetch_one(&mut *tx).await?;

let new_confirmed = accepted_count >= minimum_participants as i64;
sqlx::query("UPDATE schedules SET is_confirmed = $1 WHERE id = $2")
    .bind(new_confirmed).bind(schedule_id)
    .execute(&mut *tx).await?;

tx.commit().await?;
```

Firestore did the same thing inside `runTransaction`. The difference is `INSERT ON CONFLICT` and `DELETE` instead of `arrayUnion`/`arrayRemove`, and `COUNT(*)` instead of array length. The business rules are identical; only the expression changes.

I kept `is_confirmed` as a separate column for query performance. Calendar sync needs "confirmed future schedules," and `WHERE is_confirmed = TRUE AND start_at >= NOW()` is one line with a clear index path. Better than counting votes every time.

---

## Mutual Exclusion in Recurring Schedules

The fun part of the recurring schedule schema was the CHECK constraint.

```sql
CONSTRAINT chk_recurrence_fields CHECK (
  (frequency = 'daily'
    AND days_of_week IS NULL
    AND day_of_month IS NULL)
  OR
  (frequency = 'weekly'
    AND days_of_week IS NOT NULL
    AND array_length(days_of_week, 1) > 0
    AND day_of_month IS NULL)
  OR
  (frequency = 'monthly'
    AND days_of_week IS NULL
    AND day_of_month IS NOT NULL
    AND day_of_month BETWEEN 1 AND 31)
)
```

Daily but `days_of_week` is set? INSERT fails. Weekly but `days_of_week` is empty? Fails. Monthly but no `day_of_month`? Fails. Even if the service code misses a validation, the database catches it.

In Swift, you'd express this mutual exclusion with an enum with associated values:

```swift
enum Recurrence {
    case daily
    case weekly(daysOfWeek: [Int])
    case monthly(dayOfMonth: Int)
}
```

The type system guarantees "weekly always has daysOfWeek" at compile time. SQL's CHECK constraint provides the same guarantee at runtime, at the database level. Different layer, same purpose.

---

## Code: Before/After

### Creating a Schedule

In Firebase, group schedules and personal events take completely different paths.

```typescript
// Firebase: group schedule -- Cloud Function
export const createPromise = onCall(async (request) => {
  const promiseRef = promisesCollection.doc();
  await promiseRef.set({
    title, groupId, hostId: userId,
    votes: { accepted: [userId], declined: [], until: startAt },
    isConfirmed: initialAccepted.length >= minimumParticipants,
    // ... 20 more lines ...
  });
  return { promiseId: promiseRef.id };
});

// Firebase: personal event -- client writes to Firestore directly
db.collection("users").document(userId)
  .collection("personalEvents").addDocument(data: [...])
```

In Rust, it's a single function that branches on `schedule_type`.

```rust
pub async fn create_schedule(
    pool: &PgPool, user_id: &str, req: CreateScheduleRequest
) -> Result<CreateScheduleResponse, AppError> {
    match req.schedule_type {
        ScheduleType::Group => {
            // Check group membership + INSERT + auto-accept host vote
            let mut tx = pool.begin().await?;
            let schedule = sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (...) VALUES (...) RETURNING *"
            ).fetch_one(&mut *tx).await?;

            // Host auto-accepted
            sqlx::query("INSERT INTO schedule_votes ...")
                .execute(&mut *tx).await?;
            tx.commit().await?;
        }
        ScheduleType::Personal => {
            // Just verify user_id + INSERT
            sqlx::query_as::<_, Schedule>(
                "INSERT INTO schedules (...) VALUES (...) RETURNING *"
            ).fetch_one(pool).await?;
        }
    }
}
```

### Calendar Query

In Firebase, three separate queries from three locations.

```swift
// iOS: group schedules -- query by groupId (chunked, max 10 per query)
for chunk in groupIds.chunked(into: 10) {
    let snapshot = try await db.collection("promises")
        .whereField("groupId", in: chunk)
        .whereField("startAt", isGreaterThan: startDate)
        .getDocuments()
}

// iOS: personal events
let personal = try await db.collection("users").document(uid)
    .collection("personalEvents")
    .whereField("startAt", isGreaterThan: startDate)
    .getDocuments()

// Merge + sort on client
let all = (groupSchedules + personalSchedules).sorted(by: \.startAt)
```

In Rust, the server does the merging.

```rust
// Group + personal in one query
let schedules = sqlx::query_as::<_, Schedule>(
    "SELECT * FROM schedules
     WHERE (schedule_type = 'group' AND group_id = ANY($1))
        OR (schedule_type = 'personal' AND user_id = $2)
     AND start_at BETWEEN $3 AND $4
     ORDER BY start_at"
)
.bind(&group_ids).bind(user_id)
.bind(start).bind(end)
.fetch_all(pool).await?;
```

The chunking code for Firestore's 10-item `in` operator limit becomes a single `= ANY($1)` in PostgreSQL. Client-side merging and sorting moves to a server-side `ORDER BY`.

---

## What Disappeared

Things removed in this migration:

- The entire `scheduleSlots` collection + 7 Firestore triggers
- The split between `promises` and `personalEvents` -- merged into a single `schedules` table
- Chunking code for Firestore's `in` operator 10-item limit
- Client-side schedule merging and sorting logic
- `arrayUnion`/`arrayRemove`-based vote logic -- replaced by SQL UPSERT/DELETE
- The `votes` subcollection (used for LiveActivity broadcasts) -- to be handled separately later
- The `badgesCleared` flag -- to be redesigned in the notifications migration (#5)

Things that were added: title length limit (30 chars), description limit (500 chars), end time must be after start time, start time must be in the future. Server-side validations that were missing in Firebase, now added in Rust. A side effect of rewriting: you spot the gaps.

---

## Wrapping Up

Three collections merged into one table. Seven triggers replaced by a single SQL query. The vote state machine wrapped in a transaction. More changes than the group migration, but the same principle: strip away complexity that came from Firestore's constraints, keep only the business rules.

`scheduleSlots` is the poster child. Firestore couldn't do range queries across collections, so I built date-keyed denormalization and maintained it with seven triggers. In PostgreSQL, JOIN + WHERE produces the same result. What seven triggers did, two indexes now handle.

*Next: #5 Notifications and Push -- Direct FCM, Badges, and Per-Group Settings*

*Promiso -- [App Store](https://apps.apple.com/kr/app/id6757733720) -- [GitHub](https://github.com/kswift1/Promiso)*
