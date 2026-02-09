//
//  HomeFeatureStateTests.swift
//  HomeFeature
//
//  HomeFeature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `HomeFeature/Sources/HomeFeature.swift`
//  - State의 computed properties (직접 쿼리 기반)
//
//  ## 테스트 목적
//  - PromiseModel 배열 기반 약속 필터링 및 정렬 로직 검증
//  - 로딩 상태 판단 로직 검증
//

import Foundation
import Testing
import Clients
import Sharing
@testable import HomeFeature

// MARK: - HomeFeature State Tests

@Suite("HomeFeature.State computed properties 테스트")
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
    selectedStatusFilter: HomeModels.StatusFilter = .all
  ) -> Home.Feature.State {
    @Shared(.inMemory("test-current-user")) var currentUser = makeCurrentUser()
    var state = Home.Feature.State(currentUser: $currentUser)
    state.promisesState = promisesState
    state.selectedStatusFilter = selectedStatusFilter
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

  // MARK: - todayPromises 테스트

  @Test("오늘 약속 목록 반환")
  func todayPromises_returnsConfirmedTodayPromises() {
    // KST 타임존 사용 (실제 코드와 동일)
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
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

    #expect(state.todayPromises.count == 2)
  }

  // MARK: - pendingPromises 테스트

  @Test("응답 필요 약속 목록 반환")
  func pendingPromises_returnsPendingVotePromises() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    
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

    #expect(state.pendingPromises.count == 1)
  }

  // MARK: - upcomingPromises 테스트

  @Test("다가오는 약속 목록 반환")
  func upcomingPromises_returnsConfirmedUpcomingPromises() {
    let calendar = Calendar.current
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

    #expect(state.upcomingPromises.count == 1)
  }

  // MARK: - allPromises 테스트

  @Test("모든 약속 반환")
  func allPromises_returnsAllPromises() {
    let calendar = Calendar.current
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
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    
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
    var calendar = Calendar.current
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
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
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    
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

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
    #expect(state.allPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func idleState_returnsEmptyArrays() {
    let state = makeState(promisesState: .idle)

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
    #expect(state.allPromises.isEmpty)
  }
}
