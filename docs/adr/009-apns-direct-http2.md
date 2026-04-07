# ADR-009: APNs HTTP/2 직접 발송으로 reqwest 선택

## 상태

확정

## 맥락

LiveActivity 도메인을 Rust로 마이그레이션하면서 APNs(Apple Push Notification service)를 직접 발송해야 한다. 현재 Firebase Functions에서 Node.js `http2` 모듈로 직접 구현되어 있으며, iOS 18 Broadcast Channel API를 사용한다:

- `/3/device/{token}` — Push to Start (단말 직접 발송)
- `/1/apps/{bundleId}/channels` — Broadcast 채널 생성
- `/4/broadcasts/apps/{bundleId}` — Broadcast 발송

APNs는 HTTP/2가 필수이며, ES256 JWT 인증을 사용한다.

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 확장성 | 높음 | Apple 신규 API(Broadcast 등) 즉시 대응 가능 여부 |
| 안정성 | 높음 | 라이브러리 유지보수 상태, 프로덕션 검증 |
| 락인 | 낮음 | 두 선택지 모두 락인 없음 |
| 성능 | 낮음 | 두 선택지 모두 HTTP/2 멀티플렉싱 |

## 비교

| 기준 | A. `a2` crate (APNs 전용) | B. `reqwest` + HTTP/2 직접 구현 |
|------|--------------------------|-------------------------------|
| 확장성 | 낮음 — Broadcast Channel API 미지원, 라이브러리 업데이트 의존 | 높음 — Apple 신규 API 즉시 구현 가능 |
| 안정성 | 중간 — 마지막 업데이트 2023년 | 높음 — reqwest는 활발히 유지, 직접 통제 |
| 락인 | 낮음 | 없음 |
| 성능 | 동일 (HTTP/2) | 동일 (HTTP/2) |

## 결정

**B. `reqwest` + HTTP/2 직접 구현**을 선택한다.

핵심 이유: `a2` crate가 iOS 18 Broadcast Channel API(`/1/apps/.../channels`, `/4/broadcasts/...`)를 지원하지 않는다. 현재 Firebase에서 이미 Broadcast 방식을 사용 중이므로 `a2`로는 기존 기능을 구현할 수 없다.

`reqwest`는 이미 Cargo.toml에 있으며, `http2` feature를 추가하면 APNs HTTP/2 통신이 가능하다. 기존 TypeScript `apns.ts`와 동일한 구조를 Rust로 포팅한다.

## 결과

- **얻는 것**: iOS 18 Broadcast 완전 지원, Apple 신규 API 즉시 대응, 기존 TypeScript 구현과 동일한 기능
- **잃는 것**: APNs 전용 crate 대비 boilerplate 코드 증가 (JWT 서명, 헤더 구성 등)
- **후속 결정**: `reqwest`에 `http2` feature 추가, ES256 JWT 서명을 위한 `jsonwebtoken` 활용 (이미 존재)
