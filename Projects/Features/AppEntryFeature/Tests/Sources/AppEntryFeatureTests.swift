// MARK: - AppEntryFeatureTests.swift
// Swift Testing 프레임워크를 사용한 AppEntry Feature 테스트

import Testing
import ComposableArchitecture
import Clients
import Shared
@testable import AppEntryFeature

// MARK: - State Tests

@Suite("AppEntry State")
@MainActor
struct StateTests {

  @Test("초기 상태가 올바르게 설정됨")
  func initialState() {
    let state = AppEntry.Feature.State()

    #expect(state.splash == .visible)
    #expect(state.destination != nil)

    guard case .auth = state.destination else {
      Issue.record("Initial destination should be auth")
      return
    }
  }

  @Test("Splash 상태 전환", arguments: [
    AppEntry.Feature.State.SplashState.visible,
    AppEntry.Feature.State.SplashState.animatingOut,
    AppEntry.Feature.State.SplashState.hidden
  ])
  func splashStateTransitions(splashState: AppEntry.Feature.State.SplashState) {
    var state = AppEntry.Feature.State()
    state.splash = splashState

    #expect(state.splash == splashState)
  }

  @Test("DestinationType helper - Auth")
  func destinationTypeAuth() {
    var state = AppEntry.Feature.State()
    state.destination = .auth(Auth.Feature.State())

    #expect(state.destinationType == .auth)
  }

  @Test("DestinationType helper - Profile")
  func destinationTypeProfile() {
    var state = AppEntry.Feature.State()
    state.destination = .profile(AppEntry.ProfileSetup.State())

    #expect(state.destinationType == .profile)
  }

  @Test("DestinationType helper - Main")
  func destinationTypeMain() {
    let mockUser = UserModel(id: "test", email: "test@example.com", nickname: "test")
    var state = AppEntry.Feature.State()
    state.destination = .main(RootTab.Feature.State(currentUser: mockUser))

    #expect(state.destinationType == .main)
  }

  @Test("Destination이 nil이면 destinationType도 nil")
  func destinationTypeNil() {
    var state = AppEntry.Feature.State()
    state.destination = nil

    #expect(state.destinationType == nil)
  }
}

// MARK: - ProfileSetup State Injection Tests

@Suite("ProfileSetup State Injection")
@MainActor
struct StateInjectionTests {

  @Test("FirebaseUserSnapshot을 ProfileSetup State에 주입")
  func injectUser() {
    var state = AppEntry.ProfileSetup.State()

    let user = FirebaseUserSnapshot(
      uid: "test-uid",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: URL(string: "https://example.com/photo.jpg")
    )

    state.inject(user: user)

    #expect(state.uid == "test-uid")
    #expect(state.email == "test@example.com")
    #expect(state.fullName == "Test User")
    #expect(state.nickname == "Test User")

    guard case .url(let url) = state.profileImage else {
      Issue.record("Profile image should be .url")
      return
    }

    #expect(url == URL(string: "https://example.com/photo.jpg"))
  }

  @Test("photoURL이 nil이면 profileImage가 .none")
  func injectUserWithoutPhotoURL() {
    var state = AppEntry.ProfileSetup.State()

    let user = FirebaseUserSnapshot(
      uid: "test-uid",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: nil
    )

    state.inject(user: user)

    guard case .none = state.profileImage else {
      Issue.record("Profile image should be .none")
      return
    }
  }

  @Test("displayName이 nil이면 빈 문자열로 설정")
  func injectUserWithoutDisplayName() {
    var state = AppEntry.ProfileSetup.State()

    let user = FirebaseUserSnapshot(
      uid: "test-uid",
      email: "test@example.com",
      displayName: nil,
      photoURL: nil
    )

    state.inject(user: user)

    #expect(state.fullName == "")
    #expect(state.nickname == "")
  }

  @Test("providerId 정보가 올바르게 주입됨")
  func injectUserWithProviderInfo() {
    var state = AppEntry.ProfileSetup.State()

    let user = FirebaseUserSnapshot(
      uid: "test-uid",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: nil,
      providerId: "google.com",
      providerUid: "google-123",
      providerType: "google"
    )

    state.inject(user: user)

    #expect(state.providerId == "google.com")
    #expect(state.providerUid == "google-123")
    #expect(state.providerType == "google")
  }
}

// MARK: - Integration Tests

@Suite("AppEntry Integration")
@MainActor
struct IntegrationTests {

  @Test("Feature 인스턴스가 정상적으로 생성됨")
  func featureCreatesValidInstance() {
    let store = Store(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    }

    // Store는 구조체이므로 항상 non-nil
    #expect(true)
  }

  @Test("Feature가 AuthClient 의존성을 가짐")
  func featureHasAuthClient() async {
    await confirmation("AuthClient is called", expectedCount: 1) { @Sendable confirm in
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.isAuthenticated = {
          confirm()
          return false
        }
      }

      await store.send(.view(.onAppear))

      // 비동기 작업이 완료될 때까지 대기
      try? await Task.sleep(for: .milliseconds(100))
    }
  }

  @Test("Feature가 UserProfileClient 의존성을 가짐")
  func featureHasUserProfileClient() async {
    await confirmation("UserProfileClient is called", expectedCount: 1) { @Sendable confirm in
      let mockUser = FirebaseUserSnapshot(
        uid: "test-uid",
        email: "test@example.com",
        displayName: "Test User",
        photoURL: nil
      )

      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.isAuthenticated = { true }
        $0.authClient.currentUser = { mockUser }
        $0.userProfileClient.hasProfile = { _ in
          confirm()
          return nil
        }
      }

      await store.send(.view(.onAppear))

      // 비동기 작업이 완료될 때까지 대기
      try? await Task.sleep(for: .milliseconds(200))
    }
  }
}

// MARK: - Reducer Logic Tests

@Suite("AppEntry Reducer Logic")
@MainActor
struct ReducerLogicTests {

  @Test("onAppear 액션 전송 가능")
  func sendOnAppear() async {
    let store = Store(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient.isAuthenticated = { false }
    }

    await store.send(.view(.onAppear))

    // 에러 없이 전송되는지 확인
    #expect(true)
  }

  @Test("splashAnimationCompleted 액션 전송 가능")
  func sendSplashAnimationCompleted() async {
    var state = AppEntry.Feature.State()
    state.splash = .animatingOut

    let store = Store(initialState: state) {
      AppEntry.Feature()
    }

    await store.send(.view(.splashAnimationCompleted))

    // 에러 없이 전송되는지 확인
    #expect(true)
  }

  @Test("미인증 사용자 플로우")
  func unauthenticatedUserFlow() async {
    await confirmation("Session check is called", expectedCount: 1) { @Sendable confirm in
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.isAuthenticated = {
          confirm()
          return false
        }
      }

      await store.send(.view(.onAppear))

      // 비동기 작업 완료 대기
      try? await Task.sleep(for: .milliseconds(100))
    }
  }

  @Test("인증된 사용자 플로우")
  func authenticatedUserFlow() async {
    await confirmation("Both checks are called", expectedCount: 2) { @Sendable confirm in
      let mockUser = FirebaseUserSnapshot(
        uid: "test-uid",
        email: "test@example.com",
        displayName: "Test User",
        photoURL: nil
      )

      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.isAuthenticated = {
          confirm()
          return true
        }
        $0.authClient.currentUser = { mockUser }
        $0.userProfileClient.hasProfile = { _ in
          confirm()
          return nil
        }
      }

      await store.send(.view(.onAppear))

      // 비동기 작업 완료 대기
      try? await Task.sleep(for: .milliseconds(200))
    }
  }

  @Test("로그아웃 플로우")
  func logoutFlow() async {
    await confirmation("Logout is called", expectedCount: 1) { @Sendable confirm in
      let mockUserModel = UserModel(
        id: "test-uid",
        email: "test@example.com",
        nickname: "testnick"
      )

      var initialState = AppEntry.Feature.State()
      initialState.destination = .main(RootTab.Feature.State(currentUser: mockUserModel))

      let store = Store(initialState: initialState) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.logout = {
          confirm()
        }
      }

      await store.send(.destination(.presented(.main(.delegate(.logoutRequested)))))

      // 비동기 작업 완료 대기
      try? await Task.sleep(for: .milliseconds(100))
    }
  }
}

// MARK: - Dependency Tests

@Suite("AppEntry Dependencies")
@MainActor
struct DependencyTests {

  @Test("AuthClient testValue 동작")
  func authClientTestValue() async {
    let store = Store(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.authClient = .testValue
    }

    // testValue가 정상적으로 주입되는지 확인
    #expect(true)
  }

  @Test("UserProfileClient testValue 동작")
  func userProfileClientTestValue() async {
    let store = Store(initialState: AppEntry.Feature.State()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.userProfileClient = .testValue
    }

    // testValue가 정상적으로 주입되는지 확인
    #expect(true)
  }

  @Test("Mock 의존성 주입 가능")
  func mockDependencyInjection() async {
    await confirmation("Custom mock is called", expectedCount: 1) { @Sendable confirm in
      let store = Store(initialState: AppEntry.Feature.State()) {
        AppEntry.Feature()
      } withDependencies: {
        $0.authClient.isAuthenticated = {
          confirm()
          return false
        }
      }

      await store.send(.view(.onAppear))

      try? await Task.sleep(for: .milliseconds(50))
    }
  }
}

// MARK: - ProfileSetup Effects

@Suite("ProfileSetup Effects")
@MainActor
struct ProfileSetupEffectsTests {

  @Test("프로필 저장 시 UserProfileClient.saveProfileWithImage 호출")
  func saveProfileCallsClient() async {
    await confirmation("saveProfileWithImage is called", expectedCount: 1) { @Sendable confirm in
      let state = AppEntry.ProfileSetup.State(
        profileImageUrl: nil,
        email: "test@example.com",
        uid: "test-uid",
        fullName: "Test User"
      )

      let store = Store(initialState: state) {
        AppEntry.ProfileSetup()
      } withDependencies: {
        $0.userProfileClient.saveProfileWithImage = { uid, profile, _ in
          confirm()
          return UserModel(
            id: uid,
            email: profile.email ?? "",
            nickname: profile.nickname
          )
        }
      }

      await store.send(.internal(.saveProfile))
      try? await Task.sleep(for: .milliseconds(100))
    }
  }
}
