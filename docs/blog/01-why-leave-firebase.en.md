# From Firebase to Rust — Why I'm Leaving Firebase

*An iOS App Server Migration #1 — Motivation, Tech Choices, and Migration Strategy*

---

"Creating a schedule feels kind of slow."

Reading that user feedback, I thought to myself: I know. It's the Cloud Functions cold start. When there's no traffic for a while, the instance spins down. The next request has to spin up a new one, and that takes seconds. A TypeScript function cold-starting in the Seoul region (asia-northeast3) takes 1 to 5 seconds. That's how long a user stares at a loading spinner after tapping "Create."

Can I fix this? Not really — not within Firebase. Setting min_instances keeps instances alive, but applying that across 50+ functions would blow up the bill. So I convinced myself it was "just a Firebase limitation" and moved on.

---

## The Limits of Firebase

Promiso is a group-based scheduling iOS app. You create groups with friends, make plans, vote on them, and share locations. The entire thing runs on Firebase:

- **Firebase Auth** — Apple/Google sign-in
- **Firestore** — Main database (12+ collections)
- **Cloud Functions** — Business logic, 50+ functions (TypeScript)
- **Firebase Storage** — Profile/group/event images
- **FCM** — Push notifications
- **Analytics, Crashlytics** — Monitoring

This isn't calling one Cloud Function. **The entire backend is Firebase.**

Cold starts weren't the only problem.

**Cost**: Firestore charges per read/write. For an app with many real-time listeners, costs grow faster than linearly with user count. PostgreSQL has fixed costs. Predictable and more efficient at scale.

**Scalability**: Firestore has a 1-write-per-second limit per document. No JOINs. So you have to denormalize — copy the same data to multiple places — and maintaining that is a nightmare. What takes one JOIN in SQL requires triggers and sync logic in Firestore.

**Lock-in**: Auth, Firestore, Functions, Storage — all Firebase. If pricing changes? If there's an outage? No alternatives.

---

## Build My Own Server?

I get the limitations. But build my own server? I'm an iOS developer with two years of Swift experience. The server has always been Firebase's job. Building my own backend was a different universe.

Rust was a language I vaguely wanted to try someday. The ownership system, memory safety without a GC, C-level performance with modern syntax. I was curious, but never seriously considered it. Learning Rust while building an iOS app? Too much to take on.

Then AI changed that calculation entirely.

---

## AI Changed How We Choose Tech

When you code with an AI like Claude, the meaning of "learning curve" shifts. You don't need to memorize syntax. You don't need to internalize patterns one by one. **You just need to understand.** If you know *why* something works the way it does, AI handles the implementation. The "Google → Stack Overflow → copy → tweak" cycle that even 10-year veterans go through with a new language? Gone.

This isn't just about convenience. **It means the criteria for choosing technology fundamentally change.**

When picking a tech stack, people usually look at:

- Is it easy to learn?
- Are there enough references?
- Is the community active?
- How fast can I ship?

What do these criteria have in common? They all assume **a human is writing the code.** When AI becomes your coding partner, these criteria lose most of their weight.

So what's left? The pure fundamentals of the technology itself:

1. **Cost at scale** — How much does it cost per user as you grow?
2. **Scalability** — Can it handle 100x traffic without a rewrite?
3. **Reliability** — How often does it break, and how fast can it recover?
4. **Lock-in** — Can you switch to something else later?
5. **Performance** — How fast does it handle a single request?
6. **Safety** — How many bugs does it catch before production?

---

## Rust vs Go vs TypeScript

The current backend is TypeScript (Cloud Functions). If I'm moving to my own server, there were three candidates.

| Criteria | Rust | Go | TypeScript |
|----------|------|-----|-----------|
| Cost at scale | **Best** — No GC, extreme memory efficiency | Good — GC but lightweight | Average — V8 overhead |
| Scalability | High — tokio async + multithreading | High — goroutines | High — but weak on CPU-bound work |
| Reliability | **Best** — If it compiles, runtime errors are rare | Good — simple but nil panics possible | Average — runtime type errors |
| Lock-in | None — native binary | None | Firebase-dependent (currently) |
| Performance | **Best** — On par with C/C++ | Good | Average |
| Safety | **Best** — Ownership system prevents data races at compile time | Good | Weak |

Go is a perfectly good choice. But Go's biggest strength — "easy to pick up and use right away" — becomes achievable with Rust too when you have AI. Given that premise, there was no reason not to choose Rust, which leads in both performance and safety.

And honestly? I just wanted to use Rust. I'd had this vague fascination with the language, and I figured if not now, when? The comparison table backs up the decision, but the starting point was a personal desire to build something with this language.

> There's always emotion in a tech decision. What matters is starting with emotion but validating with evidence.

---

## How to Migrate — The Strategy

Deciding to leave Firebase is one thing. How do you safely migrate a live service? That's the real problem.

At first I thought big bang — build everything, switch all at once. But if something breaks on launch day? Every live user is affected. Rollback isn't easy either.

Fortunately, the iOS app's architecture had the answer.

### Branch by Abstraction

The app uses TCA (The Composable Architecture). The key insight: **every backend call goes through a Client abstraction layer.** Features never call Firebase directly. They always go through a Client.

This means I can change *where* the Client sends requests:

```swift
createGroup: { group in
    if FeatureFlags.useRustAPI(.groups) {
        // New Rust API
        return try await apiClient.post("/groups", body: group)
    } else {
        // Existing Firebase
        return try await functions.httpsCallable("createGroup").call(data)
    }
}
```

The Feature layer code **doesn't change at all.** Just flip the flag.

> Develop like a big bang, but switch gradually. Get both speed and safety.

### Dev → Stage → Prod

The app has three environments: Dev, Stage, and Prod. I use them in sequence:

```
1) Turn on Feature Flag in Dev, test the Rust API
2) If stable, expand to Stage
3) If Stage is solid, switch Prod
```

If something goes wrong at any step, just turn off the flag and instantly fall back to Firebase.

### TDD as a Safety Net

The scariest part of migration is "something that worked on Firebase doesn't work on Rust." To prevent this, I apply TDD.

Extract business rules from Firebase Functions code, then **write Rust tests first.** Start with all tests failing (Red), then make them pass one by one as I implement (Green).

```
Extract rules from Firebase code
  → "Only the host can delete a group"
  → "The host can't leave (must transfer first)"
  → "Invite codes are 6 characters, unique per group"
    ↓
Convert to Rust tests (before implementation)
    ↓
Implement until tests pass
```

This way, every rule that worked in Firebase is guaranteed to work in Rust.

---

## Working with AI

This migration uses Claude Code. Role-based agents handle code exploration, Rust implementation, Swift implementation, and review. For each domain I migrate, I repeat the same workflow. My role is **deciding and verifying** — I review what agents analyze, make judgments from comparison tables, and confirm the final results.

Every tech decision is recorded as an ADR (Architecture Decision Record). The "Rust vs Go vs TypeScript" table in this post came from an ADR. The detailed workflow will unfold naturally as the series progresses.

---

When the learning curve disappears, the criteria for choosing tech change. You stop asking "is it easy to learn?" and start asking "is it fundamentally better?" I answered that question with Rust.

This series is the process of proving whether that answer was right.

---

*Next: #2 Building the Server Skeleton — Axum + SQLx + PostgreSQL Environment Setup*
