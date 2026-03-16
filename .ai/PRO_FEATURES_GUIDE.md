# Pro 기능 작동 방식 가이드

> 이 문서는 Pro 기능의 **작동 방식, 권한 판단, 서버 흐름**을 한 장으로 빠르게 이해하기 위한 overview 문서입니다.
> 상세 구현은 하단의 참고 문서를 따릅니다.

---

## 1. 한 줄 요약

Promiso의 Pro 기능은 단순히 "결제했는가"만으로 동작하지 않는다.
실제 서버 동작 기준은 **실효 Pro 권한(effective Pro)** 이며,
이 값은 기본적으로 `subscriptions/{uid}`를 기준으로 하고
운영상 필요 시 `entitlementOverrides/{uid}`를 추가로 반영한다.

---

## 2. 권한 판단 기준

### SSOT

- **통합 판정 read model**: `entitlements/{uid}` (구독 + 오버라이드 합산)
- 원본 구독 상태: `subscriptions/{uid}`
- 운영 예외 권한: `entitlementOverrides/{uid}`

### 활성 Pro로 보는 상태

- `subscribed`
- `lifetime`
- `gracePeriod`

### 비활성 Pro로 보는 상태

- `none`
- `expired`
- `revoked`

### effective Pro

```text
effectivePro = hasActiveSubscription(subscription.status) || overrideActive
```

즉:
- 일반 사용자: `subscriptions/{uid}`만으로 판정
- 운영 예외 사용자: override가 있으면 Pro처럼 동작 가능

---

## 3. Pro 기능 목록

### 1. 일정 충돌 감지

- 일정 생성/수정 시 기존 일정과 겹침 여부를 서버에서 판단
- 임계값(0/15/30/60분) 커스텀 가능
- 게이팅:
  - 무료 사용자는 설정/진입 시 Pro 유도
  - 서버에서는 구독 상태 기준으로 기능 허용 여부를 판단

### 2. 날씨 정보

- 일정 생성/홈에서 장소 기반 날씨 정보 제공
- 게이팅:
  - 무료 사용자는 날씨를 blur 처리하는 방식이 아니라, 서버 fetch 자체를 안 하는 방향

### 3. 매일 일정 브리핑

- 오늘 일정 + 날씨 + 교통 정보를 종합해 AI 브리핑 생성
- 브리핑 스타일, 알림 시간, 교통수단 설정 가능
- 게이팅:
  - 홈 카드 노출/내용/푸시 알림 모두 Pro 기준

### 4. 출발 관련 Pro 기능

- 출발 시간 안내
- 브리핑에서 교통수단별 정보 반영
- 일부 CTA/알림은 Pro 사용자 기준으로만 노출

---

## 4. 구독 상태 데이터 흐름

```text
StoreKit 2 / Apple Server Notification
  -> verifyPurchase / appleServerNotification
  -> subscriptions/{uid} 갱신
  -> 필요 시 subscriptionOwners/{originalTransactionId} 갱신
  -> onSubscriptionWriteSyncEntitlement 트리거
  -> entitlements/{uid} read model 갱신
```

핵심 포인트:
- `subscriptions/{uid}`는 App Store 구독 상태 원본
- `entitlements/{uid}`는 구독 + 오버라이드를 합산한 Pro 판정 read model
- `subscriptionOwners/{originalTransactionId}`는 소유권 인덱스
- 만료/환불/웹훅 반영은 서버가 담당
- 클라이언트는 `entitlements/{uid}` 단일 리스닝으로 Pro 상태를 수신

---

## 5. 브리핑 알림은 어떻게 동작하나

브리핑 알림은 현재 Pro 기능 중 서버 측 판정과 스케줄링이 가장 복잡한 축이다.

### 변경 전 개념

- `users/{uid}/settings/main.proSettings.briefing.notificationHour`가 있으면 발송 후보로 봄
- 매시간 전체 settings를 스캔
- stale `proSettings`가 남으면 비구독자도 잘못 발송될 수 있음

### 현재 구조

브리핑 알림은 settings를 직접 스캔하지 않고,
서버가 별도 projection 컬렉션을 유지한다.

#### projection 컬렉션

```text
briefingSubscriptions/{uid}
```

이 문서에는 아래 정보만 담긴다.

- `notificationHour`
- `timezone`
- `language`
- `style`
- `nextDispatchAt`

### projection 입력

- `users/{uid}/settings/main.proSettings.briefing`
- `entitlements/{uid}` (구독 + 오버라이드 합산)

### projection 갱신 트리거

- settings/main 변경
- entitlements/{uid} 변경

### 스케줄러 동작

```text
scheduledBriefingDispatch
  -> briefingSubscriptions 에서 nextDispatchAt <= now 조회
  -> Cloud Task enqueue
  -> 성공 시 nextDispatchAt 을 다음 시각으로 advance
```

### task 실행 직전 최종 가드

`executeBriefingNotification`는 enqueue된 payload만 믿지 않는다.
실행 직전에 다시 아래 값을 읽는다.

- 최신 `settings/main`
- 최신 `entitlements/{uid}`

이유:
- enqueue 후 구독 상태가 바뀔 수 있음
- 알림 시간이 바뀌거나 꺼질 수 있음
- stale task를 마지막에 한 번 더 차단해야 안전함

---

## 6. 왜 projection을 쓰나

`subscriptions/{uid}`만 읽으면 "누가 Pro인지"는 알 수 있지만,
"언제 어떤 브리핑을 보내야 하는지"는 알 수 없다.

스케줄러가 실제로 필요한 값:
- 알림 시간
- 타임존
- 언어
- 스타일

선택지는 둘이다.

### A. 매시간 `subscriptions`를 읽고 유저별 `settings/main`을 다시 읽는다

장점:
- 구조가 단순함

단점:
- 스케줄러가 매시간 entitlement + settings 조인을 반복해야 함
- Pro 유저 수가 늘수록 반복 read 비용이 커짐

### B. `subscription + settings`를 projection으로 합친다

장점:
- 스케줄러는 due 문서만 조회하면 됨
- 반복 read를 변경 시점 계산으로 옮길 수 있음
- stale settings 방어가 쉬움

단점:
- 트리거/백필/운영 문서가 추가로 필요함

Promiso는 브리핑에 대해 B를 채택했다.

---

## 7. 운영에서 확인할 포인트

### "왜 이 유저가 Pro인가?"

1. `entitlements/{uid}` 확인 (`hasPro`, `source` 필드)
2. 원인 추적: `subscriptions/{uid}` 또는 `entitlementOverrides/{uid}` 확인

### "왜 브리핑 알림이 갔나 / 안 갔나?"

1. `users/{uid}/settings/main.proSettings.briefing` 확인
2. `briefingSubscriptions/{uid}` 존재 여부 확인
3. `nextDispatchAt`이 현재 시각 기준 due였는지 확인
4. `executeBriefingNotification` 직전 entitlement 변경이 있었는지 확인

### "기존 유저는 언제 projection에 들어오나?"

- settings 변경 시 자동 반영
- subscription 변경 시 자동 반영
- 배포 직후 기존 데이터는 backfill 스크립트로 한 번 채움

---

## 8. 문서 읽는 순서

Pro 기능을 처음 보면 이 순서를 추천한다.

1. 이 문서
2. `PRO_PLAN.md`
3. `BRIEFING_SPEC.md`
4. `FIRESTORE_SCHEMA.md`

---

## 9. 참고 문서

- [PRO_PLAN.md](./PRO_PLAN.md)
- [BRIEFING_SPEC.md](./specs/BRIEFING_SPEC.md)
- [FIRESTORE_SCHEMA.md](./FIRESTORE_SCHEMA.md)
- [TEST_POLICY.md](./TEST_POLICY.md)
- [docs/ADMIN_CONSOLE_PLAN.md](../docs/ADMIN_CONSOLE_PLAN.md)
