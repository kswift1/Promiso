import Testing
@testable import GroupFeature

@Suite("ManageGroup.Feature reducer 테스트")
@MainActor
struct ManageGroupFeatureTests {

  private func makeGroup(
    id: String = "group-1",
    name: String = "테스트 그룹",
    createdBy: String = "host-user",
    memberCount: Int = 2
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      memberCount: memberCount,
      maxMembers: 10,
      inviteCode: "TEST01",
      createdBy: createdBy
    )
  }

  private func makeMember(
    userId: String,
    name: String
  ) -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: name,
      nickname: name,
      metadata: .init()
    )
  }

  private func makeSchedule(
    id: String = "schedule-1",
    startAt: Date = Date().addingTimeInterval(3600)
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: "일정 \(id)",
      hostId: "host-user",
      groupId: "group-1",
      minimumParticipants: 2,
      votes: ScheduleVotesModel(
        accepted: [],
        declined: [],
        until: Date().addingTimeInterval(1800)
      ),
      startAt: startAt
    )
  }

  @Test("onAppear 시 멤버가 비어 있으면 로딩 후 멤버를 채운다")
  func onAppear_loadsMembersWhenEmpty() async {
    let members = [
      makeMember(userId: "host-user", name: "호스트"),
      makeMember(userId: "member-1", name: "멤버1")
    ]

    let store = TestStore(
      initialState: ManageGroup.Feature.State(
        group: makeGroup(),
        summary: nil,
        currentUserId: "host-user",
        schedules: [makeSchedule()]
      )
    ) {
      ManageGroup.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupMembers = { _ in members }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal) {
      $0.membersState = .loading
    }
    await store.receive(\.internal) {
      $0.membersState = .loaded(members)
      $0.members = members
    }
  }

  @Test("onAppear 시 preloaded 멤버가 있으면 로딩 표시 없이 백그라운드 갱신한다")
  func onAppear_refreshesMembersWhenPreloaded() async {
    let preloaded = [makeMember(userId: "member-1", name: "예전 멤버")]
    let refreshed = [
      makeMember(userId: "host-user", name: "호스트"),
      makeMember(userId: "member-1", name: "새 멤버")
    ]

    let store = TestStore(
      initialState: ManageGroup.Feature.State(
        group: makeGroup(),
        summary: nil,
        currentUserId: "host-user",
        preloadedMembers: preloaded,
        schedules: []
      )
    ) {
      ManageGroup.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupMembers = { _ in refreshed }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal)
    await store.receive(\.internal) {
      $0.membersState = .loaded(refreshed)
      $0.members = refreshed
    }
  }

  @Test("confirmLeave 성공 시 groupLeft delegate를 보낸다")
  func confirmLeave_success_sendsDelegate() async {
    let leftGroupID = LockIsolated<String?>(nil)

    let store = TestStore(
      initialState: ManageGroup.Feature.State(
        group: makeGroup(),
        summary: nil,
        currentUserId: "member-1",
        schedules: []
      )
    ) {
      ManageGroup.Feature()
    } withDependencies: {
      $0.groupClient.leaveGroup = { groupID in
        leftGroupID.setValue(groupID)
      }
    }

    await store.send(.view(.confirmLeave)) {
      $0.isLeavingGroup = true
      $0.leaveError = nil
    }
    await store.receive(\.internal) {
      $0.isLeavingGroup = false
    }
    await store.receive(\.delegate)

    #expect(leftGroupID.value == "group-1")
  }

  @Test("confirmDelete 실패 시 deleteError를 설정한다")
  func confirmDelete_failure_setsError() async {
    let store = TestStore(
      initialState: ManageGroup.Feature.State(
        group: makeGroup(),
        summary: nil,
        currentUserId: "host-user",
        schedules: []
      )
    ) {
      ManageGroup.Feature()
    } withDependencies: {
      $0.groupClient.deleteGroup = { _ in
        throw GroupClientError.serverError
      }
    }

    await store.send(.view(.confirmDelete)) {
      $0.isDeletingGroup = true
      $0.deleteError = nil
    }
    await store.receive(\.internal) {
      $0.isDeletingGroup = false
      $0.deleteError = GroupClientError.serverError.localizedMessage
    }
  }

  @Test("confirmTransferHost 성공 시 상태를 정리하고 hostTransferred delegate를 보낸다")
  func confirmTransferHost_success_sendsDelegate() async {
    let transferred = LockIsolated<(String, String)?>(nil)
    let newHost = makeMember(userId: "member-1", name: "멤버1")

    var state = ManageGroup.Feature.State(
      group: makeGroup(),
      summary: nil,
      currentUserId: "host-user",
      schedules: []
    )
    state.isShowingTransferSheet = true
    state.selectedNewHost = newHost

    let store = TestStore(initialState: state) {
      ManageGroup.Feature()
    } withDependencies: {
      $0.groupClient.transferHost = { groupID, newHostID in
        transferred.setValue((groupID, newHostID))
      }
    }

    await store.send(.view(.confirmTransferHost)) {
      $0.isTransferringHost = true
      $0.transferError = nil
    }
    await store.receive(\.internal) {
      $0.isTransferringHost = false
      $0.isShowingTransferSheet = false
      $0.selectedNewHost = nil
    }
    await store.receive(\.delegate)

    #expect(transferred.value?.0 == "group-1")
    #expect(transferred.value?.1 == "member-1")
  }

  @Test("dismissError 시 leave/delete/transfer 에러를 모두 초기화한다")
  func dismissError_clearsErrors() async {
    var state = ManageGroup.Feature.State(
      group: makeGroup(),
      summary: nil,
      currentUserId: "host-user",
      schedules: []
    )
    state.leaveError = "leave"
    state.deleteError = "delete"
    state.transferError = "transfer"

    let store = TestStore(initialState: state) {
      ManageGroup.Feature()
    }

    await store.send(.view(.dismissError)) {
      $0.leaveError = nil
      $0.deleteError = nil
      $0.transferError = nil
    }
  }
}
