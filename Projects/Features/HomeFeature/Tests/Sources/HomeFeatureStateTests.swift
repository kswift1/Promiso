//
//  HomeFeatureStateTests.swift
//  HomeFeature
//
//  HomeFeature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `HomeFeature/Sources/HomeFeature.swift`
//  - State의 computed properties (promisesState 기반)
//
//  ## 테스트 목적
//  - 약속 필터링 및 정렬 로직 검증
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

  /// 오늘 날짜의 약속 생성 (확정됨)
  private func makeTodayPromise(
    id: String = "today-promise",
    title: String = "오늘 약속",
    acceptedCount: Int = 3
  ) -> PromiseModel {
    let calendar = Calendar.current
    let now = Date()
    let startAt = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600)
    let accepted = (0..<acceptedCount).map { "user-\($0)" }
    return PromiseModel(
      id: id,
      title: title,
      hostId: "host",
      groupId: "group-id",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: accepted,
        declined: [],
        until: now.addingTimeInterval(-3600)
      ),
      startAt: startAt
    )
  }

  /// 미응답 약속 생성 (투표 마감 전)
  private func makePendingPromise(
    id: String = "pending-promise",
    title: String = "미응답 약속",
    votingDeadline: Date = Date().addingTimeInterval(86400)
  ) -> PromiseModel {
    PromiseModel(
      id: id,
      title: title,
      hostId: "host",
      groupId: "group-id",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: [],
        declined: [],
        until: votingDeadline
      ),
      startAt: Date().addingTimeInterval(172800)
    )
  }

  /// 다가오는 약속 생성 (내일 이후 + 확정 + 현재 유저 수락)
  private func makeUpcomingPromise(
    id: String = "upcoming-promise",
    title: String = "다가오는 약속",
    daysFromNow: Int = 3
  ) -> PromiseModel {
    let startAt = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
    return PromiseModel(
      id: id,
      title: title,
      hostId: "host",
      groupId: "group-id",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: ["current-user", "user-1", "user-2"],
        declined: [],
        until: Date().addingTimeInterval(-3600)
      ),
      startAt: startAt
    )
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

  @Test("오늘 확정 약속 목록 반환")
  func todayPromises_returnsConfirmedTodayPromises() {
    let promise1 = makeTodayPromise(id: "today-1")
    let promise2 = makeTodayPromise(id: "today-2")
    let state = makeState(promisesState: .loaded([promise1, promise2]))

    #expect(state.todayPromises.count == 2)
  }

  // MARK: - pendingPromises 테스트

  @Test("응답 필요 약속 목록 반환")
  func pendingPromises_returnsPendingPromises() {
    let promise = makePendingPromise(id: "pending-1")
    let state = makeState(promisesState: .loaded([promise]))

    #expect(state.pendingPromises.count == 1)
  }

  // MARK: - upcomingPromises 테스트

  @Test("다가오는 약속 목록 반환")
  func upcomingPromises_returnsUpcomingConfirmedPromises() {
    let promise = makeUpcomingPromise(id: "upcoming-1")
    let state = makeState(promisesState: .loaded([promise]))

    #expect(state.upcomingPromises.count == 1)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 개수 반환")
  func pendingResponseCount_returnsPendingCount() {
    let p1 = makePendingPromise(id: "p1")
    let p2 = makePendingPromise(id: "p2")
    let state = makeState(promisesState: .loaded([p1, p2]))

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
    let p1 = makeTodayPromise(id: "t1")
    let p2 = makeTodayPromise(id: "t2")
    let p3 = makeTodayPromise(id: "t3")
    let state = makeState(promisesState: .loaded([p1, p2, p3]))

    #expect(state.overviewData.todayCount == 3)
  }

  @Test("응답 필요 개수 계산")
  func overviewData_needResponseCount() {
    let p1 = makePendingPromise(id: "pd1")
    let p2 = makePendingPromise(id: "pd2")
    let state = makeState(promisesState: .loaded([p1, p2]))

    #expect(state.overviewData.needResponseCount == 2)
  }

  // MARK: - Empty State 테스트

  @Test("빈 배열에서 빈 결과 반환")
  func emptyPromises_returnsEmptyArrays() {
    let state = makeState(promisesState: .loaded([]))

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func idleState_returnsEmptyArrays() {
    let state = makeState(promisesState: .idle)

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
  }
}
