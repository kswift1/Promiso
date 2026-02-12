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

import Foundation
import Testing
import ComposableArchitecture
import Clients
import PromisoShared
@testable import GroupFeature

// MARK: - GroupSettings Feature Tests

@Suite("GroupSettings.Feature reducer 테스트")
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
      userPlan: .free
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("호스트 사용자 isHost true 확인")
  func isHost_trueForHostUser() {
    let state = makeState(currentUserId: "host-user")
    #expect(state.isHost == true)
  }

  @Test("일반 멤버 isHost false 확인")
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
      $0.hapticFeedback.buttonTap = {}
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
}
