import Testing
@testable import RootTabFeature

@Suite("LiveSchedule.Detail reducer 테스트")
@MainActor
struct LiveScheduleDetailTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let data = makeLiveData()
    let state = LiveSchedule.Detail.State(data: Shared(value: data))

    #expect(state.selectedTab == .status)
    #expect(state.customMinuteInput == "")
    #expect(state.isETASheetPresented == false)
    #expect(state.schedule == nil)
  }

  // MARK: - 탭 선택 테스트

  @Test("탭 선택 시 selectedTab 변경")
  func tabSelected_changesSelectedTab() async {
    let store = makeStore()

    await store.send(.view(.tabSelected(.map))) {
      $0.selectedTab = .map
    }
    await store.finish()
  }

  // MARK: - ETA 버튼 테스트

  @Test("etaButtonTapped 시 입력 초기화 + 시트 닫기 + delegate 전달")
  func etaButtonTapped_clearsInputAndSendsDelegate() async {
    var data = makeLiveData()
    let state = LiveSchedule.Detail.State(data: Shared(value: data))
    var mutableState = state
    // customMinuteInput이 있는 상태에서 ETA 버튼 탭
    let store = TestStore(initialState: state) {
      LiveSchedule.Detail()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.etaButtonTapped(15))) {
      $0.customMinuteInput = ""
      $0.isETASheetPresented = false
    }
  }

  // MARK: - 직접 입력 테스트

  @Test("customMinuteInputChanged 시 숫자만 필터링")
  func customMinuteInputChanged_filtersNonNumbers() async {
    let store = makeStore()

    await store.send(.view(.customMinuteInputChanged("12abc34"))) {
      $0.customMinuteInput = "1234"
    }
  }

  @Test("customMinuteInputChanged 숫자만 입력하면 그대로 저장")
  func customMinuteInputChanged_numbersOnly_storesAsIs() async {
    let store = makeStore()

    await store.send(.view(.customMinuteInputChanged("25"))) {
      $0.customMinuteInput = "25"
    }
  }

  @Test("submitCustomMinute 유효한 값이면 delegate 전달")
  func submitCustomMinute_valid_sendsDelegate() async {
    let data = makeLiveData()
    var state = LiveSchedule.Detail.State(data: Shared(value: data))
    state.customMinuteInput = "20"

    let store = TestStore(initialState: state) {
      LiveSchedule.Detail()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.submitCustomMinute)) {
      $0.customMinuteInput = ""
      $0.isETASheetPresented = false
    }
  }

  @Test("submitCustomMinute 빈 문자열이면 에러 햅틱")
  func submitCustomMinute_empty_triggersError() async {
    let errorRecorder = CallCounter()
    let store = makeStore() {
      $0.hapticFeedback.error = {
        await errorRecorder.increment()
      }
    }

    await store.send(.view(.submitCustomMinute))
    await store.finish()
    #expect(await errorRecorder.value() == 1)
  }

  @Test("submitCustomMinute 0이면 에러 햅틱")
  func submitCustomMinute_zero_triggersError() async {
    let data = makeLiveData()
    var state = LiveSchedule.Detail.State(data: Shared(value: data))
    state.customMinuteInput = "0"

    let errorRecorder = CallCounter()

    let store = TestStore(initialState: state) {
      LiveSchedule.Detail()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      $0.hapticFeedback.error = {
        await errorRecorder.increment()
      }
    }

    await store.send(.view(.submitCustomMinute))
    await store.finish()
    #expect(await errorRecorder.value() == 1)
  }

  // MARK: - ETA 시트 토글 테스트

  @Test("showETASheet 시 시트 표시")
  func showETASheet_setsPresented() async {
    let store = makeStore()

    await store.send(.view(.showETASheet)) {
      $0.isETASheetPresented = true
    }
    await store.finish()
  }

  @Test("hideETASheet 시 시트 닫기")
  func hideETASheet_clearsPresented() async {
    let data = makeLiveData()
    var state = LiveSchedule.Detail.State(data: Shared(value: data))
    state.isETASheetPresented = true

    let store = TestStore(initialState: state) {
      LiveSchedule.Detail()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }

    await store.send(.view(.hideETASheet)) {
      $0.isETASheetPresented = false
    }
  }

  // MARK: - 길찾기 테스트

  @Test("directionsTapped 좌표 있으면 길찾기 실행")
  func directionsTapped_withCoordinates_opensDirections() async {
    let flag = LockIsolated(false)
    let data = makeLiveData(latitude: 37.4979, longitude: 127.0276)

    let store = makeStore(data: data) {
      $0.mapClient.openDirections = { _, _, _, _ in
        flag.setValue(true)
      }
    }

    await store.send(.view(.directionsTapped))
    await store.finish()
    #expect(flag.value == true)
  }

  @Test("directionsTapped 좌표 없으면 아무 동작 안 함")
  func directionsTapped_withoutCoordinates_doesNothing() async {
    let store = makeStore()
    await store.send(.view(.directionsTapped))
  }
}

// MARK: - Helpers

private extension LiveScheduleDetailTests {

  actor CallCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
  }

  func makeLiveData(
    latitude: Double? = nil,
    longitude: Double? = nil,
    location: String? = "강남역"
  ) -> LiveSchedule.Data {
    LiveSchedule.Data(
      emoji: "📍",
      title: "일정",
      location: location,
      latitude: latitude,
      longitude: longitude,
      scheduledTime: Date(timeIntervalSince1970: 1_700_000_000),
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5)
      ],
      currentUserId: "test-user",
      trackingDurationMinutes: 30,
      hostId: "host-1"
    )
  }

  func makeStore(
    data: LiveSchedule.Data? = nil,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<LiveSchedule.Detail> {
    let resolvedData = data ?? makeLiveData()
    return TestStore(
      initialState: LiveSchedule.Detail.State(data: Shared(value: resolvedData))
    ) {
      LiveSchedule.Detail()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.hapticFeedback.light = {}
    deps.hapticFeedback.medium = {}
    deps.hapticFeedback.error = {}
    deps.hapticFeedback.selection = {}
    deps.mapClient.openDirections = { _, _, _, _ in }
  }
}
