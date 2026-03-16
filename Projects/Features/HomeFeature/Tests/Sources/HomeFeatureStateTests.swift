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

  /// 테스트용 ScheduleModel 생성
  /// isConfirmed를 true로 만들려면 votes.accepted에 minimumParticipants 이상의 사용자 필요
  private func makeSchedule(
    id: String = "test-schedule",
    title: String = "테스트 일정",
    groupId: String = "group-id",
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    minimumParticipants: Int = 2,
    votes: ScheduleVotesModel? = nil
  ) -> ScheduleModel {
    let defaultVotes = votes ?? ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(1800)
    )
    
    return ScheduleModel(
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
    schedulesState: LoadingState<[ScheduleModel]> = .idle,
    selectedStatusFilter: HomeModels.StatusFilter = .all,
    selectedGroupId: String? = nil
  ) -> Home.Feature.State {
    @Shared(.inMemory("test-\(UUID().uuidString.prefix(8))")) var currentUser = makeCurrentUser()
    var state = Home.Feature.State(currentUser: $currentUser)
    state.schedulesState = schedulesState
    state.personalEventsState = .loaded([])
    state.recurringEventsState = .loaded([])
    state.selectedStatusFilter = selectedStatusFilter
    state.selectedGroupId = selectedGroupId
    state.refreshHomeContentSnapshot()
    return state
  }

  // MARK: - isLoading 테스트

  @Test("schedulesState가 loading이면 true")
  func isLoading_whenLoading_returnsTrue() {
    let state = makeState(schedulesState: .loading)
    #expect(state.isLoading == true)
  }

  @Test("schedulesState가 loaded이면 false")
  func isLoading_whenLoaded_returnsFalse() {
    let state = makeState(schedulesState: .loaded([]))
    #expect(state.isLoading == false)
  }

  @Test("schedulesState가 idle이면 true (아직 로딩 시작 전)")
  func isLoading_whenIdle_returnsTrue() {
    let state = makeState(schedulesState: .idle)
    #expect(state.isLoading == true)
  }

  // MARK: - homeContentSnapshot.todaySchedules 테스트

  @Test("오늘 일정 목록 반환")
  func homeContentSnapshot_todaySchedules_returnsConfirmedTodaySchedules() {
    // KST 타임존 사용 (실제 코드와 동일)
    let calendar = Calendar.scheduleDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!

    // isMySchedule = true (current-user가 accepted에 포함)
    let confirmedVotes = ScheduleVotesModel(
      accepted: ["current-user", "user2"],  // minimumParticipants(2) 이상 + 현재 유저 포함
      declined: [],
      until: Date()
    )

    let schedule1 = makeSchedule(
      id: "today-1",
      startAt: todayAfternoon,
      votes: confirmedVotes
    )
    let schedule2 = makeSchedule(
      id: "today-2",
      startAt: todayAfternoon.addingTimeInterval(3600),
      votes: confirmedVotes
    )

    let state = makeState(schedulesState: .loaded([schedule1, schedule2]))

    #expect(state.homeContentSnapshot.todaySchedules.count == 2)
  }

  // MARK: - homeContentSnapshot.pendingSchedules 테스트

  @Test("응답 필요 일정 목록 반환")
  func homeContentSnapshot_pendingSchedules_returnsPendingVoteSchedules() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    // current-user가 pending (accepted/declined에 없음)
    let votes = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    
    let schedule = makeSchedule(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes
    )

    let state = makeState(schedulesState: .loaded([schedule]))

    #expect(state.homeContentSnapshot.pendingSchedules.count == 1)
  }

  // MARK: - homeContentSnapshot.upcomingSchedules 테스트

  @Test("다가오는 일정 목록 반환")
  func homeContentSnapshot_upcomingSchedules_returnsConfirmedUpcomingSchedules() {
    // 실제 구현(Home.Feature.State.todayRange)과 동일하게 KST 기준으로 계산
    let calendar = Calendar.scheduleDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    // isConfirmed = true, current-user가 accepted
    let votes = ScheduleVotesModel(
      accepted: ["current-user", "user2"],  // minimumParticipants(2) 이상
      declined: [],
      until: Date()
    )

    let schedule = makeSchedule(
      id: "upcoming-1",
      startAt: tomorrow,
      votes: votes
    )

    let state = makeState(schedulesState: .loaded([schedule]))

    #expect(state.homeContentSnapshot.upcomingSchedules.count == 1)
  }

  // MARK: - allSchedules 테스트

  @Test("모든 일정 반환")
  func allSchedules_returnsAllSchedules() {
    let calendar = Calendar.scheduleDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

    let confirmedVotes = ScheduleVotesModel(
      accepted: ["user1", "user2"],
      declined: [],
      until: Date()
    )
    let today = makeSchedule(id: "today", startAt: todayAfternoon, votes: confirmedVotes)
    
    let pendingVotes = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let pending = makeSchedule(
      id: "pending",
      startAt: tomorrow,
      votes: pendingVotes
    )
    
    let upcomingVotes = ScheduleVotesModel(
      accepted: ["current-user", "user2"],
      declined: [],
      until: Date()
    )
    let upcoming = makeSchedule(
      id: "upcoming",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: upcomingVotes
    )

    let state = makeState(schedulesState: .loaded([today, pending, upcoming]))

    #expect(state.allSchedules.count == 3)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 개수 반환")
  func pendingResponseCount_returnsPendingCount() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    let votes1 = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let schedule1 = makeSchedule(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes1
    )
    
    let votes2 = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(7200)
    )
    let schedule2 = makeSchedule(
      id: "pending-2",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: votes2
    )

    let state = makeState(schedulesState: .loaded([schedule1, schedule2]))

    #expect(state.pendingResponseCount == 2)
  }

  @Test("응답 필요 없으면 0")
  func pendingResponseCount_whenNoPending_returnsZero() {
    let state = makeState(schedulesState: .loaded([]))

    #expect(state.pendingResponseCount == 0)
  }

  // MARK: - overviewData 테스트

  @Test("오늘 일정 개수 계산")
  func overviewData_todayCount() {
    // KST 타임존 사용 (실제 코드와 동일)
    let calendar = Calendar.scheduleDisplay
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let todayAfternoon = calendar.date(byAdding: .hour, value: 14, to: startOfToday)!

    let confirmedVotes = ScheduleVotesModel(
      accepted: ["current-user", "user2"],  // 현재 유저 포함
      declined: [],
      until: Date()
    )

    let schedule1 = makeSchedule(id: "today-1", startAt: todayAfternoon, votes: confirmedVotes)
    let schedule2 = makeSchedule(id: "today-2", startAt: todayAfternoon.addingTimeInterval(3600), votes: confirmedVotes)
    let schedule3 = makeSchedule(id: "today-3", startAt: todayAfternoon.addingTimeInterval(7200), votes: confirmedVotes)

    let state = makeState(schedulesState: .loaded([schedule1, schedule2, schedule3]))

    #expect(state.overviewData.todayCount == 3)
  }

  @Test("응답 필요 개수 계산")
  func overviewData_needResponseCount() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    
    let votes1 = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(3600)
    )
    let schedule1 = makeSchedule(
      id: "pending-1",
      startAt: tomorrow,
      votes: votes1
    )
    
    let votes2 = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: Date().addingTimeInterval(7200)
    )
    let schedule2 = makeSchedule(
      id: "pending-2",
      startAt: tomorrow.addingTimeInterval(3600),
      votes: votes2
    )

    let state = makeState(schedulesState: .loaded([schedule1, schedule2]))

    #expect(state.overviewData.needResponseCount == 2)
  }

  // MARK: - Empty State 테스트

  @Test("빈 배열에서 빈 배열 반환")
  func emptySchedules_returnsEmptyArrays() {
    let state = makeState(schedulesState: .loaded([]))

    #expect(state.homeContentSnapshot.todaySchedules.isEmpty)
    #expect(state.homeContentSnapshot.pendingSchedules.isEmpty)
    #expect(state.homeContentSnapshot.upcomingSchedules.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func idleState_returnsEmptyArrays() {
    let state = makeState(schedulesState: .idle)

    #expect(state.homeContentSnapshot.todaySchedules.isEmpty)
    #expect(state.homeContentSnapshot.pendingSchedules.isEmpty)
    #expect(state.homeContentSnapshot.upcomingSchedules.isEmpty)
  }

  // MARK: - filteredSchedules 테스트

  @Test("그룹 필터 적용 시 해당 그룹 일정만 반환")
  func filteredSchedules_withGroupFilter_filtersByGroup() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    let schedule1 = makeSchedule(id: "p1", groupId: "group-1", startAt: tomorrow)
    let schedule2 = makeSchedule(id: "p2", groupId: "group-2", startAt: tomorrow)

    let state = makeState(
      schedulesState: .loaded([schedule1, schedule2]),
      selectedGroupId: "group-1"
    )

    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "p1")
  }

  @Test("확정됨 필터 적용 시 확정 일정만 반환")
  func filteredSchedules_confirmed_returnsOnlyConfirmed() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    let confirmedVotes = ScheduleVotesModel(
      accepted: ["u1", "u2"],
      declined: [],
      until: Date()
    )
    let unconfirmedVotes = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )

    let confirmed = makeSchedule(id: "confirmed", startAt: tomorrow, votes: confirmedVotes)
    let unconfirmed = makeSchedule(id: "unconfirmed", startAt: tomorrow, votes: unconfirmedVotes)

    let state = makeState(
      schedulesState: .loaded([confirmed, unconfirmed]),
      selectedStatusFilter: .confirmed
    )

    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "confirmed")
  }

  @Test("응답 필요 필터 적용 시 미응답 일정만 반환")
  func filteredSchedules_needResponse_returnsOnlyPending() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    // current-user가 accepted/declined에 없음 → pending
    let pendingVotes = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )
    // current-user가 accepted → not pending
    let acceptedVotes = ScheduleVotesModel(
      accepted: ["current-user", "u2"],
      declined: [],
      until: Date()
    )

    let pending = makeSchedule(id: "pending", startAt: tomorrow, votes: pendingVotes)
    let accepted = makeSchedule(id: "accepted", startAt: tomorrow, votes: acceptedVotes)

    let state = makeState(
      schedulesState: .loaded([pending, accepted]),
      selectedStatusFilter: .needResponse
    )

    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "pending")
  }

  @Test("진행 중 필터 적용 시 미확정+투표 마감 전 일정만 반환")
  func filteredSchedules_inProgress_returnsInProgress() {
    let tomorrow = Calendar.scheduleDisplay.date(byAdding: .day, value: 1, to: Date())!
    // 미확정 + 투표 마감 전
    let inProgressVotes = ScheduleVotesModel(
      accepted: [],
      declined: [],
      until: tomorrow
    )
    // 확정됨 → inProgress 아님
    let confirmedVotes = ScheduleVotesModel(
      accepted: ["u1", "u2"],
      declined: [],
      until: Date()
    )

    let inProgress = makeSchedule(id: "in-progress", startAt: tomorrow, votes: inProgressVotes)
    let confirmed = makeSchedule(id: "confirmed", startAt: tomorrow, votes: confirmedVotes)

    let state = makeState(
      schedulesState: .loaded([inProgress, confirmed]),
      selectedStatusFilter: .inProgress
    )

    #expect(state.filteredSchedules.count == 1)
    #expect(state.filteredSchedules.first?.id == "in-progress")
  }

  // MARK: - timelineData 테스트

  @Test("날짜별 그룹화된 타임라인 반환")
  func timelineData_groupsByDate() {
    let calendar = Calendar.scheduleDisplay
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
    let dayAfter = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: Date()))!

    let p1 = makeSchedule(id: "p1", startAt: tomorrow)
    let p2 = makeSchedule(id: "p2", startAt: tomorrow.addingTimeInterval(3600))
    let p3 = makeSchedule(id: "p3", startAt: dayAfter)

    let state = makeState(schedulesState: .loaded([p1, p2, p3]))

    #expect(state.timelineData.count == 2)
    #expect(state.timelineData[0].schedules.count == 2)
    #expect(state.timelineData[1].schedules.count == 1)
  }

  @Test("타임라인 시간순 정렬 확인")
  func timelineData_sortedByTime() {
    let calendar = Calendar.scheduleDisplay
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

    let later = makeSchedule(id: "later", startAt: tomorrow.addingTimeInterval(7200))
    let earlier = makeSchedule(id: "earlier", startAt: tomorrow.addingTimeInterval(3600))

    let state = makeState(schedulesState: .loaded([later, earlier]))

    #expect(state.timelineData.count == 1)
    #expect(state.timelineData[0].schedules[0].id == "earlier")
    #expect(state.timelineData[0].schedules[1].id == "later")
  }
}
