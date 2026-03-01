import Testing
@testable import HomeFeature

@Suite("HomeFeature.State computed properties 테스트")
@MainActor
struct HomeFeatureStateTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser() -> UserPrivateModel {
    UserPrivateModel(
      userId: "current-user",
      name: "테스트 유저",
      nickname: "테스트",
      email: "test@example.com",
      provider: "iOS",
      metadata: .init()
    )
  }

  /// 테스트용 PromiseModel 생성
  /// isConfirmed를 true로 만들려면 votes.accepted에 minimumParticipants 이상의 사용자 필요
  private func makePromise(
    id: String = "test-promise",
    title: String = "테스트 약속",
    groupId: String = "group-id",
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    minimumParticipants: Int = 2,
    votes: PromiseVotesModel? = nil
  ) -> PromiseModel {
    let defaultVotes = votes ?? PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(1800)
    )
    
    return PromiseModel(
      id: id,
      title: title,
      groupId: groupId,
      minimumParticipants: minimumParticipants,
      votes: defaultVotes,
      startAt: startAt,
      endAt: endAt
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    promisesState: LoadingState<[PromiseModel]> = .idle,
    selectedStatusFilter: HomeModels.StatusFilter = .all,
    selectedGroupId: String? = nil
  ) -> Home.Feature.State {
    @Shared(.inMemory("test-\(UUID().uuidString.prefix(8))")) var currentUser = makeCurrentUser()
    var state = Home.Feature.State(currentUser: $currentUser)
    state.promisesState = promisesState
    state.selectedStatusFilter = selectedStatusFilter
    state.selectedGroupId = selectedGroupId
    state.refreshHomeContentSnapshot()
    return state
  }

  // MARK: - isLoading 테스트

  @Test("promisesState가 loading이면 true")
  func isLoading_whenLoading_returnsTrue() {
    let state = makeState(promisesState: .loading)
    #expect(state.isLoading == true)
  }

  @Test("promisesState가 loaded이면 false")
  func isLoading_whenLoaded_returnsFalse() {
    let state = makeState(promisesState: .loaded([]))
    #expect(state.isLoading == false)
  }

  @Test("promisesState가 idle이면 false")
  func isLoading_whenIdle_returnsFalse() {
    let state = makeState(promisesState: .idle)
    #expect(state.isLoading == false)
  }

  // MARK: - homeContentSnapshot.todayPromises 테스트

  @Test("오늘 약속 목록 반환")
  func homeContentSnapshot_todayPromises_returnsConfirmedTodayPromises() {
    // KST 타임존 사용 (실제 코드와 동일)
    let calendar = Calendar.promiseDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!

    // isConfirmed = true (accepted >= minimumParticipants)
    let confirmedVotes = PromiseVotesModel(
      accepted: ["user1", "user2"],  // minimumParticipants(2) 이상
      declined: [],
      until: Date()
    )

    let promise1 = makePromise(
      id: "today-1",
      startAt: todayAfternoon,
      votes: confirmedVotes
    )
    let promise2 = makePromise(
      id: "today-2",
      startAt: todayAfternoon.addingTimeInterval(3600),
      votes: confirmedVotes
    )

    let state = makeState(promisesState: .loaded([promise1, promise2]))

    #expect(state.homeContentSnapshot.todayPromises.count == 2)
  }

  // MARK: - homeContentSnapshot.pendingPromises 테스트

  @Test("응답 필요 약속 목록 반환")
  func homeContentSnapshot_pendingPromises_returnsPendingVotePromises() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    // current-user가 pending (accepted/declined에 없음)
    let votes = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    
    let promise = makePromise(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes
    )

    let state = makeState(promisesState: .loaded([promise]))

    #expect(state.homeContentSnapshot.pendingPromises.count == 1)
  }

  // MARK: - homeContentSnapshot.upcomingPromises 테스트

  @Test("다가오는 약속 목록 반환")
  func homeContentSnapshot_upcomingPromises_returnsConfirmedUpcomingPromises() {
    // 실제 구현(Home.Feature.State.todayRange)과 동일하게 KST 기준으로 계산
    let calendar = Calendar.promiseDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    // isConfirmed = true, current-user가 accepted
    let votes = PromiseVotesModel(
      accepted: ["current-user", "user2"],  // minimumParticipants(2) 이상
      declined: [],
      until: Date()
    )

    let promise = makePromise(
      id: "upcoming-1",
      startAt: tomorrow,
      votes: votes
    )

    let state = makeState(promisesState: .loaded([promise]))

    #expect(state.homeContentSnapshot.upcomingPromises.count == 1)
  }

  // MARK: - allPromises 테스트

  @Test("모든 약속 반환")
  func allPromises_returnsAllPromises() {
    let calendar = Calendar.promiseDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    let confirmedVotes = PromiseVotesModel(
      accepted: ["user1", "user2"],
      declined: [],
      until: Date()
    )
    let today = makePromise(id: "today", startAt: todayAfternoon, votes: confirmedVotes)
    
    let pendingVotes = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let pending = makePromise(
      id: "pending",
      startAt: tomorrow,
      votes: pendingVotes
    )
    
    let upcomingVotes = PromiseVotesModel(
      accepted: ["current-user", "user2"],
      declined: [],
      until: Date()
    )
    let upcoming = makePromise(
      id: "upcoming",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: upcomingVotes
    )

    let state = makeState(promisesState: .loaded([today, pending, upcoming]))

    #expect(state.allPromises.count == 3)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 개수 반환")
  func pendingResponseCount_returnsPendingCount() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    let votes1 = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let promise1 = makePromise(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes1
    )
    
    let votes2 = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(7200)
    )
    let promise2 = makePromise(
      id: "pending-2",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: votes2
    )

    let state = makeState(promisesState: .loaded([promise1, promise2]))

    #expect(state.pendingResponseCount == 2)
  }

  @Test("응답 필요 없으면 0")
  func pendingResponseCount_whenNoPending_returnsZero() {
    let state = makeState(promisesState: .loaded([]))

    #expect(state.pendingResponseCount == 0)
  }

  // MARK: - overviewData 테스트

  @Test("오늘 약속 개수 계산")
  func overviewData_todayCount() {
    // KST 타임존 사용 (실제 코드와 동일)
    let calendar = Calendar.promiseDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!

    let confirmedVotes = PromiseVotesModel(
      accepted: ["user1", "user2"],
      declined: [],
      until: Date()
    )

    let promise1 = makePromise(id: "today-1", startAt: todayAfternoon, votes: confirmedVotes)
    let promise2 = makePromise(id: "today-2", startAt: todayAfternoon.addingTimeInterval(3600), votes: confirmedVotes)
    let promise3 = makePromise(id: "today-3", startAt: todayAfternoon.addingTimeInterval(7200), votes: confirmedVotes)

    let state = makeState(promisesState: .loaded([promise1, promise2, promise3]))

    #expect(state.overviewData.todayCount == 3)
  }

  @Test("응답 필요 개수 계산")
  func overviewData_needResponseCount() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    let votes1 = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let promise1 = makePromise(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes1
    )
    
    let votes2 = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(7200)
    )
    let promise2 = makePromise(
      id: "pending-2",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: votes2
    )

    let state = makeState(promisesState: .loaded([promise1, promise2]))

    #expect(state.overviewData.needResponseCount == 2)
  }

  // MARK: - Empty State 테스트

  @Test("빈 배열에서 빈 배열 반환")
  func emptyPromises_returnsEmptyArrays() {
    let state = makeState(promisesState: .loaded([]))

    #expect(state.homeContentSnapshot.todayPromises.isEmpty)
    #expect(state.homeContentSnapshot.pendingPromises.isEmpty)
    #expect(state.homeContentSnapshot.upcomingPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func idleState_returnsEmptyArrays() {
    let state = makeState(promisesState: .idle)

    #expect(state.homeContentSnapshot.todayPromises.isEmpty)
    #expect(state.homeContentSnapshot.pendingPromises.isEmpty)
    #expect(state.homeContentSnapshot.upcomingPromises.isEmpty)
  }

  // MARK: - filteredPromises 테스트

  @Test("그룹 필터 적용 시 해당 그룹 약속만 반환")
  func filteredPromises_withGroupFilter_filtersByGroup() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    let promise1 = makePromise(id: "p1", groupId: "group-1", startAt: tomorrow)
    let promise2 = makePromise(id: "p2", groupId: "group-2", startAt: tomorrow)

    let state = makeState(
      promisesState: .loaded([promise1, promise2]),
      selectedGroupId: "group-1"
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "p1")
  }

  @Test("확정됨 필터 적용 시 확정 약속만 반환")
  func filteredPromises_confirmed_returnsOnlyConfirmed() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    let confirmedVotes = PromiseVotesModel(
      accepted: ["u1", "u2"],
      declined: [],
      until: Date()
    )
    let unconfirmedVotes = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )

    let confirmed = makePromise(id: "confirmed", startAt: tomorrow, votes: confirmedVotes)
    let unconfirmed = makePromise(id: "unconfirmed", startAt: tomorrow, votes: unconfirmedVotes)

    let state = makeState(
      promisesState: .loaded([confirmed, unconfirmed]),
      selectedStatusFilter: .confirmed
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "confirmed")
  }

  @Test("응답 필요 필터 적용 시 미응답 약속만 반환")
  func filteredPromises_needResponse_returnsOnlyPending() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    // current-user가 accepted/declined에 없음 → pending
    let pendingVotes = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )
    // current-user가 accepted → not pending
    let acceptedVotes = PromiseVotesModel(
      accepted: ["current-user", "u2"],
      declined: [],
      until: Date()
    )

    let pending = makePromise(id: "pending", startAt: tomorrow, votes: pendingVotes)
    let accepted = makePromise(id: "accepted", startAt: tomorrow, votes: acceptedVotes)

    let state = makeState(
      promisesState: .loaded([pending, accepted]),
      selectedStatusFilter: .needResponse
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "pending")
  }

  @Test("진행 중 필터 적용 시 미확정+투표 마감 전 약속만 반환")
  func filteredPromises_inProgress_returnsInProgress() {
    let tomorrow = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: Date())!
    // 미확정 + 투표 마감 전
    let inProgressVotes = PromiseVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )
    // 확정됨 → inProgress 아님
    let confirmedVotes = PromiseVotesModel(
      accepted: ["u1", "u2"],
      declined: [],
      until: Date()
    )

    let inProgress = makePromise(id: "in-progress", startAt: tomorrow, votes: inProgressVotes)
    let confirmed = makePromise(id: "confirmed", startAt: tomorrow, votes: confirmedVotes)

    let state = makeState(
      promisesState: .loaded([inProgress, confirmed]),
      selectedStatusFilter: .inProgress
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "in-progress")
  }

  // MARK: - timelineData 테스트

  @Test("날짜별 그룹화된 타임라인 반환")
  func timelineData_groupsByDate() {
    let calendar = Calendar.promiseDisplay
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
    let dayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!

    let p1 = makePromise(id: "p1", startAt: tomorrow)
    let p2 = makePromise(id: "p2", startAt: tomorrow.addingTimeInterval(3600))
    let p3 = makePromise(id: "p3", startAt: dayAfter)

    let state = makeState(promisesState: .loaded([p1, p2, p3]))

    #expect(state.timelineData.count == 2)
    #expect(state.timelineData[0].promises.count == 2)
    #expect(state.timelineData[1].promises.count == 1)
  }

  @Test("타임라인 시간순 정렬 확인")
  func timelineData_sortedByTime() {
    let calendar = Calendar.promiseDisplay
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

    let later = makePromise(id: "later", startAt: tomorrow.addingTimeInterval(7200))
    let earlier = makePromise(id: "earlier", startAt: tomorrow.addingTimeInterval(3600))

    let state = makeState(promisesState: .loaded([later, earlier]))

    #expect(state.timelineData.count == 1)
    #expect(state.timelineData[0].promises[0].id == "earlier")
    #expect(state.timelineData[0].promises[1].id == "later")
  }
}
