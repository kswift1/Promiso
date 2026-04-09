# ADR-010: Big-bang 인증 전환은 Provider 토큰 검증 + 서버 JWT + Refresh Session으로 간다

## 상태

확정

## 맥락

로드맵 `#7` 기준으로 인증 자체 구현 단계에 들어간다.

이번 전환은 점진 전환이 아니라 배포 시점 big-bang cutover다. 따라서 기존 Firebase Auth를 남겨 둔 dual-stack이나 bridge를 유지하지 않는다.

현재 제약:

- iOS는 Apple Sign In, Google Sign-In SDK를 이미 사용 중이다.
- Rust API는 현재 Firebase ID 토큰 검증을 전제로 한다.
- 기존 PostgreSQL `users.id`는 Firebase UID 문자열을 기준으로 다른 도메인 FK가 연결되어 있다.
- 앱은 시작 시 세션 복원, 신규 사용자 온보딩 분기, widget token 발급, 계정 삭제를 모두 인증 상태에 의존한다.

즉, 이번 결정은 "로그인만 어떻게 할지"가 아니라 API 인증, 세션 복원, 로그아웃, 기기별 세션 폐기까지 포함한다.

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 스케일 비용 | 중간 | 요청 수 증가 시 추가 비용과 서버 부담 |
| 확장성 | 높음 | Apple/Google 외 provider 추가, widget/session 관리 확장 용이성 |
| 안정성 | 높음 | 로그아웃, 세션 폐기, 장애 복구, 구버전 차단 용이성 |
| 락인 | 높음 | Firebase Auth 의존 제거, 특정 벤더 종속 최소화 |
| 성능 | 중간 | 요청당 DB hit, 토큰 검증 비용 |
| 안전성 | 높음 | 세션 탈취 완화, 토큰 폐기/회전, 구현 단순성으로 인한 오류 감소 |

## 비교

| 기준 | Provider 토큰 검증 + Access JWT + Refresh Session(DB) | Provider 토큰 검증 + Opaque Session Only | 서버 주도 OAuth Code Flow + PKCE |
|------|-------------------------------------------------------|-------------------------------------------|-----------------------------------|
| 스케일 비용 | 중간 — access token은 stateless, refresh 시에만 DB hit | 중간상 — 모든 API 호출이 세션 조회에 가까움 | 높음 — callback/session/PKCE 전체 운영 |
| 확장성 | 높음 — provider 추가, 기기별 세션, widget/auth 분리 자연스러움 | 중간 — session 기반 확장은 가능하나 widget/public token 모델이 무거움 | 높음 — 장기적으로 가장 표준적이지만 현재 구조와 거리 큼 |
| 안정성 | 높음 — access 만료 짧게, refresh 회전/폐기 가능 | 높음 — 강제 폐기는 쉽지만 세션 조회 병목 가능 | 중간 — iOS 리디렉션/브라우저 흐름 포함으로 표면 증가 |
| 락인 | 낮음 — Firebase Auth 제거, provider 표준 토큰 검증만 남음 | 낮음 — Firebase 제거 가능 | 낮음 — 가장 독립적이나 구현량 큼 |
| 성능 | 높음 — 일반 요청은 JWT 검증만 수행 | 중간 — 매 요청 session 확인 필요 | 높음 — 구현만 되면 좋지만 초기 오버헤드 큼 |
| 안전성 | 높음 — 짧은 access + 회전 가능한 refresh로 균형 좋음 | 중간상 — DB 세션만으로도 안전하나 토큰 경계가 덜 명확 | 높음 — 표준 흐름이지만 구현 리스크가 더 큼 |

## 결정

**Apple/Google provider 토큰을 Rust 서버에서 직접 검증하고, 서버가 `access JWT + refresh session`을 발급한다.**

구체 원칙:

- iOS는 Apple/Google native SDK를 계속 사용해 provider 토큰만 획득한다.
- Rust는 provider 토큰을 검증하고, 앱 내부 사용자 식별자는 기존 `users.id` 문자열을 유지한다.
- API 인증은 서버가 발급한 `Authorization: Bearer <access_jwt>`로 통일한다.
- refresh token은 DB의 `auth_sessions` 계열 테이블에 저장하고 회전 가능한 세션으로 관리한다.
- 로그아웃, 전 기기 로그아웃, 계정 삭제는 refresh session 폐기 중심으로 동작한다.
- widget token은 access JWT로 인증된 사용자에게만 발급한다.
- Firebase Auth 검증 미들웨어는 cutover 후 제거한다.

이 결정은 다음을 의미한다.

- 기존 [ADR-006](/Users/sungwon-kim/conductor/workspaces/promiso-v1/cairo-v1/docs/adr/006-auth-firebase-token-verification.md)는 전환 기간 결정이었고, big-bang cutover에는 더 이상 유효하지 않다.
- OAuth code flow를 서버 중심으로 다시 짜지는 않는다. 지금 앱이 이미 native provider SDK를 안정적으로 쓰고 있기 때문이다.
- 완전한 opaque session only 방식도 선택하지 않는다. 일반 API 요청에서 DB 의존을 줄이고, widget/public/private 토큰 경계를 명확히 하기 위해서다.

## 결과

이 결정으로 인해:

- **얻는 것**:
  - Firebase Auth 없이도 로그인, 세션 복원, 로그아웃, 계정 삭제를 일관된 Rust 경계 안에서 처리할 수 있다
  - access token은 stateless, refresh session은 회전/폐기가 가능해 모바일 세션 모델에 적합하다
  - 기존 `users.id`와 다른 도메인 FK를 재마이그레이션하지 않고 auth만 교체할 수 있다
- **잃는 것**:
  - provider 토큰 검증, refresh rotation, session persistence를 직접 구현해야 한다
  - 배포 시점 cutover를 위해 강제 업데이트와 세션 마이그레이션 시나리오를 함께 관리해야 한다
- **후속 결정**:
  - access JWT signing key 형식과 rotation 정책
  - refresh session 스키마와 device binding 세부 규칙
  - Apple/Google provider 검증 실패 시 에러 코드 매핑
