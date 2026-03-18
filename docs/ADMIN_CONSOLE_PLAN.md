# Admin Console Plan

## Overview

ProPlan 출시와 함께 필요한 것은 "모든 것을 편집하는 백오피스"가 아니라, 운영자가 핵심 업무를 빠르게 처리할 수 있는 작은 운영 콘솔입니다.

이 문서는 다음을 정리합니다.
- 왜 지금 운영 콘솔이 필요한가
- 출시 MVP에 무엇을 넣고 무엇을 미루는가
- 어떤 기술 스택이 지금 팀 상황에 맞는가
- 어떤 데이터 모델과 보안 원칙으로 가야 하는가
- 어떤 순서로 만들면 되는가

---

## 1. Why Now

ProPlan 출시 직후 가장 많이 생기는 운영 이슈는 대체로 아래 4가지입니다.

1. 결제/권한 이슈
   - 구매했는데 Pro가 안 풀림
   - 복원이 안 됨
   - grace period / expired / refunded 상태 문의
2. 운영 공지
   - 전체 유저 또는 특정 조건 유저에게 공지 푸시 발송
3. 릴리즈 제어
   - 강제 업데이트
   - 권장 업데이트
   - 기능 킬 스위치
4. 감사/추적
   - 누가 어떤 사용자 권한을 바꿨는지
   - 누가 어떤 푸시를 언제 발송했는지

현재 코드베이스에는 이미 재사용 가능한 핵심 조각이 있습니다.
- `infra/firebase/functions/src/functions/subscription.ts`
  - 구매 검증
  - Apple Server Notification 처리
  - `subscriptions/{userId}` 갱신
- `infra/firebase/functions/src/functions/notifications.ts`
  - 푸시 저장 + FCM 전송
- `infra/firebase/remoteconfig.template.json`
  - 운영자가 조정할 만한 앱 설정 값의 출발점

즉, 새로 만들어야 하는 것은 "운영 UI + admin-only API 레이어"이지, 비즈니스 로직 전체가 아닙니다.

---

## 2. Product Principle

운영 콘솔은 아래 원칙으로 설계합니다.

1. 소비자 앱과 분리한다
   - 일반 사용자 앱 안에 관리자 기능을 넣지 않는다
2. UI는 얇게 유지한다
   - 모든 쓰기 작업은 admin-only server function으로 처리한다
3. Apple 구독 상태와 운영자 보정 상태를 분리한다
   - Apple SSOT를 덮어쓰지 않는다
4. 모든 위험한 액션은 로그를 남긴다
   - 권한 변경
   - 전체 푸시
   - 원격 설정 변경
5. 처음부터 "작은 운영 콘솔"로 만든다
   - 고객지원 + 권한 + 공지 + 릴리즈 제어까지만

---

## 3. MVP Scope

### 3.1 Launch Critical

#### A. User Lookup
- userId / email / nickname 검색
- 기본 프로필 조회
- 현재 구독 상태 조회
- 현재 override 상태 조회
- 최근 admin action 이력 조회

#### B. Subscription / Entitlement Support
- 현재 구독 상태 표시
  - `none`
  - `subscribed`
  - `lifetime`
  - `gracePeriod`
  - `expired`
  - `revoked`
- 원본 transaction 정보 표시
- 수동 Pro grant
- 수동 Pro revoke
- 보정 만료일 설정
- 보정 사유 입력

#### C. Push Jobs
- 테스트 발송
- dry-run
- 전체 발송
- 조건 발송
  - active users
  - Pro users
  - free users
- 예약 발송은 2차로 미뤄도 됨

#### D. Release Controls
- force update version
- recommended version
- support email / FAQ / 약관 URL
- ProPlan 관련 킬 스위치 또는 노출 플래그

#### E. Audit Log
- 누가 실행했는지
- 대상이 누구였는지
- 이전 값 / 이후 값
- 언제 실행했는지

### 3.2 Defer

아래는 MVP에서 제외합니다.
- full analytics dashboard
- cohort builder 고도화
- 시각화 차트 중심 대시보드
- 고객 메시지 템플릿 관리 CMS
- Firestore 전체 수동 편집기
- App Store 정산/환불 대시보드 대체

App Store Connect가 해결하는 문제까지 내부 콘솔로 다시 만들 필요는 없습니다.

---

## 4. Recommended Stack

### Recommendation

가장 추천하는 스택은 아래 조합입니다.

| Layer | Choice | Reason |
|------|--------|--------|
| Frontend | React + TypeScript + Vite | SSR이 필요 없고, Next.js보다 개념이 적음 |
| UI | MUI | 내부 툴에 필요한 테이블/폼/다이얼로그를 빠르게 구성 가능 |
| Data Fetching | TanStack Query | 서버 상태 관리가 단순하고 안정적 |
| Auth | Firebase Auth (Google Sign-In) + admin allowlist/custom claims | 기존 Firebase 인프라와 자연스럽게 연결 |
| Backend | Firebase Functions (TypeScript) | 현재 로직 재사용 가능 |
| Data | Firestore | audit log, push jobs, overrides 저장에 적합 |
| Config | Firebase Remote Config | 릴리즈 제어와 기능 토글에 적합 |
| Hosting | Firebase Hosting | 같은 Firebase 프로젝트 안에서 단순 운영 가능 |

### Why This Stack

이 조합은 아래 이유로 지금 팀 상황에 맞습니다.

1. 새 서버를 따로 만들 필요가 없다
2. 기존 Firebase Functions를 그대로 감쌀 수 있다
3. admin 전용 UI만 새로 만들면 된다
4. 내부 도구라 SEO, SSR, 복잡한 렌더링 전략이 필요 없다
5. React + MUI는 "관리 화면" 구현 속도가 빠르다

### Why Not Next.js First

Next.js가 나쁜 선택은 아니지만, 현재 상황에서는 과할 수 있습니다.

- 내부 admin 콘솔은 SEO가 필요 없다
- SSR이 핵심 가치가 아니다
- App Router / Server Components / Deployment 개념이 추가된다
- 처음 웹을 배우는 입장에서는 React + Vite가 훨씬 단순하다

### Why Not a Separate Backend

FastAPI, NestJS, Rails 같은 별도 백엔드를 새로 두는 것은 지금 타이밍에 비효율적입니다.

- 기존 Functions 로직 재사용 가능
- 운영 복잡도 증가
- 배포 포인트 증가
- 권한 체계가 분산됨

---

## 5. Alternative Options

### Option A. Retool / Appsmith

가장 빨리 만들 수 있는 선택지입니다.

장점:
- 웹 지식이 거의 없어도 시작 가능
- 테이블, 폼, 필터, 버튼 UI를 빠르게 구성 가능
- 내부 툴 MVP를 빨리 검증 가능

단점:
- 장기적으로 제품/도메인 로직이 분산될 수 있음
- 커스텀 동작이 늘수록 결국 코드가 필요함
- 권한/감사/배포를 repo 바깥에서 관리하게 됨

추천 상황:
- ProPlan 출시가 매우 급하고
- 1~2주 안에 내부 운영 툴이 꼭 필요하며
- 장기 확장성보다 속도가 중요할 때

### Option B. SwiftUI macOS Internal App

본인이 iOS/Swift에 가장 익숙하다면 현실적인 대안입니다.

장점:
- 학습 비용이 가장 낮음
- 기존 Swift/TCA 감각을 유지 가능
- 혼자 빠르게 만들 수 있음

단점:
- 운영 툴은 브라우저 접근성이 높을수록 편함
- 팀원이 늘어나면 공유가 불편함
- 데스크톱 CRUD / 표 / 필터 경험은 웹이 더 편함

추천 상황:
- 당장 운영자를 본인 1명으로 가정하고
- 웹 학습 비용을 최소화하고 싶을 때

### Decision

현재 팀 상황을 기준으로는 아래 순서를 추천합니다.

1. **가장 현실적인 coded solution**: React + Vite + Firebase
2. **가장 빠른 no/low-code solution**: Retool
3. **가장 낮은 학습 비용**: SwiftUI macOS internal tool

---

## 6. Architecture

```text
Admin UI
  -> Firebase Auth (admin user only)
  -> admin-only HTTPS / callable functions
  -> Firestore / Remote Config / FCM / existing business functions
```

중요한 점:
- 브라우저에서 Firestore Admin SDK를 직접 쓰지 않는다
- 위험한 write는 무조건 admin-only function 뒤로 숨긴다
- UI는 "입력 + 확인 + 결과 표시" 역할만 한다

### Repository Strategy

초기에는 **현재 레포 안에서 관리**하는 것이 맞습니다.

권장 위치:
```text
apps/admin-console
```

이유:
- 앱/Functions와 같은 도메인을 다룸
- subscription / push / remote config 변경을 같은 PR에서 조정 가능
- 소수 인원일수록 레포 분리 비용이 큼

대신 아래는 분리합니다.
- 앱 디렉터리
- 빌드 파이프라인
- 배포 파이프라인
- 환경변수

별도 레포 분리를 재검토할 시점:
- 운영 콘솔 전담 인력이 생길 때
- 배포 주기가 메인 앱과 완전히 달라질 때
- 접근 권한을 조직적으로 강하게 분리해야 할 때

---

## 7. Data Model

### 7.1 Keep Existing Sources of Truth

#### `subscriptions/{userId}`
- Apple 검증/웹훅 기준 상태
- 직접 수동 수정하지 않음

### 7.2 Add New Admin Collections

#### `entitlementOverrides/{userId}`

운영자가 수동으로 권한을 부여/회수하는 컬렉션

예시 필드:
```json
{
  "isActive": true,
  "type": "manual_pro_grant",
  "reason": "CS compensation",
  "expiresAt": "2026-04-30T00:00:00Z",
  "createdBy": "admin_uid",
  "createdAt": "...",
  "updatedAt": "..."
}
```

#### `adminPushJobs/{jobId}`

예시 필드:
```json
{
  "status": "completed",
  "audience": "all",
  "filters": {
    "subscriptionTier": "all"
  },
  "title": "공지사항",
  "body": "원하는 메시지",
  "dryRun": false,
  "createdBy": "admin_uid",
  "createdAt": "...",
  "result": {
    "targetCount": 1200,
    "successCount": 1180,
    "failureCount": 20
  }
}
```

#### `adminAuditLogs/{logId}`

예시 필드:
```json
{
  "actorId": "admin_uid",
  "action": "grant_entitlement",
  "targetType": "user",
  "targetId": "user_uid",
  "before": {},
  "after": {},
  "createdAt": "..."
}
```

#### `adminUsers/{uid}`

예시 필드:
```json
{
  "role": "owner",
  "email": "admin@promiso.app",
  "enabled": true
}
```

### 7.3 Effective Entitlement Rule

실제 Pro 접근 권한은 아래처럼 계산합니다.

```text
effectivePro = active subscription OR active entitlement override
```

이렇게 해야 Apple 상태와 운영 보정이 충돌하지 않습니다.

---

## 8. Security Model

### Roles

최소 역할만 둡니다.

| Role | Permission |
|------|------------|
| owner | 모든 권한 |
| support | 유저 조회, 권한 보정 |
| marketer | 푸시 발송, Remote Config 일부 편집 |

### Required Safeguards

- Google 로그인 + admin allowlist
- admin function에서 role 확인
- 전체 푸시는 2단계 확인
- dry-run 필수
- 모든 write 액션 audit log 남김
- prod/stage 환경 명시

---

## 9. MVP Screens

### A. Login
- Google Sign-In
- admin 사용자만 통과

### B. User Search
- userId / email / nickname 검색
- subscription / override / devices / basic metadata 조회

### C. Entitlements
- grant
- revoke
- expiry 설정
- reason 기록

### D. Push Jobs
- message 작성
- audience 선택
- dry-run
- test send
- send
- 결과 보기

### E. Release Controls
- force/recommended version
- support links
- feature flags

### F. Audit Logs
- action list
- actor
- target
- timestamp

---

## 10. Delivery Plan

### Phase 0. Decision / Setup
- stack 확정
- admin auth 방식 확정
- Firestore 컬렉션 설계 확정

### Phase 1. Backend Foundations
- `adminUsers`
- `adminAuditLogs`
- `entitlementOverrides`
- admin-only functions
  - `getAdminUserSummary`
  - `grantEntitlementOverride`
  - `revokeEntitlementOverride`
  - `sendAdminPush`
  - `updateRemoteConfig`

### Phase 2. Admin UI MVP
- 로그인
- 유저 검색
- 권한 보정
- 푸시 발송
- 릴리즈 제어

### Phase 3. Operational Hardening
- dry-run / preview
- webhook failure visibility
- push history
- filtering 개선
- operational analytics MVP
  - GA4 recent events
  - BigQuery historical funnel

### Phase 3 TODO. Analytics External Setup
- [x] 운영 콘솔 Dashboard에 analytics MVP UI 추가
- [x] `getAdminAnalyticsSummary` callable 추가
- [x] stage GA4 property ID 확인 (`528306317`)
- [ ] `promiso-stage`에서 Google Analytics -> BigQuery export 활성화 완료
- [ ] BigQuery dataset 생성 확인
  - 예상 dataset: `analytics_528306317`
  - 추천 location: `US`
- [ ] stage 앱에서 실제 analytics 이벤트 유입 확인
  - 참고: DEBUG 빌드는 기본적으로 analytics가 비활성화됨
  - Xcode 실행 시 `-FIRDebugEnabled` 또는 `PROMISO_ANALYTICS_DEBUG=1` 필요
- [ ] `getAdminAnalyticsSummary` 런타임 서비스 계정에 GA4 property 읽기 권한 부여
- [ ] BigQuery dataset read 권한 + project `jobUser` 권한 부여
- [ ] `infra/firebase/functions/.env.promiso-stage`에 analytics params 입력
- [ ] `firebase deploy --only functions:getAdminAnalyticsSummary --project promiso-stage`
- [ ] stage Dashboard에서 live analytics 숫자 확인

---

## 11. Suggested Build Order

시간이 제한적이라면 이 순서가 좋습니다.

1. admin auth
2. user lookup
3. entitlement override
4. push jobs
5. remote config controls
6. audit log viewer

이 순서는 "매출/지원 문제를 먼저 해결"하는 순서입니다.

---

## 12. Recommendation for a Team With Only iOS Experience

현재 팀이 사실상 iOS 중심이고, 웹 경험이 거의 없다면 이렇게 판단하는 것이 좋습니다.

### If you want the best long-term shape
- React + TypeScript + Vite + MUI + Firebase

### If you want the fastest launch support
- Retool first, then replace later if needed

### If you want the lowest learning cost for yourself
- SwiftUI macOS internal app

### Final Recommendation

**권장 1안**
- 운영 콘솔은 웹으로 간다
- 스택은 `React + Vite + MUI + Firebase Auth + Firebase Functions + Firestore`

이유:
- 내부 툴의 전형적인 형태와 잘 맞고
- 팀이 커져도 공유가 쉽고
- 기존 Firebase 백엔드를 그대로 활용할 수 있기 때문

**권장 2안**
- ProPlan 출시가 정말 급하면 Retool로 1차 운영 툴을 만들고
- 워크플로가 안정되면 2차로 자체 웹 콘솔로 옮긴다

---

## 13. Non-Goals

초기 운영 콘솔은 아래를 목표로 하지 않습니다.

- App Store Connect를 완전히 대체
- 데이터 웨어하우스/BI 도구 대체
- 전체 Firestore 관리자
- 마케팅 자동화 플랫폼 대체

---

## 14. Next Questions

구현 전 아래 결정이 필요합니다.

1. 운영자를 몇 명으로 볼 것인가
2. 웹을 새로 배워도 되는가, 아니면 학습 비용을 최소화해야 하는가
3. Pro 권한 수동 부여 정책이 필요한가
4. 전체 푸시를 얼마나 자주 보낼 것인가
5. Remote Config에서 실제로 제어할 항목은 무엇인가

---

## 15. Practical Next Step

가장 먼저 할 일은 아래 둘 중 하나를 고르는 것입니다.

### Option 1
- React + Vite 기반 `admin-console` 디렉터리 생성

### Option 2
- Retool로 MVP 운영 플로우 검증

개인적으로는, 현재 코드베이스와 장기 운영성을 고려하면 `Option 1`이 가장 균형이 좋습니다.
