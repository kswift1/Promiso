//
//  HomeFeatureStateTests.swift
//  HomeFeature
//
//  HomeFeature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `HomeFeature/Sources/HomeFeature.swift`
//  - State의 computed properties
//
//  ## 사용처
//  - **HomeView**: 오늘 약속, 응답 필요 약속, 다가오는 약속 표시
//  - **RootTabFeature**: 응답 필요 배지 카운트
//
//  ## 테스트 목적
//  - 약속 필터링 및 정렬 로직 검증
//  - 로딩 상태 판단 로직 검증
//

import Foundation
import Testing
import Clients
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

  /// 테스트용 약속 생성
  private func makePromise(
    id: String = "test-promise",
    startAt: Date = Date().addingTimeInterval(3600),
    isConfirmed: Bool = false,
    voteUntil: Date = Date().addingTimeInterval(1800)
  ) -> PromiseModel {
    let votes = PromiseVotesModel(
      accepted: isConfirmed ? ["user1", "user2"] : [],
      declined: [],
      until: voteUntil
    )
    return PromiseModel(
      id: id,
      title: "테스트 약속",
      hostId: "host-id",
      groupId: "group-id",
      minimumParticipants: 2,
      votes: votes,
      startAt: startAt
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    todaysPromises: LoadingState<[PromiseModel]> = .idle,
    pendingResponses: LoadingState<[PromiseModel]> = .idle,
    upcomingPromises: LoadingState<[PromiseModel]> = .idle
  ) -> Home.Feature.State {
    var state = Home.Feature.State(currentUser: makeCurrentUser())
    state.todaysPromisesState = todaysPromises
    state.pendingResponsesState = pendingResponses
    state.upcomingPromisesState = upcomingPromises
    return state
  }

  // MARK: - todaysPromises 테스트

  @Test("확정된 오늘 약속만 필터링")
  func todaysPromises_filtersOnlyConfirmed() {
    let confirmedPromise = makePromise(id: "confirmed", isConfirmed: true)
    let pendingPromise = makePromise(id: "pending", isConfirmed: false)

    let state = makeState(
      todaysPromises: .loaded([confirmedPromise, pendingPromise])
    )

    #expect(state.todaysPromises.count == 1)
    #expect(state.todaysPromises.first?.id == "confirmed")
  }

  @Test("오늘 약속 시간순 정렬")
  func todaysPromises_sortsByStartTime() {
    let laterPromise = makePromise(id: "later", startAt: Date().addingTimeInterval(7200), isConfirmed: true)
    let earlierPromise = makePromise(id: "earlier", startAt: Date().addingTimeInterval(3600), isConfirmed: true)

    let state = makeState(
      todaysPromises: .loaded([laterPromise, earlierPromise])
    )

    #expect(state.todaysPromises.count == 2)
    #expect(state.todaysPromises[0].id == "earlier")
    #expect(state.todaysPromises[1].id == "later")
  }

  @Test("로딩 상태에서 빈 배열 반환")
  func todaysPromises_whenLoading_returnsEmpty() {
    let state = makeState(todaysPromises: .loading)
    #expect(state.todaysPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func todaysPromises_whenIdle_returnsEmpty() {
    let state = makeState(todaysPromises: .idle)
    #expect(state.todaysPromises.isEmpty)
  }

  // MARK: - pendingResponses 테스트

  @Test("응답 필요 약속 마감순 정렬")
  func pendingResponses_sortsByVoteUntil() {
    let laterDeadline = makePromise(id: "later", voteUntil: Date().addingTimeInterval(7200))
    let earlierDeadline = makePromise(id: "earlier", voteUntil: Date().addingTimeInterval(3600))

    let state = makeState(
      pendingResponses: .loaded([laterDeadline, earlierDeadline])
    )

    #expect(state.pendingResponses.count == 2)
    #expect(state.pendingResponses[0].id == "earlier") // 마감 임박순
    #expect(state.pendingResponses[1].id == "later")
  }

  // MARK: - upcomingPromises 테스트

  @Test("확정된 다가오는 약속만 필터링")
  func upcomingPromises_filtersOnlyConfirmed() {
    let confirmedPromise = makePromise(id: "confirmed", isConfirmed: true)
    let pendingPromise = makePromise(id: "pending", isConfirmed: false)

    let state = makeState(
      upcomingPromises: .loaded([confirmedPromise, pendingPromise])
    )

    #expect(state.upcomingPromises.count == 1)
    #expect(state.upcomingPromises.first?.id == "confirmed")
  }

  @Test("다가오는 약속 시간순 정렬")
  func upcomingPromises_sortsByStartTime() {
    let laterPromise = makePromise(id: "later", startAt: Date().addingTimeInterval(7200), isConfirmed: true)
    let earlierPromise = makePromise(id: "earlier", startAt: Date().addingTimeInterval(3600), isConfirmed: true)

    let state = makeState(
      upcomingPromises: .loaded([laterPromise, earlierPromise])
    )

    #expect(state.upcomingPromises.count == 2)
    #expect(state.upcomingPromises[0].id == "earlier")
    #expect(state.upcomingPromises[1].id == "later")
  }

  // MARK: - isLoading 테스트

  @Test("아무것도 로딩 중이 아니면 false")
  func isLoading_whenNothingLoading_returnsFalse() {
    let state = makeState(
      todaysPromises: .loaded([]),
      pendingResponses: .loaded([]),
      upcomingPromises: .loaded([])
    )
    #expect(state.isLoading == false)
  }

  @Test("오늘 약속 로딩 중이면 true")
  func isLoading_whenTodaysLoading_returnsTrue() {
    let state = makeState(
      todaysPromises: .loading,
      pendingResponses: .loaded([]),
      upcomingPromises: .loaded([])
    )
    #expect(state.isLoading == true)
  }

  @Test("응답 필요 약속 로딩 중이면 true")
  func isLoading_whenPendingLoading_returnsTrue() {
    let state = makeState(
      todaysPromises: .loaded([]),
      pendingResponses: .loading,
      upcomingPromises: .loaded([])
    )
    #expect(state.isLoading == true)
  }

  @Test("다가오는 약속 로딩 중이면 true")
  func isLoading_whenUpcomingLoading_returnsTrue() {
    let state = makeState(
      todaysPromises: .loaded([]),
      pendingResponses: .loaded([]),
      upcomingPromises: .loading
    )
    #expect(state.isLoading == true)
  }

  @Test("모두 로딩 중이면 true")
  func isLoading_whenAllLoading_returnsTrue() {
    let state = makeState(
      todaysPromises: .loading,
      pendingResponses: .loading,
      upcomingPromises: .loading
    )
    #expect(state.isLoading == true)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 약속 개수 반환")
  func pendingResponseCount_returnsCorrectCount() {
    let promise1 = makePromise(id: "1", voteUntil: Date().addingTimeInterval(1800))
    let promise2 = makePromise(id: "2", voteUntil: Date().addingTimeInterval(3600))
    let promise3 = makePromise(id: "3", voteUntil: Date().addingTimeInterval(5400))

    let state = makeState(
      pendingResponses: .loaded([promise1, promise2, promise3])
    )

    #expect(state.pendingResponseCount == 3)
  }

  @Test("응답 필요 약속 없으면 0 반환")
  func pendingResponseCount_whenEmpty_returnsZero() {
    let state = makeState(pendingResponses: .loaded([]))
    #expect(state.pendingResponseCount == 0)
  }

  @Test("로딩 중이면 0 반환")
  func pendingResponseCount_whenLoading_returnsZero() {
    let state = makeState(pendingResponses: .loading)
    #expect(state.pendingResponseCount == 0)
  }
}
