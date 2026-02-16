# Toast/Snackbar 구현 완료

> 브랜치: `feat/toast-snackbar`
> 최종 업데이트: 2026-02-15

---

## 1. 기본 원칙

### Toast vs Push Notification 구분

| 구분 | Toast | Push/Local Notification |
|------|-------|------------------------|
| **대상** | 액션을 수행한 본인 | 다른 사용자 (그룹 멤버 등) |
| **시점** | 즉시 (액션 직후) | 비동기 (서버 처리 후) |
| **용도** | 액션 결과 피드백 | 이벤트 알림 |
| **예시** | "약속 삭제에 실패했어요" | "OOO님이 약속에 수락했습니다" |

**절대 겹치지 않는 이유**: Toast는 "내가 한 일의 결과"를, Push는 "남이 한 일의 알림"을 보여줌

### Toast 최종 적용 기준

- **적용 O**: 에러 발생 시, 권한 거부 시
- **적용 X**: 성공 피드백 (화면 전환으로 충분), 확인 다이얼로그 (`.alert()` 유지)

### 공통 패턴

```swift
// State
var toastMessage: ToastMessage?

// ViewAction
case toastDismissed

// Reducer
case .view(.toastDismissed):
  state.toastMessage = nil
  return .none

// View (.toast modifier)
.toast(Binding(
  get: { store.toastMessage },
  set: { _ in store.send(.view(.toastDismissed)) }
))

// Position: 전체 .bottom 통일
```

---

## 2. 완료된 작업

### 커밋 내역

| 커밋 | 타입 | 내용 |
|------|------|------|
| `ac4df2c` | feat | ToastView 컴포넌트 추가 (Glass Effect + Haptic) |
| `26872d8` | fix | 스와이프 dismiss 제스처 개선 |
| `b5ff1f9` | feat | 11개 Feature에 토스트 통합 (Phase 1) |
| `04694e2` | feat | PromiseDetailFeature 추가 (Phase 2) |
| `fc2f7e4` | refactor | 73% 축소 - 에러/경고만 유지 (Phase 3) |

### 최종 적용 현황 (12개 유지)

| Feature | Toast | 타입 |
|---------|-------|------|
| **GroupSettingsFeature** | 알림 권한 거부 | warning |
| **GroupSettingsFeature** | 알림 설정 실패 | error |
| **GroupSettingsFeature** | 멤버 추방 실패 | error |
| **NotificationCenterFeature** | 읽음 처리 실패 | error |
| **NotificationCenterFeature** | 삭제 실패 | error |
| **SettingsFeature** | 로그아웃 실패 | error |
| **SettingsFeature** | 프로필 저장 실패 | error |
| **PersonalFeature** | 일정 삭제 실패 | error |
| **AccountInfoView** | 계정 삭제 실패 | error |
| **CalendarSettingsFeature** | 캘린더 권한 거부 | warning |
| **PromiseDetailFeature** | 응답 전송 실패 | error |
| **PromiseDetailFeature** | 약속 삭제 실패 | error |

---

## 3. Push Notification 목록 (참고)

> Toast와 겹치지 않음을 확인

| Push 타입 | 발생 시점 | 수신 대상 | Toast 충돌 |
|----------|----------|----------|-----------|
| `promise_invitation` | 약속 생성 | 그룹 멤버 (생성자 제외) | X |
| `promise_confirmed` | 약속 확정 | 수락 멤버 전체 | X |
| `promise_cancelled` | 약속 취소 | 그룹 멤버 전체 | X |
| `promise_updated` | 약속 수정 | 참여자 전체 | X |
| `promise_reminder` | 스케줄 리마인더 | 수락 참여자 | X |
| `attendance_response` | 참석 응답 | 약속 호스트만 | X |
| `group_invitation` | 멤버 참여 | 기존 멤버 | X |
| `group_update` | 그룹 설정 변경 | 그룹 멤버 | X |
| `personal_event_reminder` | 로컬 리마인더 | 본인만 | X |

---

## 4. 변경 모듈

```
Shared (ToastView.swift) ← 신규 컴포넌트
  ↑
CalendarFeature
GroupFeature (GroupMain + GroupSettings)
HomeFeature
NotificationCenterFeature
PersonalFeature
SettingsFeature (AccountInfo + CalendarSettings + NotificationSettings + Settings + Support)
SharedFeature (PromiseDetail)
```
