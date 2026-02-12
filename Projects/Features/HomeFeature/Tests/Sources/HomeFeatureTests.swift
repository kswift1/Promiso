//
//  HomeFeatureTests.swift
//  HomeFeature
//
//  Home.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `HomeFeature/Sources/HomeFeature.swift`
//  - Reducer의 action 처리 및 side effect 검증
//
//  ## 테스트 목적
//  - onAppear 시 fetchPromises 트리거 검증
//  - 조건부 reload 로직 검증
//  - 에러 핸들링 검증
//  - Pull-to-refresh 동작 검증
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
import Sharing
@testable import HomeFeature

// MARK: - HomeFeature Tests

@Suite("Home.Feature reducer 테스트")
struct HomeFeatureTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser(
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: "test-user-123",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      metadata: .init(),
      groups: groups
    )
  }

  /// 테스트용 그룹 정보 생성
  private func makeGroupInfo(
    id: String = "group-1",
    name: String = "테스트 그룹"
  ) -> UserGroupInfo {
    UserGroupInfo(id: id, name: name)
  }

  /// 테스트용 약속 생성
  private func makePromise(
    id: String = "promise-1",
    groupId: String = "group-1",
    startAt: Date = Date().addingTimeInterval(3600)
  ) -> PromiseModel {
    PromiseModel(
      id: id,
      title: "테스트 약속",
      groupId: groupId,
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: [],
        declined: [],
        until: Date().addingTimeInterval(1800)
      ),
      startAt: startAt
    )
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 hasLoadedOnce 설정 및 fetchPromises 트리거")
  func onAppear_setsHasLoadedOnceAndTriggersFetch() async {
    let groups = [makeGroupInfo()]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-onAppear")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.promiseClient.getHomePromises = { _, _ in [] }
      $0.notificationClient.getUnreadCount = { _ in 0 }
      $0.notificationClient.setBadgeCount = { _ in }
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }

    await store.receive(\.internal.promisesResponse.success) {
      $0.promisesState = .loaded([])
    }

    await store.receive(\.internal.fetchUnreadNotificationCount)
    await store.receive(\.internal.unreadNotificationCountResponse)
  }

  @Test("onAppear 반복 호출 시에도 fetchPromises 트리거")
  func onAppear_alwaysTriggersFetch() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-onAppear-repeat")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.hasLoadedOnce = true

    let store = TestStore(initialState: state) {
      Home.Feature()
    }

    // 그룹이 없으면 fetchPromises에서 빈 배열 즉시 반환
    await store.send(.view(.onAppear))

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
  }

  // MARK: - 그룹 없을 때 테스트

  @Test("그룹 없으면 빈 약속 배열 반환")
  func fetchPromises_noGroups_returnsEmptyArray() async {
    let user = makeCurrentUser(groups: [])
    @Shared(.inMemory("test-no-groups")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
  }

  // MARK: - refreshTriggered 테스트

  @Test("refreshTriggered 시 fetchPromises 트리거")
  func refreshTriggered_triggersFetch() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-refresh")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.refreshTriggered))

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
  }

  // MARK: - 에러 핸들링 테스트

  @Test("약속 조회 실패 시 에러 상태 설정")
  func fetchPromises_failure_setsErrorState() async {
    let groups = [makeGroupInfo()]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-error")) var currentUser = user

    let testError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "네트워크 오류"])

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.promiseClient.getHomePromises = { _, _ in throw testError }
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }

    await store.receive(\.internal.promisesResponse.failure) {
      $0.promisesState = .failed(testError)
    }
  }

  // MARK: - 필터 테스트

  @Test("그룹 필터 변경")
  func groupFilterChanged_updatesSelectedGroupId() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-group-filter")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.groupFilterChanged("group-2"))) {
      $0.selectedGroupId = "group-2"
    }
  }

  @Test("상태 필터 변경")
  func statusFilterChanged_updatesSelectedStatusFilter() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-status-filter")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.statusFilterChanged(.confirmed))) {
      $0.selectedStatusFilter = .confirmed
    }
  }

  @Test("필터 초기화")
  func resetFilters_clearsAllFilters() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-reset-filter")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.selectedGroupId = "group-1"
    state.selectedStatusFilter = .confirmed

    let store = TestStore(initialState: state) {
      Home.Feature()
    }

    await store.send(.view(.resetFilters)) {
      $0.selectedGroupId = nil
      $0.selectedStatusFilter = .all
    }
  }

  // MARK: - 네비게이션 테스트

  @Test("seeAllUpcomingTapped 시 delegate 전달")
  func seeAllUpcomingTapped_sendsDelegate() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-see-all")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.seeAllUpcomingTapped))

    await store.receive(\.delegate.navigateToAllPromises)
  }

  // MARK: - 알림 배지 테스트

  @Test("refreshNotificationBadge 시 알림 개수 조회")
  func refreshNotificationBadge_fetchesUnreadCount() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-badge")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.notificationClient.getUnreadCount = { _ in 5 }
      $0.notificationClient.setBadgeCount = { _ in }
    }

    await store.send(.view(.refreshNotificationBadge))

    await store.receive(\.internal.fetchUnreadNotificationCount)

    await store.receive(\.internal.unreadNotificationCountResponse.success) {
      $0.unreadNotificationCount = 5
    }
  }

  // MARK: - 스크롤 타겟 테스트

  @Test("scrollTargetCleared 시 스크롤 타겟 초기화")
  func scrollTargetCleared_resetsTarget() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-scroll")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.scrollTarget = .needResponse

    let store = TestStore(initialState: state) {
      Home.Feature()
    }

    await store.send(.view(.scrollTargetCleared)) {
      $0.scrollTarget = nil
    }
  }
}
