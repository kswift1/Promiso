import Testing
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
    #expect(state.destinationType == .auth)
  }

  // MARK: - Splash 테스트

  @Test("splashAnimationCompleted 시 splash hidden 설정")
  func splashAnimationCompleted_hidesSplash() async {
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
      $0.notificationClient.saveNotificationToken = { _ in }
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal.checkVersion)
    await store.receive(\.internal.versionCheckCompleted)
    await receiveContinueAppFlowUnauthenticated(store)
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
      $0.notificationClient.saveNotificationToken = { _ in }
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.view(.scenePhaseChanged(.active)))
    await store.receive(\.internal.recheckVersionAfterAppStore)
    await store.receive(\.internal.versionCheckCompleted) {
      $0.updateAlert = nil
    }
    await receiveContinueAppFlowUnauthenticated(store)
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
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.userDefaultsClient.stringForKey = { _ in nil }
      $0.userDefaultsClient.setString = { _, _ in }
      $0.whatsNewClient.fetchWhatsNew = { _ in nil }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.startProfileCheck))
    await store.receive(\.internal.profileCheckResponse)
    await store.receive(\.internal.transitionToMain)
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

  @Test("upToDate 수신 시 기존 updateAlert 닫기 및 앱 진행")
  func versionCheckCompleted_upToDate_withExistingAlert_clearsAlert() async {
    var state = AppEntry.Feature.State()
    state.updateAlert = .recommendUpdate(currentVersion: "1.0.0", recommendedVersion: "1.1.0")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
      $0.authClient.currentUser = { nil }
      $0.deeplinkClient.pushNotificationTapStream = { AsyncStream { _ in } }
      $0.notificationClient.saveNotificationToken = { _ in }
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.internal(.versionCheckCompleted(.upToDate))) {
      $0.updateAlert = nil
    }

    await receiveContinueAppFlowUnauthenticated(store)
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
      $0.notificationClient.saveNotificationToken = { _ in }
      $0.userDefaultsClient.boolForKey = { _ in true }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.updateAlert(.laterTapped)) {
      $0.updateAlert = nil
    }

    await receiveContinueAppFlowUnauthenticated(store)
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

  @Test("profileCheckResponse 기존 사용자 + pending 없으면 메인 전환만")
  func profileCheck_existingUser_noPending_routesToMainOnly() async {
    var state = AppEntry.Feature.State()
    state.splash = .visible

    let user = makeUser(id: "user-no-pending", nickname: "기존유저")
    let firebaseUser = makeFirebaseUser(uid: "firebase-no-pending")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.userDefaultsClient.stringForKey = { _ in nil }
      $0.userDefaultsClient.setString = { _, _ in }
      $0.whatsNewClient.fetchWhatsNew = { _ in nil }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileCheckResponse(user: firebaseUser, profile: user)))
    #expect(store.state.splash == .animatingOut)
    await store.receive(\.internal.transitionToMain)
    #expect(store.state.destinationType == .main)
    #expect(store.state.pendingDeeplink == nil)
  }

  @Test("profileCheckResponse 기존 사용자면 메인 전환 및 pending 딥링크 처리")
  func profileCheck_existingUser_routesToMainAndProcessesPendingDeeplink() async {
    var state = AppEntry.Feature.State()
    state.pendingDeeplink = .liveSchedule(scheduleId: "p-1")
    state.splash = .visible

    let user = makeUser(id: "user-main", nickname: "기존유저")
    let firebaseUser = makeFirebaseUser(uid: "firebase-main")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.userDefaultsClient.stringForKey = { _ in nil }
      $0.userDefaultsClient.setString = { _, _ in }
      $0.whatsNewClient.fetchWhatsNew = { _ in nil }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileCheckResponse(user: firebaseUser, profile: user)))
    #expect(store.state.splash == .animatingOut)
    await store.receive(\.internal.transitionToMain)
    #expect(store.state.pendingDeeplink == nil)
    #expect(store.state.destinationType == .main)
    await store.receive(\.destination.presented.main.openLiveScheduleDetail)
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

    await store.send(.destination(.presented(.profile(.delegate(.completed(user)))))) {
      $0.pendingUserForMain = user
    }
    await store.receive(\.internal.checkNotificationPermission)
    await store.receive(\.internal.notificationPermissionChecked) {
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
    state.pendingDeeplink = .liveSchedule(scheduleId: "live-1")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.notificationPermissionChecked(isAuthorized: true, user: user)))
    await store.receive(\.internal.transitionToMain)
    #expect(store.state.pendingDeeplink == nil)
    #expect(store.state.destinationType == .main)
    await store.receive(\.destination.presented.main.openLiveScheduleDetail)
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
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.userDefaultsClient.setBool = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.notificationPermission(.presented(.delegate(.dismissed))))
    await store.receive(\.internal.transitionToMain)
    #expect(store.state.notificationPermission == nil)
    #expect(store.state.pendingUserForMain == nil)
    #expect(store.state.destinationType == .main)
  }

  @Test("notificationPermission permissionChanged 시 pendingUser로 메인 전환")
  func notificationPermissionChanged_movesToMainWithPendingUser() async {
    let user = makeUser(id: "permission-changed-user", nickname: "권한변경유저")
    var state = AppEntry.Feature.State()
    state.pendingUserForMain = user
    state.notificationPermission = NotificationPermission.Feature.State()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _ in }
      $0.crashlyticsClient.setUser = { _ in }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.userDefaultsClient.setBool = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.notificationPermission(.presented(.delegate(.permissionChanged(isGranted: true)))))
    await store.receive(\.internal.transitionToMain)
    #expect(store.state.notificationPermission == nil)
    #expect(store.state.pendingUserForMain == nil)
    #expect(store.state.destinationType == .main)
  }

  // MARK: - 온보딩 인트로 플로우 (비인증 + 온보딩 미완료)

  @Test("sessionCheckResponse 비인증 + 온보딩 미완료 → onboardingIntro")
  func sessionCheck_unauthenticated_onboardingNotCompleted_showsIntro() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userDefaultsClient.boolForKey = { _ in false }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.internal(.sessionCheckResponse(isAuthenticated: false))) {
      $0.isFullOnboarding = true
      $0.destination = .onboardingIntro(AppEntry.OnboardingIntro.State())
      $0.splash = .animatingOut
    }
  }

  @Test("onboardingIntro.delegate.introCompleted → auth 화면으로 전환")
  func onboardingIntroCompleted_showsAuth() async {
    var state = AppEntry.Feature.State()
    state.destination = .onboardingIntro(AppEntry.OnboardingIntro.State())

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userDefaultsClient.setBool = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.destination(.presented(.onboardingIntro(.delegate(.introCompleted))))) {
      $0.isFullOnboarding = true
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
    }
  }

  @Test("notificationPermission dismissed + pendingUserForMain nil → auth 화면")
  func notificationPermissionDismissed_noPendingUser_showsAuth() async {
    var state = AppEntry.Feature.State()
    state.notificationPermission = NotificationPermission.Feature.State()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userDefaultsClient.setBool = { _, _ in }
    }

    await store.send(.notificationPermission(.presented(.delegate(.dismissed)))) {
      $0.notificationPermission = nil
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
    }
  }

  // MARK: - Profile + 풀 온보딩 플로우

  @Test("profile.completed + isFullOnboarding=true → 알림 권한 확인으로 진행")
  func profileCompleted_fullOnboarding_checksNotificationPermission() async {
    let user = makeUser(id: "full-onboarding-user", nickname: "풀온보딩")
    var state = AppEntry.Feature.State()
    state.destination = .profile(AppEntry.ProfileSetup.State())
    state.isFullOnboarding = true

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.analyticsClient.logEvent = { _, _ in }
      $0.notificationClient.getAuthorizationStatus = { .denied }
    }

    await store.send(.destination(.presented(.profile(.delegate(.completed(user)))))) {
      $0.pendingUserForMain = user
    }
    await store.receive(\.internal.checkNotificationPermission)
    await store.receive(\.internal.notificationPermissionChecked) {
      $0.notificationPermission = NotificationPermission.Feature.State()
    }
  }

  // MARK: - Logout 테스트

  @Test("logoutRequested delegate 수신 시 auth로 전환")
  func logoutRequested_movesToAuth() async {
    let state = makeMainState()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.notificationClient.deleteCurrentDeviceRegistration = { }
      $0.authClient.logout = { }
      $0.authClient.clearWidgetAuthToken = { }
      $0.clarityClient.clearUser = { }
      $0.crashlyticsClient.clearUser = { }
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
      $0.notificationClient.deleteCurrentDeviceRegistration = { throw LogoutError.failed }
      $0.authClient.logout = { throw LogoutError.failed }
      $0.authClient.clearWidgetAuthToken = { }
      $0.clarityClient.clearUser = { }
      $0.crashlyticsClient.clearUser = { }
      $0.analyticsClient.setUserID = { _ in }
    }

    await store.send(.destination(.presented(.main(.delegate(.logoutRequested))))) {
      $0.destination = .auth(AuthFeature.Auth.Feature.State())
    }
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
      $0.notificationClient.saveNotificationToken = { _ in }
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
      $0.notificationClient.saveNotificationToken = { _ in }
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
      $0.notificationClient.saveNotificationToken = { _ in throw SaveError.failed }
    }

    await store.send(.internal(.fcmTokenReceived("token-3")))
  }

  @Test("subscribePushNotificationTap 구독 중 푸시 수신 시 pushNotificationTapped 전달")
  func subscribePushNotificationTap_receivesAndForwards() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.pushNotificationTapStream = {
        AsyncStream { continuation in
          continuation.yield(.group(groupId: "push-stream-g1"))
          continuation.finish()
        }
      }
    }

    await store.send(.internal(.subscribePushNotificationTap))
    await store.receive(\.internal.pushNotificationTapped) {
      $0.pendingDeeplink = .group(groupId: "push-stream-g1")
    }
  }

  @Test("subscribeFCMToken 구독 중 알림 수신 시 fcmTokenReceived 전달")
  func subscribeFCMToken_receivesNotificationToken() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
      $0.notificationClient.saveNotificationToken = { _ in }
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

  // MARK: - Deeplink 테스트

  @Test("handleDeeplink 시 메인 아니면 pendingDeeplink에 저장")
  func handleDeeplink_notOnMain_storesPending() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .liveSchedule(scheduleId: "p-1") }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://live")!))) {
      $0.pendingDeeplink = .liveSchedule(scheduleId: "p-1")
    }
  }

  @Test("handleDeeplink 파싱 실패 시 아무 일도 안 함")
  func handleDeeplink_parseFailure_doesNothing() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in nil }
    }

    await store.send(.view(.handleDeeplink(URL(string: "invalid://url")!)))
  }

  @Test("handleDeeplink 시 메인이면 즉시 라우팅")
  func handleDeeplink_onMain_routesImmediately() async {
    let state = makeMainState()

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .liveSchedule(scheduleId: "p-1") }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://live")!)))
    await store.receive(\.destination.presented.main.openLiveScheduleDetail)
  }

  @Test("pushNotificationTapped 시 메인 아니면 pendingDeeplink에 저장")
  func pushNotificationTapped_notOnMain_storesPending() async {
    let store = TestStore(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    }

    await store.send(.internal(.pushNotificationTapped(.group(groupId: "g-1")))) {
      $0.pendingDeeplink = .group(groupId: "g-1")
    }
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

  @Test("ProfileSetup inject 시 user.photoURL 있으면 providerProfileImageURL보다 우선")
  func profileSetupInject_withUserPhotoURL_prefersUserPhotoURL() {
    var profileState = AppEntry.ProfileSetup.State()
    let userPhotoURL = URL(string: "https://example.com/firebase-photo.png")!
    let providerPhotoURL = URL(string: "https://example.com/provider-photo.png")!

    profileState.inject(
      user: makeFirebaseUser(photoURL: userPhotoURL),
      providerProfileImageURL: providerPhotoURL
    )

    #expect(profileState.profileImage == .url(userPhotoURL))
  }

  @Test("ProfileSetup inject 시 user.photoURL 없으면 providerProfileImageURL 사용")
  func profileSetupInject_withoutUserPhotoURL_usesProviderURL() {
    var profileState = AppEntry.ProfileSetup.State()
    let providerPhotoURL = URL(string: "https://example.com/provider-photo.png")!

    profileState.inject(
      user: makeFirebaseUser(photoURL: nil),
      providerProfileImageURL: providerPhotoURL
    )

    #expect(profileState.profileImage == .url(providerPhotoURL))
  }
}

private extension AppEntryFeatureTests {

  /// 비인증 상태의 continueAppFlow → sessionCheck → auth 전환 체인 수신 후 구독 정리
  func receiveContinueAppFlowUnauthenticated(
    _ store: TestStoreOf<AppEntry.Feature>
  ) async {
    await store.receive(\.internal.continueAppFlow)
    await store.receive(\.internal.startSessionCheck)
    await store.receive(\.internal.subscribeFCMToken)
    await store.receive(\.internal.subscribePushNotificationTap)
    await store.receive(\.internal.sessionCheckResponse) {
      $0.isFullOnboarding = true
      $0.destination = .onboardingIntro(AppEntry.OnboardingIntro.State())
      $0.splash = .animatingOut
    }
    await store.send(.internal(.cancelSubscriptions))
  }

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
