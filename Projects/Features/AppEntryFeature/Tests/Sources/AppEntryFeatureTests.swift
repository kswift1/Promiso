import Foundation
import Testing
import ExternalDependency
import Clients
import PromisoShared
import Sharing
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

  @Test("onAppear 시 선택 업데이트 필요하면 recommendAlert 설정")
  func onAppear_recommendUpdate_setsAlert() async {
    let store = TestStore(
      initialState: AppEntry.Feature.State()
    ) {
      AppEntry.Feature()
    } withDependencies: {
      $0.appConfigClient.checkVersion = {
        .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")
      }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal.checkVersion)
    await store.receive(\.internal.versionCheckCompleted) {
      $0.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")
    }
  }

  @Test("scene active + updateAlert 있음 시 앱스토어 복귀 버전 재체크")
  func sceneActive_withUpdateAlert_rechecksVersion() async {
    var state = AppEntry.Feature.State()
    state.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.appConfigClient.checkVersionForced = { .upToDate }
      $0.authClient.isAuthenticated = { false }
      $0.authClient.currentUser = { nil }
      $0.deeplinkClient.pushNotificationTapStream = { AsyncStream { _ in } }
      $0.notificationClient.saveFCMToken = { _ in }
    }

    await store.send(.view(.scenePhaseChanged(.active)))
    await store.receive(\.internal.recheckVersionAfterAppStore)
    await store.receive(\.internal.versionCheckCompleted) {
      $0.updateAlert = nil
    }
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

  @Test("scene inactive 시 버전 재체크 안 함")
  func sceneInactive_doesNotRecheckVersion() async {
    var state = AppEntry.Feature.State()
    state.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    }

    await store.send(.view(.scenePhaseChanged(.inactive)))
  }

  @Test("sessionCheckResponse 인증됨이면 profileCheck 시작")
  func sessionCheck_authenticated_startsProfileCheck() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.currentUser = { nil }
    }

    await store.send(.internal(.sessionCheckResponse(isAuthenticated: true)))
    await store.receive(\.internal.startProfileCheck)
  }

  @Test("startProfileCheck currentUser=nil 이면 종료")
  func startProfileCheck_withoutUser_doesNothing() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.currentUser = { nil }
    }

    await store.send(.internal(.startProfileCheck))
  }

  @Test("startProfileCheck currentUser 존재 시 profileCheckResponse 처리")
  func startProfileCheck_withUser_processesProfileResponse() async {
    let firebaseUser = makeFirebaseUser(uid: "firebase-existing")
    let user = makeUser(id: "existing-user", nickname: "기존프로필")

    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.currentUser = { firebaseUser }
      $0.userProfileClient.getPrivateProfile = { _ in user }
      $0.clarityClient.setUser = { _, _ in }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.startProfileCheck))
    await store.receive(\.internal.profileCheckResponse)
    #expect(store.state.destinationType == .main)
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

  @Test("updateTapped 시 App Store URL 오픈")
  func updateAlert_updateTapped_opensAppStoreURL() async {
    let recorder = URLRecorder()
    var state = AppEntry.Feature.State()
    state.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.openURL = .init { url in
        await recorder.record(url)
        return true
      }
    }

    await store.send(.updateAlert(.updateTapped))
    #expect(await recorder.value() == AppConstants.App.appStoreURL)
  }

  // MARK: - Profile / Permission 플로우 테스트

  @Test("auth 로그인 delegate 수신 시 providerProfileImage 저장 후 profileCheck 시작")
  func authLoggedIn_delegate_setsProviderProfileAndStartsProfileCheck() async {
    let profileImageURL = URL(string: "https://example.com/profile.png")!

    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.currentUser = { nil }
    }

    await store.send(.destination(.presented(.auth(.delegate(.loggedIn(providerProfileImageURL: profileImageURL)))))) {
      $0.providerProfileImageURL = profileImageURL
    }
    await store.receive(\.internal.startProfileCheck)
  }

  @Test("profileCheckResponse 기존 사용자면 메인 전환 및 pending 딥링크 처리")
  func profileCheck_existingUser_routesToMainAndProcessesPendingDeeplink() async {
    var state = AppEntry.Feature.State()
    state.pendingDeeplink = .livePromise(promiseId: "p-1")
    state.splash = .visible

    let user = makeUser(id: "user-main", nickname: "기존유저")
    let firebaseUser = makeFirebaseUser(uid: "firebase-main")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _, _ in }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileCheckResponse(user: firebaseUser, profile: user)))
    #expect(store.state.splash == .animatingOut)
    #expect(store.state.pendingDeeplink == nil)
    #expect(store.state.destinationType == .main)
    await store.receive(\.destination.presented.main.openLivePromiseDetail)
  }

  @Test("profileCheckResponse 신규 사용자면 profile setup으로 전환")
  func profileCheck_newUser_routesToProfileSetup() async {
    var state = AppEntry.Feature.State()
    state.splash = .visible
    state.providerProfileImageURL = URL(string: "https://example.com/provider-profile.png")

    let firebaseUser = makeFirebaseUser(
      uid: "firebase-new",
      displayName: "신규 사용자",
      photoURL: nil
    )

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    }

    await store.send(.internal(.profileCheckResponse(user: firebaseUser, profile: nil))) {
      var expectedProfile = AppEntry.ProfileSetup.State()
      expectedProfile.inject(user: firebaseUser, providerProfileImageURL: URL(string: "https://example.com/provider-profile.png"))
      $0.destination = .profile(expectedProfile)
      $0.splash = .animatingOut
    }
  }

  @Test("profile 완료 delegate 수신 시 알림 권한 체크 시작")
  func profileCompleted_delegate_startsNotificationPermissionCheck() async {
    let user = makeUser(id: "signup-user", nickname: "회원가입유저")
    var state = AppEntry.Feature.State()
    state.destination = .profile(AppEntry.ProfileSetup.State())

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.analyticsClient.logEvent = { _, _ in }
      $0.notificationClient.getAuthorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.profile(.delegate(.completed(user)))))) 
    await store.receive(\.internal.checkNotificationPermission)
    await store.receive(\.internal.notificationPermissionChecked) {
      $0.pendingUserForMain = user
      $0.notificationPermission = NotificationPermission.Feature.State()
    }
  }

  @Test("checkNotificationPermission 액션은 권한 상태 조회 후 checked 액션 전달")
  func checkNotificationPermission_sendsCheckedResult() async {
    let user = makeUser(id: "permission-user", nickname: "권한유저")

    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .denied }
    }

    await store.send(.internal(.checkNotificationPermission(user)))
    await store.receive(\.internal.notificationPermissionChecked) {
      $0.pendingUserForMain = user
      $0.notificationPermission = NotificationPermission.Feature.State()
    }
  }

  @Test("notificationPermissionChecked 허용 시 메인 전환 및 pending 딥링크 처리")
  func notificationPermissionChecked_authorized_routesMainAndPendingDeeplink() async {
    let user = makeUser(id: "permission-ok", nickname: "권한완료")
    var state = AppEntry.Feature.State()
    state.pendingDeeplink = .livePromise(promiseId: "live-1")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.notificationPermissionChecked(isAuthorized: true, user: user)))
    #expect(store.state.pendingDeeplink == nil)
    #expect(store.state.destinationType == .main)
    await store.receive(\.destination.presented.main.openLivePromiseDetail)
  }

  @Test("notificationPermissionChecked 미허용 시 온보딩 표시")
  func notificationPermissionChecked_denied_showsOnboarding() async {
    let user = makeUser(id: "permission-denied", nickname: "권한거부")

    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    }

    await store.send(.internal(.notificationPermissionChecked(isAuthorized: false, user: user))) {
      $0.pendingUserForMain = user
      $0.notificationPermission = NotificationPermission.Feature.State()
    }
  }

  @Test("notificationPermission dismiss 시 pendingUser로 메인 전환")
  func notificationPermissionDismissed_movesToMainWithPendingUser() async {
    let user = makeUser(id: "pending-user", nickname: "대기유저")
    var state = AppEntry.Feature.State()
    state.pendingUserForMain = user
    state.notificationPermission = NotificationPermission.Feature.State()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _, _ in }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.notificationPermission(.presented(.delegate(.dismissed))))
    #expect(store.state.notificationPermission == nil)
    #expect(store.state.pendingUserForMain == nil)
    #expect(store.state.destinationType == .main)
  }

  @Test("logoutRequested delegate 수신 시 auth로 전환")
  func logoutRequested_movesToAuth() async {
    let state = makeMainState()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.notificationClient.deleteFCMToken = { }
      $0.authClient.logout = { }
      $0.authClient.clearWidgetAuthToken = { }
      $0.clarityClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
    }

    await store.send(.destination(.presented(.main(.delegate(.logoutRequested))))) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
    }
  }

  @Test("logoutRequested 시 토큰 삭제/로그아웃 실패해도 auth 전환 유지")
  func logoutRequested_failureInCleanup_stillMovesToAuth() async {
    enum LogoutError: Error { case failed }

    let state = makeMainState()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.notificationClient.deleteFCMToken = { throw LogoutError.failed }
      $0.authClient.logout = { throw LogoutError.failed }
      $0.authClient.clearWidgetAuthToken = { }
      $0.clarityClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
    }

    await store.send(.destination(.presented(.main(.delegate(.logoutRequested))))) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
    }
  }

  // MARK: - App Restart 테스트

  @Test("appRestartRequested 시 상태 초기화 후 sessionCheck 시작")
  func appRestartRequested_resetsStateAndStartsSessionCheck() async {
    let firstUser = makeUser(id: "first-user", nickname: "기존")
    let secondUser = makeUser(id: "second-user", nickname: "대기")
    var state = makeMainState(user: firstUser)
    state.splash = .hidden
    state.pendingDeeplink = .group(groupId: "g-1")
    state.pendingUserForMain = secondUser
    state.providerProfileImageURL = URL(string: "https://example.com/temp.png")
    state.notificationPermission = NotificationPermission.Feature.State()

    KoreanDateFormatters.use24HourFormat = false

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.authClient.isAuthenticated = { false }
    }

    await store.send(.internal(.appRestartRequested)) {
      $0.splash = .visible
      $0.destination = nil
      $0.pendingDeeplink = nil
      $0.pendingUserForMain = nil
      $0.providerProfileImageURL = nil
      $0.notificationPermission = nil
    }
    #expect(KoreanDateFormatters.use24HourFormat == true)

    await store.receive(\.internal.startSessionCheck)
    await store.receive(\.internal.sessionCheckResponse) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
      $0.splash = .animatingOut
    }
  }

  @Test("subscribeAppRestart 구독 중 재시작 알림 수신 시 appRestartRequested 전달")
  func subscribeAppRestart_receivesRestartNotification() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.authClient.isAuthenticated = { false }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.subscribeAppRestart))
    await Task.yield()

    NotificationCenter.default.post(name: AppConstants.Notifications.appRestartRequested, object: nil)

    await store.receive(\.internal.appRestartRequested)
    await store.receive(\.internal.startSessionCheck)
    await store.receive(\.internal.sessionCheckResponse)

    await store.send(.internal(.cancelSubscriptions))
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

  @Test("fcmTokenReceived 인증 상태면 저장 후 fcmTokenSaved")
  func fcmTokenReceived_authenticated_savesAndEmitsSaved() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { true }
      $0.notificationClient.saveFCMToken = { _ in }
    }

    await store.send(.internal(.fcmTokenReceived("token-1")))
    await store.receive(\.internal.fcmTokenSaved)
  }

  @Test("fcmTokenReceived 비인증 상태면 저장 시도 안 함")
  func fcmTokenReceived_unauthenticated_doesNotSave() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
      $0.notificationClient.saveFCMToken = { _ in }
    }

    await store.send(.internal(.fcmTokenReceived("token-2")))
  }

  @Test("fcmTokenReceived 저장 실패 시 fcmTokenSaved 미전달")
  func fcmTokenReceived_saveFailure_doesNotEmitSaved() async {
    enum SaveError: Error { case failed }

    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { true }
      $0.notificationClient.saveFCMToken = { _ in throw SaveError.failed }
    }

    await store.send(.internal(.fcmTokenReceived("token-3")))
  }

  @Test("subscribeFCMToken 구독 중 알림 수신 시 fcmTokenReceived 전달")
  func subscribeFCMToken_receivesNotificationToken() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
      $0.notificationClient.saveFCMToken = { _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.subscribeFCMToken))
    await Task.yield()

    NotificationCenter.default.post(
      name: AppConstants.Notifications.fcmTokenDidReceive,
      object: nil,
      userInfo: ["token": "stream-token"]
    )

    await store.receive(\.internal.fcmTokenReceived)
    await store.send(.internal(.cancelSubscriptions))
  }

  // MARK: - State Helper 테스트

  @Test("destinationType 계산 값 확인")
  func destinationType_matchesDestinationState() {
    var state = AppEntry.Feature.State()
    #expect(state.destinationType == .auth)

    state.destination = .profile(AppEntry.ProfileSetup.State())
    #expect(state.destinationType == .profile)

    @Shared(.inMemory("destination-type-main-user")) var user = makeUser(id: "dest-main")
    state.destination = .main(RootTab.Feature.State(currentUser: $user))
    #expect(state.destinationType == .main)

    state.destination = nil
    #expect(state.destinationType == nil)
  }

  @Test("ProfileSetup inject 시 displayName=nil 이면 빈 문자열로 설정")
  func profileSetupInject_withoutDisplayName_usesEmptyString() {
    var profileState = AppEntry.ProfileSetup.State()
    profileState.inject(user: makeFirebaseUser(displayName: nil), providerProfileImageURL: nil)

    #expect(profileState.fullName == "")
    #expect(profileState.nickname == "")
  }
}

private extension AppEntryFeatureTests {
  
  actor URLRecorder {
    private(set) var capturedURL: URL?
    
    func record(_ url: URL) {
      self.capturedURL = url
    }
    
    func value() -> URL? {
      capturedURL
    }
  }
  
  func makeUser(
    id: String = "user-1",
    name: String = "테스트",
    nickname: String = "테스터"
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: id,
      name: name,
      nickname: nickname,
      email: "\(id)@example.com",
      provider: "google",
      metadata: .init()
    )
  }
  
  func makeFirebaseUser(
    uid: String = "firebase-1",
    displayName: String? = "Firebase User",
    photoURL: URL? = nil
  ) -> FirebaseUserSnapshot {
    FirebaseUserSnapshot(
      uid: uid,
      email: "\(uid)@example.com",
      displayName: displayName,
      photoURL: photoURL,
      providerId: "google.com",
      providerUid: "provider-\(uid)",
      providerType: "google"
    )
  }
  
  func makeMainState(user: UserPrivateModel = UserPrivateModel(
    userId: "main-user",
    name: "메인",
    nickname: "메인유저",
    email: "main@example.com",
    provider: "google",
    metadata: .init()
  )) -> AppEntry.Feature.State {
    @Shared(.inMemory("app-entry-main-user")) var currentUser = user
    var state = AppEntry.Feature.State()
    state.destination = .main(RootTab.Feature.State(currentUser: $currentUser))
    state.splash = .hidden
    return state
  }
}
