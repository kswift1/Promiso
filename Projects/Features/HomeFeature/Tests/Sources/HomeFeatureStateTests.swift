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
//  - **HomeView**: 약속 목록, 필터링, 타임라인 표시
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
    groupId: String = "group-id",
    startAt: Date = Date().addingTimeInterval(3600),
    isConfirmed: Bool = false,
    voteUntil: Date = Date().addingTimeInterval(1800),
    currentUserVoted: Bool = false
  ) -> PromiseModel {
    var accepted: [String] = isConfirmed ? ["user1", "user2"] : []
    if currentUserVoted {
      accepted.append("current-user")
    }
    let votes = PromiseVotesModel(
      accepted: accepted,
      declined: [],
      until: voteUntil
    )
    return PromiseModel(
      id: id,
      title: "테스트 약속",
      hostId: "host-id",
      groupId: groupId,
      minimumParticipants: 2,
      votes: votes,
      startAt: startAt
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    promisesState: LoadingState<[PromiseModel]> = .idle,
    selectedStatusFilter: HomeModels.StatusFilter = .all
  ) -> Home.Feature.State {
    var state = Home.Feature.State(currentUser: makeCurrentUser())
    state.promisesState = promisesState
    state.selectedStatusFilter = selectedStatusFilter
    return state
  }

  // MARK: - allPromises 테스트

  @Test("loaded 상태에서 약속 목록 반환")
  func allPromises_whenLoaded_returnsPromises() {
    let promise1 = makePromise(id: "1")
    let promise2 = makePromise(id: "2")

    let state = makeState(promisesState: .loaded([promise1, promise2]))

    #expect(state.allPromises.count == 2)
  }

  @Test("loading 상태에서 빈 배열 반환")
  func allPromises_whenLoading_returnsEmpty() {
    let state = makeState(promisesState: .loading)
    #expect(state.allPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func allPromises_whenIdle_returnsEmpty() {
    let state = makeState(promisesState: .idle)
    #expect(state.allPromises.isEmpty)
  }

  // MARK: - todayPromises 테스트

  @Test("오늘 확정 약속만 반환")
  func todayPromises_onlyTodayConfirmed() {
    let todayConfirmed = makePromise(
      id: "today-confirmed",
      startAt: Date().addingTimeInterval(3600),
      isConfirmed: true
    )
    let todayPending = makePromise(
      id: "today-pending",
      startAt: Date().addingTimeInterval(7200),
      isConfirmed: false
    )
    let tomorrowConfirmed = makePromise(
      id: "tomorrow-confirmed",
      startAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
      isConfirmed: true
    )

    let state = makeState(promisesState: .loaded([todayConfirmed, todayPending, tomorrowConfirmed]))

    #expect(state.todayPromises.count == 1)
    #expect(state.todayPromises.first?.id == "today-confirmed")
  }

  @Test("오늘 약속 시간순 정렬")
  func todayPromises_sortedByTime() {
    let later = makePromise(
      id: "later",
      startAt: Date().addingTimeInterval(7200),
      isConfirmed: true
    )
    let earlier = makePromise(
      id: "earlier",
      startAt: Date().addingTimeInterval(3600),
      isConfirmed: true
    )

    let state = makeState(promisesState: .loaded([later, earlier]))

    #expect(state.todayPromises.count == 2)
    #expect(state.todayPromises[0].id == "earlier")
    #expect(state.todayPromises[1].id == "later")
  }

  // MARK: - pendingPromises 테스트

  @Test("응답 필요 약속만 반환")
  func pendingPromises_onlyNeedResponse() {
    let needResponse = makePromise(
      id: "need-response",
      startAt: Date().addingTimeInterval(86400),
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: false
    )
    let alreadyVoted = makePromise(
      id: "voted",
      startAt: Date().addingTimeInterval(86400),
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: true
    )

    let state = makeState(promisesState: .loaded([needResponse, alreadyVoted]))

    #expect(state.pendingPromises.count == 1)
    #expect(state.pendingPromises.first?.id == "need-response")
  }

  @Test("응답 필요 약속 마감일 기준 정렬")
  func pendingPromises_sortedByVoteDeadline() {
    let laterDeadline = makePromise(
      id: "later-deadline",
      voteUntil: Date().addingTimeInterval(7200),
      currentUserVoted: false
    )
    let earlierDeadline = makePromise(
      id: "earlier-deadline",
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: false
    )

    let state = makeState(promisesState: .loaded([laterDeadline, earlierDeadline]))

    #expect(state.pendingPromises.count == 2)
    #expect(state.pendingPromises[0].id == "earlier-deadline")
    #expect(state.pendingPromises[1].id == "later-deadline")
  }

  // MARK: - upcomingPromises 테스트

  @Test("다가오는 확정 약속만 반환 (오늘 제외)")
  func upcomingPromises_excludesToday() {
    let todayConfirmed = makePromise(
      id: "today",
      startAt: Date().addingTimeInterval(3600),
      isConfirmed: true
    )
    let tomorrowConfirmed = makePromise(
      id: "tomorrow",
      startAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
      isConfirmed: true
    )
    let tomorrowPending = makePromise(
      id: "tomorrow-pending",
      startAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
      isConfirmed: false
    )

    let state = makeState(promisesState: .loaded([todayConfirmed, tomorrowConfirmed, tomorrowPending]))

    #expect(state.upcomingPromises.count == 1)
    #expect(state.upcomingPromises.first?.id == "tomorrow")
  }

  @Test("다가오는 약속 날짜순 정렬")
  func upcomingPromises_sortedByDate() {
    let dayAfter = makePromise(
      id: "day-after",
      startAt: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
      isConfirmed: true
    )
    let tomorrow = makePromise(
      id: "tomorrow",
      startAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
      isConfirmed: true
    )

    let state = makeState(promisesState: .loaded([dayAfter, tomorrow]))

    #expect(state.upcomingPromises.count == 2)
    #expect(state.upcomingPromises[0].id == "tomorrow")
    #expect(state.upcomingPromises[1].id == "day-after")
  }

  // MARK: - filteredPromises 테스트

  @Test("전체 필터: 과거 약속 제외")
  func filteredPromises_allFilter_excludesPast() {
    let futurePromise = makePromise(id: "future", startAt: Date().addingTimeInterval(3600))
    let pastPromise = makePromise(id: "past", startAt: Date().addingTimeInterval(-3600))

    let state = makeState(
      promisesState: .loaded([futurePromise, pastPromise]),
      selectedStatusFilter: .all
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "future")
  }

  @Test("확정됨 필터: 확정된 약속만")
  func filteredPromises_confirmedFilter_onlyConfirmed() {
    let confirmedPromise = makePromise(id: "confirmed", startAt: Date().addingTimeInterval(3600), isConfirmed: true)
    let pendingPromise = makePromise(id: "pending", startAt: Date().addingTimeInterval(3600), isConfirmed: false)

    let state = makeState(
      promisesState: .loaded([confirmedPromise, pendingPromise]),
      selectedStatusFilter: .confirmed
    )

    #expect(state.filteredPromises.count == 1)
    #expect(state.filteredPromises.first?.id == "confirmed")
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

  // MARK: - overviewData 테스트

  @Test("오늘 확정 약속 개수 계산")
  func overviewData_todayCount() {
    let todayConfirmed = makePromise(
      id: "today-confirmed",
      startAt: Date().addingTimeInterval(3600),
      isConfirmed: true
    )
    let todayPending = makePromise(
      id: "today-pending",
      startAt: Date().addingTimeInterval(7200),
      isConfirmed: false
    )

    let state = makeState(promisesState: .loaded([todayConfirmed, todayPending]))

    #expect(state.overviewData.todayCount == 1)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 약속 개수")
  func pendingResponseCount_returnsCorrectCount() {
    // 응답 안 한 약속 (voteUntil이 미래)
    let needResponse = makePromise(
      id: "need-response",
      startAt: Date().addingTimeInterval(86400),
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: false
    )
    // 이미 응답한 약속
    let alreadyVoted = makePromise(
      id: "already-voted",
      startAt: Date().addingTimeInterval(86400),
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: true
    )

    let state = makeState(promisesState: .loaded([needResponse, alreadyVoted]))

    #expect(state.pendingResponseCount == 1)
  }

  @Test("응답 필요 약속 없으면 0")
  func pendingResponseCount_whenAllVoted_returnsZero() {
    let alreadyVoted = makePromise(
      id: "voted",
      voteUntil: Date().addingTimeInterval(3600),
      currentUserVoted: true
    )

    let state = makeState(promisesState: .loaded([alreadyVoted]))

    #expect(state.pendingResponseCount == 0)
  }

  // MARK: - timelineData 테스트

  @Test("날짜별 그룹화")
  func timelineData_groupsByDate() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: Date())!

    let promise1 = makePromise(id: "1", startAt: tomorrow)
    let promise2 = makePromise(id: "2", startAt: tomorrow.addingTimeInterval(3600))
    let promise3 = makePromise(id: "3", startAt: dayAfter)

    let state = makeState(promisesState: .loaded([promise1, promise2, promise3]))

    #expect(state.timelineData.count == 2)
    #expect(state.timelineData[0].promises.count == 2)
    #expect(state.timelineData[1].promises.count == 1)
  }

  @Test("날짜 오름차순 정렬")
  func timelineData_sortsByDateAscending() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: Date())!

    let laterPromise = makePromise(id: "later", startAt: dayAfter)
    let earlierPromise = makePromise(id: "earlier", startAt: tomorrow)

    let state = makeState(promisesState: .loaded([laterPromise, earlierPromise]))

    #expect(state.timelineData[0].promises.first?.id == "earlier")
    #expect(state.timelineData[1].promises.first?.id == "later")
  }
}
