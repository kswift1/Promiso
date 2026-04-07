# ADR-009: 일반 알림은 FCM, Live Activity는 APNs 채널로 분리

## 상태

확정

## 맥락

Promiso는 iOS 앱이지만 푸시 채널이 두 종류다.

- 일반 앱 알림: 일정 생성/확정/취소, 그룹 가입, 출석 응답 등
- Live Activity: `push-to-start`, activity update/broadcast 같은 ActivityKit 제어

초기 notifications 마이그레이션(#5)은 이 둘을 `devices` 한 테이블에 같이 저장했다.

- `fcm_token`
- `push_to_start_token`
- `live_activity_push_token`

이 구조의 문제:

- 일반 알림 전송(Firebase FCM)과 Live Activity 토큰(APNs)의 책임 경계가 DB/API에 드러나지 않음
- 클라이언트가 Push to Start 토큰만 저장할 때도 `fcmToken: ""` 같은 우회가 필요했음
- "push"라는 말 아래 서로 다른 lifecycle과 장애 원인을 가진 채널이 섞여 있었음

## 평가 기준

| 기준 | 가중치 | 설명 |
|------|--------|------|
| 경계 명확성 | 높음 | 일반 알림과 Live Activity 책임을 코드/스키마에 드러낼 수 있는가 |
| 운영 단순성 | 높음 | 어떤 토큰이 어느 전송 경로용인지 바로 이해 가능한가 |
| iOS 적합성 | 중간 | FCM과 APNs를 혼합 사용하더라도 iOS 전용 기능을 자연스럽게 담는가 |
| 확장성 | 중간 | 일반 알림 provider 변경이나 Live Activity 확장 시 영향 범위가 작은가 |

## 비교

| 기준 | 단일 `devices` 테이블에 토큰 혼합 | 채널별 endpoint 분리 |
|------|----------------------------------|----------------------|
| 경계 명확성 | 낮음 — FCM/APNs 토큰이 같은 row에 섞임 | 높음 — `notification_endpoints`, `live_activity_endpoints`로 분리 |
| 운영 단순성 | 낮음 — 어떤 API가 어떤 토큰을 다루는지 불명확 | 높음 — 일반 알림과 Live Activity 등록 API가 분리 |
| iOS 적합성 | 보통 — 구현은 가능하나 모델이 어색함 | 높음 — ActivityKit/APNs 토큰을 별도 lifecycle로 취급 가능 |
| 확장성 | 낮음 — 새 채널 추가 시 `devices`가 계속 비대해짐 | 높음 — provider/endpoint 단위로 확장 가능 |

## 결정

일반 앱 알림과 Live Activity를 별도 채널로 취급한다.

- 일반 앱 알림 transport: `FCM`
- Live Activity transport: `APNs`

구현 원칙:

- `devices`는 디바이스 메타데이터만 저장
- 일반 알림 endpoint는 `notification_endpoints`
- Live Activity endpoint는 `live_activity_endpoints`
- API도 같은 기준으로 분리
  - `PUT /api/v1/devices`
  - `PUT /api/v1/devices/{device_id}/notification-endpoints/{provider}`
  - `PUT /api/v1/devices/{device_id}/live-activity-endpoint`

즉, transport를 하나로 통일하지는 않지만 채널 경계를 명시적으로 모델링한다.

## 결과

이 결정으로 인해:

- **얻는 것**:
  - 일반 알림과 Live Activity의 책임이 DB/API/클라이언트에 명확히 드러남
  - Push to Start 토큰 저장 시 FCM 토큰 우회가 사라짐
  - 나중에 일반 알림 transport를 FCM에서 APNs direct로 바꾸더라도 `notification_endpoints` 경계 안에서 교체 가능
- **잃는 것**:
  - 토큰 저장 테이블과 API 수가 늘어남
  - 초기 구현 시 라우트/DTO/클라이언트 변경 범위가 조금 커짐
- **후속 결정**:
  - Live Activity remote update/broadcast의 APNs sender 구체 구조는 실시간 도메인 ADR에서 별도 다룸
