# ADR-006: 전환 기간 인증은 Firebase ID 토큰 검증으로 유지

## 상태

확정

## 맥락

Rust 서버에서 사용자 인증을 어떻게 처리할지 결정해야 한다.

현재 iOS 앱은 Firebase Auth를 사용하여 Apple/Google 로그인을 처리하고 있다. 모든 API 호출 시 Firebase ID 토큰을 함께 보낸다.

ADR-002에서 정한 전환 순서상 인증은 Phase C (위험 높음)로, 모든 도메인 API 전환이 끝난 후 마지막에 처리한다.

## 비교

| 방법 | 설명 | 구현량 | 위험도 |
|------|------|--------|--------|
| **Firebase ID 토큰 검증** | iOS가 보내는 Firebase 토큰을 Rust에서 검증만 함 | 낮음 — 미들웨어 하나 | 낮음 — iOS 변경 없음 |
| **자체 JWT 발급** | Rust 서버가 직접 Apple/Google OAuth 처리 + JWT 발급 | 높음 — OAuth 플로우, 토큰 발급/갱신/폐기 전체 구축 | 높음 — iOS 인증 흐름 전면 변경 |

## 결정

**전환 기간 동안 Firebase ID 토큰 검증 방식을 사용한다.**

Rust 서버의 auth 미들웨어가 하는 일:
1. `Authorization: Bearer <firebase_id_token>` 헤더에서 토큰 추출
2. Firebase 공개 키로 서명 검증 (Google 공개 키 엔드포인트에서 캐싱)
3. `uid`, `email` 클레임 추출 (전환 기간 최소 범위)
4. 요청 컨텍스트에 주입

> `provider` 정보(`firebase.sign_in_provider`, `firebase.identities`)는 전환 기간 동안 클라이언트 요청 body에서 받는다 (기존 Firebase Functions과 동일 방식). Phase C (자체 인증 전환) 시 토큰 클레임 기반으로 변경한다.

iOS 앱은 기존 Firebase Auth 로그인 흐름을 그대로 유지한다. 변경 없음.

### 자체 JWT 전환 시점

모든 도메인 API 전환 완료 후 (Phase C) 별도 ADR로 결정한다. 그때까지 Firebase Auth 의존성은 유지된다.

## 결과

- **얻는 것**: iOS 변경 없이 Rust 서버 인증 즉시 동작, 구현 최소화, 도메인 마이그레이션에 집중 가능
- **잃는 것**: Firebase Auth 의존성 지속 (전환 기간 한정)
- **후속 결정**: Phase C에서 자체 인증 시스템 구축 여부 (모든 도메인 전환 완료 후)
