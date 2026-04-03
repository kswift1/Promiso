# Firebase에서 Rust로 — 서버 뼈대 잡기

*iOS 앱 서버 마이그레이션기 #2 — 인프라 선택부터 Axum + SQLx 환경 구축까지*

---

Rust로 가겠다고 결심한 건 좋았는데, 실제로 서버를 띄우려면 결정할 게 산더미다. DB는 어디에 둘 건지, 서버는 어디서 돌릴 건지, 인증은 어떻게 할 건지. Firebase에서는 이런 고민을 할 필요가 없었다. 전부 Firebase가 해줬으니까.

이제 직접 골라야 한다. 단, 전부 동시에 해결할 필요는 없다. 이 글의 결정들은 *지금 도메인 마이그레이션을 시작할 수 있는 최소한의 조합*을 찾는 과정이다. 최종 아키텍처가 아니라 Phase 1 최솟값.

---

## 네 가지 결정

"Rust 서버"라는 한 줄 뒤에는 네 가지 결정이 숨어있다.

1. 서버를 어디서 돌릴 것인가 — 호스팅
2. 데이터를 어디에 저장할 것인가 — 데이터베이스
3. 유저를 어떻게 인증할 것인가 — 인증
4. 이미지를 어디에 저장할 것인가 — 스토리지

전부 한 번에 결정하려니 막막했다. 그래서 하나씩 좁혀갔다.

---

## 서버: Cloud Run

후보는 네 개였다. Cloud Run, Fly.io, Railway, Render.

처음에는 Fly.io를 유력하게 봤다. WebSocket 제한이 없어서 LiveActivity 실시간 업데이트에 좋겠다 싶었다. 그런데 앱의 LiveActivity가 APNs 기반이라는 걸 깨달았다. WebSocket을 쓰지 않는다. Fly.io의 가장 큰 장점이 의미가 없어진 거다.

기준을 다시 세웠다. 혼자 개발하니까 가장 중요한 건 **"얼마나 신경 안 쓰고 개발할 수 있냐"**와 **레이턴시**다. 한국 사용자 대상 서비스니까 서울 리전이 있는지가 결정적이다.

| | Cloud Run | Fly.io | Railway |
|--|-----------|--------|---------|
| 한국 레이턴시 | 약 5ms (서울) | 약 30ms (도쿄) | 약 80ms (싱가포르) |
| 비용 (초기) | $0 (scale-to-zero) | 약 $4/월 | 약 $5/월 |
| 배포 | Docker + gcloud deploy | Dockerfile + flyctl | git push |

Railway는 git push만 하면 배포가 끝나서 DX가 압도적이다. 솔직히 끌렸다. 하지만 서울 리전이 없다는 게 발목을 잡았다.

Cloud Run은 scale-to-zero라 콜드스타트가 있다. 1편에서 Firebase를 버리게 만든 게 바로 그 콜드스타트였는데, 같은 문제를 안고 가는 거 아닌가 싶었다.

근데 달랐다. Node.js는 콜드스타트할 때 V8 엔진을 초기화하고, 모듈을 로드하고, JIT 워밍업을 거친다. 그게 1~5초다. Rust는 컴파일 타임에 이미 네이티브 바이너리가 된다. 별도 런타임이 없다. OS가 바이너리를 메모리에 올리면 끝이다. 내 환경에서 100ms 이내.

콜드스타트를 아예 없앨 수도 있었다. Cloud Run은 `min-instances=1`로 인스턴스를 항상 켜둘 수 있다. 1편에서 Firebase도 같은 옵션이 있었는데, 50개가 넘는 함수에 적용하면 비용이 급증했다. Cloud Run은 서버가 하나라 min-instances=1이어도 비용이 예측 가능하다. 하지만 지금은 트래픽이 없는 초기 단계다. 굳이 돈을 낼 이유가 없다. 트래픽이 생기면 그때 올리면 된다.

결국 **서울 리전 + 비용 0**인 Cloud Run을 선택했다.

---

## 데이터베이스: Cloud SQL + Neon

PostgreSQL은 이미 정해져 있었다. 문제는 어디에 호스팅할 것인가.

후보: Neon(서버리스), Supabase, Cloud SQL, Railway PG.

처음에는 Neon 하나로 개발과 프로덕션 모두 커버하려 했다. 무료 티어가 관대하고 scale-to-zero라 쓰지 않으면 비용이 0이다. 문제는 **아시아 리전이 싱가포르뿐**이라는 것. Cloud Run이 서울인데 DB가 싱가포르면 쿼리마다 약 70ms가 붙는다. API 하나에 쿼리 3–4개면 200ms 넘게 누적된다.

그러다 환경별로 요구사항이 다르다는 걸 깨달았다.

| | Prod | Dev |
|--|------|-----|
| 최우선 | 레이턴시, 안정성 | 비용 $0, 실험 편의 |
| 레이턴시 | 중요 | 무관 |

**Prod은 Cloud SQL(서울), Dev는 Neon(싱가포르).**

Cloud SQL은 Cloud Run과 같은 GCP 프로젝트 안에서 VPC로 연결된다. 서버-DB 레이턴시가 약 1ms. 자동 백업, 자동 패치. Neon의 Dev 환경에서 70ms가 붙어도 실질적인 지장은 없다.

코드에서는 환경변수 하나만 바꾸면 된다:

```bash
# Dev
DATABASE_URL=postgresql://user:pass@neon-singapore/promiso

# Prod
DATABASE_URL=postgresql://user:pass@/promiso?host=/cloudsql/project:seoul:db
```

SQLx는 `DATABASE_URL`만 보고 연결하니까 코드 변경 없이 환경 전환이 된다.

---

## 인증과 스토리지: 일단 Firebase 유지

인증과 스토리지는 "지금 바꿀 필요가 있는가?"를 먼저 물었다.

iOS 앱이 이미 Firebase Auth로 로그인하고, Firebase Storage에 이미지를 올리고 있다. 이걸 지금 바꾸면:

- 인증: Apple/Google OAuth 직접 구현 + JWT 발급 시스템 + iOS 전체 인증 흐름 변경
- 스토리지: 기존 이미지 전체 마이그레이션 + 업로드/다운로드 로직 교체

도메인 마이그레이션도 시작 못 한 상태에서 이런 인프라 작업을 같이 하면 끝이 없다.

Rust 서버는 iOS가 보내는 Firebase ID 토큰을 **검증만 하면 된다**. Google 공개 키로 서명 확인하고, uid와 email을 꺼내서 요청에 붙이면 끝. 기존 로그인 플로우를 건드릴 필요가 없다.

```
iOS 앱 → Firebase Auth 로그인 (기존 그대로)
  → Firebase ID 토큰 발급
    → Rust 서버로 API 호출 (Bearer 토큰)
      → Rust가 토큰 검증 + uid 추출
```

스토리지는 인증보다 더 단순하다. 인증은 Rust가 토큰을 직접 검증해야 하니 인터페이스를 바꿔야 하지만, 스토리지는 그렇지 않다. iOS가 Firebase Storage에 이미지를 올리고 경로만 Rust에 알려주면 되니까, Rust는 URL 문자열을 저장할 뿐이다. 기존 유저들의 이미지 데이터도 건드릴 필요가 없다.

**바꿀 이유가 없는 것은 바꾸지 않는다.** 토큰 검증의 구체적인 구현 — Google 공개 키 캐싱, RS256 서명 검증, 클레임 추출 — 은 다음 글에서 Users 도메인을 올리면서 다룬다.

---

## Axum + SQLx: 서버 뼈대

결정이 끝났으니 실제로 코드를 만들 차례다. Rust 웹 프레임워크로 Axum, DB 라이브러리로 SQLx를 선택했다.

프로젝트 구조:

```
infra/rust-backend/
├── src/
│   ├── main.rs           # 서버 부팅
│   ├── config/           # 환경 설정
│   ├── routes/           # HTTP 핸들러
│   ├── services/         # 비즈니스 로직
│   ├── models/           # 데이터 구조체
│   ├── middleware/        # 인증
│   └── errors/           # 에러 처리
├── migrations/           # DB 스키마
└── Dockerfile            # Cloud Run 배포용
```

Swift 개발자 입장에서 익숙하게 느껴지는 구조다. TCA 프로젝트의 Feature/Client/Model 레이어와 비슷하다.

`main.rs`에서 DB 풀을 만들고, Axum Router에 연결하는 게 부팅의 전부다:

```rust
#[tokio::main]  // Swift의 @main과 비슷하다 — async main 진입점
async fn main() {
    let pool = PgPoolOptions::new()
        .connect(&env::var("DATABASE_URL").unwrap())
        .await
        .expect("DB 연결 실패");

    let app = Router::new()
        .route("/health", get(health_check))
        .with_state(pool);  // pool을 모든 핸들러에 주입 — Swift의 @Dependency와 비슷하다

    let listener = TcpListener::bind("0.0.0.0:8080").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

health check 하나로 전체가 연결되는지 확인했다:

```rust
async fn health_check(State(pool): State<PgPool>) -> Json<Value> {
    let db_ok = sqlx::query("SELECT 1")
        .execute(&pool)
        .await      // Swift: await foo() / Rust: foo().await — 위치가 반대다
        .is_ok();

    Json(json!({
        "status": if db_ok { "healthy" } else { "degraded" },
        "db": db_ok,
    }))
}
```

`cargo run` → `curl localhost:8080/health` → `{"status":"healthy","db":true}`.

Neon Singapore DB에 연결되고, health check가 응답한다. 뼈대가 섰다.

---

## 삽질: iOS 시뮬레이터가 localhost를 못 찾는다

서버를 띄우고 시뮬레이터에서 호출했더니 연결이 안 됐다.

```
Error Domain=NSURLErrorDomain Code=-1004 "서버에 연결할 수 없습니다."
```

`curl localhost:8080/health`은 잘 되는데, 시뮬레이터에서만 안 된다.

순서대로 삽질했다. ATS(App Transport Security) 설정을 풀었다 — 안 됐다. `localhost`를 `127.0.0.1`로 바꿨다 — 안 됐다. IPv6까지 지원하도록 서버 바인딩 주소를 `[::]`로 바꿨다 — 안 됐다.

결국 Mac의 LAN IP(`192.168.x.x`)를 직접 넣으니 연결됐다. 내 환경에서는 iOS 26 시뮬레이터가 loopback 인터페이스를 제대로 못 타는 것 같았다. 깔끔한 해결은 아니지만, 로컬 개발 단계에서는 이걸로 충분하다. Cloud Run에 배포하면 어차피 실제 URL을 쓰게 된다.

---

## Firebase의 에러 코드, Rust에서 살리기

Firebase Functions에서는 에러를 이렇게 던진다:

```typescript
throw new HttpsError("not-found", "사용자를 찾을 수 없습니다");
throw new HttpsError("permission-denied", "권한이 없습니다");
```

iOS 앱이 이 에러 코드(`not-found`, `permission-denied`)에 맞춰 처리하고 있다. Rust로 옮겨도 같은 코드를 내려줘야 한다.

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
// Swift의 Error enum과 같은 구조 — case마다 연관값(String)을 가진다
```

각 variant가 HTTP 상태 코드와 Firebase 에러 코드에 매핑된다. Internal 에러만 클라이언트에 상세 메시지를 숨기고 로그에만 기록한다.

---

## 뼈대의 의미

이번 글에서 결정한 스택:
- **서버**: Cloud Run (서울 리전)
- **DB**: Cloud SQL / Prod + Neon / Dev
- **인증**: Firebase Auth 유지 (토큰 검증만)
- **스토리지**: Firebase Storage 유지 (경로만 Rust로)

Firebase에서는 `firebase init functions` 하면 끝이었다. 직접 서버를 만든다는 건 모든 걸 하나씩 결정하고, 하나씩 만든다는 뜻이다. 귀찮다. 하지만 선택할 수 있다는 건 최적화할 수 있다는 뜻이기도 하다. 서울 리전, 1ms DB, 개발 비용 0 — Firebase에서는 불가능했던 조합이 가능해졌다.

이제 이 뼈대 위에 첫 번째 도메인을 올릴 차례다.

*다음 글: #3 첫 번째 도메인 — Firestore 유저를 PostgreSQL로*

*Promiso — [App Store](https://apps.apple.com/kr/app/id6757733720) · [GitHub](https://github.com/kswift1/Promiso)*
