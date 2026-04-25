# From Firebase to Rust — Group API: Firestore to PostgreSQL

*An iOS App Server Migration #3 — From Denormalization to Normalization*

---

The first time I realized creating a group meant writing data to two separate places, something felt off.

In Firestore, group data lives in two locations. The `groups/{groupId}` document holds the group's basic info:

```json
{
  "name": "Weekend Hiking Group",
  "memberIds": ["user_A", "user_B", "user_C"],
  "createdBy": "user_A",
  "maxMembers": 10,
  "inviteCode": "AB12CD",
  "imageUrl": "https://storage.googleapis.com/..."
}
```

Then the group name and image get copied into `users/{uid}.groups`, along with per-member data like role and notification settings:

```json
{
  "groups": {
    "group_123": {
      "groupName": "Weekend Hiking Group",
      "role": "admin",
      "imageUrl": "https://storage.googleapis.com/...",
      "hasNewActivity": false,
      "notifications": { "enabled": true, "promise": { ... }, "group": { ... } }
    }
  }
}
```

Why this structure? Firestore doesn't support JOINs like SQL. To show "groups I belong to," you either scan every group document or pre-copy the data into the user document. Since Firestore charges per document read, reading one user document that contains the entire group list is faster and cheaper. Optimized for reads, it made sense.

The cost shows up on writes. Group name and image URL exist in both places, so every change requires syncing. When an image changes, the `onGroupImageUpdated` trigger updates every member's copy. When someone joins, both `groups.memberIds` and `users.groups` need updating. I've actually seen this sync break. A user changed their group image, but the old one kept showing in the list. The trigger had lagged. The fix was easy, but the real problem was knowing the same structural issue could repeat for names, membership, anything.

Moving to PostgreSQL, there was no reason to carry this structure over. PostgreSQL has JOINs. One join table gets the same result without copies, and no sync triggers needed. Firestore's denormalization was accidental complexity born from Firestore's constraints — not something inherent to the group domain. Instead of a 1:1 port, I redesigned for PostgreSQL.

---

## PostgreSQL Group Schema

The redesigned schema is two tables: `groups` and `group_members`.

```sql
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  max_members SMALLINT NOT NULL DEFAULT 10,
  invite_code CHAR(6) NOT NULL,
  last_activity_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_group_name_len
    CHECK (char_length(name) BETWEEN 2 AND 12),
  CONSTRAINT chk_group_max_members
    CHECK (max_members BETWEEN 2 AND 10)
);

CREATE TABLE group_members (
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  role group_member_role NOT NULL DEFAULT 'member',
  group_color TEXT NOT NULL DEFAULT '#AF52DE',
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  -- ... notification setting fields ...
  calendar_sync BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);
```

There are many changes, but one principle runs through all of them: store data in one place, combine with JOINs when needed.

The biggest change is eliminating the `createdBy` column. In Firestore, the group document had a `createdBy` field to identify the host. The problem was host transfer. After a transfer, the "creator" and the "current host" diverge. Different parts of the code would disagree on who the real host was. In PostgreSQL, the row in `group_members` with `role = 'admin'` is the host. Transferring means swapping the role, and the rule "exactly one admin per group" is enforced by the database itself.

```sql
CREATE UNIQUE INDEX uq_group_members_single_admin
  ON group_members (group_id)
  WHERE role = 'admin';
```

Notification settings also changed structurally. Users can toggle which push notifications they receive per group — schedule invitations, reminders, confirmations, cancellations, eight items individually. In Firestore, these were stored as nested Maps (`notifications.promise.invitation`), with legacy and new formats coexisting, making parsing painful. In PostgreSQL, they're flat boolean columns: `notifications_enabled`, `schedule_invitation`, `group_update`, and so on. Since the number of toggles is fixed, NOT NULL + DEFAULT eliminates the possibility of empty states entirely.

The "unread activity" badge on the group list also works differently now. In Firestore, when a new schedule was created, a trigger would flip `hasNewActivity` to `true` for every member. When the user opened the group, it flipped back to `false`. One boolean written to N user documents. In PostgreSQL, nothing is stored — it's computed. If `groups.last_activity_at > group_members.last_read_at`, there's new activity. The entire codebase for manually managing that flag is gone.

Membership management is handled entirely by the `group_members` join table. No `memberIds` array, no `users.groups` Map. Deleting a group triggers `ON DELETE CASCADE` to clean up members automatically. The code that used to delete Map keys one member at a time is no longer needed.

| Aspect | Firestore | PostgreSQL |
|--------|-----------|------------|
| Membership | `memberIds` array + `users.groups` Map | `group_members` join table |
| Host identification | `createdBy` field | `role = 'admin'` |
| Notification settings | Nested Map (legacy + new) | Explicit boolean columns |
| New activity indicator | `hasNewActivity` flag | Timestamp comparison |
| Image sync | Trigger updates copies | JOIN (no triggers) |
| Group deletion | Manual per-member cleanup | `ON DELETE CASCADE` |

---

## Code: Before and After

Two comparisons where the difference is most dramatic.

### Creating a Group

In Firebase, you have to write the group document and the user document separately. Two writes, two locations.

```typescript
// Firebase: create group — writes to two places
await groupRef.set({
  name: data.name,
  memberIds: [creatorId],
  createdBy: creatorId,
  inviteCode, maxMembers: data.maxMembers,
});

await usersCollection.doc(creatorId).set({
  groups: { [groupId]: { groupName: data.name, role: "admin", ... } }
}, { merge: true });
```

In Rust, a single transaction wraps both the `groups` INSERT and the `group_members` INSERT. Data exists in one place only.

```rust
// pool.begin() — similar to Swift's Firestore runTransaction,
// but works across any table. Auto-rollback on failure.
let mut tx = pool.begin().await?;

// INSERT ... RETURNING * — a pattern Swift doesn't have.
// INSERT and get back DB-generated UUID, created_at, etc. in one shot.
let group = sqlx::query_as::<_, Group>(
    "INSERT INTO groups (name, description, max_members, invite_code)
     VALUES ($1, $2, $3, $4) RETURNING *"
)
.bind(&name).bind(&description)
.bind(max_members).bind(&invite_code)
.fetch_one(&mut *tx).await?; // ? — equivalent to Swift's try

// Instead of a createdBy field, role = 'admin' represents the host
sqlx::query(
    "INSERT INTO group_members (group_id, user_id, role)
     VALUES ($1, $2, 'admin')"
)
.bind(group.id).bind(creator_uid)
.execute(&mut *tx).await?;

tx.commit().await?;
```

### Listing My Groups

In Firebase, you read the `groups` Map from the user document. That's the payoff of denormalization — one read gets all group info. But what's stored there is a copy. If the group name or image changed and the trigger failed, you see stale data.

In Rust, it's a single JOIN query.

```rust
// JOIN — something Firestore doesn't have. Combines two tables in one query.
// Think of it as fetchGroups + fetchGroupMembers in a single call.
let rows = sqlx::query_as::<_, _>(
    "SELECT g.id, g.name, g.image_url, g.max_members,
            gm.role::TEXT, gm.group_color,
            g.last_activity_at, gm.last_read_at,
            -- Subquery grabs the member count too. No separate COUNT call needed.
            (SELECT COUNT(*) FROM group_members
             WHERE group_id = g.id) AS member_count
     FROM group_members gm
     JOIN groups g ON gm.group_id = g.id
     WHERE gm.user_id = $1
     ORDER BY gm.joined_at DESC"
)
.bind(user_uid)
.fetch_all(pool).await?; // fetch_all — like returning [Model] in Swift
```

You're reading the original, not a copy. Sync lag is structurally impossible. One query returns group info, membership data, and member count all at once. The N+1 problem of calling `fetchGroupMembers` once per group in Firestore is gone too.

---

## What I Discovered While Building This

As planned in the first post, I extracted business rules and wrote Rust tests first. 65 of them. I worked with Claude Code from schema design through implementation. Getting the tests to pass wasn't hard. The problems came after. When I ran a code review with Codex, blind spots started showing up.

When creating a group, an invite code is generated, and it has a unique constraint. Between generating the code and INSERT-ing the group, another request could INSERT with the same code and cause a conflict. Initially, these two steps weren't even in the same transaction. If the group INSERT succeeded but the member INSERT failed, an orphaned group with no admin would sit in the database.

A similar issue existed in group joining. If two people simultaneously request to join a group at 9/10 capacity, both pass the "still room" check and you end up at 11/10 — a classic race condition. And the initial implementation had an N+1 query counting members separately for each group in the list.

How did Firebase handle these issues? Honestly, it didn't — not properly. Firestore transactions are scoped to individual documents, making atomic updates across multiple collections difficult. Between batch limits of 500 operations and trigger timing issues, I was essentially relying on "it works most of the time."

In PostgreSQL, transactions don't care about table boundaries. Wrap `groups` and `group_members` in one transaction and everything either commits or rolls back together. Check capacity and INSERT inside the same transaction for group joining, and the race condition disappears.

---

## What Got Removed

Here's everything that was eliminated in this migration:

- `onGroupImageUpdated` trigger — replaced by JOIN
- The entire `users.groups` Map — consolidated into `group_members` table
- `groups.memberIds` array — replaced by the same table
- `createdBy` field — unified into `role = 'admin'`
- Manual `hasNewActivity` boolean management — replaced by timestamp comparison
- Legacy/new dual format for notification settings — single boolean columns
- Firestore batch 500-operation limit workaround code — unnecessary in PostgreSQL
- Client-side groupId generation + duplicate checks — server-side UUID generation
- Per-plan `maxMembers` branching (Free: 10, Pro: 30) — uniform 10

Sync triggers gone. Manual flag management gone. Legacy compatibility code gone. What's left is just the business rules.

---

## Wrapping Up

Moving from a document DB to a relational DB isn't about copying the schema. It's about separating "things we had to add because of platform constraints" from "things we need because of business rules."

Firestore's denormalization made sense inside Firestore. Bring it to PostgreSQL and the rationale evaporates. JOINs mean no copying. Cross-table transactions mean no sync triggers.

Of the 26 fixes in this migration, half were removing these artifacts of structural constraints. The other half were bug fixes, security hardening, and legacy cleanup. In the end, migration isn't copying — it's reinterpretation. Which rules are essential and which are accidental? Changing the database makes that visible.

*Next: #4 Schedule API — Voting, Confirmation, and Recurring Schedules*

*Promiso — [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
