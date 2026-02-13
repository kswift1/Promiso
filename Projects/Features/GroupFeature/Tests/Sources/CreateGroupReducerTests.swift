//
//  CreateGroupReducerTests.swift
//  GroupFeature
//
//  CreateGroup.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreateGroup/Main/CreateGroupFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Testing
@testable import GroupFeature

// MARK: - CreateGroup Feature Tests

@Suite("CreateGroup.Feature reducer 테스트")
@MainActor
struct CreateGroupReducerTests {

  // MARK: - Test Helpers

  private func makeCurrentUser() -> UserPrivateModel {
    UserPrivateModel(
      userId: "test-user-123",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      metadata: .init(),
      groups: []
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let user = makeCurrentUser()
    let state = CreateGroup.Feature.State(currentUser: user)

    #expect(state.step == .input)
    #expect(state.groupName == "")
    #expect(state.groupDescription == "")
    #expect(state.maxMembers == .five)
    #expect(state.isCreating == false)
    #expect(state.creationError == nil)
    #expect(state.photoData == nil)
    #expect(state.isValid == false)
    #expect(state.canSubmit == false)
  }

  // MARK: - Validation 테스트

  @Test("그룹 이름 2자 이상일 때 isValid true")
  func isValid_trueWhenNameHasTwoOrMoreChars() {
    let user = makeCurrentUser()
    var state = CreateGroup.Feature.State(currentUser: user)
    state.groupName = "AB"

    #expect(state.isValid == true)
    #expect(state.canSubmit == true)
  }

  @Test("그룹 이름 1자일 때 isValid false")
  func isValid_falseWhenNameHasOneChar() {
    let user = makeCurrentUser()
    var state = CreateGroup.Feature.State(currentUser: user)
    state.groupName = "A"

    #expect(state.isValid == false)
    #expect(state.canSubmit == false)
  }

  // MARK: - View Actions 테스트

  @Test("cancelTapped 시 dismiss delegate 전달")
  func cancelTapped_sendsDismissDelegate() async {
    let user = makeCurrentUser()
    let store = TestStore(
      initialState: CreateGroup.Feature.State(currentUser: user)
    ) {
      CreateGroup.Feature()
    }

    await store.send(.view(.cancelTapped))
    await store.receive(\.delegate.dismiss)
  }

  @Test("errorAlertDismissed 시 에러 초기화")
  func errorAlertDismissed_clearsError() async {
    let user = makeCurrentUser()
    var state = CreateGroup.Feature.State(currentUser: user)
    state.creationError = "테스트 에러"

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.view(.errorAlertDismissed)) {
      $0.creationError = nil
    }
  }

  // MARK: - Internal Actions 테스트

  @Test("photoLoaded 시 사진 데이터 설정")
  func photoLoaded_setsPhotoData() async {
    let user = makeCurrentUser()
    let testData = Data([0x00, 0x01, 0x02])

    let store = TestStore(
      initialState: CreateGroup.Feature.State(currentUser: user)
    ) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.photoLoaded(testData))) {
      $0.photoData = testData
    }
  }

  @Test("createGroupResponse 성공 시 success step으로 이동")
  func createGroupResponse_success_movesToSuccessStep() async {
    let user = makeCurrentUser()
    var state = CreateGroup.Feature.State(currentUser: user)
    state.isCreating = true

    let result = GroupCreationResultModel(
      id: "group-new",
      name: "테스트 그룹",
      inviteCode: "ABC123"
    )

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.createGroupResponse(.success(result)))) {
      $0.isCreating = false
      $0.step = .success(result)
    }
  }

  @Test("createGroupResponse 실패 시 에러 설정")
  func createGroupResponse_failure_setsError() async {
    let user = makeCurrentUser()
    var state = CreateGroup.Feature.State(currentUser: user)
    state.isCreating = true

    let testError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "생성 실패"])

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    }

    await store.send(.internal(.createGroupResponse(.failure(testError)))) {
      $0.isCreating = false
      $0.creationError = testError.localizedDescription
    }
  }

  // MARK: - successAcknowledged 테스트

  @Test("성공 확인 시 settings 단계로 이동")
  func successAcknowledged_movesToSettingsStep() async {
    let user = makeCurrentUser()
    let result = GroupCreationResultModel(
      id: "group-new",
      name: "테스트 그룹",
      inviteCode: "ABC123"
    )
    var state = CreateGroup.Feature.State(currentUser: user)
    state.step = .success(result)

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.eventKitClient.authorizationStatus = { .fullAccess }
    }
    store.exhaustivity = .off

    await store.send(.view(.successAcknowledged)) {
      $0.step = .settings(result)
    }
  }

  // MARK: - settingsSkipped 테스트

  @Test("설정 건너뛰기 시 delegate.groupCreated 전달")
  func settingsSkipped_sendsGroupCreatedDelegate() async {
    let user = makeCurrentUser()
    let result = GroupCreationResultModel(
      id: "group-new",
      name: "테스트 그룹",
      inviteCode: "ABC123"
    )
    var state = CreateGroup.Feature.State(currentUser: user)
    state.step = .settings(result)

    let store = TestStore(initialState: state) {
      CreateGroup.Feature()
    } withDependencies: {
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.view(.settingsSkipped))
    await store.receive(\.delegate.groupCreated) {
      $0.step = .input
    }
  }
}
