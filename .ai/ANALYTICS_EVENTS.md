# Firebase Analytics 이벤트 명세

## 개요

Promiso 앱에서 수집하는 Firebase Analytics 이벤트 목록입니다.
이 문서는 앱의 핵심 비즈니스 메트릭과 사용자 행동을 추적하기 위한 이벤트를 정의합니다.

**최종 업데이트**: 2026-03-12
**Analytics SDK**: FirebaseAnalytics 12.3.0

---

## 이벤트 카테고리

### 🎯 핵심 비즈니스 이벤트 (7개)

앱의 핵심 기능 사용을 추적하는 필수 이벤트입니다.

| 이벤트 이름 | 설명 | 파라미터 | Feature | 코드 위치 |
|------------|------|----------|---------|----------|
| `user_signup` | 회원가입 완료 (프로필 설정 완료 후) | `login_method` | AppEntryFeature | AppEntryFeature.swift |
| `user_login` | 로그인 (기존 사용자) | `login_method` | AppEntryFeature | AppEntryFeature.swift |
| `group_created` | 그룹 생성 완료 | `group_id`, `group_name` | CreateGroupFeature | CreateGroupFeature.swift:327 |
| `group_joined` | 그룹 가입 완료 | `group_id`, `group_name` | JoinGroupFeature | JoinGroupFeature.swift:362 |
| `schedule_created` | 일정 생성 완료 | `schedule_id`, `schedule_title` | CreateScheduleFeature | CreateScheduleFeature.swift |
| `schedule_response_yes` | 일정 "가능" 응답 | `schedule_id`, `schedule_title` | SharedFeature | ScheduleDetailFeature.swift |
| `schedule_response_no` | 일정 "불가능" 응답 | `schedule_id`, `schedule_title` | SharedFeature | ScheduleDetailFeature.swift |

---

### 📱 사용자 행동 이벤트 (5개)

사용자의 앱 사용 패턴을 이해하기 위한 이벤트입니다.

| 이벤트 이름 | 설명 | 파라미터 | Feature | 코드 위치 |
|------------|------|----------|---------|----------|
| `profile_setup_completed` | 프로필 설정 완료 | - | AppEntryFeature | AppEntryFeature.swift |
| `group_invite_shared` | 그룹 초대 진입 (기존 대시보드 호환용, 초대 시트 열림) | `group_id`, `group_name` | GroupFeature | GroupSettingsFeature.swift / GroupMainFeature.swift |
| `group_invite_link_shared` | 그룹 초대 링크 실제 공유 시도 | `group_id`, `group_name`, `share_method`, `schedule_count?` | GroupFeature / CreateGroupFeature | GroupSettingsFeature.swift / GroupMainFeature.swift / CreateGroupFeature.swift |
| `schedule_share_sheet_opened` | 일정 공유 시트 열림 | `schedule_id`, `schedule_title` | GroupFeature / SharedFeature | GroupMainFeature.swift / ScheduleDetailFeature.swift |
| `schedule_link_shared` | 일정 링크 실제 공유 시도 | `schedule_id`, `schedule_title`, `share_method` | GroupFeature / SharedFeature | GroupMainFeature.swift / ScheduleDetailFeature.swift |
| `settings_opened` | 설정 화면 열림 (설정 탭 선택) | - | RootTabFeature | RootTabFeature.swift:219 |

---

### 💳 Pro Plan 이벤트 (4개)

Paywall 진입과 주요 CTA 상호작용을 추적하는 이벤트입니다.

| 이벤트 이름 | 설명 | 파라미터 | Feature | 코드 위치 |
|------------|------|----------|---------|----------|
| `paywall_open` | Paywall 화면 노출 | `has_intro_offer` | ProPlanFeature | PaywallView.swift |
| `paywall_purchase` | Paywall 구매 CTA 탭 | `product_id` | ProPlanFeature | ProPlanFeature.swift |
| `paywall_restore` | Paywall 복원 버튼 탭 | - | ProPlanFeature | ProPlanFeature.swift |
| `paywall_close` | Paywall 화면 종료 | - | ProPlanFeature | PaywallView.swift |

---

### 🔔 알림 권한 이벤트 (3개)

알림 권한 요청 및 결과를 추적하는 이벤트입니다.

| 이벤트 이름 | 설명 | 파라미터 | Feature | 코드 위치 |
|------------|------|----------|---------|----------|
| `notification_permission_requested` | 알림 권한 요청 시작 | - | NotificationPermissionFeature | NotificationPermissionFeature.swift |
| `notification_permission_granted` | 알림 권한 허용됨 | - | NotificationPermissionFeature | NotificationPermissionFeature.swift |
| `notification_permission_denied` | 알림 권한 거부됨 | - | NotificationPermissionFeature | NotificationPermissionFeature.swift |

---

### 🖥️ 화면 이벤트

주요 루트 화면은 Firebase 표준 `screen_view` 이벤트로 수동 추적합니다.

| screen_name | 화면 |
|------------|------|
| `notification_permission` | 알림 권한 화면 |
| `create_group` | 그룹 생성 화면 |
| `join_group` | 그룹 참여 화면 |
| `group_main` | 그룹 메인 화면 |
| `group_settings` | 그룹 설정 화면 |
| `create_schedule` | 일정 생성 화면 |
| `schedule_detail` | 일정 상세 화면 |
| `paywall` | Paywall 화면 |

---

## 이벤트 파라미터

### 공통 파라미터

Firebase Analytics는 기본적으로 다음 정보를 자동 수집합니다:
- 사용자 ID (`setUserID`)
- 디바이스 정보 (OS 버전, 기기 모델)
- 앱 버전
- 화면 이름 (`screen_view` 수동 로깅)

### 커스텀 파라미터

| 파라미터 키 | 타입 | 설명 | 예시 값 | 사용 이벤트 |
|-----------|------|------|---------|-----------|
| `group_id` | String | 그룹 고유 ID | "abc123xyz" | `group_created`, `group_joined`, `group_invite_shared`, `group_invite_link_shared` |
| `group_name` | String | 그룹 이름 | "우리 동아리" | `group_created`, `group_joined`, `group_invite_shared`, `group_invite_link_shared` |
| `schedule_id` | String | 일정 고유 ID | "schedule456" | `schedule_created`, `schedule_response_yes`, `schedule_response_no`, `schedule_share_sheet_opened`, `schedule_link_shared` |
| `schedule_title` | String | 일정 제목 | "점심 약속" | `schedule_created`, `schedule_response_yes`, `schedule_response_no`, `schedule_share_sheet_opened`, `schedule_link_shared` |
| `login_method` | String | 로그인 제공자 | "apple", "google" | `user_signup`, `user_login` |
| `share_method` | String | 공유 채널 | "kakao", "system" | `group_invite_link_shared`, `schedule_link_shared` |
| `schedule_count` | Int | 공유 카드에 포함된 일정 수 | 3 | `group_invite_link_shared` |
| `product_id` | String | 선택한 구독 상품 ID | "promiso.pro.yearly" | `paywall_purchase` |
| `has_intro_offer` | Bool | 무료 체험 대상 여부 | true | `paywall_open` |

---

## 유저 속성 (User Properties)

Firebase Analytics에 설정되는 사용자 속성입니다.

| 속성 이름 | 타입 | 설명 | 설정 시점 | 코드 위치 |
|---------|------|------|----------|----------|
| `nickname` | String | 사용자 닉네임 | 로그인/회원가입 시 | AppEntryFeature.swift |
| `auth_provider` | String | 인증 제공자 | 로그인/회원가입 시 | AppEntryFeature.swift |
| `subscription_tier` | String | 무료/Pro 구독 상태 | 구독 상태 변경 시 | RootTabFeature.swift |
| `notification_permission_status` | String | 시스템 알림 권한 상태 | 권한 온보딩/설정 진입 시 | NotificationPermissionFeature.swift / NotificationSettingsFeature.swift / AppEntryFeature.swift |
| `has_group` | String | 그룹 가입 여부 | 로그인 시, 그룹 목록 갱신 시 | AppEntryFeature.swift / GroupMainFeature.swift |
| `group_count_bucket` | String | 그룹 수 버킷 | 로그인 시, 그룹 목록 갱신 시 | AppEntryFeature.swift / GroupMainFeature.swift |
| `calendar_sync_enabled` | String | 개인 또는 그룹 캘린더 동기화가 하나라도 켜져 있는지 | 로그인 시, 그룹 목록 갱신 시, 캘린더 설정 변경 시 | AppEntryFeature.swift / GroupMainFeature.swift / CalendarSettingsFeature.swift |

값 가이드:
- `auth_provider`: `apple`, `google`
- `subscription_tier`: `free`, `pro`
- `notification_permission_status`: `not_determined`, `denied`, `authorized`, `provisional`, `ephemeral`
- `has_group`: `true`, `false`
- `group_count_bucket`: `0`, `1`, `2_4`, `5_plus`
- `calendar_sync_enabled`: `true`, `false`

**유저 ID 관리**:
- 로그인 시: `analyticsClient.setUserID(userModel.id)` 호출
- 로그아웃 시: `analyticsClient.setUserID(nil)` 호출
- 로그아웃 시 위 유저 속성도 모두 `nil`로 초기화

---

## 코드 사용법

### 1. 기본 이벤트 로깅

```swift
// 파라미터 없는 이벤트
analyticsClient.log(.notificationPermissionGranted)
```

### 2. 파라미터 포함 이벤트

```swift
// 그룹 생성 이벤트
analyticsClient.log(
  .groupCreated(
    groupID: "abc123",
    groupName: "우리 그룹"
  )
)
```

### 3. 유저 ID 설정

```swift
// 로그인 시
analyticsClient.setUserID(userModel.id)
analyticsClient.setUserProperty(userModel.nickname, .nickname)
analyticsClient.setUserProperty("apple", .authProvider)
analyticsClient.setGroupMembershipProperties(userModel.groups)
analyticsClient.setCalendarSyncEnabled(
  personalEnabled: true,
  groups: userModel.groups
)

// 상태 변화 시
analyticsClient.setSubscriptionTier(.lifetime)
analyticsClient.setNotificationPermissionStatus(.authorized)

// 로그아웃 시
analyticsClient.setUserID(nil)
analyticsClient.setUserProperty(nil, .nickname)
analyticsClient.setUserProperty(nil, .authProvider)
analyticsClient.setUserProperty(nil, .subscriptionTier)
analyticsClient.setUserProperty(nil, .notificationPermissionStatus)
```

---

## Firebase Console에서 확인하기

### 1. 실시간 이벤트 확인 (DebugView)

```bash
# iOS는 Xcode 스킴에서 -FIRDebugEnabled 플래그 추가
# 또는 환경변수 PROMISO_ANALYTICS_DEBUG=1 설정
```

Firebase Console > Analytics > DebugView에서 실시간 이벤트 확인 가능

### 2. 이벤트 대시보드

Firebase Console > Analytics > 이벤트
- 각 이벤트의 발생 횟수, 사용자 수 확인
- 이벤트 파라미터별 필터링

### 3. Funnel 분석

추천 퍼널:
```
회원가입 → 그룹 가입 → 일정 생성 → 일정 응답
user_signup → group_joined → schedule_created → schedule_response_yes/no
```

---

## 이벤트 네이밍 컨벤션

### 규칙
1. **소문자 + 언더스코어** 사용 (`snake_case`)
2. **동사 + 명사** 순서 (`action_object`)
3. **동사 과거 분사형 사용** (`created` ✅, `create` ❌, `creating` ❌) - 완료된 동작을 나타냅니다.
4. **명확하고 구체적인 이름** (`button_tapped` ❌ → `login_button_tapped` ✅)

### 예시
```
✅ 좋은 예시:
- user_signup
- group_created
- schedule_response_yes

❌ 나쁜 예시:
- signup (주체 불명확)
- create_group (동사 원형 사용)
- promise_responded (결과 불명확 - yes/no 구분 없음)
```

---

## 디버그 모드 설정

### Debug 빌드에서 Analytics 기본 비활성화

**AppDelegate.swift**:
```swift
func configureAnalytics() {
  #if DEBUG
  let isDebugAnalyticsEnabled =
    ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled")
    || ProcessInfo.processInfo.environment["PROMISO_ANALYTICS_DEBUG"] == "1"

  Analytics.setAnalyticsCollectionEnabled(isDebugAnalyticsEnabled)
  #else
  Analytics.setAnalyticsCollectionEnabled(true)
  #endif
}
```

---

## 개인정보 보호

### 수집하지 않는 정보
- 사용자의 위치 정보 (정확한 GPS 좌표)
- 개인 식별 정보 (이메일, 전화번호)
- 메시지 내용 또는 비공개 데이터

### 수집하는 정보
- 익명화된 사용자 행동 데이터
- 앱 사용 패턴 및 기능 사용률
- 크래시 로그 (Crashlytics)

Firebase Analytics는 GDPR, CCPA를 준수합니다.

---

## 추가 이벤트 제안 (향후 추가 가능)

### 고급 사용자 행동
- `promise_edited`: 약속 수정
- `promise_deleted`: 약속 삭제
- `group_left`: 그룹 탈퇴
- `live_activity_started`: Live Activity 시작
- `calendar_synced`: 캘린더 동기화

### 앱 성능
- `app_opened`: 앱 열림 (Firebase 기본 이벤트 `app_open` 사용 권장)
- `screen_view`: 화면 전환 (자동 수집)

### A/B 테스팅
- Remote Config와 연동하여 실험 그룹 추적

---

## 문의 및 수정

이벤트 추가/수정이 필요한 경우:
1. **코드 수정**: `Projects/Clients/Sources/Clients/AnalyticsClient.swift`의 `EventName` enum에 이벤트 추가
2. **문서 업데이트**: 이 파일(`.ai/ANALYTICS_EVENTS.md`) 업데이트
3. **커밋 메시지**: `feat: [이벤트명] Analytics 이벤트 추가` 형식 사용

---

## 참고 자료

- [Firebase Analytics 공식 문서](https://firebase.google.com/docs/analytics)
- [iOS에서 Analytics 사용하기](https://firebase.google.com/docs/analytics/get-started?platform=ios)
- [이벤트 및 속성 권장사항](https://support.google.com/analytics/answer/9267735)
- [AnalyticsClient.swift 소스 코드](../Projects/Clients/Sources/Clients/AnalyticsClient.swift)
