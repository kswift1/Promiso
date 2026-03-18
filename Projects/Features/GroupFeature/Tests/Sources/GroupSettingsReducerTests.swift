//
//  GroupSettingsReducerTests.swift
//  GroupFeature
//
//  GroupSettings.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/GroupSettings/GroupSettingsFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Testing
@testable import GroupFeature

// MARK: - GroupSettings Feature Tests

@Suite("GroupSettings.Feature reducer 테스트")
@MainActor
struct GroupSettingsReducerTests {

  // MARK: - Test Helpers

  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    createdBy: String = "host-user"
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberIds: ["host-user", "member-1"],
      maxMembers: 10,
      inviteCode: "TEST01",
      createdBy: createdBy
    )
  }

  private func makeState(
    currentUserId: String = "host-user"
  ) -> GroupSettings.Feature.State {
    GroupSettings.Feature.State(
      group: makeGroup(),
      summary: nil,
      currentUserId: currentUserId,
      isPro: false
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("[G9] 호스트 사용자 isHost true 확인")
  func isHost_trueForHostUser() {
    let state = makeState(currentUserId: "host-user")
    #expect(state.isHost == true)
  }

  @Test("[G9] 일반 멤버 isHost false 확인")
  func isHost_falseForMember() {
    let state = makeState(currentUserId: "member-1")
    #expect(state.isHost == false)
  }

  // MARK: - View Actions 테스트

  @Test("inviteTapped 시 초대 시트 표시")
  func inviteTapped_showsInviteSheet() async {
    let store = TestStore(initialState: makeState()) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.light = {}
      $0.analyticsClient.logEvent = { _, _ in }
    }

    await store.send(.view(.inviteTapped)) {
      $0.showInviteSheet = true
    }
  }

  @Test("dismissInviteSheet 시 초대 시트 닫기")
  func dismissInviteSheet_closesSheet() async {
    var state = makeState()
    state.showInviteSheet = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.dismissInviteSheet)) {
      $0.showInviteSheet = false
    }
  }

  @Test("leaveGroupTapped 시 탈퇴 확인 Alert 표시")
  func leaveGroupTapped_showsLeaveAlert() async {
    let store = TestStore(initialState: makeState()) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.warning = {}
    }

    await store.send(.view(.leaveGroupTapped)) {
      $0.showLeaveAlert = true
    }
  }

  @Test("dismissLeaveAlert 시 Alert 닫기")
  func dismissLeaveAlert_closesAlert() async {
    var state = makeState()
    state.showLeaveAlert = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.dismissLeaveAlert)) {
      $0.showLeaveAlert = false
    }
  }

  @Test("deleteGroupTapped 시 삭제 확인 Alert 표시")
  func deleteGroupTapped_showsDeleteAlert() async {
    let store = TestStore(initialState: makeState()) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.warning = {}
    }

    await store.send(.view(.deleteGroupTapped)) {
      $0.showDeleteAlert = true
    }
  }

  @Test("dismissError 시 모든 에러 초기화")
  func dismissError_clearsAllErrors() async {
    var state = makeState()
    state.leaveError = "탈퇴 에러"
    state.deleteError = "삭제 에러"
    state.notificationError = "알림 에러"

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.dismissError)) {
      $0.leaveError = nil
      $0.deleteError = nil
      $0.notificationError = nil
    }
  }

  @Test("transferHostTapped 시 양도 시트 표시")
  func transferHostTapped_showsTransferSheet() async {
    let store = TestStore(initialState: makeState()) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.warning = {}
    }

    await store.send(.view(.transferHostTapped)) {
      $0.isShowingTransferSheet = true
      $0.selectedNewHost = nil
    }
  }

  @Test("selectNewHost 시 새 호스트 선택")
  func selectNewHost_setsSelectedNewHost() async {
    let member = UserPublicModel(
      userId: "member-1",
      name: "멤버1",
      nickname: "멤버닉네임",
      metadata: .init()
    )

    let store = TestStore(initialState: makeState()) {
      GroupSettings.Feature()
    }

    await store.send(.view(.selectNewHost(member))) {
      $0.selectedNewHost = member
    }
  }

  @Test("dismissTransferSheet 시 양도 시트 닫기")
  func dismissTransferSheet_closesSheet() async {
    var state = makeState()
    state.isShowingTransferSheet = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.dismissTransferSheet)) {
      $0.isShowingTransferSheet = false
      $0.selectedNewHost = nil
    }
  }

  // MARK: - 도메인 규칙 테스트

  @Test("[G3] editGroupDescriptionChanged 시 50자로 잘림")
  func editGroupDescriptionChanged_truncatesAt50Characters() async {
    var state = makeState()
    state.editGroup = GroupSettings.Feature.EditGroupState(
      description: "",
      maxMembers: 10,
      selectedPhoto: nil,
      photoData: nil,
      isSaving: false,
      error: nil
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    let longText = String(repeating: "가", count: 60)
    await store.send(.view(.editGroupDescriptionChanged(longText))) {
      $0.editGroup?.description = String(repeating: "가", count: 50)
    }
  }

  @Test("[G3] editGroupDescriptionChanged 시 50자 이하는 그대로")
  func editGroupDescriptionChanged_shortTextUnchanged() async {
    var state = makeState()
    state.editGroup = GroupSettings.Feature.EditGroupState(
      description: "",
      maxMembers: 10,
      selectedPhoto: nil,
      photoData: nil,
      isSaving: false,
      error: nil
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.editGroupDescriptionChanged("짧은 설명"))) {
      $0.editGroup?.description = "짧은 설명"
    }
  }

  @Test("[G5] editGroupMaxMembersChanged 시 하한(현재 멤버 수) 이하로 내려가지 않음")
  func editGroupMaxMembersChanged_clampsToMinimum() async {
    var state = makeState()
    state.editGroup = GroupSettings.Feature.EditGroupState(
      description: "",
      maxMembers: 10,
      selectedPhoto: nil,
      photoData: nil,
      isSaving: false,
      error: nil
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    // memberIds는 2명이므로 minMaxMembers = max(2, 2) = 2
    await store.send(.view(.editGroupMaxMembersChanged(1))) {
      $0.editGroup?.maxMembers = 2
    }
  }

  @Test("[G5] editGroupMaxMembersChanged 시 상한(10) 초과하지 않음")
  func editGroupMaxMembersChanged_clampsToMaximum() async {
    var state = makeState()
    state.editGroup = GroupSettings.Feature.EditGroupState(
      description: "",
      maxMembers: 8,
      selectedPhoto: nil,
      photoData: nil,
      isSaving: false,
      error: nil
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    }

    await store.send(.view(.editGroupMaxMembersChanged(15))) {
      $0.editGroup?.maxMembers = 10
    }
  }

  @Test("[G12] canTransferHost - 호스트이고 멤버 2명 이상이면 true")
  func canTransferHost_hostWithMultipleMembers_returnsTrue() {
    var state = makeState(currentUserId: "host-user")
    state.members = [
      UserPublicModel(userId: "host-user", name: "호스트", nickname: "호스트", metadata: .init()),
      UserPublicModel(userId: "member-1", name: "멤버1", nickname: "멤버1", metadata: .init()),
    ]
    #expect(state.canTransferHost == true)
  }

  @Test("[G12] canTransferHost - 호스트가 아니면 false")
  func canTransferHost_notHost_returnsFalse() {
    var state = makeState(currentUserId: "member-1")
    state.members = [
      UserPublicModel(userId: "host-user", name: "호스트", nickname: "호스트", metadata: .init()),
      UserPublicModel(userId: "member-1", name: "멤버1", nickname: "멤버1", metadata: .init()),
    ]
    #expect(state.canTransferHost == false)
  }

  @Test("[G12] canTransferHost - 호스트이지만 혼자면 false")
  func canTransferHost_hostAlone_returnsFalse() {
    var state = makeState(currentUserId: "host-user")
    state.members = [
      UserPublicModel(userId: "host-user", name: "호스트", nickname: "호스트", metadata: .init()),
    ]
    #expect(state.canTransferHost == false)
  }

  // MARK: - confirmLeave 테스트

  @Test("confirmLeave 시 탈퇴 로딩 시작")
  func confirmLeave_startsLeaving() async {
    var state = makeState(currentUserId: "member-1")
    state.showLeaveAlert = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.heavy = {}
      $0.groupClient.leaveGroup = { _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.confirmLeave)) {
      $0.showLeaveAlert = false
      $0.isLeavingGroup = true
      $0.leaveError = nil
    }
  }

  // MARK: - leaveGroupResponse 테스트

  @Test("탈퇴 성공 시 로딩 해제")
  func leaveGroupResponse_success_clearsLoading() async {
    var state = makeState(currentUserId: "member-1")
    state.isLeavingGroup = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.success = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.leaveGroupResponse(.success(())))) {
      $0.isLeavingGroup = false
    }
  }

  @Test("탈퇴 실패 시 에러 메시지 설정")
  func leaveGroupResponse_failure_setsError() async {
    var state = makeState(currentUserId: "member-1")
    state.isLeavingGroup = true

    let error = GroupClientError.serverError

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.error = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.leaveGroupResponse(.failure(error)))) {
      $0.isLeavingGroup = false
      $0.leaveError = error.localizedMessage
    }
  }

  // MARK: - confirmDelete 테스트

  @Test("[G11] confirmDelete 시 삭제 로딩 시작")
  func confirmDelete_startsDeletingGroup() async {
    var state = makeState()
    state.showDeleteAlert = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.heavy = {}
      $0.groupClient.deleteGroup = { _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.confirmDelete)) {
      $0.showDeleteAlert = false
      $0.isDeletingGroup = true
      $0.deleteError = nil
    }
  }

  // MARK: - deleteGroupResponse 테스트

  @Test("삭제 성공 시 로딩 해제")
  func deleteGroupResponse_success_clearsLoading() async {
    var state = makeState()
    state.isDeletingGroup = true

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.success = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.deleteGroupResponse(.success(())))) {
      $0.isDeletingGroup = false
    }
  }

  @Test("삭제 실패 시 에러 메시지 설정")
  func deleteGroupResponse_failure_setsError() async {
    var state = makeState()
    state.isDeletingGroup = true

    let error = GroupClientError.serverError

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.error = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.deleteGroupResponse(.failure(error)))) {
      $0.isDeletingGroup = false
      $0.deleteError = error.localizedMessage
    }
  }

  // MARK: - confirmTransferHost 테스트

  @Test("[G12] confirmTransferHost 시 양도 시작")
  func confirmTransferHost_startsTransferring() async {
    var state = makeState()
    state.selectedNewHost = UserPublicModel(
      userId: "member-1", name: "멤버1", nickname: "멤버닉네임", metadata: .init()
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.heavy = {}
      $0.groupClient.transferHost = { _, _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.confirmTransferHost)) {
      $0.isTransferringHost = true
      $0.transferError = nil
    }
  }

  // MARK: - transferHostResponse 테스트

  @Test("양도 성공 시 상태 초기화")
  func transferHostResponse_success_resetsState() async {
    var state = makeState()
    state.isTransferringHost = true
    state.isShowingTransferSheet = true
    state.selectedNewHost = UserPublicModel(
      userId: "member-1", name: "멤버1", nickname: "멤버닉네임", metadata: .init()
    )

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.success = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.transferHostResponse(.success(())))) {
      $0.isTransferringHost = false
      $0.isShowingTransferSheet = false
      $0.selectedNewHost = nil
    }
  }

  @Test("양도 실패 시 에러 메시지 설정")
  func transferHostResponse_failure_setsError() async {
    var state = makeState()
    state.isTransferringHost = true

    let error = GroupClientError.serverError

    let store = TestStore(initialState: state) {
      GroupSettings.Feature()
    } withDependencies: {
      $0.hapticFeedback.error = {}
    }
    store.exhaustivity = .off

    await store.send(.internal(.transferHostResponse(.failure(error)))) {
      $0.isTransferringHost = false
      $0.transferError = error.localizedMessage
    }
  }
}
