import Testing
@testable import AppEntryFeature

@Suite("딥링크 라우팅 테스트")
@MainActor
struct DeeplinkRoutingTests {
  @Test("joinGroup 딥링크는 메인에서 즉시 그룹 참여 라우팅")
  func routeJoinGroup_sendsOpenJoinGroupWithCode() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-join-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .joinGroup(inviteCode: "ABC123") }
      $0.groupClient.previewGroup = { _ in makeGroupPreviewModel() }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://join/ABC123")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openJoinGroupWithCode)
  }

  @Test("group 딥링크는 메인에서 handleGroupDeeplink로 전달")
  func routeGroup_sendsHandleGroupDeeplink() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-group-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .group(groupId: "group-123") }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://group/group-123")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("promise 딥링크는 메인에서 handleGroupDeeplink로 전달")
  func routePromise_sendsHandleGroupDeeplink() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-promise-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .promise(promiseId: "promise-1", groupId: "group-1") }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://promise/promise-1/group-1")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("liveActivityETA 딥링크는 ETA 시트 오픈 액션 전달")
  func routeLiveActivityETA_sendsOpenETASheet() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-eta-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .liveActivityETA(promiseId: "promise-eta") }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://promise/promise-eta/eta")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openLiveActivityETASheet)
  }

  @Test("livePromise 딥링크는 상세 오픈 액션 전달")
  func routeLivePromise_sendsOpenLivePromiseDetail() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-live-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .livePromise(promiseId: "promise-live") }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://live/promise-live")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openLivePromiseDetail)
  }

  @Test("create 딥링크는 그룹 탭 약속 생성 액션 전달")
  func routeCreate_sendsOpenCreatePromiseIfPossible() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-create-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .create }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.handleDeeplink(URL(string: "promiso://create")!)))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openCreatePromiseIfPossible)
  }

  @Test("Auth 화면에서 joinGroup 딥링크는 pending으로 저장")
  func deeplinkWhileAuth_joinGroup_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .joinGroup(inviteCode: "PENDING-123") }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://join/PENDING-123")!))) {
      $0.pendingDeeplink = .joinGroup(inviteCode: "PENDING-123")
    }
  }

  @Test("Auth 화면에서 promise 딥링크는 pending으로 저장")
  func deeplinkWhileAuth_promise_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .promise(promiseId: "p-auth", groupId: "g-auth") }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://promise/p-auth/g-auth")!))) {
      $0.pendingDeeplink = .promise(promiseId: "p-auth", groupId: "g-auth")
    }
  }

  @Test("Auth 화면에서 딥링크 연속 수신 시 pending은 최신 값으로 갱신")
  func deeplinkWhileAuth_overwritesPendingWithLatest() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { url in
        if url.absoluteString.contains("/join/") {
          return .joinGroup(inviteCode: "FIRST")
        }
        return .group(groupId: "LATEST-GROUP")
      }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://join/FIRST")!))) {
      $0.pendingDeeplink = .joinGroup(inviteCode: "FIRST")
    }
    await store.send(.view(.handleDeeplink(URL(string: "promiso://group/LATEST-GROUP")!))) {
      $0.pendingDeeplink = .group(groupId: "LATEST-GROUP")
    }
  }

  @Test("pending promise 딥링크는 profileCheckResponse 이후 메인 진입 시 라우팅")
  func pendingPromise_routesAfterProfileCheckResponse() async {
    var state = makeAuthState()
    state.pendingDeeplink = .promise(promiseId: "pending-promise", groupId: "pending-group")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _, _ in }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileCheckResponse(
      user: makeFirebaseUser(uid: "firebase-main"),
      profile: makeUser(id: "user-main", nickname: "메인유저")
    )))
    await store.receive(\.internal.transitionToMain)

    #expect(store.state.destinationType == .main)
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("잘못된 URL은 무시된다")
  func invalidURL_ignored() async {
    let store = TestStore(initialState: makeMainState(key: "deeplink-invalid-url")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in nil }
    }

    await store.send(.view(.handleDeeplink(URL(string: "https://example.com")!)))
    #expect(store.state.pendingDeeplink == nil)
  }

  @Test("Auth 화면에서 create 딥링크는 pending으로 저장")
  func deeplinkWhileAuth_create_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .create }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://create")!))) {
      $0.pendingDeeplink = .create
    }
  }

  @Test("Auth 화면에서 livePromise 딥링크는 pending으로 저장")
  func deeplinkWhileAuth_livePromise_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .livePromise(promiseId: "live-auth") }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://live/live-auth")!))) {
      $0.pendingDeeplink = .livePromise(promiseId: "live-auth")
    }
  }

  @Test("Auth 화면에서 liveActivityETA 딥링크는 pending으로 저장")
  func deeplinkWhileAuth_liveActivityETA_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    } withDependencies: {
      $0.deeplinkClient.parseURL = { _ in .liveActivityETA(promiseId: "eta-auth") }
    }

    await store.send(.view(.handleDeeplink(URL(string: "promiso://promise/eta-auth/eta")!))) {
      $0.pendingDeeplink = .liveActivityETA(promiseId: "eta-auth")
    }
  }
}

@Suite("푸시 알림 딥링크 테스트")
@MainActor
struct PushNotificationDeeplinkTests {
  @Test("푸시 promise 탭은 handleGroupDeeplink로 라우팅")
  func pushNotificationTap_promise_routes() async {
    let store = TestStore(initialState: makeMainState(key: "push-promise-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.pushNotificationTapped(.promise(promiseId: "p1", groupId: "g1"))))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("푸시 group 탭은 handleGroupDeeplink로 라우팅")
  func pushNotificationTap_group_routes() async {
    let store = TestStore(initialState: makeMainState(key: "push-group-main")) {
      AppEntry.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.pushNotificationTapped(.group(groupId: "g1"))))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }

  @Test("푸시 liveActivityETA 탭은 ETA 시트 오픈으로 라우팅")
  func pushNotificationTap_liveActivityETA_routes() async {
    let store = TestStore(initialState: makeMainState(key: "push-eta-main")) {
      AppEntry.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.pushNotificationTapped(.liveActivityETA(promiseId: "p-eta"))))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openLiveActivityETASheet)
  }

  @Test("푸시 livePromise 탭은 상세 오픈으로 라우팅")
  func pushNotificationTap_livePromise_routes() async {
    let store = TestStore(initialState: makeMainState(key: "push-live-main")) {
      AppEntry.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.pushNotificationTapped(.livePromise(promiseId: "p-live"))))
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.openLivePromiseDetail)
  }

  @Test("Auth 화면에서 푸시 promise 탭은 pending 저장")
  func pushNotificationTap_whileAuth_storesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    }

    await store.send(.internal(.pushNotificationTapped(.promise(promiseId: "pending-p", groupId: "pending-g")))) {
      $0.pendingDeeplink = .promise(promiseId: "pending-p", groupId: "pending-g")
    }
  }

  @Test("Auth 화면에서 푸시 연속 탭 시 pending은 최신 값으로 갱신")
  func pushNotificationTap_whileAuth_overwritesPending() async {
    let store = TestStore(initialState: makeAuthState()) {
      AppEntry.Feature()
    }

    await store.send(.internal(.pushNotificationTapped(.promise(promiseId: "p-old", groupId: "g-old")))) {
      $0.pendingDeeplink = .promise(promiseId: "p-old", groupId: "g-old")
    }
    await store.send(.internal(.pushNotificationTapped(.group(groupId: "g-new")))) {
      $0.pendingDeeplink = .group(groupId: "g-new")
    }
  }

  @Test("pending group 푸시 딥링크는 profileCheckResponse 이후 라우팅")
  func pendingPushGroup_routesAfterProfileCheckResponse() async {
    var state = makeAuthState()
    state.pendingDeeplink = .group(groupId: "pending-group")

    let store = TestStore(initialState: state) {
      AppEntry.Feature()
    } withDependencies: {
      $0.clarityClient.setUser = { _, _ in }
      $0.analyticsClient.setUserID = { _ in }
      $0.analyticsClient.setUserProperty = { _, _ in }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileCheckResponse(
      user: makeFirebaseUser(uid: "firebase-push-main"),
      profile: makeUser(id: "user-push-main", nickname: "푸시메인")
    )))
    await store.receive(\.internal.transitionToMain)

    #expect(store.state.destinationType == .main)
    #expect(store.state.pendingDeeplink == nil)
    await store.receive(\.destination.presented.main.handleGroupDeeplink)
  }
}

// MARK: - Shared Helpers

private func makeMainState(key: String) -> AppEntry.Feature.State {
  @Shared(.inMemory("deeplink-main-user-\(key)")) var mockUser = UserPrivateModel(
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

private func makeAuthState() -> AppEntry.Feature.State {
  var state = AppEntry.Feature.State()
  state.destination = .auth(Auth.Feature.State())
  state.splash = .hidden
  return state
}

private func makeUser(
  id: String = "user-1",
  nickname: String = "테스터"
) -> UserPrivateModel {
  UserPrivateModel(
    userId: id,
    name: "테스트",
    nickname: nickname,
    email: "\(id)@example.com",
    provider: "google",
    metadata: .init()
  )
}

private func makeFirebaseUser(uid: String) -> FirebaseUserSnapshot {
  FirebaseUserSnapshot(
    uid: uid,
    email: "\(uid)@example.com",
    displayName: "Firebase User",
    photoURL: nil,
    providerId: "google.com",
    providerUid: "provider-\(uid)",
    providerType: "google"
  )
}

private func makeGroupPreviewModel() -> GroupPreviewModel {
  let group = GroupModel(
    id: "group-preview",
    name: "테스트 그룹",
    maxMembers: 10,
    inviteCode: "ABC123",
    createdBy: "host-user"
  )
  return GroupPreviewModel(group: group, members: [])
}
