import Testing
@testable import HomeFeature

@Suite("Home.Feature reducer 테스트")
@MainActor
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

  /// 테스트 스토어 생성 헬퍼
  private func makeStore(
    groups: [UserGroupInfo] = [],
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<Home.Feature> {
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-\(UUID().uuidString.prefix(8))")) var currentUser = user
    return TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.briefingClient.generate = { _ in BriefingResult(summary: "", detail: "") }
      $0.locationClient.getCurrentLocation = { Coordinate(latitude: 37.5, longitude: 127.0) }
      $0.locationClient.reverseGeocode = { _ in "서울" }
      $0.locationClient.authorizationStatus = { .notDetermined }
      $0.weatherClient.getWeather = { _, _, _ in WeatherInfo() }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      configure(&$0)
    }
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
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.briefingClient.generate = { _ in BriefingResult(summary: "", detail: "") }
      $0.locationClient.getCurrentLocation = { Coordinate(latitude: 37.5, longitude: 127.0) }
      $0.locationClient.reverseGeocode = { _ in "서울" }
      $0.locationClient.authorizationStatus = { .notDetermined }
      $0.weatherClient.getWeather = { _, _, _ in WeatherInfo() }
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }

    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.internal.promisesResponse.success) {
      $0.promisesState = .loaded([])
    }
    await store.receive(\.internal.unreadNotificationCountResponse)
    await store.finish()
  }

  @Test("onAppear 반복 호출 시에도 fetchPromises 트리거")
  func onAppear_alwaysTriggersFetch() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-onAppear-repeat")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.hasLoadedOnce = true

    let store = TestStore(initialState: state) {
      Home.Feature()
    } withDependencies: {
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.locationClient.authorizationStatus = { .notDetermined }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 그룹이 없으면 fetchPromises에서 빈 배열 즉시 반환
    await store.send(.view(.onAppear))

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
    await store.finish()
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
    } withDependencies: {
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.locationClient.authorizationStatus = { .notDetermined }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
    await store.finish()
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
    } withDependencies: {
      $0.personalEventClient.getActiveEvents = { _ in [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.refreshTriggered))

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loaded([])
    }
    await store.finish()
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
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.locationClient.authorizationStatus = { .notDetermined }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }

    await store.receive(\.internal.promisesResponse.failure) {
      $0.promisesState = .failed(testError)
    }
    await store.finish()
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

  // MARK: - 알림 버튼 테스트

  @Test("notificationButtonTapped 시 알림센터 path 추가")
  func notificationButtonTapped_appendsNotificationCenter() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-notif-button")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    await store.send(.view(.notificationButtonTapped)) {
      $0.path.append(.notificationCenter(.init()))
    }
  }

  // MARK: - 약속 조회 성공 테스트 (그룹 있을 때)

  @Test("약속 조회 성공 시 loaded 상태 설정 및 알림 개수 조회")
  func fetchPromises_success_setsLoadedStateAndFetchesNotifications() async {
    let groups = [makeGroupInfo()]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-success-fetch")) var currentUser = user

    let testPromise = makePromise()

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.promiseClient.getHomePromises = { _, _ in [testPromise] }
      $0.notificationClient.getUnreadCount = { _ in 3 }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.briefingClient.generate = { _ in BriefingResult(summary: "", detail: "") }
      $0.locationClient.getCurrentLocation = { Coordinate(latitude: 37.5, longitude: 127.0) }
      $0.locationClient.reverseGeocode = { _ in "서울" }
      $0.locationClient.authorizationStatus = { .notDetermined }
      $0.weatherClient.getWeather = { _, _, _ in WeatherInfo() }
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }

    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }

    // GroupModel의 createdAt/updatedAt가 Date() 기본값이라 타이밍 불일치 발생
    // exhaustivity off로 전환 후 명시적 receive로 chain 완료
    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.receive(\.internal.promisesResponse)
    await store.receive(\.internal.unreadNotificationCountResponse)
    await store.finish()

    let promises = store.state.promisesState.value
    #expect(promises?.count == 1)
    #expect(promises?.first?.group?.id == "group-1")
    #expect(promises?.first?.group?.name == "테스트 그룹")
    #expect(store.state.unreadNotificationCount == 3)
  }

  // MARK: - 약속 탭 테스트

  @Test("pendingPromiseTapped 시 navigateToGroupWithPromise delegate 전달")
  func pendingPromiseTapped_sendsDelegate() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-pending-tap")) var currentUser = user

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    }

    let promise = makePromise(id: "p-1", groupId: "g-1")

    await store.send(.view(.pendingPromiseTapped(promise)))

    await store.receive(\.delegate.navigateToGroupWithPromise)
  }

  // MARK: - Computed Properties 테스트

  @Test("allPromises - promisesState가 idle이면 빈 배열")
  func allPromises_idle_returnsEmpty() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-all-idle")) var currentUser = user

    let state = Home.Feature.State(currentUser: $currentUser)
    #expect(state.allPromises.isEmpty)
  }

  @Test("isLoading - loading 상태이면 true")
  func isLoading_loading_returnsTrue() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-loading")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.promisesState = .loading
    #expect(state.isLoading == true)
  }

  @Test("isLoading - loaded 상태이면 false")
  func isLoading_loaded_returnsFalse() {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-not-loading")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.promisesState = .loaded([])
    #expect(state.isLoading == false)
  }

  @Test("availableGroups - 유저 그룹 정보를 GroupInfo로 변환")
  func availableGroups_mapsUserGroups() {
    let groups = [
      makeGroupInfo(id: "g-1", name: "그룹1"),
      makeGroupInfo(id: "g-2", name: "그룹2"),
    ]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-available")) var currentUser = user

    let state = Home.Feature.State(currentUser: $currentUser)
    #expect(state.availableGroups.count == 2)
    #expect(state.availableGroups[0].id == "g-1")
    #expect(state.availableGroups[1].id == "g-2")
  }

  // MARK: - 알림 배지 에러 핸들링 테스트

  @Test("알림 개수 조회 실패 시 배지 카운트 유지")
  func unreadNotificationCount_failure_keepsExisting() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-badge-fail")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.unreadNotificationCount = 5

    let store = TestStore(initialState: state) {
      Home.Feature()
    } withDependencies: {
      $0.notificationClient.getUnreadCount = { _ in throw NSError(domain: "test", code: -1) }
    }

    await store.send(.view(.refreshNotificationBadge))
    await store.receive(\.internal.fetchUnreadNotificationCount)
    await store.receive(\.internal.unreadNotificationCountResponse.failure)
    // unreadNotificationCount는 변경되지 않음 (실패 시 기존 값 유지)
  }

  // MARK: - 추가 필터 테스트

  @Test("상태 필터 needResponse로 변경")
  func statusFilterChanged_needResponse() async {
    let store = makeStore()

    await store.send(.view(.statusFilterChanged(.needResponse))) {
      $0.selectedStatusFilter = .needResponse
    }
  }

  // MARK: - 약속 카드 탭 테스트

  @Test("todayPromiseTapped 시 promiseDetail path 추가")
  func todayPromiseTapped_appendsPromiseDetail() async {
    let promise = makePromise()
    let store = makeStore()

    await store.send(.view(.todayPromiseTapped(promise))) {
      $0.path.append(.promiseDetail(.init(
        promise: promise,
        currentUserId: "test-user-123"
      )))
    }
  }

  @Test("upcomingPromiseTapped 시 promiseDetail path 추가")
  func upcomingPromiseTapped_appendsPromiseDetail() async {
    let promise = makePromise()
    let store = makeStore()

    await store.send(.view(.upcomingPromiseTapped(promise))) {
      $0.path.append(.promiseDetail(.init(
        promise: promise,
        currentUserId: "test-user-123"
      )))
    }
  }

  // MARK: - 기존 데이터 유지 테스트

  @Test("fetchPromises 기존 데이터 있으면 loading 상태 스킵")
  func fetchPromises_withExistingData_skipsLoadingState() async {
    let groups = [makeGroupInfo()]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-existing-data")) var currentUser = user

    var state = Home.Feature.State(currentUser: $currentUser)
    state.promisesState = .loaded([])

    let store = TestStore(initialState: state) {
      Home.Feature()
    } withDependencies: {
      $0.promiseClient.getHomePromises = { _, _ in [] }
      $0.notificationClient.getUnreadCount = { _ in 0 }
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.briefingClient.generate = { _ in BriefingResult(summary: "", detail: "") }
      $0.locationClient.getCurrentLocation = { Coordinate(latitude: 37.5, longitude: 127.0) }
      $0.locationClient.reverseGeocode = { _ in "서울" }
      $0.weatherClient.getWeather = { _, _, _ in WeatherInfo() }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // refreshTriggered → fetchPromises: promisesState.value != nil이므로 .loading 스킵
    await store.send(.view(.refreshTriggered))

    await store.receive(\.internal.fetchPromises)
    // promisesState는 .loaded([]) 유지, .loading으로 전환되지 않음

    await store.receive(\.internal.promisesResponse.success)
    await store.finish()
  }

  @Test("중복 그룹 ID가 있어도 홈 조회는 고유 ID로만 요청")
  func fetchPromises_withDuplicateGroupIds_deduplicatesRequestIds() async {
    let groups = [
      makeGroupInfo(id: "group-1", name: "그룹1"),
      makeGroupInfo(id: "group-1", name: "그룹1-중복"),
      makeGroupInfo(id: "group-2", name: "그룹2"),
    ]
    let user = makeCurrentUser(groups: groups)
    @Shared(.inMemory("test-duplicate-groups")) var currentUser = user

    let requestedGroupIds = LockIsolated<[String]>([])

    let store = TestStore(
      initialState: Home.Feature.State(currentUser: $currentUser)
    ) {
      Home.Feature()
    } withDependencies: {
      $0.promiseClient.getHomePromises = { groupIds, _ in
        requestedGroupIds.setValue(groupIds)
        return []
      }
      $0.notificationClient.getUnreadCount = { _ in 0 }
      $0.notificationClient.getAuthorizationStatus = { .notDetermined }
      $0.personalEventClient.getActiveEvents = { _ in [] }
      $0.briefingClient.generate = { _ in BriefingResult(summary: "", detail: "") }
      $0.locationClient.getCurrentLocation = { Coordinate(latitude: 37.5, longitude: 127.0) }
      $0.locationClient.reverseGeocode = { _ in "서울" }
      $0.locationClient.authorizationStatus = { .notDetermined }
      $0.weatherClient.getWeather = { _, _, _ in WeatherInfo() }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
    }
    await store.receive(\.internal.fetchPromises) {
      $0.promisesState = .loading
    }
    await store.receive(\.internal.promisesResponse.success)
    await store.finish()

    #expect(requestedGroupIds.value.count == 2)
    #expect(Set(requestedGroupIds.value) == Set(["group-1", "group-2"]))
  }
}
