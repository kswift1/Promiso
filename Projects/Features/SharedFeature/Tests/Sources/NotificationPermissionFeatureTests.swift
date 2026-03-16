import Testing
@testable import SharedFeature

@Suite("NotificationPermission.Feature reducer 테스트")
@MainActor
struct NotificationPermissionFeatureTests {

  @Test("onAppear 시 현재 권한 상태를 로드하고 버튼 상태를 갱신한다")
  func onAppear_loadsAuthorizationStatus() async {
    let userProperties = LockIsolated<[String: String]>([:])

    let store = TestStore(initialState: NotificationPermission.Feature.State()) {
      NotificationPermission.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .denied }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.analyticsClient.setUserProperty = { value, key in
        if let value {
          userProperties.withValue { $0[key] = value }
        }
      }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal) {
      $0.authorizationStatus = .denied
    }

    #expect(store.state.primaryButtonTitle == LocalizedStrings.Shared.goToSettings)
    #expect(store.state.showSecondaryButton == false)
    #expect(
      userProperties.value[AnalyticsClient.UserPropertyKey.notificationPermissionStatus.rawValue] == "denied"
    )
  }

  @Test("권한이 이미 허용된 상태에서 primaryButtonTapped 시 완료 delegate를 보낸다")
  func primaryButtonTapped_whenAuthorized_sendsDelegates() async {
    var state = NotificationPermission.Feature.State()
    state.authorizationStatus = .authorized

    let store = TestStore(initialState: state) {
      NotificationPermission.Feature()
    }

    await store.send(.view(.primaryButtonTapped))
    await store.receive(\.delegate)
    await store.receive(\.delegate)
  }

  @Test("권한이 거부된 상태에서 primaryButtonTapped 시 설정 화면을 연다")
  func primaryButtonTapped_whenDenied_opensSettings() async {
    let settingsOpened = LockIsolated(false)

    var state = NotificationPermission.Feature.State()
    state.authorizationStatus = .denied

    let store = TestStore(initialState: state) {
      NotificationPermission.Feature()
    } withDependencies: {
      $0.notificationClient.openNotificationSettings = {
        settingsOpened.setValue(true)
      }
    }

    await store.send(.view(.primaryButtonTapped))
    await store.finish()

    #expect(settingsOpened.value == true)
  }

  @Test("권한 미결정 상태에서 primaryButtonTapped 시 요청 결과를 반영하고 닫는다")
  func primaryButtonTapped_whenNotDetermined_requestsPermission() async {
    let loggedEvents = LockIsolated<[String]>([])
    let userProperties = LockIsolated<[String: String]>([:])

    let store = TestStore(initialState: NotificationPermission.Feature.State()) {
      NotificationPermission.Feature()
    } withDependencies: {
      $0.notificationClient.requestAuthorization = { true }
      $0.analyticsClient.logEvent = { name, _ in
        loggedEvents.withValue { $0.append(name) }
      }
      $0.analyticsClient.setUserProperty = { value, key in
        if let value {
          userProperties.withValue { $0[key] = value }
        }
      }
    }

    await store.send(.view(.primaryButtonTapped))
    await store.receive(\.internal) {
      $0.authorizationStatus = .authorized
    }
    await store.receive(\.delegate)
    await store.receive(\.delegate)

    #expect(loggedEvents.value == [
      AnalyticsClient.EventName.notificationPermissionRequested,
      AnalyticsClient.EventName.notificationPermissionGranted
    ])
    #expect(
      userProperties.value[AnalyticsClient.UserPropertyKey.notificationPermissionStatus.rawValue] == "authorized"
    )
  }

  @Test("설정에서 돌아와 권한이 허용되면 자동으로 완료 처리한다")
  func authorizationStatusLoaded_afterDeniedAndGranted_autoDismisses() async {
    let userProperties = LockIsolated<[String: String]>([:])

    var state = NotificationPermission.Feature.State()
    state.authorizationStatus = .denied

    let store = TestStore(initialState: state) {
      NotificationPermission.Feature()
    } withDependencies: {
      $0.analyticsClient.logEvent = { _, _ in }
      $0.analyticsClient.setUserProperty = { value, key in
        if let value {
          userProperties.withValue { $0[key] = value }
        }
      }
    }

    await store.send(.internal(.authorizationStatusLoaded(.authorized))) {
      $0.authorizationStatus = .authorized
    }
    await store.receive(\.delegate)
    await store.receive(\.delegate)

    #expect(
      userProperties.value[AnalyticsClient.UserPropertyKey.notificationPermissionStatus.rawValue] == "authorized"
    )
  }
}
