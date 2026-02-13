import Foundation
import Testing
import ComposableArchitecture
import Clients
@testable import AppEntryFeature

@Suite("AppEntry.Feature 테스트")
@MainActor
struct AppEntryFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = AppEntry.Feature.State()

    #expect(state.splash == .visible)
    #expect(state.pendingDeeplink == nil)
    #expect(state.pendingUserForMain == nil)
    #expect(state.providerProfileImageURL == nil)
    #expect(state.updateAlert == nil)
  }

  @Test("초기 상태에서 destination은 auth")
  func initialState_destinationIsAuth() {
    let state = AppEntry.Feature.State()

    if case .auth = state.destination {
      // auth 상태 확인
    } else {
      Issue.record("destination이 auth가 아닙니다")
    }
  }

  // MARK: - Splash 테스트

  @Test("splashAnimationCompleted 시 splash hidden 설정")
  func splashAnimationCompleted_hidesSpash() async {
    var state = AppEntry.Feature.State()
    state.splash = .animatingOut

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    }

    await store.send(.view(.splashAnimationCompleted)) {
      $0.splash = .hidden
    }
  }

  // MARK: - Version Check 테스트

  @Test("onAppear 시 버전 체크 시작")
  func onAppear_startsVersionCheck() async {
    let store = TestStore(
      initialState: AppEntry.Feature.State()
    ) {
      AppEntry.Feature()
    } withDependencies: {
      $0.appConfigClient.checkVersion = { .upToDate }
      $0.authClient.isAuthenticated = { false }
      $0.authClient.currentUser = { nil }
      $0.deeplinkClient.pushNotificationTapStream = { AsyncStream { _ in } }
      $0.notificationClient.saveFCMToken = { _ in }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal.checkVersion)
    await store.receive(\.internal.versionCheckCompleted)
    await store.receive(\.internal.continueAppFlow)

    // continueAppFlow에서 startSessionCheck, subscribeFCMToken 등 트리거
    await store.receive(\.internal.startSessionCheck)
    await store.receive(\.internal.subscribeFCMToken)
    await store.receive(\.internal.subscribePushNotificationTap)
    await store.receive(\.internal.subscribeAppRestart)

    await store.receive(\.internal.sessionCheckResponse) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
      $0.splash = .animatingOut
    }

    await store.send(.internal(.cancelSubscriptions))
  }

  // MARK: - Update Alert 테스트

  @Test("강제 업데이트 필요 시 updateAlert 설정")
  func versionCheck_forceUpdate_setsAlert() async {
    let store = TestStore(
      initialState: AppEntry.Feature.State()
    ) {
      AppEntry.Feature()
    } withDependencies: {
      $0.appConfigClient.checkVersion = {
        .forceUpdate(currentVersion: "1.0.0", requiredVersion: "2.0.0")
      }
    }

    await store.send(.view(.onAppear))

    await store.receive(\.internal.checkVersion)

    await store.receive(\.internal.versionCheckCompleted) {
      $0.updateAlert = .forceUpdate(currentVersion: "1.0.0", requiredVersion: "2.0.0")
    }
  }

  @Test("선택 업데이트 나중에 탭 시 updateAlert 닫기 및 앱 진행")
  func updateAlert_laterTapped_forRecommendUpdate_closesAlert() async {
    var state = AppEntry.Feature.State()
    state.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
      $0.authClient.currentUser = { nil }
      $0.deeplinkClient.pushNotificationTapStream = { AsyncStream { _ in } }
      $0.notificationClient.saveFCMToken = { _ in }
    }

    await store.send(.updateAlert(.laterTapped)) {
      $0.updateAlert = nil
    }

    // continueAppFlow 체인
    await store.receive(\.internal.continueAppFlow)
    await store.receive(\.internal.startSessionCheck)
    await store.receive(\.internal.subscribeFCMToken)
    await store.receive(\.internal.subscribePushNotificationTap)
    await store.receive(\.internal.subscribeAppRestart)
    await store.receive(\.internal.sessionCheckResponse) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
      $0.splash = .animatingOut
    }

    await store.send(.internal(.cancelSubscriptions))
  }

  @Test("강제 업데이트 나중에 탭 시 아무 일도 안 함")
  func updateAlert_laterTapped_forForceUpdate_doesNothing() async {
    var state = AppEntry.Feature.State()
    state.updateAlert = .forceUpdate(currentVersion: "1.0.0", requiredVersion: "2.0.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    }

    await store.send(.updateAlert(.laterTapped))
    // forceUpdate에서는 laterTapped가 무시됨
  }

  // MARK: - FCM Token 저장 테스트

  @Test("fcmTokenSaved 시 아무 state 변경 없음")
  func fcmTokenSaved_noStateChange() async {
    let store = TestStore(
      initialState: AppEntry.Feature.State()
    ) {
      AppEntry.Feature()
    }

    await store.send(.internal(.fcmTokenSaved))
  }
}
