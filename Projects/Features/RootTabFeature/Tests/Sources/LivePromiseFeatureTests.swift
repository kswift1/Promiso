import Testing
@testable import RootTabFeature

@Suite("LivePromise.Feature reducer 테스트")
@MainActor
struct LivePromiseFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = LivePromise.Feature.State(
      emoji: "📍",
      title: "약속",
      currentUserId: "test-user"
    )
    #expect(state.data.emoji == "📍")
    #expect(state.data.title == "약속")
    #expect(state.pendingETAUpdate == nil)
    #expect(state.data.isProcessingETAUpdate == false)
  }

  // MARK: - View 액션 테스트

  @Test("tapped 시 delegate showDetail 전달")
  func tapped_sendsShowDetailDelegate() async {
    let store = makeStore()

    await store.send(.view(.tapped))
    await store.receive(\.delegate.showDetail)
  }

  @Test("onAppear 시 refresh + contentState 구독 시작")
  func onAppear_startsRefreshAndSubscription() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear))
    await store.receive(\.view.refreshFromLiveActivity)
    await store.receive(\.internal.observeContentStateUpdates)
    await store.finish()
  }

  @Test("refreshFromLiveActivity 활성 Activity 있으면 상태 동기화")
  func refreshFromLiveActivity_withActive_syncsState() async {
    let attributes = makeAttributes(emoji: "🎉", title: "파티", location: "홍대", hostId: "host-2", hostName: "호스트2")
    let contentState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 45,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 0)
      ]
    )

    let store = makeStore() {
      $0.liveActivityClient.hasActiveActivity = { true }
      $0.liveActivityClient.currentAttributes = { attributes }
      $0.liveActivityClient.currentState = { contentState }
    }

    await store.send(.view(.refreshFromLiveActivity))
    await store.receive(\.internal.liveActivityStateUpdated) {
      $0.$data.withLock {
        $0.emoji = "🎉"
        $0.title = "파티"
        $0.location = "홍대"
        $0.hostId = "host-2"
        $0.hostName = "호스트2"
        $0.participants = contentState.participants
        $0.trackingDurationMinutes = 45
      }
    }
  }

  @Test("refreshFromLiveActivity 활성 Activity 없으면 nil 전달")
  func refreshFromLiveActivity_withoutActive_sendsNil() async {
    let store = makeStore()

    await store.send(.view(.refreshFromLiveActivity))
    await store.receive(\.internal.liveActivityStateUpdated)
  }

  // MARK: - ETA 업데이트 테스트

  @Test("etaButtonTapped 시 ETA 업데이트 처리 시작")
  func etaButtonTapped_startsProcessing() async {
    let contentState = makeContentState()
    let updateRecorder = CallCounter()

    let store = makeStore() {
      $0.liveActivityClient.activeActivityId = { "activity-1" }
      $0.liveActivityClient.currentState = { contentState }
      $0.liveActivityClient.update = { _, _ in
        await updateRecorder.increment()
      }
      $0.liveActivityClient.hasActiveActivity = { false }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.etaButtonTapped(10)))
    #expect(store.state.data.isProcessingETAUpdate == true)
    #expect(store.state.pendingETAUpdate?.estimatedMinutes == 10)

    await store.finish()

    #expect(await updateRecorder.value() == 1)
    #expect(store.state.data.isProcessingETAUpdate == false)
    #expect(store.state.pendingETAUpdate == nil)
  }

  @Test("etaButtonTapped 처리 중이면 무시")
  func etaButtonTapped_whileProcessing_isIgnored() async {
    let data = makeLiveData(isProcessingETAUpdate: true)
    let store = makeStore(data: data)

    await store.send(.view(.etaButtonTapped(10)))
  }

  // MARK: - 내부 액션 테스트 (상태 동기화)

  @Test("liveActivityStateUpdated 시 attributes와 contentState 동기화")
  func liveActivityStateUpdated_syncsData() async {
    let attributes = makeAttributes(emoji: "🎉", title: "파티", location: "홍대", hostId: "host-2", hostName: "호스트2")
    let contentState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 45,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 0)
      ]
    )

    let store = makeStore()

    await store.send(.internal(.liveActivityStateUpdated(attributes, contentState))) {
      $0.$data.withLock {
        $0.emoji = "🎉"
        $0.title = "파티"
        $0.location = "홍대"
        $0.hostId = "host-2"
        $0.hostName = "호스트2"
        $0.participants = contentState.participants
        $0.trackingDurationMinutes = 45
      }
    }
  }

  @Test("liveActivityStateUpdated nil이면 상태 변경 없음")
  func liveActivityStateUpdated_nil_noChange() async {
    let store = makeStore()
    await store.send(.internal(.liveActivityStateUpdated(nil, nil)))
  }

  // MARK: - 내부 액션 테스트 (ETA 처리)

  @Test("processPendingETAUpdate 시 activityId 없으면 processing 해제")
  func processPendingETAUpdate_withNoActivityId_clearsProcessing() async {
    let data = makeLiveData(isProcessingETAUpdate: true)
    var state = LivePromise.Feature.State(data: Shared(value: data))
    let etaUpdate = ETAUpdate(promiseId: "", userId: "test-user", estimatedMinutes: 10, timestamp: Date())
    state.pendingETAUpdate = etaUpdate

    let store = TestStore(initialState: state) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }

    await store.send(.internal(.processPendingETAUpdate(etaUpdate))) {
      $0.$data.withLock { $0.isProcessingETAUpdate = false }
    }
  }

  @Test("processPendingETAUpdate 성공 시 etaUpdateSent 전달")
  func processPendingETAUpdate_success_sendsEtaUpdateSent() async {
    let data = makeLiveData(isProcessingETAUpdate: true)
    var state = LivePromise.Feature.State(data: Shared(value: data))
    let etaUpdate = ETAUpdate(promiseId: "", userId: "test-user", estimatedMinutes: 10, timestamp: Date())
    state.pendingETAUpdate = etaUpdate

    let contentState = makeContentState()

    let store = TestStore(initialState: state) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      $0.liveActivityClient.activeActivityId = { "activity-1" }
      $0.liveActivityClient.currentState = { contentState }
      $0.liveActivityClient.update = { _, _ in }
      $0.liveActivityClient.hasActiveActivity = { false }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.processPendingETAUpdate(etaUpdate)))
    await store.receive(\.internal.etaUpdateSent) {
      $0.$data.withLock { $0.isProcessingETAUpdate = false }
      $0.pendingETAUpdate = nil
    }
    // etaUpdateSent triggers refreshFromLiveActivity
    await store.finish()
  }

  @Test("processPendingETAUpdate 실패 시 etaUpdateFailed 전달")
  func processPendingETAUpdate_failure_sendsEtaUpdateFailed() async {
    enum TestError: Error { case failed }

    let data = makeLiveData(isProcessingETAUpdate: true)
    var state = LivePromise.Feature.State(data: Shared(value: data))
    let etaUpdate = ETAUpdate(promiseId: "", userId: "test-user", estimatedMinutes: 10, timestamp: Date())
    state.pendingETAUpdate = etaUpdate

    let contentState = makeContentState()

    let store = TestStore(initialState: state) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      $0.liveActivityClient.activeActivityId = { "activity-1" }
      $0.liveActivityClient.currentState = { contentState }
      $0.liveActivityClient.update = { _, _ in throw TestError.failed }
    }

    await store.send(.internal(.processPendingETAUpdate(etaUpdate)))
    await store.receive(\.internal.etaUpdateFailed) {
      $0.$data.withLock { $0.isProcessingETAUpdate = false }
      $0.pendingETAUpdate = nil
    }
  }

  @Test("etaUpdateSent 시 processing 해제 및 새로고침")
  func etaUpdateSent_clearsStateAndRefreshes() async {
    let data = makeLiveData(isProcessingETAUpdate: true)
    var state = LivePromise.Feature.State(data: Shared(value: data))
    state.pendingETAUpdate = ETAUpdate(promiseId: "", userId: "test-user", estimatedMinutes: 10, timestamp: Date())

    let store = TestStore(initialState: state) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.etaUpdateSent)) {
      $0.$data.withLock { $0.isProcessingETAUpdate = false }
      $0.pendingETAUpdate = nil
    }
    // refreshFromLiveActivity chain
    await store.finish()
  }

  @Test("etaUpdateFailed 시 processing 해제")
  func etaUpdateFailed_clearsState() async {
    let data = makeLiveData(isProcessingETAUpdate: true)
    var state = LivePromise.Feature.State(data: Shared(value: data))
    state.pendingETAUpdate = ETAUpdate(promiseId: "", userId: "test-user", estimatedMinutes: 5, timestamp: Date())

    let store = TestStore(initialState: state) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
    }

    await store.send(.internal(.etaUpdateFailed)) {
      $0.$data.withLock { $0.isProcessingETAUpdate = false }
      $0.pendingETAUpdate = nil
    }
  }

  // MARK: - 내부 액션 테스트 (ContentState 구독)

  @Test("observeContentStateUpdates 활성 약속 없으면 아무 동작 안 함")
  func observeContentStateUpdates_withoutActivePromise_doesNothing() async {
    let store = makeStore()
    await store.send(.internal(.observeContentStateUpdates))
  }

  @Test("observeContentStateUpdates 활성 약속이면 스트림 구독")
  func observeContentStateUpdates_withActivePromise_subscribes() async {
    let newContentState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 20,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 3)
      ]
    )

    let store = makeStore() {
      $0.liveActivityClient.activePromiseId = { "promise-1" }
      $0.liveActivityClient.observeStateUpdates = { _ in
        AsyncStream { continuation in
          continuation.yield(newContentState)
          continuation.finish()
        }
      }
    }

    await store.send(.internal(.observeContentStateUpdates))
    await store.receive(\.internal.contentStateUpdated) {
      $0.$data.withLock {
        $0.participants = newContentState.participants
        $0.trackingDurationMinutes = 20
      }
    }
  }

  @Test("contentStateUpdated 시 participants 동기화")
  func contentStateUpdated_syncsParticipants() async {
    let updatedContentState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 25,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 0),
        ParticipantState(id: "user-2", name: "친구", estimatedArrivalMinutes: 7)
      ]
    )

    let store = makeStore()

    await store.send(.internal(.contentStateUpdated(updatedContentState))) {
      $0.$data.withLock {
        $0.participants = updatedContentState.participants
        $0.trackingDurationMinutes = 25
      }
    }
  }
}

// MARK: - Helpers

private extension LivePromiseFeatureTests {

  actor CallCounter {
    private var count = 0
    func increment() { count += 1 }
    func value() -> Int { count }
  }

  func makeLiveData(
    emoji: String = "📍",
    title: String = "약속",
    location: String? = "강남역",
    participants: [ParticipantState] = [
      ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5)
    ],
    currentUserId: String = "test-user",
    isProcessingETAUpdate: Bool = false
  ) -> LivePromise.Data {
    LivePromise.Data(
      emoji: emoji,
      title: title,
      location: location,
      scheduledTime: Date(timeIntervalSince1970: 1_700_000_000),
      participants: participants,
      currentUserId: currentUserId,
      trackingDurationMinutes: 30,
      isProcessingETAUpdate: isProcessingETAUpdate,
      hostId: "host-1"
    )
  }

  func makeStore(
    data: LivePromise.Data? = nil,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<LivePromise.Feature> {
    let resolvedData = data ?? makeLiveData()
    return TestStore(initialState: LivePromise.Feature.State(data: Shared(value: resolvedData))) {
      LivePromise.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.liveActivityClient.hasActiveActivity = { false }
    deps.liveActivityClient.currentAttributes = { nil }
    deps.liveActivityClient.currentState = { nil }
    deps.liveActivityClient.activeActivityId = { nil }
    deps.liveActivityClient.activePromiseId = { nil }
    deps.liveActivityClient.observeStateUpdates = { _ in nil }
    deps.liveActivityClient.update = { _, _ in }
  }

  func makeAttributes(
    emoji: String = "📍",
    title: String = "약속",
    location: String? = "강남역",
    hostId: String = "host-1",
    hostName: String? = nil
  ) -> PromiseActivityAttributes {
    PromiseActivityAttributes(
      promiseId: "promise-1",
      currentUserId: "test-user",
      emoji: emoji,
      title: title,
      location: location,
      scheduledTime: Date(timeIntervalSince1970: 1_700_000_000),
      trackingDurationMinutes: 30,
      hostId: hostId,
      hostName: hostName
    )
  }

  func makeContentState() -> PromiseActivityAttributes.ContentState {
    PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 30,
      participants: [
        ParticipantState(id: "test-user", name: "나", estimatedArrivalMinutes: 5)
      ]
    )
  }
}
