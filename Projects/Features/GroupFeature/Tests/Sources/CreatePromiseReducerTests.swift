//
//  CreatePromiseReducerTests.swift
//  GroupFeature
//
//  CreatePromise.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreatePromise/Core/CreatePromiseFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
@testable import GroupFeature

// MARK: - CreatePromise Feature Tests

@Suite("CreatePromise.Feature reducer 테스트")
struct CreatePromiseReducerTests {

  // MARK: - Test Helpers

  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    memberIds: [String] = ["user-1", "user-2", "user-3"]
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberIds: memberIds,
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "user-1"
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = CreatePromise.Feature.State()

    #expect(state.currentStep == .first)
    #expect(state.isCreatingPromise == false)
    #expect(state.creationError == nil)
    #expect(state.isEmojiLoading == false)
    #expect(state.useLocation == true)
    #expect(state.showLiveActivityInfo == false)
  }

  // MARK: - Step Navigation 테스트

  @Test("nextStep 시 다음 단계로 이동")
  func nextStep_movesToNextStep() async {
    let store = TestStore(
      initialState: CreatePromise.Feature.State(currentStep: .first)
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.nextStep)) {
      $0.currentStep = .second
    }
  }

  @Test("previousStep 시 이전 단계로 이동")
  func previousStep_movesToPreviousStep() async {
    let store = TestStore(
      initialState: CreatePromise.Feature.State(currentStep: .second)
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.previousStep)) {
      $0.currentStep = .first
    }
  }

  // MARK: - Group Selection 테스트

  @Test("groupSelected 시 그룹 설정 및 최소 참가인원 자동 계산 (2명 그룹)")
  func groupSelected_twoMembers_setsMinParticipantsToTwo() async {
    let group = makeGroup(memberIds: ["user-1", "user-2"])

    let store = TestStore(
      initialState: CreatePromise.Feature.State()
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.groupSelected(group))) {
      $0.promise.group = group
      $0.promise.minimumParticipants = 2
    }
  }

  @Test("groupSelected 시 3명 이상 그룹에서 절반으로 최소 참가인원 설정")
  func groupSelected_threeOrMore_setsMinParticipantsToHalf() async {
    let group = makeGroup(memberIds: ["user-1", "user-2", "user-3", "user-4"])

    let store = TestStore(
      initialState: CreatePromise.Feature.State()
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.groupSelected(group))) {
      $0.promise.group = group
      $0.promise.minimumParticipants = 2  // ceil(4/2) = 2
    }
  }

  // MARK: - Participants 테스트

  @Test("incrementParticipants 시 최소 참가인원 증가")
  func incrementParticipants_incrementsCount() async {
    let group = makeGroup(memberIds: ["user-1", "user-2", "user-3"])
    var state = CreatePromise.Feature.State()
    state.promise.group = group
    state.promise.minimumParticipants = 2

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.incrementParticipants)) {
      $0.promise.minimumParticipants = 3
    }
  }

  @Test("decrementParticipants 시 최소 참가인원 감소 (최소 2)")
  func decrementParticipants_decrementsCountMinTwo() async {
    let group = makeGroup(memberIds: ["user-1", "user-2", "user-3"])
    var state = CreatePromise.Feature.State()
    state.promise.group = group
    state.promise.minimumParticipants = 2

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    // 이미 2이므로 감소하지 않음
    await store.send(.view(.decrementParticipants))
  }

  // MARK: - Date & Description 테스트

  @Test("setEndDate 시 종료 날짜 설정")
  func setEndDate_setsEndDate() async {
    let endDate = Date().addingTimeInterval(7200)

    let store = TestStore(
      initialState: CreatePromise.Feature.State()
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setEndDate(endDate))) {
      $0.promise.endAt = endDate
    }
  }

  @Test("setDescription 시 설명 설정 (500자 제한)")
  func setDescription_setsDescription() async {
    let store = TestStore(
      initialState: CreatePromise.Feature.State()
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setDescription("테스트 설명입니다"))) {
      $0.promise.description = "테스트 설명입니다"
    }
  }

  // MARK: - Location 테스트

  @Test("toggleUseLocation 시 장소 사용 토글")
  func toggleUseLocation_togglesState() async {
    let store = TestStore(
      initialState: CreatePromise.Feature.State(useLocation: true)
    ) {
      CreatePromise.Feature()
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = false
    }
  }

  // MARK: - Error Handling 테스트

  @Test("clearCreationError 시 에러 초기화")
  func clearCreationError_clearsError() async {
    var state = CreatePromise.Feature.State()
    state.creationError = .unknown("테스트 에러")

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.clearCreationError)) {
      $0.creationError = nil
    }
  }
}
