//
//  DeeplinkRoutingTests.swift
//  AppEntryFeature
//
//  딥링크 라우팅 동작 테스트
//
//  ## 테스트 대상
//  - `AppEntryFeature/Sources/AppEntryFeature.swift`
//  - `AppEntry.Feature.routeDeeplink(_:)` 메서드
//  - `AppEntry.Feature.routeOrPendDeeplink(_:state:)` 메서드
//
//  ## 사용처
//  - **AppMain.swift**: `.onOpenURL { }` → `handleDeeplink(URL)`
//  - **AppEntryFeature**: 푸시 알림 탭 → `pushNotificationTapped(destination)`
//
//  ## 라우팅 규칙
//  - 메인 화면 상태: 즉시 라우팅
//  - 로그인/프로필 설정 중: pending으로 저장 → 메인 진입 시 라우팅
//
//  ## 테스트 목적
//  - 각 DeeplinkDestination이 올바른 RootTab Action으로 변환되는지 검증
//  - 앱 상태에 따른 라우팅/펜딩 로직 검증
//

import Testing
import ComposableArchitecture
import Clients
import PromisoShared
import Sharing
@testable import AppEntryFeature

// MARK: - Deeplink Routing Tests

@Suite("딥링크 라우팅 테스트")
@MainActor
struct DeeplinkRoutingTests {

  // MARK: - Test Helpers

  /// 메인 화면 상태의 테스트용 State 생성
  private func makeMainState() -> AppEntry.Feature.State {
    @Shared(.inMemory("test-current-user-deeplink")) var mockUser = UserPrivateModel(
      userId: "test-user",
      name: "테스트",
      nickname: "테스트",
      email: "test@example.com",
      provider: "iOS",
      metadata: .init()
    )
    var state = AppEntry.Feature.State()
    state.destination = .main(RootTab.Feature.State(currentUser: $mockUser))
    state.splash = .hidden
    return state
  }

  /// Auth 화면 상태의 테스트용 State 생성
  private func makeAuthState() -> AppEntry.Feature.State {
    var state = AppEntry.Feature.State()
    state.destination = .auth(Auth.Feature.State())
    state.splash = .hidden
    return state
  }

  // MARK: - 메인 화면에서 즉시 라우팅 테스트
  //
  // 앱이 메인 화면 상태일 때 딥링크가 즉시 처리됩니다.
  // RootTab.Feature로 적절한 액션이 전달됩니다.

  @Test("joinGroup 딥링크 → openJoinGroupWithCode 액션")
  func routeJoinGroup_sendsOpenJoinGroupWithCode() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .joinGroup(inviteCode: "ABC123")
      }
      // RootTab에서 호출되는 의존성 mock
      $0.groupClient.previewGroup = { _ in
        let group = GroupModel(id: "test", name: "Test Group", maxMembers: 10, inviteCode: "ABC", createdBy: "user1")
        return GroupPreviewModel(group: group, members: [])
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://join/ABC123")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 openJoinGroupWithCode 액션 전달 확인
    await store.receive(\.destination.presented.main.openJoinGroupWithCode)
  }

  @Test("group 딥링크 → handleGroupDeeplink(.group) 액션")
  func routeGroup_sendsHandleGroupDeeplink() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .group(groupId: "group123")
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://group/group123")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 handleGroupDeeplink 액션 전달 확인
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("promise 딥링크 → handleGroupDeeplink(.promise) 액션")
  func routePromise_sendsHandleGroupDeeplink() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .promise(promiseId: "promise123", groupId: "group456")
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://promise/promise123/group456")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 handleGroupDeeplink 액션 전달 확인
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("liveActivityETA 딥링크 → openLiveActivityETASheet 액션")
  func routeLiveActivityETA_sendsOpenETASheet() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .liveActivityETA(promiseId: "promise789")
      }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://promise/promise789/eta")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 openLiveActivityETASheet 액션 전달 확인
    await store.receive(\.destination.presented.main.openLiveActivityETASheet)
  }

  @Test("livePromise 딥링크 → openLivePromiseDetail 액션")
  func routeLivePromise_sendsOpenLivePromiseDetail() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .livePromise(promiseId: "promise999")
      }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://live/promise999")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 openLivePromiseDetail 액션 전달 확인
    await store.receive(\.destination.presented.main.openLivePromiseDetail)
  }

  @Test("create 딥링크 → openCreatePromiseIfPossible 액션")
  func routeCreate_sendsOpenCreatePromiseIfPossible() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .create
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    let url = URL(string: "promiso://create")!
    await store.send(.view(.handleDeeplink(url)))

    // RootTab에 openCreatePromiseIfPossible 액션 전달 확인
    await store.receive(\.destination.presented.main.openCreatePromiseIfPossible)
  }

  // MARK: - 메인 화면 아닐 때 펜딩 테스트
  //
  // 앱이 로그인/프로필 설정 화면일 때 딥링크는 pendingDeeplink에 저장됩니다.
  // 메인 화면 진입 시 저장된 딥링크가 처리됩니다.

  @Test("Auth 화면에서 딥링크 수신 → pendingDeeplink에 저장")
  func deeplinkWhileAuth_storesPending() async {
    let state = makeAuthState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in
        .joinGroup(inviteCode: "PENDING123")
      }
    }

    let url = URL(string: "promiso://join/PENDING123")!
    await store.send(.view(.handleDeeplink(url))) {
      $0.pendingDeeplink = .joinGroup(inviteCode: "PENDING123")
    }
  }

  @Test("잘못된 URL → 무시 (state 변경 없음)")
  func invalidURL_ignored() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in nil }
    }

    let url = URL(string: "https://example.com")!
    await store.send(.view(.handleDeeplink(url)))
    // 아무 액션도 발생하지 않음
  }
}

// MARK: - Push Notification Deeplink Tests

@Suite("푸시 알림 딥링크 테스트")
@MainActor
struct PushNotificationDeeplinkTests {

  /// 메인 화면 상태의 테스트용 State 생성
  private func makeMainState() -> AppEntry.Feature.State {
    @Shared(.inMemory("test-current-user-deeplink")) var mockUser = UserPrivateModel(
      userId: "test-user",
      name: "테스트",
      nickname: "테스트",
      email: "test@example.com",
      provider: "iOS",
      metadata: .init()
    )
    var state = AppEntry.Feature.State()
    state.destination = .main(RootTab.Feature.State(currentUser: $mockUser))
    state.splash = .hidden
    return state
  }

  // MARK: - 푸시 알림 탭 → 딥링크 라우팅
  //
  // 푸시 알림을 탭하면 DeeplinkClient.pushNotificationTapStream에서
  // DeeplinkDestination이 전달되고, handleDeeplink와 동일하게 라우팅됩니다.

  @Test("푸시 알림 탭 (promise) → handleGroupDeeplink 액션")
  func pushNotificationTap_promise_routes() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    // 푸시 알림 탭 시뮬레이션
    await store.send(.internal(.pushNotificationTapped(.promise(promiseId: "p1", groupId: "g1"))))

    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("푸시 알림 탭 (group) → handleGroupDeeplink 액션")
  func pushNotificationTap_group_routes() async {
    let state = makeMainState()
    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    await store.send(.internal(.pushNotificationTapped(.group(groupId: "g1"))))

    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }
}
