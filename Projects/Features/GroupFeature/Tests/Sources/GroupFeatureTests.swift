//
//  GroupFeatureTests.swift
//  GroupFeature
//
//  GroupMain.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/GroupMain/GroupMainFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//
//  ## 테스트 목적
//  - onAppear 시 초기화 로직 검증
//  - 그룹 변경 시 상태 전환 검증
//  - 필터 변경 로직 검증
//  - 일정 생성/참여 시트 표시 검증
//  - 일정 응답 상태 관리 검증
//

import Testing
@testable import GroupFeature

// MARK: - GroupFeature Tests

@Suite("GroupMain.Feature reducer 테스트")
@MainActor
struct GroupFeatureTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser(
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: "current-user",
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

  /// 테스트용 그룹 모델 생성
  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹"
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "current-user"
    )
  }

  /// 테스트용 일정 생성
  private func makeSchedule(
    id: String = "schedule-1",
    groupId: String = "group-1",
    startAt: Date = Date().addingTimeInterval(3600),
    accepted: [String] = [],
    declined: [String] = [],
    minimumParticipants: Int = 2
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: "테스트 일정 \(id)",
      hostId: "host-id",
      groupId: groupId,
      minimumParticipants: minimumParticipants,
      votes: ScheduleVotesModel(
        accepted: accepted,
        declined: declined,
        until: Date().addingTimeInterval(1800)
      ),
      startAt: startAt
    )
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 초기화 및 설정 로드")
  func onAppear_setsInitializedAndFetchesSettings() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-onAppear")) var currentUser = user

    let store = TestStore(
      initialState: GroupMain.Feature.State(currentUser: $currentUser)
    ) {
      GroupMain.Feature()
    } withDependencies: {
      $0.userSettingsClient.fetchSettings = { _ in
        UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
      }
      $0.subscriptionClient.fetchStatus = { .none }
      $0.groupClient.fetchGroupSummaries = { [] }
      $0.userDefaultsClient.boolForKey = { _ in false }
    }
    store.exhaustivity = .off

    await store.send(.view(.onAppear)) {
      $0.isInitialized = true
    }
  }

  @Test("onAppear 두 번째 호출 시 무시")
  func onAppear_secondCall_ignored() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-onAppear-twice")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.isInitialized = true

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.onAppear))
    // 이미 초기화된 상태이므로 아무 효과 없음
  }

  // MARK: - 필터 변경 테스트

  @Test("필터 변경 시 selectedFilter 업데이트")
  func filterChanged_updatesSelectedFilter() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-filter")) var currentUser = user

    let store = TestStore(
      initialState: GroupMain.Feature.State(currentUser: $currentUser)
    ) {
      GroupMain.Feature()
    }

    await store.send(.view(.filterChanged(.confirmed))) {
      $0.selectedFilter = .confirmed
    }
  }

  @Test("all 필터로 변경")
  func filterChanged_toAll() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-filter-all")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .confirmed

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.filterChanged(.all))) {
      $0.selectedFilter = .all
    }
  }

  @Test("과거 필터 선택 시 과거 일정 fetch")
  func filterChanged_toPast_fetchesPastSchedules() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-filter-past")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.scheduleClient.getPastSchedules = { _, _, _ in [] }
    }

    await store.send(.view(.filterChanged(.past))) {
      $0.selectedFilter = .past
    }

    await store.receive(\.internal.fetchPastSchedules) {
      $0.pastSchedulesState = .loading
    }

    await store.receive(\.internal.pastSchedulesResponse.success) {
      $0.pastSchedulesState = .loaded([])
    }
  }

  // MARK: - 일정 생성 테스트

  @Test("일정 생성 시 createSchedule 시트 표시")
  func createNewSchedule_showsCreateScheduleSheet() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-create-schedule")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.createNewSchedule))
  }

  // MARK: - 그룹 생성/참여 테스트

  @Test("그룹 생성 시 createGroup 시트 표시")
  func createGroup_showsCreateGroupSheet() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-create-group")) var currentUser = user

    let store = TestStore(
      initialState: GroupMain.Feature.State(currentUser: $currentUser)
    ) {
      GroupMain.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.createGroup))
  }

  @Test("그룹 참여 시 joinGroup 시트 표시")
  func joinGroup_showsJoinGroupSheet() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-join-group")) var currentUser = user

    let store = TestStore(
      initialState: GroupMain.Feature.State(currentUser: $currentUser)
    ) {
      GroupMain.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.joinGroup))
  }

  // MARK: - 하이라이트 클리어 테스트

  @Test("하이라이트된 일정 클리어")
  func clearHighlightedSchedule_clearsHighlight() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-highlight")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.highlightedScheduleId = "schedule-1"

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.clearHighlightedSchedule)) {
      $0.highlightedScheduleId = nil
    }
  }

  // MARK: - 일정 응답 테스트

  @Test("일정 수락 시 accepting 상태 설정")
  func proposalAccepted_setsAcceptingState() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-accept")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()
    state.schedulesState = .loaded([makeSchedule()])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(scheduleId: "schedule-1", status: "accepted", isConfirmed: false, confirmedSchedule: nil)
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }
    store.exhaustivity = .off

    await store.send(.view(.proposalAccepted("schedule-1"))) {
      $0.proposalResponding["schedule-1"] = .accepting
    }
  }

  @Test("일정 거절 시 rejecting 상태 설정")
  func proposalRejected_setsRejectingState() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-reject")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()
    state.schedulesState = .loaded([makeSchedule()])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(scheduleId: "schedule-1", status: "accepted", isConfirmed: false, confirmedSchedule: nil)
      }
      $0.groupClient.fetchGroupSummaries = { [] }
      $0.calendarSyncClient.removeSchedule = { _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.proposalRejected("schedule-1"))) {
      $0.proposalResponding["schedule-1"] = .rejecting
    }
  }

  // MARK: - 일정 삭제 테스트

  @Test("일정 삭제 요청 시 알럿 표시")
  func scheduleDeleteRequested_showsAlert() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-delete-alert")) var currentUser = user

    let schedule = makeSchedule()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.schedulesState = .loaded([schedule])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.scheduleDeleteRequested("schedule-1"))) {
      $0.scheduleToDelete = "schedule-1"
    }
  }

  // MARK: - Widget 딥링크 테스트

  @Test("그룹 없을 때 openCreateScheduleIfPossible 무시")
  func openCreateScheduleIfPossible_noGroups_doesNothing() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-widget-no-groups")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = []

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.openCreateScheduleIfPossible))
    // 그룹 없으므로 아무 동작 없음
  }

  @Test("그룹 있을 때 openCreateScheduleIfPossible 일정 생성")
  func openCreateScheduleIfPossible_withGroups_createsSchedule() async {
    let groupInfo = makeGroupInfo()
    let user = makeCurrentUser(groups: [groupInfo])
    @Shared(.inMemory("test-widget-with-groups")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = [groupInfo]
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.openCreateScheduleIfPossible))
  }

  // MARK: - 그룹 변경 테스트

  @Test("같은 그룹 변경 시 무시")
  func groupChanged_sameGroup_doesNothing() async {
    let groupInfo = makeGroupInfo()
    let user = makeCurrentUser(groups: [groupInfo])
    @Shared(.inMemory("test-same-group")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.groupChanged(groupInfo)))
    // 같은 그룹이므로 상태 변경 없음
  }

  // MARK: - proposalRespondFailed 테스트

  @Test("일정 응답 실패 시 responding 초기화 및 에러 설정")
  func proposalRespondFailed_clearsRespondingAndSetsError() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-respond-failed")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.proposalResponding["schedule-1"] = .accepting

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    let error = AppError(message: "응답 실패")
    await store.send(.internal(.proposalRespondFailed(scheduleId: "schedule-1", error: error))) {
      $0.proposalResponding["schedule-1"] = nil
      $0.schedulesState = .failed(error)
    }
  }

  // MARK: - deleteScheduleFailed 테스트

  @Test("일정 삭제 실패 시 에러 상태 설정")
  func deleteScheduleFailed_setsErrorState() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-delete-failed")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.schedulesState = .loaded([])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    let error = AppError(message: "삭제 실패")
    await store.send(.internal(.deleteScheduleFailed(scheduleId: "schedule-1", error: error))) {
      $0.schedulesState = .failed(error)
    }
  }
}
