# Deeplink 가이드

## 개요

Promiso 앱의 딥링크 처리 아키텍처와 구현 방법을 정의합니다.

---

## 딥링크 타입

### DeeplinkDestination (Clients 모듈)

URL/푸시 파싱 결과를 담는 타입:

| 타입 | 설명 | 예시 |
|------|------|------|
| `promise` | 약속 상세 화면 | promiseId + groupId 필요 |
| `group` | 그룹 상세 화면 | groupId 필요 |
| `joinGroup` | 그룹 참여 (초대 코드) | inviteCode 필요 |
| `liveActivityETA` | LiveActivity ETA 변경 시트 | promiseId 필요 |
| `livePromise` | LivePromise 상세 화면 | promiseId 필요 |
| `create` | 약속 만들기 화면 | 파라미터 없음 (그룹 있을 때만 동작) |

### GroupMain.Deeplink (GroupFeature 모듈)

그룹 탭에서 처리하는 딥링크:

| 타입 | 설명 |
|------|------|
| `group(groupId:)` | 그룹 상세 화면 |
| `promise(promiseId:groupId:)` | 약속 상세 화면 |

---

## URL 스킴

### 지원 URL 형식

| URL 패턴 | DeeplinkDestination | 설명 |
|----------|---------------------|------|
| `promiso://join/{inviteCode}` | `.joinGroup(inviteCode:)` | 초대 코드로 그룹 참여 |
| `promiso://group/{groupId}` | `.group(groupId:)` | 그룹 상세 화면 |
| `promiso://promise/{promiseId}/{groupId}` | `.promise(promiseId:groupId:)` | 약속 상세 화면 |
| `promiso://promise/{promiseId}/eta` | `.liveActivityETA(promiseId:)` | LiveActivity ETA 변경 시트 |
| `promiso://live/{promiseId}` | `.livePromise(promiseId:)` | LivePromise 상세 화면 |
| `promiso://create` | `.create` | 약속 만들기 화면 (Widget용) |

### 예시

```
promiso://join/ABC123
promiso://group/group_123456
promiso://promise/promise_789/group_123456
promiso://promise/promise_789/eta
promiso://live/promise_789
promiso://create
```

---

## 아키텍처

### 흐름도

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   AppDelegate   │────▶│  DeeplinkClient  │────▶│ AppEntryFeature │
│  (URL/Push)     │     │   (파싱/스트림)   │     │  (라우팅)        │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │                           │
                              ▼                           ▼
                        DeeplinkDestination        GroupMain.Deeplink
                        (파싱 결과)                (탭별 딥링크)
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │  RootTabFeature │
                                                 │  (탭 전환)       │
                                                 └─────────────────┘
                                                          │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │ GroupMainFeature│
                                                 │  (화면 이동)     │
                                                 └─────────────────┘
```

### 타입 변환 흐름

```
DeeplinkDestination (Clients)
    ↓ AppEntryFeature에서 변환
GroupMain.Deeplink (GroupFeature)
    ↓ RootTabFeature를 통해 전달
GroupMainFeature에서 처리
```

### 컴포넌트 역할

| 컴포넌트 | 역할 |
|----------|------|
| `AppDelegate` | URL 스킴 수신, 푸시 알림 탭 감지, NotificationCenter로 전달 |
| `DeeplinkClient` | URL/푸시 데이터 파싱, `DeeplinkDestination` 반환 |
| `AppEntryFeature` | 딥링크 수신, `GroupMain.Deeplink`로 변환, pending 관리 |
| `RootTabFeature` | 탭 전환, `handleGroupDeeplink` 액션으로 전달 |
| `GroupMainFeature` | `GroupMain.Deeplink` 처리, 그룹/약속 네비게이션 |

---

## DeeplinkClient

### 위치

`Projects/Clients/Sources/Clients/DeeplinkClient.swift`

### API

```swift
public struct DeeplinkClient: Sendable {
  /// 푸시 알림 탭 이벤트 스트림
  public var pushNotificationTapStream: @Sendable () -> AsyncStream<DeeplinkDestination>

  /// URL 딥링크 파싱
  public var parseURL: @Sendable (_ url: URL) -> DeeplinkDestination?

  /// 푸시 알림 데이터에서 딥링크 목적지 파싱
  public var parseNotification: @Sendable (_ data: PushNotificationData) -> DeeplinkDestination?
}
```

### 사용 예시

```swift
@Reducer
public struct Feature {
  @Dependency(\.deeplinkClient) var deeplinkClient

  // URL 딥링크 처리
  case .handleDeeplink(let url):
    guard let destination = deeplinkClient.parseURL(url) else {
      return .none
    }
    // destination 처리...

  // 푸시 알림 탭 구독
  case .subscribePushNotificationTap:
    return .run { send in
      for await destination in deeplinkClient.pushNotificationTapStream() {
        await send(.internal(.pushNotificationTapped(destination)))
      }
    }
}
```

---

## 푸시 알림 딥링크

### FCM Payload 데이터

```json
{
  "type": "promise_invitation",
  "promiseId": "promise_123",
  "groupId": "group_456"
}
```

### 딥링크 매핑

| NotificationType.deeplinkGuide | promiseId | groupId | DeeplinkDestination |
|--------------------------------|-----------|---------|---------------------|
| `promiseAndGroup` | O | O | `.promise(promiseId:groupId:)` |
| `groupOnly` | X | O | `.group(groupId:)` |
| `none` | X | X | nil (무시) |

### 타입별 동작

| NotificationType | 이동 화면 |
|------------------|----------|
| `promise_invitation` | 약속 상세 |
| `promise_confirmed` | 약속 상세 |
| `promise_cancelled` | 약속 상세 |
| `promise_updated` | 약속 상세 |
| `promise_reminder` | 약속 상세 |
| `attendance_response` | 약속 상세 |
| `group_invitation` | 그룹 상세 |
| `group_update` | 그룹 상세 |
| `system` | 이동 없음 |

---

## Pending 딥링크 처리

앱이 아직 메인 화면으로 전환되지 않은 상태에서 딥링크가 수신되면, `pendingDeeplink`에 저장 후 메인 화면 준비 시 처리합니다.

### 처리 시점

1. 앱 시작 시 (cold start)
2. 로그인 완료 후
3. 프로필 설정 완료 후

### 코드 예시

```swift
// AppEntryFeature.swift

@ObservableState
public struct State {
  /// 앱이 준비되기 전 수신된 딥링크
  var pendingDeeplink: DeeplinkDestination?
}

case .profileCheckResponse(let user, let profile):
  if let userModel = profile {
    state.destination = .main(RootTab.Feature.State(currentUser: userModel))

    // pending deeplink 처리
    if let deeplink = state.pendingDeeplink {
      state.pendingDeeplink = nil
      switch deeplink {
      case .promise(let promiseId, let groupId):
        return .send(.destination(.presented(.main(.handleDeeplink(...)))))
      case .group(let groupId):
        return .send(.destination(.presented(.main(.handleDeeplink(...)))))
      case .joinGroup(let inviteCode):
        return .send(.destination(.presented(.main(.openJoinGroupWithCode(...)))))
      }
    }
  }
```

---

## 테스트 방법

### URL 스킴 테스트

```bash
# 시뮬레이터에서 테스트
xcrun simctl openurl booted "promiso://join/ABC123"
xcrun simctl openurl booted "promiso://group/group_123"
xcrun simctl openurl booted "promiso://promise/promise_456/group_123"
xcrun simctl openurl booted "promiso://create"
```

### 푸시 알림 테스트

1. Firebase Console → Cloud Messaging → 테스트 메시지
2. Additional options에 data 추가:
   - `type`: `promise_invitation`
   - `promiseId`: `test_promise_id`
   - `groupId`: `test_group_id`

---

## 관련 파일

| 파일 | 설명 |
|------|------|
| `Projects/Clients/Sources/Clients/DeeplinkClient.swift` | 딥링크 클라이언트 |
| `Projects/Features/AppEntryFeature/Sources/AppEntryFeature.swift` | 앱 진입점, 딥링크 수신 |
| `Projects/Features/RootTabFeature/Sources/RootTabFeature.swift` | 탭 전환 처리 |
| `Projects/Features/GroupFeature/Sources/GroupMain/GroupMainFeature.swift` | 그룹/약속 네비게이션 |
| `Projects/App/Sources/AppDelegate.swift` | URL/푸시 수신 |
| `Projects/Shared/Sources/Constants/AppConstants.swift` | 알림 이름 정의 |

---

## 주의사항

1. **URL 스킴 등록**: Info.plist에 `promiso` URL 스킴이 등록되어 있어야 함
2. **Associated Domains**: Universal Links 사용 시 apple-app-site-association 설정 필요
3. **백그라운드 처리**: 앱이 백그라운드일 때 수신된 딥링크는 앱 활성화 시 처리됨
4. **인증 상태**: 미인증 상태에서 딥링크 수신 시 `pendingDeeplink`에 저장 후 로그인 완료 시 처리
5. **LiveActivity 딥링크**: `liveActivityETA`/`livePromise`는 RootTabFeature에서 처리
