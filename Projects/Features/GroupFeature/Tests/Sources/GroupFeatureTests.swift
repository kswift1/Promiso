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
//  - 약속 생성/참여 시트 표시 검증
//  - 약속 응답 상태 관리 검증
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
import Sharing
@testable import GroupFeature

// MARK: - GroupFeature Tests

@Suite("GroupMain.Feature reducer 테스트")
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

  /// 테스트용 약속 생성
  private func makePromise(
    id: String = "promise-1",
    groupId: String = "group-1",
    startAt: Date = Date().addingTimeInterval(3600),
    accepted: [String] = [],
    declined: [String] = [],
    minimumParticipants: Int = 2
  ) -> PromiseModel {
    PromiseModel(
      id: id,
      title: "테스트 약속 \(id)",
      hostId: "host-id",
      groupId: groupId,
      minimumParticipants: minimumParticipants,
      votes: PromiseVotesModel(
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
        UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent, plan: .free)
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }

    await store.send(.view(.onAppear)) {
      $0.isInitialized = true
    }

    await store.receive(\.internal.fetchSettings)

    await store.receive(\.internal.settingsResponse.success) {
      $0.allGroupSummaries = []
    }

    // settingsResponse가 fetchGroupList도 트리거
    await store.receive(\.internal.setDefaultGroup)
    await store.receive(\.internal.fetchGroupList)
    await store.receive(\.internal.groupListResponse.success)
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

  @Test("과거 필터 선택 시 과거 약속 fetch")
  func filterChanged_toPast_fetchesPastPromises() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-filter-past")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.promiseClient.getPastPromises = { _, _, _ in [] }
    }

    await store.send(.view(.filterChanged(.past))) {
      $0.selectedFilter = .past
    }

    await store.receive(\.internal.fetchPastPromises) {
      $0.pastPromisesState = .loading
    }

    await store.receive(\.internal.pastPromisesResponse.success) {
      $0.pastPromisesState = .loaded([])
    }
  }

  // MARK: - 약속 생성 테스트

  @Test("약속 생성 시 createPromise 시트 표시")
  func createNewPromise_showsCreatePromiseSheet() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-create-promise")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.createNewPromise)) {
      #expect($0.createPromise != nil)
    }
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

    await store.send(.view(.createGroup)) {
      #expect($0.createGroup != nil)
    }
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

    await store.send(.view(.joinGroup)) {
      #expect($0.joinGroup != nil)
    }
  }

  // MARK: - 하이라이트 클리어 테스트

  @Test("하이라이트된 약속 클리어")
  func clearHighlightedPromise_clearsHighlight() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-highlight")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.highlightedPromiseId = "promise-1"

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.clearHighlightedPromise)) {
      $0.highlightedPromiseId = nil
    }
  }

  // MARK: - 약속 응답 테스트

  @Test("약속 수락 시 accepting 상태 설정")
  func proposalAccepted_setsAcceptingState() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-accept")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()
    state.promisesState = .loaded([makePromise()])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.promiseClient.respondPromise = { _, _ in
        RespondPromiseResult(promiseId: "promise-1", status: "accepted", isConfirmed: false, confirmedPromise: nil)
      }
      $0.groupClient.fetchGroupSummaries = { [] }
    }

    await store.send(.view(.proposalAccepted("promise-1"))) {
      $0.proposalResponding["promise-1"] = .accepting
    }

    await store.receive(\.internal.respondPromise)
    await store.receive(\.internal.proposalRespondDone) {
      $0.proposalResponding["promise-1"] = nil
    }

    // 응답 후 그룹 리스트 갱신
    await store.receive(\.internal.fetchGroupList)
    await store.receive(\.internal.groupListResponse.success)
  }

  @Test("약속 거절 시 rejecting 상태 설정")
  func proposalRejected_setsRejectingState() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-reject")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.currentGroup = makeGroup()
    state.promisesState = .loaded([makePromise()])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    } withDependencies: {
      $0.promiseClient.respondPromise = { _, _ in
        RespondPromiseResult(promiseId: "promise-1", status: "accepted", isConfirmed: false, confirmedPromise: nil)
      }
      $0.groupClient.fetchGroupSummaries = { [] }
      $0.calendarSyncClient.removePromise = { _ in }
    }

    await store.send(.view(.proposalRejected("promise-1"))) {
      $0.proposalResponding["promise-1"] = .rejecting
    }

    await store.receive(\.internal.respondPromise)
    await store.receive(\.internal.proposalRespondDone) {
      $0.proposalResponding["promise-1"] = nil
    }

    await store.receive(\.internal.fetchGroupList)
    await store.receive(\.internal.groupListResponse.success)
  }

  // MARK: - 약속 삭제 테스트

  @Test("약속 삭제 요청 시 알럿 표시")
  func promiseDeleteRequested_showsAlert() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-delete-alert")) var currentUser = user

    let promise = makePromise()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.promisesState = .loaded([promise])

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.promiseDeleteRequested("promise-1"))) {
      $0.promiseToDelete = "promise-1"
      #expect($0.deleteAlert != nil)
    }
  }

  // MARK: - Widget 딥링크 테스트

  @Test("그룹 없을 때 openCreatePromiseIfPossible 무시")
  func openCreatePromiseIfPossible_noGroups_doesNothing() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-widget-no-groups")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = []

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.openCreatePromiseIfPossible))
    // 그룹 없으므로 아무 동작 없음
  }

  @Test("그룹 있을 때 openCreatePromiseIfPossible 약속 생성")
  func openCreatePromiseIfPossible_withGroups_createsPromise() async {
    let groupInfo = makeGroupInfo()
    let user = makeCurrentUser(groups: [groupInfo])
    @Shared(.inMemory("test-widget-with-groups")) var currentUser = user

    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = [groupInfo]
    state.currentGroup = makeGroup()

    let store = TestStore(initialState: state) {
      GroupMain.Feature()
    }

    await store.send(.view(.openCreatePromiseIfPossible))

    await store.receive(\.view.createNewPromise) {
      #expect($0.createPromise != nil)
    }
  }
}
