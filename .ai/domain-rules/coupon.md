# 쿠폰 (Coupon) 도메인 규칙

> Pro 플랜 체험/프로모션용 쿠폰 시스템

---

## 쿠폰 생성

| # | 규칙 | 비고 |
|---|------|------|
| C-01 | 쿠폰 생성은 admin/marketer 권한만 가능 | Cloud Functions `createCoupon` |
| C-02 | 코드 8자리 영숫자 (0/1/I/O/l 제외), 자동생성 또는 수동 지정 | |
| C-03 | 기본 유효기간: 30일 또는 90일 | `durationDays` 필드 |
| C-04 | 쿠폰 만료(`expiresAt`) 전까지만 사용 가능 | |

## 쿠폰 사용 (Redeem)

| # | 규칙 | 비고 |
|---|------|------|
| C-05 | **1인 1쿠폰**: 한 번이라도 쿠폰을 사용한 계정은 다른 쿠폰도 사용 불가 | `entitlementOverrides.type == "coupon_redeem"` 체크 |
| C-06 | 이미 다른 사용자가 사용한 쿠폰은 사용 불가 | `redeemedBy` 체크 |
| C-07 | 만료된 쿠폰은 사용 불가 | `expiresAt < now` 체크 |
| C-08 | **구독 활성 상태에서 쿠폰 사용 차단** | 구독 중에는 쿠폰 불필요, 이중 결제 혼란 방지 |

## 쿠폰 적용 결과

| # | 규칙 | 비고 |
|---|------|------|
| C-09 | 쿠폰 사용 시 `entitlementOverrides/{uid}` 문서 생성 (`type: "coupon_redeem"`) | |
| C-10 | `reconcileEntitlement` 트리거로 `entitlements/{uid}` 자동 동기화 | `hasPro`, `source`, `overrideType` 갱신 |
| C-11 | Pro 소스 우선순위: `subscription > override > none` | 구독이 있으면 `source: "subscription"` |

## UI 노출

| # | 규칙 | 비고 |
|---|------|------|
| C-12 | 쿠폰 입력 UI는 Paywall(비구독 상태)에서만 노출 | |
| C-13 | Pro 구독 관리 화면(ManageView)에서 쿠폰 입력 UI 미노출 | 이미 Pro인 유저에게 불필요 |

## 관리

| # | 규칙 | 비고 |
|---|------|------|
| C-14 | 미사용 쿠폰만 관리자가 즉시 만료 가능 | 사용된 쿠폰의 override는 별도 해제 |
| C-15 | 모든 쿠폰 사용/만료 이벤트는 감사 로그(`auditLogs`) 기록 | |
