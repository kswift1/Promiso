//
//  HomeFeatureStateTests.swift
//  HomeFeature
//
//  HomeFeature.State computed properties 테스트
//
//  ## 테스트 대상
//  - `HomeFeature/Sources/HomeFeature.swift`
//  - State의 computed properties (스냅샷 기반)
//
//  ## 테스트 목적
//  - 스냅샷 데이터 기반 약속 필터링 및 정렬 로직 검증
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

  /// 테스트용 SnapshotPromise 생성
  private func makeSnapshotPromise(
    id: String = "test-promise",
    title: String = "테스트 약속",
    groupId: String = "group-id",
    startAt: Date = Date().addingTimeInterval(3600),
    isConfirmed: Bool = false,
    myVoteStatus: SnapshotVoteStatus = .pending,
    votingDeadline: Date = Date().addingTimeInterval(1800)
  ) -> SnapshotPromise {
    let formatter = ISO8601DateFormatter()

    return SnapshotPromise(
      id: id,
      title: title,
      emoji: "📅",
      startAt: formatter.string(from: startAt),
      endAt: nil,
      location: nil,
      groupId: groupId,
      groupName: "테스트 그룹",
      groupImageUrl: nil,
      isConfirmed: isConfirmed,
      minimumParticipants: 2,
      votes: SnapshotVotes(accepted: [], declined: []),
      myVoteStatus: myVoteStatus,
      votingDeadline: formatter.string(from: votingDeadline)
    )
  }

  /// 테스트용 HomeSnapshotDocument 생성
  private func makeSnapshot(
    todayPromises: [SnapshotPromise] = [],
    pendingPromises: [SnapshotPromise] = [],
    upcomingPromises: [SnapshotPromise] = [],
    todayCount: Int = 0,
    pendingCount: Int = 0
  ) -> HomeSnapshotDocument {
    HomeSnapshotDocument(
      todayPromises: todayPromises,
      pendingPromises: pendingPromises,
      upcomingPromises: upcomingPromises,
      groups: [],
      meta: HomeSnapshotMeta(
        todayCount: todayCount,
        pendingCount: pendingCount,
        upcomingCount: upcomingPromises.count,
        updatedAt: ISO8601DateFormatter().string(from: Date())
      )
    )
  }

  /// 테스트용 State 생성
  private func makeState(
    snapshotState: LoadingState<HomeSnapshotDocument> = .idle,
    selectedStatusFilter: HomeModels.StatusFilter = .all
  ) -> Home.Feature.State {
    @Shared(.inMemory("test-current-user")) var currentUser = makeCurrentUser()
    var state = Home.Feature.State(currentUser: $currentUser)
    state.snapshotState = snapshotState
    state.selectedStatusFilter = selectedStatusFilter
    return state
  }

  // MARK: - isLoading 테스트

  @Test("snapshotState가 loading이면 true")
  func isLoading_whenLoading_returnsTrue() {
    let state = makeState(snapshotState: .loading)
    #expect(state.isLoading == true)
  }

  @Test("snapshotState가 loaded이면 false")
  func isLoading_whenLoaded_returnsFalse() {
    let snapshot = makeSnapshot()
    let state = makeState(snapshotState: .loaded(snapshot))
    #expect(state.isLoading == false)
  }

  @Test("snapshotState가 idle이면 false")
  func isLoading_whenIdle_returnsFalse() {
    let state = makeState(snapshotState: .idle)
    #expect(state.isLoading == false)
  }

  // MARK: - todayPromises 테스트

  @Test("오늘 약속 목록 반환")
  func todayPromises_returnsSnapshotTodayPromises() {
    let promise1 = makeSnapshotPromise(id: "today-1", isConfirmed: true)
    let promise2 = makeSnapshotPromise(id: "today-2", isConfirmed: true)
    let snapshot = makeSnapshot(todayPromises: [promise1, promise2], todayCount: 2)

    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.todayPromises.count == 2)
  }

  // MARK: - pendingPromises 테스트

  @Test("응답 필요 약속 목록 반환")
  func pendingPromises_returnsSnapshotPendingPromises() {
    let promise = makeSnapshotPromise(id: "pending-1", myVoteStatus: .pending)
    let snapshot = makeSnapshot(pendingPromises: [promise], pendingCount: 1)

    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.pendingPromises.count == 1)
  }

  // MARK: - upcomingPromises 테스트

  @Test("다가오는 약속 목록 반환")
  func upcomingPromises_returnsSnapshotUpcomingPromises() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let promise = makeSnapshotPromise(id: "upcoming-1", startAt: tomorrow, isConfirmed: true)
    let snapshot = makeSnapshot(upcomingPromises: [promise])

    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.upcomingPromises.count == 1)
  }

  // MARK: - allPromises 테스트

  @Test("모든 약속 합산 반환")
  func allPromises_combinesAllCategories() {
    let today = makeSnapshotPromise(id: "today", isConfirmed: true)
    let pending = makeSnapshotPromise(id: "pending", myVoteStatus: .pending)
    let upcoming = makeSnapshotPromise(
      id: "upcoming",
      startAt: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
      isConfirmed: true
    )
    let snapshot = makeSnapshot(
      todayPromises: [today],
      pendingPromises: [pending],
      upcomingPromises: [upcoming]
    )

    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.allPromises.count == 3)
  }

  // MARK: - pendingResponseCount 테스트

  @Test("응답 필요 개수 반환")
  func pendingResponseCount_returnsMetaPendingCount() {
    let snapshot = makeSnapshot(pendingCount: 5)
    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.pendingResponseCount == 5)
  }

  @Test("응답 필요 없으면 0")
  func pendingResponseCount_whenNoPending_returnsZero() {
    let snapshot = makeSnapshot(pendingCount: 0)
    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.pendingResponseCount == 0)
  }

  // MARK: - overviewData 테스트

  @Test("오늘 약속 개수 계산")
  func overviewData_todayCount() {
    let snapshot = makeSnapshot(todayCount: 3)
    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.overviewData.todayCount == 3)
  }

  @Test("응답 필요 개수 계산")
  func overviewData_needResponseCount() {
    let snapshot = makeSnapshot(pendingCount: 2)
    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.overviewData.needResponseCount == 2)
  }

  // MARK: - Empty State 테스트

  @Test("빈 스냅샷에서 빈 배열 반환")
  func emptySnapshot_returnsEmptyArrays() {
    let snapshot = makeSnapshot()
    let state = makeState(snapshotState: .loaded(snapshot))

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
    #expect(state.allPromises.isEmpty)
  }

  @Test("idle 상태에서 빈 배열 반환")
  func idleState_returnsEmptyArrays() {
    let state = makeState(snapshotState: .idle)

    #expect(state.todayPromises.isEmpty)
    #expect(state.pendingPromises.isEmpty)
    #expect(state.upcomingPromises.isEmpty)
    #expect(state.allPromises.isEmpty)
  }
}
