# From Firebase to Rust — Building the Server Skeleton

*iOS App Server Migration #2 — From infrastructure decisions to Axum + SQLx setup*

---

Deciding to go with Rust was the easy part. Actually spinning up a server meant a pile of decisions. Where does the DB go? Where does the server run? How do I handle auth? With Firebase, none of this was my problem. Firebase handled everything.

Now I have to choose. But not everything at once. Every decision in this post is about finding *the minimum viable combination to start migrating domains right now* — not a final architecture, just Phase 1.

---

## Four Decisions

Behind the simple phrase "Rust server" are four decisions hiding in plain sight.

1. Where to run the server — hosting
2. Where to store data — database
3. How to authenticate users — auth
4. Where to store images — storage

Trying to decide everything at once felt overwhelming. So I narrowed them down one by one.

---

## Server: Cloud Run

Four candidates. Cloud Run, Fly.io, Railway, Render.

I initially leaned toward Fly.io. No WebSocket limits — great for LiveActivity real-time updates. Then I realized the app's LiveActivity runs on APNs, not WebSocket. Fly.io's biggest advantage became irrelevant.

I reset my criteria. As a solo developer, what matters most is **"how little do I need to think about infrastructure"** and **latency**. The app targets Korean users, so having a Seoul region is decisive.

| | Cloud Run | Fly.io | Railway |
|--|-----------|--------|---------|
| Korea latency | ~5ms (Seoul) | ~30ms (Tokyo) | ~80ms (Singapore) |
| Cost (initial) | $0 (scale-to-zero) | ~$4/mo | ~$5/mo |
| Deploy | Docker + gcloud deploy | Dockerfile + flyctl | git push |

Railway's DX is unbeatable — just git push and you're deployed. I was genuinely tempted. But no Seoul region killed it.

Cloud Run uses scale-to-zero, which means cold starts. That's exactly what drove me away from Firebase in the first post — so was I just walking into the same problem?

Turns out, it wasn't the same kind of cold start. In the first post, Firebase Functions was cold-starting in 1–5 seconds. Cloud Run's own documentation explains part of why: dynamic languages like Node.js add module loading on top of container startup time. Rust, as a native binary, doesn't carry that overhead to the same degree. On my container, the added latency for the first request was under 100ms.

I could've eliminated cold starts entirely. `min-instances=1` keeps a warm instance always running. Firebase Functions had the same option — but costs stack per function, so with 50+ functions it got expensive fast. Cloud Run manages this at the service level, so the cost structure is much simpler. That said, there's no traffic to justify it right now. When there is, I'll flip it.

**Seoul region + zero cost.** Cloud Run it is.

---

## Database: Cloud SQL + Neon

PostgreSQL was already decided. The question was where to host it.

Candidates: Neon (serverless), Supabase, Cloud SQL, Railway PG.

I initially wanted Neon for everything — dev and production. Generous free tier, scale-to-zero, costs nothing when idle. The problem: **the closest Asian region is Singapore**. With Cloud Run in Seoul and the DB in Singapore, every query adds ~70ms. Three to four queries per API call, and you're looking at 200ms+ stacked.

Then I realized dev and production have different priorities.

| | Prod | Dev |
|--|------|-----|
| Priority | Latency, reliability | $0 cost, experimentation |
| Latency | Critical | Doesn't matter |

**Prod gets Cloud SQL (Seoul), Dev gets Neon (Singapore).**

Cloud SQL connects to Cloud Run via VPC within the same GCP project. Server-to-DB latency drops to ~1ms. Automatic backups, automatic patches. The 70ms overhead in Neon's dev environment? No meaningful impact while coding.

Switching between environments is just one environment variable:

```bash
# Dev
DATABASE_URL=postgresql://user:pass@neon-singapore/promiso

# Prod
DATABASE_URL=postgresql://user:pass@/promiso?host=/cloudsql/project:seoul:db
```

SQLx reads `DATABASE_URL` and connects. No code changes needed.

---

## Auth and Storage: Keep Firebase (For Now)

For auth and storage, I asked one question first: "Do I need to change this right now?"

The iOS app already uses Firebase Auth for login and Firebase Storage for images. Replacing them now means:

- Auth: Implement Apple/Google OAuth from scratch + JWT issuance + rewrite the entire iOS auth flow
- Storage: Migrate all existing images + replace upload/download logic

I haven't even started migrating domains. Piling infrastructure work on top would be endless.

The Rust server just needs to **verify Firebase ID tokens**. Check the signature against Google's public keys, extract uid and email, attach them to the request. The existing login flow stays untouched.

```
iOS app → Firebase Auth login (unchanged)
  → Firebase ID token issued
    → API call to Rust server (Bearer token)
      → Rust verifies token + extracts uid
```

Storage is even simpler than auth. Auth requires Rust to actively verify tokens — the interface has to change. Storage doesn't. iOS uploads to Firebase Storage, then tells Rust the file path. Rust just stores a URL string. Existing user images don't need to be touched.

**Don't change what doesn't need changing.** The specifics of token verification — Google public key caching, RS256 signature validation, claims extraction — come in the next post when I build the Users domain on top of this skeleton.

---

## Axum + SQLx: The Skeleton

With decisions made, it was time to write actual code. Axum for the web framework, SQLx for the database layer. The most widely used combo in the Rust ecosystem.

Project structure:

```
infra/rust-backend/
├── src/
│   ├── main.rs           # Server bootstrap
│   ├── config/           # Environment config
│   ├── routes/           # HTTP handlers
│   ├── services/         # Business logic
│   ├── models/           # Data structs
│   ├── middleware/        # Auth
│   └── errors/           # Error handling
├── migrations/           # DB schema
└── Dockerfile            # Cloud Run deployment
```

Feels familiar if you're a Swift developer. Similar to TCA's Feature/Client/Model layers.

`main.rs` creates the DB pool, wires it into the Axum router, and starts the server:

```rust
#[tokio::main]  // Like Swift's @main — the async entry point
async fn main() {
    let pool = PgPoolOptions::new()
        .connect(&env::var("DATABASE_URL").unwrap())
        .await
        .expect("DB connection failed");

    let app = Router::new()
        .route("/health", get(health_check))
        .with_state(pool);  // Injects pool into all handlers — like Swift's @Dependency

    let listener = TcpListener::bind("0.0.0.0:8080").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

I verified everything connects with a single health check endpoint:

```rust
async fn health_check(State(pool): State<PgPool>) -> Json<Value> {
    let db_ok = sqlx::query("SELECT 1")
        .execute(&pool)
        .await      // Swift: await foo() / Rust: foo().await — reversed order
        .is_ok();

    Json(json!({
        "status": if db_ok { "healthy" } else { "degraded" },
        "db": db_ok,
    }))
}
```

`cargo run` → `curl localhost:8080/health` → `{"status":"healthy","db":true}`.

Connected to Neon Singapore. Health check responds. The skeleton stands.

---

## Debugging: iOS Simulator Can't Reach localhost

Ran the server, called it from the simulator. Connection refused.

```
Error Domain=NSURLErrorDomain Code=-1004 "Could not connect to the server."
```

`curl localhost:8080/health` works fine from the terminal. Only the simulator can't reach it.

I tried everything in order. Disabled ATS (App Transport Security) — nope. Switched `localhost` to `127.0.0.1` — nope. Added IPv6 support by binding to `[::]` — nope.

Finally, using the Mac's LAN IP (`192.168.x.x`) directly worked. In my setup, the iOS 26 simulator didn't seem to properly route through the loopback interface. Not the cleanest fix, but fine for local development. Once deployed to Cloud Run, it'll use a real URL anyway.

---

## Preserving Firebase Error Codes in Rust

Firebase Functions throw errors like this:

```typescript
throw new HttpsError("not-found", "User not found");
throw new HttpsError("permission-denied", "Access denied");
```

The iOS app handles these error codes (`not-found`, `permission-denied`). Moving to Rust, I need to return the same codes.

```rust
pub enum AppError {
    Unauthorized(String),       // → 401, "unauthenticated"
    Forbidden(String),          // → 403, "permission-denied"
    NotFound(String),           // → 404, "not-found"
    BadRequest(String),         // → 400, "invalid-argument"
    Conflict(String),           // → 409, "already-exists"
    PreconditionFailed(String), // → 412, "failed-precondition"
    Internal(String),           // → 500, "internal"
}
// Same structure as Swift's Error enum — each case carries an associated String
```

Each variant maps to an HTTP status code and a Firebase error code. Only `Internal` hides the detailed message from the client and logs it server-side.

---

## What the Skeleton Means

The stack so far:
- **Server**: Cloud Run (Seoul region)
- **DB**: Cloud SQL / Prod + Neon / Dev
- **Auth**: Firebase Auth, kept (token verification only)
- **Storage**: Firebase Storage, kept (path stored in Rust)

With Firebase, `firebase init functions` was all you needed. Building your own server means deciding everything yourself, building everything yourself. It's tedious. But being able to choose means being able to optimize. Seoul region, 1ms database, zero dev costs — a combination impossible on Firebase.

Now it's time to put the first domain on this skeleton.

*Next: #3 The First Domain — Moving Firestore Users to PostgreSQL*

*Promiso — [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
