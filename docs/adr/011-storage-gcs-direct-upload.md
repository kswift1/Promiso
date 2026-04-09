# ADR-011: Big-bang 스토리지 전환은 GCS direct + Presigned Upload로 간다

## 상태

확정

## 맥락

이번 인증 전환 이후에는 legacy backend Firebase 흔적에서 `Auth/Firestore/Functions/Storage/Remote Config`를 제거한다.

따라서 기존 `iOS -> Firebase Storage 업로드 -> Firebase Functions가 URL 생성` 경로는 유지할 수 없다.

현재 제약:

- 서버/DB는 이미 Cloud Run + Cloud SQL 중심으로 운영한다.
- FCM 전송 때문에 Rust 서버는 이미 Google service account credential을 사용한다.
- 기존 이미지 URL은 `storage.googleapis.com` / `firebasestorage.googleapis.com` 계열이 많다.
- 앱 이미지 캐시 로직도 Google Storage URL 패턴에 맞춰져 있다.
- 이번 전환은 big-bang cutover라서 스토리지 선택이 배포 리스크를 크게 좌우한다.

즉, 이번 결정은 "장기적으로 가장 예쁜 스토리지"보다 "이번 cutover를 가장 안정적으로 통과시키는 스토리지"가 더 중요하다.

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 스케일 비용 | 중간 | 저장 용량/egress 증가 시 비용 구조 |
| 확장성 | 중간 | 이미지 타입 증가, 대용량 업로드, CDN 연계 용이성 |
| 안정성 | 높음 | big-bang cutover 난이도, 기존 이미지 호환성, 운영 단순성 |
| 락인 | 중간 | 특정 클라우드 종속 정도 |
| 성능 | 중간 | 업로드/다운로드 지연, 서버 우회 여부 |
| 안전성 | 높음 | presigned URL 범위, 파일 경로 통제, 서버 과부하 방지 |

## 비교

| 기준 | GCS direct + Presigned Upload | S3-compatible + Presigned Upload | Rust Relay Upload |
|------|-------------------------------|----------------------------------|-------------------|
| 스케일 비용 | 중간 — GCP 안에서 단순, 서버 중계 없음 | 중하 — provider 선택 폭 넓음 | 높음 — 서버 대역폭/메모리 비용 증가 |
| 확장성 | 높음 — presigned upload/download 패턴으로 충분 | 높음 — 멀티클라우드/스토리지 교체 유연 | 중간 — 업로드 트래픽이 서버 병목 |
| 안정성 | 높음 — 현재 URL/인프라와 가장 가깝고 cutover 리스크 최소 | 중간상 — 새 provider, 새 URL 정책, 기존 자산 이동 부담 | 중간 — 구현은 단순해 보여도 운영 부담 큼 |
| 락인 | 중상 — GCP 종속 유지 | 낮음 — 벤더 종속 최소 | 중간 — 서버와 저장소가 더 강하게 결합 |
| 성능 | 높음 — 앱이 저장소에 직접 업로드 | 높음 — 앱 직접 업로드 | 중하 — 이미지가 Rust 서버를 한 번 거침 |
| 안전성 | 높음 — 짧은 만료의 presigned URL, 경로 제어 가능 | 높음 — presigned URL 자체는 동일하게 안전 | 중상 — 서버 검증은 쉽지만 과부하/실수 범위가 큼 |

## 결정

**스토리지는 Firebase Storage를 버리고 GCS bucket direct + presigned upload 방식으로 전환한다.**

구체 원칙:

- Rust 서버가 업로드 대상 object key를 결정한다.
- Rust 서버가 짧은 만료 시간의 presigned upload URL을 발급한다.
- iOS 앱은 이미지를 저장소에 직접 업로드하고, 완료 후 object URL 또는 object key를 Rust API에 전달한다.
- 앱이 사용하는 이미지 주소는 장기적으로 `externalURL` 중심으로 통일한다.
- 기존 Firebase Storage 자산은 가능한 범위에서 동일 GCS 자산을 직접 참조하거나, 필요 시 별도 배치 이전으로 다룬다.
- Rust 서버는 이미지 파일 바이트를 중계하지 않는다.

이 결정을 선택한 이유:

- 현재 인프라가 이미 GCP를 기반으로 하고 있어, 이번 배포의 위험을 최소화할 수 있다.
- FCM 때문에 쓰는 Google credential 체계를 재활용할 수 있다.
- 기존 Google Storage URL과 앱 캐시 동작을 가장 적게 흔든다.
- 이번 목적은 "GCP 탈출"이 아니라 "legacy backend Firebase 제거"이기 때문이다.

즉, 이번 단계에서는 storage를 Firebase 제품군 밖으로 빼내되, cloud 자체까지 동시에 갈아엎지는 않는다.

## 결과

이 결정으로 인해:

- **얻는 것**:
  - Firebase Storage 의존을 제거하면서도 big-bang cutover 리스크를 가장 낮게 유지할 수 있다
  - 이미지 업로드가 서버를 거치지 않아 성능과 서버 비용 면에서 유리하다
  - 기존 Google Storage URL, 캐시 정책, 운영 credential과의 정합성이 가장 높다
- **잃는 것**:
  - GCP 락인은 남는다
  - presigned upload 발급 API, 업로드 완료 후 메타데이터 저장 플로우를 새로 구현해야 한다
- **후속 결정**:
  - 업로드 object key 규칙 (`profile_images/...`, `group_images/...`, `schedule_images/...`)
  - 공개 URL 전략 (`storage.googleapis.com` 직접 공개 vs CDN 도메인)
  - 기존 Firebase Storage 자산의 이전/호환 정책
