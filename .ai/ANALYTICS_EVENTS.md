# Analytics Events

Firebase Analytics에 로깅되는 이벤트 목록.
Firebase Console > Analytics > Events에서 확인 가능.

---

## 그룹 생성 퍼널

유저가 그룹을 생성하는 과정을 단계별로 추적.

```
screen_view(create_group) → group_create_tapped → group_create_succeeded → group_create_settings_completed → group_created
                                                 ↘ group_create_failed
                          ↘ group_create_cancelled (어느 단계에서든)
```

| 이벤트                             | 설명                    | 파라미터                              | 트리거 시점                    |
|------------------------------------|-------------------------|---------------------------------------|-------------------------------|
| `screen_view`                      | 그룹 생성 화면 진입     | `screen_name`: "create_group"         | CreateGroupView onAppear      |
| `group_create_tapped`              | "그룹 만들기" 버튼 탭   | -                                     | 폼 제출 (API 호출 직전)       |
| `group_create_succeeded`           | API 호출 성공           | `group_id`, `group_name`              | 서버에서 그룹 생성 완료       |
| `group_create_failed`              | API 호출 실패           | `error_message`                       | 서버 에러 발생                |
| `group_create_settings_completed`  | 초기 설정 완료          | `group_id`                            | 설정 화면에서 "완료" 탭       |
| `group_created`                    | 성공 화면 확인          | `group_id`, `group_name`              | "일정 생성하러 가기" 탭       |
| `group_create_cancelled`           | 플로우 이탈             | `step`: input/settings/success        | X 버튼 탭                     |

### 퍼널 분석 쿼리 가이드

Firebase Console에서 확인할 포인트:

1. **진입 대비 시도율**: `screen_view(create_group)` → `group_create_tapped`
   - 낮으면: 폼 UI/UX 문제 (입력 허들)
2. **시도 대비 성공율**: `group_create_tapped` → `group_create_succeeded`
   - 낮으면: API/네트워크 오류 (`group_create_failed`의 `error_message` 확인)
3. **설정 완료율**: `group_create_succeeded` → `group_create_settings_completed`
   - 낮으면: 설정 화면에서 이탈
4. **최종 완료율**: `group_create_settings_completed` → `group_created`
   - 낮으면: 성공 화면에서 이탈 (앱 종료 등)
5. **이탈 지점**: `group_create_cancelled`의 `step` 파라미터로 어느 단계에서 이탈하는지 확인

---

## 핵심 비즈니스 이벤트

| 이벤트                  | 설명             | 파라미터                          |
|-------------------------|------------------|-----------------------------------|
| `user_signup`           | 회원가입         | `login_method`?                   |
| `user_login`            | 로그인           | `login_method`?                   |
| `group_created`         | 그룹 생성 확인   | `group_id`, `group_name`          |
| `group_joined`          | 그룹 참여        | `group_id`, `group_name`          |
| `schedule_created`      | 일정 생성        | `schedule_id`, `schedule_title`   |
| `schedule_response_yes` | 일정 참여 응답   | `schedule_id`, `schedule_title`   |
| `schedule_response_no`  | 일정 불참 응답   | `schedule_id`, `schedule_title`   |

## 사용자 행동 이벤트

| 이벤트                        | 설명                  | 파라미터                                                       |
|-------------------------------|-----------------------|----------------------------------------------------------------|
| `profile_setup_completed`     | 프로필 설정 완료      | -                                                              |
| `group_invite_shared`         | 초대 시트 열기        | `group_id`, `group_name`                                       |
| `group_invite_link_shared`    | 초대 링크 공유        | `group_id`, `group_name`, `share_method`, `schedule_count`?    |
| `settings_opened`             | 설정 화면 열기        | -                                                              |
| `schedule_share_sheet_opened` | 일정 공유 시트 열기   | `schedule_id`, `schedule_title`                                |
| `schedule_link_shared`        | 일정 링크 공유        | `schedule_id`, `schedule_title`, `share_method`                |

## 페이월 이벤트

| 이벤트             | 설명          | 파라미터           |
|--------------------|---------------|--------------------|
| `paywall_open`     | 페이월 열기   | `has_intro_offer`  |
| `paywall_purchase` | 구매 완료     | `product_id`       |
| `paywall_restore`  | 구매 복원     | -                  |
| `paywall_close`    | 페이월 닫기   | -                  |

## 알림 이벤트

| 이벤트                                | 설명              | 파라미터 |
|---------------------------------------|-------------------|----------|
| `notification_permission_requested`   | 알림 권한 요청    | -        |
| `notification_permission_granted`     | 알림 권한 허용    | -        |
| `notification_permission_denied`      | 알림 권한 거부    | -        |

## 유저 속성

| 속성                              | 설명              | 값                                                                         |
|-----------------------------------|-------------------|----------------------------------------------------------------------------|
| `nickname`                        | 닉네임            | string                                                                     |
| `auth_provider`                   | 인증 제공자       | string                                                                     |
| `subscription_tier`               | 구독 등급         | "pro" / "free"                                                             |
| `notification_permission_status`  | 알림 권한         | "not_determined" / "denied" / "authorized" / "provisional" / "ephemeral"  |
| `has_group`                       | 그룹 보유 여부    | "true" / "false"                                                           |
| `group_count_bucket`              | 그룹 수 구간      | "0" / "1" / "2_4" / "5_plus"                                              |
| `calendar_sync_enabled`           | 캘린더 동기화     | "true" / "false"                                                           |
