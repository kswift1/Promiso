//
//  JoinGroupReducerTests.swift
//  GroupFeature
//
//  JoinGroup.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/JoinGroup/Main/JoinGroupFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Testing
@testable import GroupFeature

// MARK: - JoinGroup Feature Tests

@Suite("JoinGroup.Feature reducer 테스트")
@MainActor
struct JoinGroupReducerTests {

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
    let state = JoinGroup.Feature.State(currentUser: user)

    #expect(state.step == .enterCode)
    #expect(state.inviteCode == "")
    #expect(state.isLoadingPreview == false)
    #expect(state.isJoining == false)
    #expect(state.previewError == nil)
    #expect(state.joinError == nil)
    #expect(state.isValidCode == false)
    #expect(state.canProceedToPreview == false)
  }

  // MARK: - Code Input 테스트

  @Test("codeChanged 시 코드 대문자 변환 및 6자리 제한")
  func codeChanged_uppercasesAndLimits() async {
    let user = makeCurrentUser()
    let store = TestStore(
      initialState: JoinGroup.Feature.State(currentUser: user)
    ) {
      JoinGroup.Feature()
    }

    await store.send(.view(.codeChanged("abc123"))) {
      $0.inviteCode = "ABC123"
    }
  }

  @Test("codeChanged 시 특수문자 필터링")
  func codeChanged_filtersSpecialCharacters() async {
    let user = makeCurrentUser()
    let store = TestStore(
      initialState: JoinGroup.Feature.State(currentUser: user)
    ) {
      JoinGroup.Feature()
    }

    await store.send(.view(.codeChanged("AB!@#C12"))) {
      $0.inviteCode = "ABC12"
    }
  }

  // MARK: - Navigation 테스트

  @Test("backTapped 시 enterCode 단계로 복귀")
  func backTapped_returnsToEnterCode() async {
    let user = makeCurrentUser()
    let group = GroupModel(
      id: "group-1",
      name: "테스트",
      maxMembers: 5,
      inviteCode: "ABC123",
      createdBy: "host"
    )
    let preview = GroupPreviewModel(
      group: group,
      members: []
    )
    var state = JoinGroup.Feature.State(currentUser: user)
    state.step = .preview(preview)

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    }

    await store.send(.view(.backTapped)) {
      $0.step = .enterCode
    }
  }

  @Test("cancelTapped 시 dismiss delegate 전달")
  func cancelTapped_sendsDismissDelegate() async {
    let user = makeCurrentUser()
    let store = TestStore(
      initialState: JoinGroup.Feature.State(currentUser: user)
    ) {
      JoinGroup.Feature()
    }

    await store.send(.view(.cancelTapped))
    await store.receive(\.delegate.dismiss)
  }

  // MARK: - nextTapped 테스트

  @Test("nextTapped 시 미리보기 로딩 시작")
  func nextTapped_startsPreviewLoading() async {
    let user = makeCurrentUser()
    var state = JoinGroup.Feature.State(currentUser: user)
    state.inviteCode = "ABC123"

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    } withDependencies: {
      $0.groupClient.previewGroup = { _ in
        let group = GroupModel(
          id: "g1", name: "테스트", maxMembers: 5,
          inviteCode: "ABC123", createdBy: "host"
        )
        return GroupPreviewModel(group: group, members: [])
      }
    }
    store.exhaustivity = .off

    await store.send(.view(.nextTapped)) {
      $0.isLoadingPreview = true
      $0.previewError = nil
    }
  }

  // MARK: - previewGroupResponse 테스트

  @Test("미리보기 성공 시 preview 단계로 이동")
  func previewGroupResponse_success_movesToPreview() async {
    let user = makeCurrentUser()
    var state = JoinGroup.Feature.State(currentUser: user)
    state.isLoadingPreview = true

    let group = GroupModel(
      id: "g1", name: "테스트", maxMembers: 5,
      inviteCode: "ABC123", createdBy: "host"
    )
    let preview = GroupPreviewModel(group: group, members: [])

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.previewGroupResponse(.success(preview)))) {
      $0.isLoadingPreview = false
      $0.step = .preview(preview)
    }
  }

  @Test("미리보기 실패 시 에러 메시지 설정")
  func previewGroupResponse_failure_setsError() async {
    let user = makeCurrentUser()
    var state = JoinGroup.Feature.State(currentUser: user)
    state.isLoadingPreview = true

    let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "미리보기 실패"])

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.previewGroupResponse(.failure(error)))) {
      $0.isLoadingPreview = false
      $0.previewError = "미리보기 실패"
    }
  }

  // MARK: - joinGroupResponse 테스트

  @Test("그룹 참여 실패 시 에러 메시지 설정")
  func joinGroupResponse_failure_setsJoinError() async {
    let user = makeCurrentUser()
    var state = JoinGroup.Feature.State(currentUser: user)
    state.isJoining = true

    let error = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "참여 실패"])

    let store = TestStore(initialState: state) {
      JoinGroup.Feature()
    }

    await store.send(.internal(.joinGroupResponse(.failure(error)))) {
      $0.isJoining = false
      $0.joinError = "참여 실패"
    }
  }
}
