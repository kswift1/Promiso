# Notifications 도메인 마이그레이션

## Firestore / Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `users/{uid}.devices` 디바이스 upsert | `PUT /api/v1/devices` | ✅ 완료 |
| FCM 토큰 저장 | `PUT /api/v1/devices/{deviceId}/notification-endpoints/fcm` | ✅ 완료 |
| Push to Start 토큰 저장 | `PUT /api/v1/devices/{deviceId}/live-activity-endpoint` | ✅ 완료 |
| 현재 디바이스 등록 삭제 | `DELETE /api/v1/devices/{deviceId}` | ✅ 완료 |
| 알림 목록 조회 | `GET /api/v1/notifications?limit=&before=` | ✅ 완료 |
| 안 읽은 알림 개수 조회 | `GET /api/v1/notifications/unread-count` | ✅ 완료 |
| 단건 읽음 처리 | `PATCH /api/v1/notifications/{id}/read` | ✅ 완료 |
| 전체 읽음 처리 | `POST /api/v1/notifications/mark-all-read` | ✅ 완료 |
| 배치 삭제 | `POST /api/v1/notifications/delete-batch` | ✅ 완료 |
| 전체 삭제 | `DELETE /api/v1/notifications` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `NotificationClient.saveNotificationToken` | Rust devices API | ✅ Rust 고정 |
| `NotificationClient.deleteCurrentDeviceRegistration` | Rust devices API | ✅ Rust 고정 |
| `NotificationClient.saveLiveActivityPushToStartToken` | Rust devices API | ✅ Rust 고정 |
| `NotificationClient.getNotifications` | Rust notifications API | ✅ Rust 고정 |
| `NotificationClient.getUnreadCount` | Rust notifications API | ✅ Rust 고정 |
| `NotificationClient.markAsRead` | Rust notifications API | ✅ Rust 고정 |
| `NotificationClient.markAllAsRead` | Rust notifications API | ✅ Rust 고정 |
| `NotificationClient.deleteNotifications` | Rust notifications API | ✅ Rust 고정 |
| `NotificationClient.deleteAllNotifications` | Rust notifications API | ✅ Rust 고정 |
| 권한 요청 / 설정 열기 / 배지 반영 | iOS 시스템 API | ✅ 유지 |

메모:

- `NotificationClient`의 Firebase Auth / Firestore fallback은 제거됐다.
- 일반 알림 토큰은 계속 FCM registration token을 사용하지만, 저장과 조회는 Rust `devices` 경로를 통해 처리한다.
- `unread` 필터는 현재 Rust API가 서버 필터를 아직 제공하지 않아 클라이언트에서 후처리한다.

## 남은 항목

- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- 코드 정리:
  - `NotificationRemoteDataSource` 삭제
  - `useRustAPI(.notifications)` 잔재 0
  - `rust_api_notifications` 잔재 0
- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
