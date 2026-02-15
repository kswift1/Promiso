import Testing
@testable import NotificationCenterFeature

@Suite("NotificationCenter.Feature reducer 테스트")
@MainActor
struct NotificationCenterFeatureTests {

  // MARK: - Test Helpers

  private func makeNotification(
    id: String = "notif-1",
    userId: String = "test-user",
    type: NotificationCategory = .promiseInvitation,
    title: String = "테스트 알림",
    body: String = "알림 내용",
    promiseId: String? = "promise-1",
    groupId: String? = "group-1",
    isRead: Bool = false,
    createdAt: Date = Date()
  ) -> NotificationModel {
    NotificationModel(
      notificationId: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      promiseId: promiseId,
      groupId: groupId,
      isRead: isRead,
      createdAt: createdAt
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = NotificationCenter.Feature.State()

    #expect(state.filter == .all)
    #expect(state.hasLoadedOnce == false)
    #expect(state.isLoadingMore == false)
    #expect(state.hasMoreData == true)
    #expect(state.isEditMode == false)
    #expect(state.selectedNotificationIds.isEmpty)
    #expect(state.isDeleting == false)
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 hasLoadedOnce 설정 및 알림 목록 로드")
  func onAppear_setsHasLoadedOnceAndFetches() async {
    let notifications = [makeNotification()]

    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.getNotifications = { _, _, _ in notifications }
    }

    await store.send(.view(.onAppear)) {
      $0.hasLoadedOnce = true
      $0.notificationsState = .loading
    }

    await store.receive(\.internal.fetchNotifications)

    await store.receive(\.internal.notificationsResponse) {
      $0.notificationsState = .loaded(notifications)
      $0.hasMoreData = false // 1개 < pageSize(20)
    }
  }

  @Test("onAppear 반복 호출 시 무시 (이미 로드)")
  func onAppear_alreadyLoaded_ignored() async {
    var state = NotificationCenter.Feature.State()
    state.hasLoadedOnce = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.onAppear))
    // hasLoadedOnce가 true이므로 아무 동작 없음
  }

  // MARK: - 필터 테스트

  @Test("filterChanged 시 필터 업데이트")
  func filterChanged_updatesFilter() async {
    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.filterChanged(.unread))) {
      $0.filter = .unread
    }
  }

  @Test("filterChanged - 같은 필터 선택 시 무시")
  func filterChanged_sameFilter_ignored() async {
    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    // 기본값이 .all이므로 동일 필터
    await store.send(.view(.filterChanged(.all)))
  }

  // MARK: - 편집 모드 테스트

  @Test("editButtonTapped 시 편집 모드 활성화")
  func editButtonTapped_enablesEditMode() async {
    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.editButtonTapped)) {
      $0.isEditMode = true
      $0.selectedNotificationIds = []
    }
  }

  @Test("cancelEditTapped 시 편집 모드 비활성화 및 선택 초기화")
  func cancelEditTapped_disablesEditMode() async {
    var state = NotificationCenter.Feature.State()
    state.isEditMode = true
    state.selectedNotificationIds = ["notif-1", "notif-2"]

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.cancelEditTapped)) {
      $0.isEditMode = false
      $0.selectedNotificationIds = []
    }
  }

  @Test("notificationSelected 시 선택 토글 (추가)")
  func notificationSelected_addsToSelection() async {
    var state = NotificationCenter.Feature.State()
    state.isEditMode = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.notificationSelected("notif-1"))) {
      $0.selectedNotificationIds = ["notif-1"]
    }
  }

  @Test("notificationSelected 시 선택 토글 (제거)")
  func notificationSelected_removesFromSelection() async {
    var state = NotificationCenter.Feature.State()
    state.isEditMode = true
    state.selectedNotificationIds = ["notif-1"]

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.notificationSelected("notif-1"))) {
      $0.selectedNotificationIds = []
    }
  }

  // MARK: - 삭제 테스트

  @Test("deleteSelectedTapped - 선택된 알림 삭제")
  func deleteSelectedTapped_deletesSelected() async {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
      makeNotification(id: "notif-3"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.isEditMode = true
    state.selectedNotificationIds = ["notif-1", "notif-3"]

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.deleteNotifications = { _ in }
    }
    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.deleteSelectedTapped)) {
      $0.isDeleting = true
    }

    await store.receive(\.internal.deleteCompleted) {
      $0.isDeleting = false
      $0.notificationsState = .loaded([notifications[1]])
      $0.selectedNotificationIds = []
      $0.isEditMode = false
    }

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .success)
    #expect(store.state.toastMessage?.title == "알림 2개를 삭제했어요")
    #expect(store.state.toastMessage?.position == .bottom)
  }

  @Test("deleteSelectedTapped - 선택 없으면 무시")
  func deleteSelectedTapped_noSelection_ignored() async {
    var state = NotificationCenter.Feature.State()
    state.isEditMode = true
    state.selectedNotificationIds = []

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.deleteSelectedTapped))
  }

  // MARK: - dismissTapped 테스트

  @Test("dismissTapped 시 delegate.dismiss 전달")
  func dismissTapped_sendsDelegateDissmiss() async {
    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.dismissTapped))
    await store.receive(\.delegate.dismiss)
  }

  // MARK: - refreshTriggered 테스트

  @Test("refreshTriggered 시 알림 목록 새로고침")
  func refreshTriggered_fetchesNotifications() async {
    let notifications = [makeNotification()]

    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.getNotifications = { _, _, _ in notifications }
    }

    await store.send(.view(.refreshTriggered))

    await store.receive(\.internal.fetchNotifications)

    await store.receive(\.internal.notificationsResponse) {
      $0.notificationsState = .loaded(notifications)
      $0.hasMoreData = false
    }
  }

  // MARK: - 전체 읽음 처리 테스트

  @Test("markAllAsReadCompleted 성공 시 모든 알림 읽음 처리")
  func markAllAsReadCompleted_success_marksAllAsRead() async {
    let notifications = [
      makeNotification(id: "notif-1", isRead: false),
      makeNotification(id: "notif-2", isRead: true),
      makeNotification(id: "notif-3", isRead: false),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }
    store.exhaustivity = .off

    await store.send(.internal(.markAllAsReadCompleted(.success(()))))

    // readAt: Date()가 reducer 내부에서 생성되므로 exhaustive 비교 불가
    // 수동으로 읽음 상태만 검증
    if case .loaded(let updatedNotifications) = store.state.notificationsState {
      #expect(updatedNotifications.count == 3)
      for notification in updatedNotifications {
        #expect(notification.isRead == true)
      }
    } else {
      Issue.record("Expected .loaded state after markAllAsReadCompleted")
    }
  }

  // MARK: - Computed Properties 테스트

  @Test("notifications - loaded 상태에서 필터 적용")
  func notifications_filterApplied() {
    let notifications = [
      makeNotification(id: "notif-1", isRead: false),
      makeNotification(id: "notif-2", isRead: true),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)

    // all 필터
    state.filter = .all
    #expect(state.notifications.count == 2)

    // unread 필터
    state.filter = .unread
    #expect(state.notifications.count == 1)
    #expect(state.notifications.first?.notificationId == "notif-1")
  }

  @Test("unreadCount - 읽지 않은 알림 수")
  func unreadCount_returnsCorrectCount() {
    let notifications = [
      makeNotification(id: "notif-1", isRead: false),
      makeNotification(id: "notif-2", isRead: true),
      makeNotification(id: "notif-3", isRead: false),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.filter = .all

    #expect(state.unreadCount == 2)
  }

  @Test("isEmpty - loaded 상태에서 알림 없으면 true")
  func isEmpty_emptyLoaded_returnsTrue() {
    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded([])

    #expect(state.isEmpty == true)
  }

  @Test("isEmpty - idle 상태에서는 false")
  func isEmpty_idle_returnsFalse() {
    let state = NotificationCenter.Feature.State()

    // idle이면 isLoaded가 false이므로 isEmpty도 false
    #expect(state.isEmpty == false)
  }

  @Test("isLoading - loading 상태에서 true")
  func isLoading_loading_returnsTrue() {
    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loading

    #expect(state.isLoading == true)
  }

  @Test("isAllSelected - 전체 선택 시 true")
  func isAllSelected_allSelected_returnsTrue() {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.selectedNotificationIds = ["notif-1", "notif-2"]

    #expect(state.isAllSelected == true)
  }

  @Test("isAllSelected - 일부 선택 시 false")
  func isAllSelected_partialSelection_returnsFalse() {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.selectedNotificationIds = ["notif-1"]

    #expect(state.isAllSelected == false)
  }

  @Test("selectedCount - 선택된 알림 수 반환")
  func selectedCount_returnsCorrectCount() {
    var state = NotificationCenter.Feature.State()
    state.selectedNotificationIds = ["notif-1", "notif-2", "notif-3"]

    #expect(state.selectedCount == 3)
  }

  // MARK: - Internal 응답 테스트

  @Test("notificationsResponse 실패 시 에러 상태 설정 (refresh)")
  func notificationsResponse_failure_refresh_setsError() async {
    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "네트워크 오류"])
    await store.send(.internal(.notificationsResponse(.failure(error), isRefresh: true))) {
      $0.notificationsState = .failed(error)
    }
  }

  @Test("notificationsResponse 실패 시 추가 로드는 기존 데이터 유지")
  func notificationsResponse_failure_loadMore_keepsExisting() async {
    let existing = [makeNotification(id: "notif-1")]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(existing)
    state.isLoadingMore = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    let error = NSError(domain: "test", code: -1)
    await store.send(.internal(.notificationsResponse(.failure(error), isRefresh: false))) {
      $0.isLoadingMore = false
      // notificationsState는 변경되지 않음 (기존 데이터 유지)
    }
  }

  @Test("deleteCompleted 실패 시 isDeleting만 해제")
  func deleteCompleted_failure_onlyClearsDeleting() async {
    var state = NotificationCenter.Feature.State()
    state.isDeleting = true
    state.notificationsState = .loaded([makeNotification()])

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }
    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    let error = NSError(domain: "test", code: -1)
    await store.send(.internal(.deleteCompleted(deletedIds: ["notif-1"], .failure(error)))) {
      $0.isDeleting = false
      // 실패 시 notificationsState와 selectedNotificationIds는 변경되지 않음
    }

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .error)
    #expect(store.state.toastMessage?.title == "알림 삭제에 실패했어요")
    #expect(store.state.toastMessage?.subtitle == error.localizedDescription)
    #expect(store.state.toastMessage?.position == .bottom)
  }

  // MARK: - notificationTapped 테스트

  @Test("notificationTapped - 읽지 않은 약속 알림 탭 시 읽음 처리 + 약속 이동")
  func notificationTapped_unreadPromise_marksReadAndNavigates() async {
    let notification = makeNotification(
      id: "notif-1",
      type: .promiseInvitation,
      promiseId: "promise-1",
      groupId: "group-1",
      isRead: false
    )

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded([notification])

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.markAsRead = { _ in }
    }
    // markAsReadCompleted 내부에서 readAt: Date() 생성 → exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.notificationTapped(notification)))
    await store.receive(\.delegate.navigateToPromise)
    await store.receive(\.internal.markAsReadCompleted)
  }

  @Test("notificationTapped - 읽은 약속 알림 탭 시 약속 이동만")
  func notificationTapped_readPromise_onlyNavigates() async {
    let notification = makeNotification(
      id: "notif-1",
      type: .promiseInvitation,
      promiseId: "promise-1",
      groupId: "group-1",
      isRead: true
    )

    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.notificationTapped(notification)))
    await store.receive(\.delegate.navigateToPromise)
  }

  @Test("notificationTapped - 그룹 알림 탭 시 그룹 이동")
  func notificationTapped_groupNotification_navigatesToGroup() async {
    let notification = makeNotification(
      id: "notif-1",
      type: .groupInvitation,
      promiseId: nil,
      groupId: "group-1",
      isRead: true
    )

    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.notificationTapped(notification)))
    await store.receive(\.delegate.navigateToGroup)
  }

  // MARK: - selectAllTapped 테스트

  @Test("selectAllTapped - 전체 선택")
  func selectAllTapped_selectsAll() async {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.isEditMode = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.selectAllTapped)) {
      $0.selectedNotificationIds = ["notif-1", "notif-2"]
    }
  }

  @Test("selectAllTapped - 전체 선택 상태에서 전체 해제")
  func selectAllTapped_allSelected_deselectsAll() async {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)
    state.isEditMode = true
    state.selectedNotificationIds = ["notif-1", "notif-2"]

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.selectAllTapped)) {
      $0.selectedNotificationIds = []
    }
  }

  // MARK: - loadMoreTriggered 테스트

  @Test("loadMoreTriggered - 추가 로드 시작 및 기존 데이터에 append")
  func loadMoreTriggered_appendsNewData() async {
    let existing = [makeNotification(id: "notif-1")]
    let newNotifications = [makeNotification(id: "notif-2")]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(existing)
    state.hasMoreData = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.getNotifications = { _, _, _ in newNotifications }
    }

    await store.send(.view(.loadMoreTriggered)) {
      $0.isLoadingMore = true
    }

    await store.receive(\.internal.fetchNotifications)

    await store.receive(\.internal.notificationsResponse) {
      $0.isLoadingMore = false
      $0.notificationsState = .loaded(existing + newNotifications)
      $0.hasMoreData = false // 1 < pageSize(20)
    }
  }

  @Test("loadMoreTriggered - 이미 로딩 중이면 무시")
  func loadMoreTriggered_alreadyLoading_ignored() async {
    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded([makeNotification()])
    state.isLoadingMore = true

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.loadMoreTriggered))
  }

  @Test("loadMoreTriggered - hasMoreData false이면 무시")
  func loadMoreTriggered_noMoreData_ignored() async {
    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded([makeNotification()])
    state.hasMoreData = false

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    await store.send(.view(.loadMoreTriggered))
  }

  // MARK: - deleteAllTapped 테스트

  @Test("deleteAllTapped - 전체 알림 삭제")
  func deleteAllTapped_deletesAllNotifications() async {
    let notifications = [
      makeNotification(id: "notif-1"),
      makeNotification(id: "notif-2"),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.deleteAllNotifications = { () async throws in }
    }
    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.deleteAllTapped)) {
      $0.isDeleting = true
    }

    await store.receive(\.internal.deleteCompleted) {
      $0.isDeleting = false
      $0.notificationsState = .loaded([])
      $0.selectedNotificationIds = []
      $0.isEditMode = false
    }

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .success)
    #expect(store.state.toastMessage?.title == "알림 2개를 삭제했어요")
    #expect(store.state.toastMessage?.position == .bottom)
  }

  // MARK: - markAllAsReadTapped 테스트

  @Test("markAllAsReadTapped 시 전체 읽음 처리 API 호출")
  func markAllAsReadTapped_callsAPI() async {
    let notifications = [
      makeNotification(id: "notif-1", isRead: false),
      makeNotification(id: "notif-2", isRead: false),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    } withDependencies: {
      $0.notificationClient.markAllAsRead = { () async throws in }
    }
    // markAllAsReadCompleted 내부에서 readAt: Date() 생성
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.markAllAsReadTapped))
    await store.receive(\.internal.markAllAsReadCompleted)

    if case .loaded(let updated) = store.state.notificationsState {
      #expect(updated.count == 2)
      for notification in updated {
        #expect(notification.isRead == true)
      }
    } else {
      Issue.record("Expected .loaded state after markAllAsReadTapped")
    }
  }

  // MARK: - markAllAsReadCompleted 실패 테스트

  @Test("markAllAsReadCompleted 실패 시 상태 변경 없음")
  func markAllAsReadCompleted_failure_noChange() async {
    let notifications = [
      makeNotification(id: "notif-1", isRead: false),
    ]

    var state = NotificationCenter.Feature.State()
    state.notificationsState = .loaded(notifications)

    let store = TestStore(initialState: state) {
      NotificationCenter.Feature()
    }

    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    let error = NSError(domain: "test", code: -1)
    await store.send(.internal(.markAllAsReadCompleted(.failure(error))))
    // 실패 시 notificationsState 변경 없음

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .error)
    #expect(store.state.toastMessage?.title == "읽음 처리에 실패했어요")
    #expect(store.state.toastMessage?.subtitle == error.localizedDescription)
    #expect(store.state.toastMessage?.position == .bottom)
  }

  // MARK: - notificationsResponse 추가 로드 성공 테스트

  @Test("notificationsResponse 성공 - pageSize 이상이면 hasMoreData true")
  func notificationsResponse_success_fullPage_hasMoreData() async {
    let fullPage = (0..<20).map { makeNotification(id: "notif-\($0)") }

    let store = TestStore(
      initialState: NotificationCenter.Feature.State()
    ) {
      NotificationCenter.Feature()
    }

    await store.send(.internal(.notificationsResponse(.success(fullPage), isRefresh: true))) {
      $0.notificationsState = .loaded(fullPage)
      $0.hasMoreData = true // 20 >= pageSize(20)
    }
  }
}
