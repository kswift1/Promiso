//
//  CreateScheduleReducerTests.swift
//  GroupFeature
//
//  CreateSchedule.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreateSchedule/Core/CreateScheduleFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Testing
@testable import CreateScheduleFeature

// MARK: - CreateSchedule Feature Tests

@Suite("CreateSchedule.Feature reducer 테스트")
@MainActor
struct CreateScheduleReducerTests {

  // MARK: - Test Helpers

  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    memberCount: Int = 3,
    maxMembers: Int = 10
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberCount: memberCount,
      maxMembers: maxMembers,
      inviteCode: "ABC123",
      createdBy: "user-1"
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = CreateSchedule.Feature.State()

    #expect(state.currentStep == .first)
    #expect(state.isCreatingSchedule == false)
    #expect(state.creationError == nil)
    #expect(state.isEmojiLoading == false)
    #expect(state.useLocation == false)
    #expect(state.showLiveActivityInfo == false)
  }

  // MARK: - Step Navigation 테스트

  @Test("nextStep 시 다음 단계로 이동")
  func nextStep_movesToNextStep() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State(currentStep: .first)
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.nextStep)) {
      $0.currentStep = .second
    }
  }

  @Test("previousStep 시 이전 단계로 이동")
  func previousStep_movesToPreviousStep() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State(currentStep: .second)
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.previousStep)) {
      $0.currentStep = .first
    }
  }

  // MARK: - Group Selection 테스트

  @Test("groupSelected 시 그룹 설정 및 최소 참가인원 자동 계산 (memberCount 기준)")
  func groupSelected_setsMinParticipantsBasedOnMemberCount() async {
    let group = makeGroup(memberCount: 2)

    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.groupSelected(group))) {
      $0.schedule.group = group
      $0.schedule.minimumParticipants = 2  // ceil(memberCount(2) / 2) = 1 → max(2, 1) = 2
    }
  }

  @Test("groupSelected 시 memberCount 기준으로 최소 참가인원 설정")
  func groupSelected_differentMemberCount_setsMinParticipantsBasedOnMemberCount() async {
    let group = makeGroup(memberCount: 4)

    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.groupSelected(group))) {
      $0.schedule.group = group
      $0.schedule.minimumParticipants = 2  // ceil(memberCount(4) / 2) = 2 → max(2, 2) = 2
    }
  }

  @Test("1인 그룹(memberCount == 1) 선택 시 최소 참가인원 1명 고정")
  func groupSelected_singleMemberGroup_setsMinParticipantsToOne() async {
    let group = makeGroup(memberCount: 1, maxMembers: 1)

    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.groupSelected(group))) {
      $0.schedule.group = group
      $0.schedule.minimumParticipants = 1
    }
  }

  // MARK: - Participants 테스트

  @Test("incrementParticipants 시 최소 참가인원 증가")
  func incrementParticipants_incrementsCount() async {
    let group = makeGroup(memberCount: 3)
    var state = CreateSchedule.Feature.State()
    state.schedule.group = group
    state.schedule.minimumParticipants = 2

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.incrementParticipants)) {
      $0.schedule.minimumParticipants = 3
    }
  }

  @Test("decrementParticipants 시 최소 참가인원 감소 (최소 2)")
  func decrementParticipants_decrementsCountMinTwo() async {
    let group = makeGroup(memberCount: 3)
    var state = CreateSchedule.Feature.State()
    state.schedule.group = group
    state.schedule.minimumParticipants = 2

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }

    // 이미 2이므로 감소하지 않음
    await store.send(.view(.decrementParticipants))
  }

  // MARK: - Date & Description 테스트

  @Test("setEndDate 시 종료 날짜 설정")
  func setEndDate_setsEndDate() async {
    let endDate = Date().addingTimeInterval(7200)

    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.setEndDate(endDate))) {
      $0.schedule.endAt = endDate
    }
  }

  @Test("setDescription 시 설명 설정 (500자 제한)")
  func setDescription_setsDescription() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.setDescription("테스트 설명입니다"))) {
      $0.schedule.description = "테스트 설명입니다"
    }
  }

  // MARK: - Location 테스트

  @Test("toggleUseLocation 시 장소 사용 토글")
  func toggleUseLocation_togglesState() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State(useLocation: true)
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = false
    }
  }

  // MARK: - Error Handling 테스트

  @Test("clearCreationError 시 에러 초기화")
  func clearCreationError_clearsError() async {
    var state = CreateSchedule.Feature.State()
    state.creationError = .unknown("테스트 에러")

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.clearCreationError)) {
      $0.creationError = nil
    }
  }

  // MARK: - LiveActivity Info 테스트

  @Test("LiveActivity 정보 버튼 탭 시 팝오버 표시")
  func liveActivityInfoButtonTapped_showsPopover() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.liveActivityInfoButtonTapped)) {
      $0.showLiveActivityInfo = true
    }
  }

  @Test("LiveActivity 정보 팝오버 닫기")
  func liveActivityInfoDismissed_hidesPopover() async {
    var state = CreateSchedule.Feature.State()
    state.showLiveActivityInfo = true
    state.hasSeenLiveActivityInfo = true

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }

    await store.send(.view(.liveActivityInfoDismissed)) {
      $0.showLiveActivityInfo = false
    }
  }

  // MARK: - toggleUseEndTime 테스트

  @Test("[P18] 종료시간 토글 ON 시 시작시간 + 2시간 설정")
  func toggleUseEndTime_on_setsEndAt() async {
    let store = TestStore(
      initialState: CreateSchedule.Feature.State()
    ) {
      CreateSchedule.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.toggleUseEndTime)) {
      $0.schedule.endAt = $0.schedule.startAt.addingTimeInterval(7200)
    }
  }

  @Test("종료시간 토글 OFF 시 endAt nil 설정")
  func toggleUseEndTime_off_clearsEndAt() async {
    var state = CreateSchedule.Feature.State()
    state.schedule.endAt = Date().addingTimeInterval(7200)

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.toggleUseEndTime)) {
      $0.schedule.endAt = nil
    }
  }

  // MARK: - createScheduleResponse 테스트

  @Test("일정 생성 성공 시 delegate.scheduleCreated 전달")
  func createScheduleResponse_success_sendsDelegate() async {
    var state = CreateSchedule.Feature.State()
    state.isCreatingSchedule = true

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.analyticsClient.logEvent = { _, _ in }
      $0.scheduleClient.startVoteLiveActivity = { _ in }
      $0.appReviewClient.requestReviewIfEligible = { }
    }
    store.exhaustivity = .off

    await store.send(.internal(.createScheduleResponse(.success("schedule-1")))) {
      $0.isCreatingSchedule = false
    }
  }

  @Test("일정 생성 실패 시 에러 설정")
  func createScheduleResponse_failure_setsError() async {
    var state = CreateSchedule.Feature.State()
    state.isCreatingSchedule = true

    let store = TestStore(initialState: state) {
      CreateSchedule.Feature()
    }

    await store.send(.internal(.createScheduleResponse(.failure(.unknown("생성 실패"))))) {
      $0.isCreatingSchedule = false
      $0.creationError = .unknown("생성 실패")
    }
  }
}
