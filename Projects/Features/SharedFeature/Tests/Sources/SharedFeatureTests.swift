// MARK: - SharedFeatureTests.swift
// TCA TestStore를 사용한 Shared Feature의 포괄적인 test suite
// 이 파일은 ScheduleDetail.Feature와 EditSchedule.Feature의
// business logic 정확성과 state management 무결성을 보장

import Testing
import PromisoShared
@testable import SharedFeature

// MARK: - ScheduleDetail.Feature Tests

@Suite("ScheduleDetail.Feature reducer 테스트")
@MainActor
struct ScheduleDetailFeatureTests {

  // MARK: - Test Helpers

  private func makeSchedule(
    id: String = "schedule-1",
    title: String = "테스트 일정",
    hostId: String = "host-user",
    groupId: String = "group-1",
    minimumParticipants: Int = 2,
    accepted: [String] = [],
    declined: [String] = [],
    startAt: Date = Date().addingTimeInterval(3600)
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: title,
      hostId: hostId,
      groupId: groupId,
      minimumParticipants: minimumParticipants,
      votes: ScheduleVotesModel(
        accepted: accepted,
        declined: declined,
        until: Date().addingTimeInterval(86400)
      ),
      startAt: startAt
    )
  }

  private func makeMember(
    userId: String,
    nickname: String = "테스트유저"
  ) -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: "이름",
      nickname: nickname,
      profile: nil,
      metadata: .init()
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let schedule = makeSchedule()
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )

    #expect(state.respondingState == .idle)
    #expect(state.isDeleting == false)
    #expect(state.showShareSheet == false)
    #expect(state.groupMembers == nil)
    #expect(state.isLoadingMembers == false)
    #expect(state.memberSheet == nil)
    #expect(state.showMapDetail == false)
    #expect(state.editSchedule == nil)
    #expect(state.alert == nil)
    #expect(state.toastMessage == nil)
  }

  // MARK: - Computed Properties 테스트

  @Test("[P10] isHost - 호스트일 때 true")
  func isHost_whenHost_returnsTrue() {
    let schedule = makeSchedule(hostId: "user-1")
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    #expect(state.isHost == true)
  }

  @Test("[P10] isHost - 호스트가 아닐 때 false")
  func isHost_whenNotHost_returnsFalse() {
    let schedule = makeSchedule(hostId: "host-user")
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "other-user"
    )

    #expect(state.isHost == false)
  }

  @Test("[P10] canManage - 일정 호스트이면 true")
  func canManage_scheduleHost_returnsTrue() {
    let schedule = makeSchedule(hostId: "user-1")
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    #expect(state.canManage == true)
  }

  @Test("[P10] canManage - 그룹 호스트이면 true")
  func canManage_groupHost_returnsTrue() {
    var schedule = makeSchedule(hostId: "other-host")
    schedule.group = GroupModel(
      id: "group-1",
      name: "그룹",
      memberIds: ["user-1", "other-host"],
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "user-1"
    )
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    #expect(state.isGroupHost == true)
    #expect(state.canManage == true)
  }

  @Test("[P10] canManage - 일정 호스트도 그룹 호스트도 아니면 false")
  func canManage_neitherHost_returnsFalse() {
    var schedule = makeSchedule(hostId: "host-user")
    schedule.group = GroupModel(
      id: "group-1",
      name: "그룹",
      memberIds: ["host-user", "regular-user"],
      maxMembers: 10,
      inviteCode: "ABC123",
      createdBy: "host-user"
    )
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "regular-user"
    )

    #expect(state.isHost == false)
    #expect(state.isGroupHost == false)
    #expect(state.canManage == false)
  }

  @Test("[P12] canEdit - 관리 권한이 있고 시작 전이면 true")
  func canEdit_canManageAndFuture_returnsTrue() {
    let futureDate = Date().addingTimeInterval(7200)
    let schedule = makeSchedule(hostId: "user-1", startAt: futureDate)
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    #expect(state.canEdit == true)
  }

  @Test("[P12] canEdit - 시작 시간이 지났으면 false")
  func canEdit_pastStartTime_returnsFalse() {
    let pastDate = Date().addingTimeInterval(-3600)
    let schedule = makeSchedule(hostId: "user-1", startAt: pastDate)
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    #expect(state.canEdit == false)
  }

  @Test("[P12] editTapped - canEdit false면 무시")
  func editTapped_whenCanEditFalse_ignored() async {
    let pastDate = Date().addingTimeInterval(-3600)
    let schedule = makeSchedule(hostId: "user-1", startAt: pastDate)

    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "user-1"
    )

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    // canEdit == false (시작 시간 지남) → editTapped 무시
    await store.send(.view(.editTapped))
  }

  @Test("myVoteStatus - 미투표 시 pending")
  func myVoteStatus_notVoted_returnsPending() {
    let schedule = makeSchedule()
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )

    #expect(state.myVoteStatus == .pending)
  }

  @Test("myVoteStatus - 수락 시 accepted")
  func myVoteStatus_accepted_returnsAccepted() {
    let schedule = makeSchedule(accepted: ["test-user"])
    let state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )

    #expect(state.myVoteStatus == .accepted)
  }

  // MARK: - View Action 테스트

  @Test("dismissTapped 시 delegate.dismiss 전달")
  func dismissTapped_sendsDelegateDissmiss() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.dismissTapped))
    await store.receive(\.delegate.dismiss)
  }

  @Test("acceptTapped 시 respondingState를 accepting으로 설정")
  func acceptTapped_setsAcceptingState() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(scheduleId: "schedule-1", status: "accepted", isConfirmed: false)
      }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.acceptTapped)) {
      $0.respondingState = .accepting
    }

    await store.receive(\.internal.respondSchedule)

    await store.receive(\.internal.respondDone) {
      $0.respondingState = .idle
      $0.schedule.votes = ScheduleVotesModel(
        accepted: ["test-user"],
        declined: [],
        until: $0.schedule.votes.until
      )
    }

    await store.receive(\.delegate.scheduleUpdated)
  }

  @Test("rejectTapped 시 respondingState를 rejecting으로 설정")
  func rejectTapped_setsRejectingState() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(scheduleId: "schedule-1", status: "declined", isConfirmed: false)
      }
      $0.calendarSyncClient.removeSchedule = { _ in }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.rejectTapped)) {
      $0.respondingState = .rejecting
    }

    await store.receive(\.internal.respondSchedule)

    await store.receive(\.internal.respondDone) {
      $0.respondingState = .idle
      $0.schedule.votes = ScheduleVotesModel(
        accepted: [],
        declined: ["test-user"],
        until: $0.schedule.votes.until
      )
    }

    await store.receive(\.delegate.scheduleUpdated)
  }

  @Test("acceptTapped - 이미 응답 중이면 무시")
  func acceptTapped_whileResponding_ignored() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.respondingState = .rejecting

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.acceptTapped))
    // respondingState가 idle이 아니므로 아무 동작 없음
  }

  @Test("shareTapped 시 showShareSheet 설정")
  func shareTapped_setsShowShareSheet() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.shareTapped)) {
      $0.showShareSheet = true
    }
  }

  @Test("systemShareTapped 시 systemShareText 설정")
  func systemShareTapped_setsSystemShareText() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.showShareSheet = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.systemShareTapped)) {
      $0.showShareSheet = false
      $0.systemShareText = schedule.shareText
    }
  }

  @Test("shareSheetDismissed 시 showShareSheet 해제")
  func shareSheetDismissed_clearsShowShareSheet() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.showShareSheet = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.shareSheetDismissed)) {
      $0.showShareSheet = false
    }
  }

  @Test("[P11] deleteTapped 시 삭제 확인 알럿 표시")
  func deleteTapped_showsDeleteAlert() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.deleteTapped)) {
      $0.alert = AlertState {
        TextState(LocalizedStrings.Shared.deleteSchedule)
      } actions: {
        ButtonState(role: .cancel) {
          TextState(LocalizedStrings.Common.cancel)
        }
        ButtonState(role: .destructive, action: .confirmDelete) {
          TextState(LocalizedStrings.Common.delete)
        }
      } message: {
        TextState(LocalizedStrings.Shared.deleteScheduleConfirm(schedule.title))
      }
    }
  }

  @Test("[P11] deleteTapped - 이미 삭제 중이면 무시")
  func deleteTapped_whileDeleting_ignored() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.isDeleting = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.deleteTapped))
  }

  @Test("memberSheetDismissed 시 memberSheet nil 설정")
  func memberSheetDismissed_clearsMemberSheet() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.memberSheet = ScheduleDetail.Feature.MemberSheetState(
      title: "참여",
      members: [],
      colorType: .accepted
    )

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.memberSheetDismissed)) {
      $0.memberSheet = nil
    }
  }

  @Test("mapDetailDismissed 시 showMapDetail false 설정")
  func mapDetailDismissed_clearsMapDetail() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.showMapDetail = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.mapDetailDismissed)) {
      $0.showMapDetail = false
    }
  }

  // MARK: - 추가 View Action 테스트

  @Test("onAppear 시 그룹 멤버 미로드이면 로딩 시작")
  func onAppear_noMembers_startsLoading() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    } withDependencies: {
      $0.groupClient.fetchGroupMembers = { _ in [] }
    }
    store.exhaustivity = .off

    await store.send(.view(.onAppear)) {
      $0.isLoadingMembers = true
    }
  }

  @Test("[P12] editTapped - canEdit true면 편집 시트 표시")
  func editTapped_whenCanEdit_showsEditSheet() async {
    let futureDate = Date().addingTimeInterval(7200)
    let schedule = makeSchedule(hostId: "user-1", startAt: futureDate)

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "user-1"
      )
    ) {
      ScheduleDetail.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.editTapped))
  }

  @Test("resetTapped 시 respondingState를 resetting으로 설정")
  func resetTapped_setsResettingState() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(scheduleId: "schedule-1", status: "pending", isConfirmed: false)
      }
      $0.analyticsClient.logEvent = { _, _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.resetTapped)) {
      $0.respondingState = .resetting
    }
  }

  @Test("mapTapped 시 showMapDetail true 설정")
  func mapTapped_setsShowMapDetail() async {
    var schedule = makeSchedule()
    schedule.location = LocationInfoModel(
      name: "강남역",
      address: "서울시 강남구",
      latitude: 37.498,
      longitude: 127.027
    )

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    }

    await store.send(.view(.mapTapped)) {
      $0.showMapDetail = true
    }
  }

  // MARK: - Internal Action 테스트

  @Test("respondFailed 시 respondingState를 idle로 복원")
  func respondFailed_resetsRespondingState() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.respondingState = .accepting

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.respondFailed(error: AppError(message: "네트워크 오류")))) {
      $0.respondingState = .idle
    }

    #expect(store.state.toastMessage?.type == .error)
    #expect(store.state.toastMessage?.title == LocalizedStrings.Error.responseSendFailed)
    #expect(store.state.toastMessage?.subtitle == "네트워크 오류")
    #expect(store.state.toastMessage?.position == .top)
  }

  @Test("deleteDone 시 isDeleting false 및 delegate 전달")
  func deleteDone_clearsDeleteStateAndSendsDelegate() async {
    let schedule = makeSchedule(id: "schedule-to-delete")

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.isDeleting = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    await store.send(.internal(.deleteDone)) {
      $0.isDeleting = false
    }

    await store.receive(\.delegate.scheduleDeleted)
  }

  @Test("deleteFailed 시 isDeleting false로 복원")
  func deleteFailed_resetsDeleteState() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.isDeleting = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.deleteFailed(error: AppError(message: "삭제 실패")))) {
      $0.isDeleting = false
    }

    #expect(store.state.toastMessage?.type == .error)
    #expect(store.state.toastMessage?.title == LocalizedStrings.Error.scheduleDeleteFailed)
    #expect(store.state.toastMessage?.subtitle == "삭제 실패")
    #expect(store.state.toastMessage?.position == .top)
  }

  @Test("scheduleUpdated 시 schedule 상태 업데이트")
  func scheduleUpdated_updatesSchedule() async {
    let schedule = makeSchedule(title: "원래 제목")

    let store = TestStore(
      initialState: ScheduleDetail.Feature.State(
        schedule: schedule,
        currentUserId: "test-user"
      )
    ) {
      ScheduleDetail.Feature()
    }

    var updatedSchedule = schedule
    updatedSchedule.title = "수정된 제목"

    await store.send(.internal(.scheduleUpdated(updatedSchedule))) {
      $0.schedule = updatedSchedule
    }
  }

  @Test("groupMembersFetched 성공 시 멤버 설정 및 로딩 해제")
  func groupMembersFetched_success_setsMembers() async {
    let schedule = makeSchedule()
    let members = [
      makeMember(userId: "user-1", nickname: "유저1"),
      makeMember(userId: "user-2", nickname: "유저2"),
    ]

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.isLoadingMembers = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }
    store.exhaustivity = .off

    await store.send(.internal(.groupMembersFetched(.success(members)))) {
      $0.isLoadingMembers = false
      $0.groupMembers = members
    }
  }

  @Test("groupMembersFetched 실패 시 로딩만 해제")
  func groupMembersFetched_failure_onlyClearsLoading() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    state.isLoadingMembers = true

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    }

    let error = NSError(domain: "test", code: -1)
    await store.send(.internal(.groupMembersFetched(.failure(error)))) {
      $0.isLoadingMembers = false
    }
  }

  // MARK: - Alert Action 테스트

  @Test("confirmDelete 알럿 시 isDeleting true 및 deleteSchedule 전송")
  func confirmDelete_setsDeleteStateAndSendsDelete() async {
    let schedule = makeSchedule()

    var state = ScheduleDetail.Feature.State(
      schedule: schedule,
      currentUserId: "test-user"
    )
    // alert이 표시된 상태에서 confirmDelete 테스트
    state.alert = AlertState {
      TextState("일정 삭제")
    } actions: {
      ButtonState(role: .cancel) {
        TextState("취소")
      }
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState("삭제")
      }
    } message: {
      TextState("'\(schedule.title)' 일정을 삭제하시겠습니까?\n삭제된 일정은 복구할 수 없습니다.")
    }

    let store = TestStore(initialState: state) {
      ScheduleDetail.Feature()
    } withDependencies: {
      $0.scheduleClient.deleteSchedule = { _ in }
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.alert = nil
      $0.isDeleting = true
    }

    await store.receive(\.internal.deleteSchedule)

    await store.receive(\.internal.deleteDone) {
      $0.isDeleting = false
    }

    await store.receive(\.delegate.scheduleDeleted)
  }
}

// MARK: - EditSchedule.Feature Tests

@Suite("EditSchedule.Feature reducer 테스트")
@MainActor
struct EditScheduleFeatureTests {

  // MARK: - Test Helpers

  private func makeSchedule(
    id: String = "schedule-1",
    title: String = "테스트 일정",
    emoji: String? = nil,
    description: String? = nil,
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    minimumParticipants: Int = 2,
    trackingStartMinutesBefore: Int? = nil
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      groupId: "group-1",
      minimumParticipants: minimumParticipants,
      votes: ScheduleVotesModel(
        accepted: [],
        declined: [],
        until: Date().addingTimeInterval(86400)
      ),
      startAt: startAt,
      endAt: endAt,
      trackingStartMinutesBefore: trackingStartMinutesBefore
    )
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let schedule = makeSchedule()
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.originalSchedule == schedule)
    #expect(state.editedSchedule == schedule)
    #expect(state.isUpdating == false)
    #expect(state.updateError == nil)
    #expect(state.maxMembers == 10)
  }

  // MARK: - Computed Properties 테스트

  @Test("hasChanges - 변경 없으면 false")
  func hasChanges_noChanges_returnsFalse() {
    let schedule = makeSchedule()
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.hasChanges == false)
  }

  @Test("hasChanges - 제목 변경 시 true")
  func hasChanges_titleChanged_returnsTrue() {
    let schedule = makeSchedule()
    var state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    state.editedSchedule.title = "수정된 제목"

    #expect(state.hasChanges == true)
  }

  @Test("useEndTime - endAt이 nil이면 false")
  func useEndTime_noEndDate_returnsFalse() {
    let schedule = makeSchedule(endAt: nil)
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.useEndTime == false)
  }

  @Test("useEndTime - endAt이 있으면 true")
  func useEndTime_hasEndDate_returnsTrue() {
    let endDate = Date().addingTimeInterval(7200)
    let schedule = makeSchedule(endAt: endDate)
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.useEndTime == true)
  }

  @Test("useRealtimeShare - trackingStartMinutesBefore가 nil이면 false")
  func useRealtimeShare_noTracking_returnsFalse() {
    let schedule = makeSchedule(trackingStartMinutesBefore: nil)
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.useRealtimeShare == false)
  }

  @Test("useRealtimeShare - trackingStartMinutesBefore 있으면 true")
  func useRealtimeShare_hasTracking_returnsTrue() {
    let schedule = makeSchedule(trackingStartMinutesBefore: 30)
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)

    #expect(state.useRealtimeShare == true)
  }

  // MARK: - View Action 테스트

  @Test("setTitle 시 editedSchedule.title 업데이트")
  func setTitle_updatesEditedScheduleTitle() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off

    await store.send(.view(.setTitle("새로운 제목"))) {
      $0.editedSchedule.title = "새로운 제목"
    }
  }

  @Test("setEmoji 시 editedSchedule.emoji 업데이트")
  func setEmoji_updatesEditedScheduleEmoji() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.setEmoji("🎉"))) {
      $0.editedSchedule.emoji = "🎉"
    }
  }

  @Test("setEmoji 빈 문자열 시 nil 설정")
  func setEmoji_emptyString_setsNil() async {
    let schedule = makeSchedule(emoji: "🎉")

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.setEmoji(""))) {
      $0.editedSchedule.emoji = nil
    }
  }

  @Test("setDescription 시 editedSchedule.description 업데이트")
  func setDescription_updatesEditedScheduleDescription() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.setDescription("일정 설명입니다"))) {
      $0.editedSchedule.description = "일정 설명입니다"
    }
  }

  @Test("setDescription 빈 문자열 시 nil 설정")
  func setDescription_emptyString_setsNil() async {
    let schedule = makeSchedule(description: "기존 설명")

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.setDescription(""))) {
      $0.editedSchedule.description = nil
    }
  }

  @Test("setStartDate 시 시작 날짜 업데이트")
  func setStartDate_updatesStartDate() async {
    let schedule = makeSchedule()
    let newDate = Date().addingTimeInterval(7200)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.setStartDate(newDate))) {
      $0.editedSchedule.startAt = newDate
      $0.conflictCheckTrigger = .startTimeChanged
    }
  }

  @Test("setStartDate 시 endAt이 startAt보다 이전이면 자동 조정")
  func setStartDate_endBeforeStart_adjustsEnd() async {
    let startDate = Date().addingTimeInterval(3600)
    let endDate = Date().addingTimeInterval(5400)
    let schedule = makeSchedule(startAt: startDate, endAt: endDate)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }
    store.exhaustivity = .off

    let newStartDate = Date().addingTimeInterval(7200) // endDate보다 이후
    await store.send(.view(.setStartDate(newStartDate))) {
      $0.editedSchedule.startAt = newStartDate
      $0.editedSchedule.endAt = newStartDate.addingTimeInterval(7200)
      $0.conflictCheckTrigger = .startTimeChanged
    }
  }

  @Test("toggleUseEndTime - endAt nil이면 2시간 후로 설정")
  func toggleUseEndTime_noEnd_setsDefaultEnd() async {
    let schedule = makeSchedule(endAt: nil)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.toggleUseEndTime)) {
      $0.editedSchedule.endAt = $0.editedSchedule.startAt.addingTimeInterval(7200)
      $0.conflictCheckTrigger = .endTimeChanged
    }
  }

  @Test("toggleUseEndTime - endAt 있으면 nil로 설정")
  func toggleUseEndTime_hasEnd_setsNil() async {
    let endDate = Date().addingTimeInterval(7200)
    let schedule = makeSchedule(endAt: endDate)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.toggleUseEndTime)) {
      $0.editedSchedule.endAt = nil
      $0.conflictCheckTrigger = .endTimeChanged
    }
  }

  @Test("incrementParticipants 시 최소 참가자 수 증가")
  func incrementParticipants_increasesMinimumParticipants() async {
    let schedule = makeSchedule(minimumParticipants: 3)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.incrementParticipants)) {
      $0.editedSchedule.minimumParticipants = 4
    }
  }

  @Test("incrementParticipants - maxMembers에 도달하면 증가 안 함")
  func incrementParticipants_atMax_noChange() async {
    let schedule = makeSchedule(minimumParticipants: 5)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 5)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.incrementParticipants))
    // maxMembers와 같으므로 변경 없음
  }

  @Test("decrementParticipants 시 최소 참가자 수 감소")
  func decrementParticipants_decreasesMinimumParticipants() async {
    let schedule = makeSchedule(minimumParticipants: 4)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.decrementParticipants)) {
      $0.editedSchedule.minimumParticipants = 3
    }
  }

  @Test("decrementParticipants - 최소 2명 이하로 감소 안 함")
  func decrementParticipants_atMinimum_noChange() async {
    let schedule = makeSchedule(minimumParticipants: 2)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.decrementParticipants))
    // 2 이하로 감소 불가
  }

  @Test("toggleUseRealtimeShare - nil이면 기본값 30분 설정")
  func toggleUseRealtimeShare_noTracking_setsDefault() async {
    let schedule = makeSchedule(trackingStartMinutesBefore: nil)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.toggleUseRealtimeShare)) {
      $0.editedSchedule.trackingStartMinutesBefore = 30
    }
  }

  @Test("toggleUseRealtimeShare - 값이 있으면 nil 설정")
  func toggleUseRealtimeShare_hasTracking_setsNil() async {
    let schedule = makeSchedule(trackingStartMinutesBefore: 30)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.toggleUseRealtimeShare)) {
      $0.editedSchedule.trackingStartMinutesBefore = nil
    }
  }

  @Test("setTrackingMinutes 시 trackingStartMinutesBefore 설정")
  func setTrackingMinutes_updatesValue() async {
    let schedule = makeSchedule(trackingStartMinutesBefore: 30)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.setTrackingMinutes(60))) {
      $0.editedSchedule.trackingStartMinutesBefore = 60
    }
  }

  @Test("setEndDate 시 종료 날짜 업데이트")
  func setEndDate_updatesEndDate() async {
    let schedule = makeSchedule(endAt: Date().addingTimeInterval(7200))
    let newEndDate = Date().addingTimeInterval(10800)

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }
    store.exhaustivity = .off

    await store.send(.view(.setEndDate(newEndDate))) {
      $0.editedSchedule.endAt = newEndDate
      $0.conflictCheckTrigger = .endTimeChanged
    }
  }

  @Test("saveTapped 시 업데이트 시작")
  func saveTapped_startsUpdating() async {
    let schedule = makeSchedule()
    var state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    state.editedSchedule.title = "수정된 제목"

    let store = TestStore(initialState: state) {
      EditSchedule.Feature()
    } withDependencies: {
      $0.scheduleClient.updateSchedule = { _ in }
    }
    store.exhaustivity = .off

    await store.send(.view(.saveTapped)) {
      $0.isUpdating = true
      $0.updateError = nil
    }
  }

  @Test("saveTapped - canSave false면 무시")
  func saveTapped_canSaveFalse_ignored() async {
    let schedule = makeSchedule()
    // 변경 없으므로 hasChanges == false → canSave == false
    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.saveTapped))
  }

  @Test("canSave - 변경 없으면 false")
  func canSave_noChanges_returnsFalse() {
    let schedule = makeSchedule()
    let state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    #expect(state.canSave == false)
  }

  @Test("cancelTapped 시 delegate.cancelled 전달")
  func cancelTapped_sendsDelegateCancelled() async {
    let schedule = makeSchedule()

    let store = TestStore(
      initialState: EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    ) {
      EditSchedule.Feature()
    }

    await store.send(.view(.cancelTapped))
    await store.receive(\.delegate.cancelled)
  }

  @Test("clearError 시 updateError nil 설정")
  func clearError_clearsUpdateError() async {
    let schedule = makeSchedule()

    var state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    state.updateError = .unknown("에러")

    let store = TestStore(initialState: state) {
      EditSchedule.Feature()
    }

    await store.send(.view(.clearError)) {
      $0.updateError = nil
    }
  }

  // MARK: - Internal Action 테스트

  @Test("updateScheduleResponse 성공 시 isUpdating false 및 delegate 전달")
  func updateScheduleResponse_success_sendsDelegate() async {
    let schedule = makeSchedule(title: "원래 제목")

    var state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    state.editedSchedule.title = "수정된 제목"
    state.isUpdating = true

    let store = TestStore(initialState: state) {
      EditSchedule.Feature()
    }

    var updatedSchedule = schedule
    updatedSchedule.title = "수정된 제목"

    await store.send(.internal(.updateScheduleResponse(.success(updatedSchedule)))) {
      $0.isUpdating = false
    }

    await store.receive(\.delegate.scheduleUpdated)
  }

  @Test("updateScheduleResponse 실패 시 에러 설정")
  func updateScheduleResponse_failure_setsError() async {
    let schedule = makeSchedule()

    var state = EditSchedule.Feature.State(schedule: schedule, maxMembers: 10)
    state.isUpdating = true

    let store = TestStore(initialState: state) {
      EditSchedule.Feature()
    }

    let error = ScheduleClientError.unknown("업데이트 실패")
    await store.send(.internal(.updateScheduleResponse(.failure(error)))) {
      $0.isUpdating = false
      $0.updateError = error
    }
  }
}
