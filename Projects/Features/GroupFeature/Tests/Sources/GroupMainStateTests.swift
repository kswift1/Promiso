//
//  GroupMainStateTests.swift
//  GroupFeature
//
//  GroupMain.Feature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/GroupMain/GroupMainFeature.swift`
//  - State의 computed properties (필터링, 정렬, 그룹화)
//
//  ## 사용처
//  - **GroupMainView**: 약속 목록 표시, 필터 선택, 그룹 바
//  - **GroupMain**: 약속 필터링 및 정렬 로직
//
//  ## 테스트 목적
//  - 필터별 약속 필터링 로직 검증
//  - 정렬 순서 검증 (시간순, 마감순)
//  - 날짜별 그룹화 로직 검증
//

import Testing
import PromisoShared
@testable import GroupFeature

// MARK: - GroupMain State Tests

@Suite("GroupMain.Feature.State computed properties 테스트")
@MainActor
struct GroupMainStateTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser() -> UserPrivateModel {
    UserPrivateModel(
      userId: "current-user",
      name: "테스트",
      nickname: "테스트",
      email: "test@example.com",
      provider: "iOS",
      metadata: .init()
    )
  }

  /// 테스트용 그룹 생성
  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    memberIds: [String] = ["current-user", "user2", "user3"]
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberIds: memberIds,
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "current-user"
    )
  }

  /// 테스트용 약속 생성
  private func makePromise(
    id: String = "promise-1",
    startAt: Date = Date().addingTimeInterval(3600),
    voteUntil: Date = Date().addingTimeInterval(1800),
    accepted: [String] = [],
    declined: [String] = [],
    minimumParticipants: Int = 2
  ) -> PromiseModel {
    let votes = PromiseVotesModel(
      accepted: accepted,
      declined: declined,
      until: voteUntil
    )
    return PromiseModel(
      id: id,
      title: "테스트 약속 \(id)",
      hostId: "host-id",
      groupId: "group-1",
      minimumParticipants: minimumParticipants,
      votes: votes,
      startAt: startAt
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    promises: [PromiseModel] = [],
    selectedFilter: GroupMain.PromiseFilter = .all,
    currentGroup: GroupModel? = nil
  ) -> GroupMain.Feature.State {
    @Shared(.inMemory("test-current-user")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.promisesState = promises.isEmpty ? .idle : .loaded(promises)
    state.selectedFilter = selectedFilter
    state.currentGroup = currentGroup ?? makeGroup()
    return state
  }

  // MARK: - needResponsePromises 테스트

  @Test("응답 필요 약속만 필터링 (현재 사용자 미응답)")
  func needResponsePromises_filtersUnrespondedPromises() {
    // 현재 사용자가 응답하지 않은 약속
    let needResponse = makePromise(id: "need", accepted: [], declined: [])

    // 현재 사용자가 이미 응답한 약속
    let alreadyResponded = makePromise(id: "responded", accepted: ["current-user"], declined: [])

    let state = makeState(promises: [needResponse, alreadyResponded])

    #expect(state.needResponsePromises.count == 1)
    #expect(state.needResponsePromises.first?.id == "need")
  }

  @Test("응답 필요 약속 마감 임박순 정렬")
  func needResponsePromises_sortsByVoteUntil() {
    let laterDeadline = makePromise(
      id: "later",
      voteUntil: Date().addingTimeInterval(7200)
    )
    let earlierDeadline = makePromise(
      id: "earlier",
      voteUntil: Date().addingTimeInterval(3600)
    )

    let state = makeState(promises: [laterDeadline, earlierDeadline])

    #expect(state.needResponsePromises.count == 2)
    #expect(state.needResponsePromises[0].id == "earlier") // 마감 임박순
    #expect(state.needResponsePromises[1].id == "later")
  }

  // MARK: - confirmedPromises 테스트

  @Test("확정된 미래 약속만 필터링")
  func confirmedPromises_filtersConfirmedFutureOnly() {
    // 확정된 미래 약속
    let confirmedFuture = makePromise(
      id: "confirmed-future",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    // 확정되지 않은 약속
    let notConfirmed = makePromise(
      id: "not-confirmed",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["user1"],
      minimumParticipants: 2
    )

    // 확정된 과거 약속
    let confirmedPast = makePromise(
      id: "confirmed-past",
      startAt: Date().addingTimeInterval(-3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    let state = makeState(promises: [confirmedFuture, notConfirmed, confirmedPast])

    #expect(state.confirmedPromises.count == 1)
    #expect(state.confirmedPromises.first?.id == "confirmed-future")
  }

  @Test("확정 약속 시작 시간순 정렬")
  func confirmedPromises_sortsByStartTime() {
    let laterStart = makePromise(
      id: "later",
      startAt: Date().addingTimeInterval(7200),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )
    let earlierStart = makePromise(
      id: "earlier",
      startAt: Date().addingTimeInterval(3600),
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )

    let state = makeState(promises: [laterStart, earlierStart])

    #expect(state.confirmedPromises.count == 2)
    #expect(state.confirmedPromises[0].id == "earlier")
    #expect(state.confirmedPromises[1].id == "later")
  }

  // MARK: - allPromises 테스트

  @Test("모든 약속 시작 시간순 정렬")
  func allPromises_sortsByStartTime() {
    let promise3 = makePromise(id: "3", startAt: Date().addingTimeInterval(10800))
    let promise1 = makePromise(id: "1", startAt: Date().addingTimeInterval(3600))
    let promise2 = makePromise(id: "2", startAt: Date().addingTimeInterval(7200))

    let state = makeState(promises: [promise3, promise1, promise2])

    #expect(state.allPromises.count == 3)
    #expect(state.allPromises[0].id == "1")
    #expect(state.allPromises[1].id == "2")
    #expect(state.allPromises[2].id == "3")
  }

  // MARK: - filteredPromises 테스트

  @Test("필터 변경 시 해당 필터 결과 반환")
  func filteredPromises_returnsCorrectFilterResults() {
    let confirmedPromise = makePromise(
      id: "confirmed",
      accepted: ["current-user", "user1", "user2"],
      minimumParticipants: 2
    )
    let pendingPromise = makePromise(id: "pending", accepted: [])

    var state = makeState(promises: [confirmedPromise, pendingPromise])

    // 전체 필터
    state.selectedFilter = .all
    #expect(state.filteredPromises.count == 2)

    // 확정 필터
    state.selectedFilter = .confirmed
    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "confirmed")
  }

  // MARK: - filterCounts 테스트

  @Test("필터별 약속 개수 계산")
  func filterCounts_calculatesCorrectCounts() {
    let confirmed1 = makePromise(id: "c1", accepted: ["current-user", "user1", "user2"], minimumParticipants: 2)
    let confirmed2 = makePromise(id: "c2", accepted: ["current-user", "user1", "user2"], minimumParticipants: 2)
    let pending = makePromise(id: "p1", accepted: [])

    let state = makeState(promises: [confirmed1, confirmed2, pending])

    #expect(state.filterCounts[.all] == 3)
    #expect(state.filterCounts[.confirmed] == 2)
  }

  // MARK: - isOnboardingMode 테스트

  @Test("그룹 없으면 온보딩 모드")
  func isOnboardingMode_whenNoGroups_returnsTrue() {
    @Shared(.inMemory("test-no-groups")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = []

    #expect(state.isOnboardingMode == true)
  }

  @Test("그룹 있으면 온보딩 모드 아님")
  func isOnboardingMode_whenHasGroups_returnsFalse() {
    @Shared(.inMemory("test-has-groups")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = [
      UserGroupInfo(id: "g1", name: "테스트 그룹")
    ]

    #expect(state.isOnboardingMode == false)
  }

  // MARK: - groupBarItems 테스트

  @Test("그룹 목록을 GroupBarItem으로 변환")
  func groupBarItems_convertsGroupSummaries() {
    @Shared(.inMemory("test-group-bar")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = [
      UserGroupInfo(id: "g1", name: "그룹1", hasNewActivity: true),
      UserGroupInfo(id: "g2", name: "그룹2", hasNewActivity: false)
    ]
    state.currentGroup = makeGroup(id: "g1", name: "그룹1")

    #expect(state.groupBarItems.count == 2)
    #expect(state.groupBarItems[0].id == "g1")
    #expect(state.groupBarItems[0].isSelected == true)
    #expect(state.groupBarItems[0].hasNewActivity == true)
    #expect(state.groupBarItems[1].id == "g2")
    #expect(state.groupBarItems[1].isSelected == false)
  }

  @Test("그룹 없으면 온보딩 Mock 그룹 표시")
  func groupBarItems_whenNoGroups_showsOnboardingItem() {
    @Shared(.inMemory("test-onboarding")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.allGroupSummaries = []

    #expect(state.groupBarItems.count == 1)
    #expect(state.groupBarItems[0].id == GroupMain.onboardingGroupId)
    #expect(state.groupBarItems[0].name == LocalizedStrings.GroupMain.onboardingGroupName)
  }

  // MARK: - isPastFilterLoading 테스트

  @Test("과거 필터 + 로딩 중이면 true")
  func isPastFilterLoading_whenPastAndLoading_returnsTrue() {
    @Shared(.inMemory("test-past-loading")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .past
    state.pastPromisesState = .loading

    #expect(state.isPastFilterLoading == true)
  }

  @Test("과거 필터 + 로딩 완료면 false")
  func isPastFilterLoading_whenPastAndLoaded_returnsFalse() {
    @Shared(.inMemory("test-past-loaded")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .past
    state.pastPromisesState = .loaded([])

    #expect(state.isPastFilterLoading == false)
  }

  @Test("다른 필터면 false")
  func isPastFilterLoading_whenOtherFilter_returnsFalse() {
    @Shared(.inMemory("test-other-filter")) var currentUser = makeCurrentUser()
    var state = GroupMain.Feature.State(currentUser: $currentUser)
    state.selectedFilter = .all
    state.pastPromisesState = .loading

    #expect(state.isPastFilterLoading == false)
  }

  // MARK: - filteredPromises 추가 테스트

  @Test("needResponse 필터 시 미응답 약속만 반환")
  func filteredPromises_needResponse_returnsUnrespondedOnly() {
    let responded = makePromise(id: "responded", accepted: ["current-user"])
    let unresponded = makePromise(id: "unresponded", accepted: [])

    var state = makeState(promises: [responded, unresponded])
    state.selectedFilter = .needResponse

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "unresponded")
  }
}
