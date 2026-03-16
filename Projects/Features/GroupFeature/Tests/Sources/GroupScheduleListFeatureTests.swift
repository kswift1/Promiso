import Testing
@testable import GroupFeature

@Suite("GroupScheduleList.Feature reducer 테스트")
@MainActor
struct GroupScheduleListFeatureTests {

  private func makeGroup(
    id: String = "group-1"
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: "테스트 그룹",
      memberIds: ["current-user", "member-1", "member-2"],
      maxMembers: 10,
      inviteCode: "TEST01",
      createdBy: "host-user"
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
    accepted: [String] = [],
    declined: [String] = [],
    startAt: Date = Date().addingTimeInterval(3600)
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: "일정 \(id)",
      hostId: "host-user",
      groupId: "group-1",
      minimumParticipants: 2,
      votes: ScheduleVotesModel(
        accepted: accepted,
        declined: declined,
        until: Date().addingTimeInterval(1800)
      ),
      startAt: startAt
    )
  }

  private func makeCalendarSchedule(
    id: String = "schedule-1",
    groupId: String = "group-1"
  ) -> CalendarSyncSchedule {
    CalendarSyncSchedule(
      id: id,
      title: "확정 일정",
      emoji: "📅",
      startAt: Date().addingTimeInterval(3600),
      endAt: Date().addingTimeInterval(7200),
      location: "서울",
      groupId: groupId
    )
  }

  @Test("filterChanged 시 selectedFilter를 갱신한다")
  func filterChanged_updatesSelectedFilter() async {
    let store = TestStore(
      initialState: GroupScheduleList.Feature.State(
        group: makeGroup(),
        schedules: [makeSchedule()],
        currentUserId: "current-user",
        groupMembers: nil
      )
    ) {
      GroupScheduleList.Feature()
    }

    await store.send(.view(.filterChanged(.confirmed))) {
      $0.selectedFilter = .confirmed
    }
  }

  @Test("scheduleTapped 시 scheduleSelected delegate를 보낸다")
  func scheduleTapped_sendsDelegate() async {
    let schedule = makeSchedule()
    let store = TestStore(
      initialState: GroupScheduleList.Feature.State(
        group: makeGroup(),
        schedules: [schedule],
        currentUserId: "current-user",
        groupMembers: nil
      )
    ) {
      GroupScheduleList.Feature()
    }

    await store.send(.view(.scheduleTapped(schedule)))
    await store.receive(\.delegate)
  }

  @Test("acceptTapped 성공 시 응답 상태를 갱신하고 확정 일정이면 캘린더에 추가한다")
  func acceptTapped_confirmed_addsCalendarSchedule() async {
    let addedSchedule = LockIsolated<CalendarSyncSchedule?>(nil)
    let calendarSyncEnabled = LockIsolated<Bool?>(nil)
    let schedule = makeSchedule(accepted: [], declined: ["current-user"])
    let confirmedSchedule = makeCalendarSchedule()
    let members = [
      makeMember(userId: "current-user", name: "나"),
      makeMember(userId: "member-1", name: "멤버1"),
      makeMember(userId: "member-2", name: "멤버2")
    ]

    var state = GroupScheduleList.Feature.State(
      group: makeGroup(),
      schedules: [schedule],
      currentUserId: "current-user",
      groupMembers: members
    )
    state.$groupCalendarSyncCache.withLock { $0 = ["group-1": false] }

    let store = TestStore(initialState: state) {
      GroupScheduleList.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(
          scheduleId: schedule.id,
          status: "accepted",
          isConfirmed: true,
          confirmedSchedule: confirmedSchedule
        )
      }
      $0.calendarSyncClient.addSchedule = { schedule, enabled in
        addedSchedule.setValue(schedule)
        calendarSyncEnabled.setValue(enabled)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.acceptTapped(schedule))) {
      $0.respondingStates[schedule.id] = .accepting
    }
    await store.receive(\.view) {
      $0.respondingStates[schedule.id] = nil
      $0.schedules[0].votes = ScheduleVotesModel(
        accepted: ["current-user"],
        declined: [],
        until: schedule.votes.until
      )
    }
    await store.finish()

    #expect(addedSchedule.value == confirmedSchedule)
    #expect(calendarSyncEnabled.value == false)
  }

  @Test("rejectTapped 성공 시 응답 상태를 갱신하고 캘린더에서 제거한다")
  func rejectTapped_success_removesCalendarSchedule() async {
    let removedScheduleID = LockIsolated<String?>(nil)
    let schedule = makeSchedule(accepted: ["current-user"], declined: [])

    let store = TestStore(
      initialState: GroupScheduleList.Feature.State(
        group: makeGroup(),
        schedules: [schedule],
        currentUserId: "current-user",
        groupMembers: nil
      )
    ) {
      GroupScheduleList.Feature()
    } withDependencies: {
      $0.scheduleClient.respondSchedule = { _, _ in
        RespondScheduleResult(
          scheduleId: schedule.id,
          status: "declined",
          isConfirmed: false,
          confirmedSchedule: nil
        )
      }
      $0.calendarSyncClient.removeSchedule = { scheduleID in
        removedScheduleID.setValue(scheduleID)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.rejectTapped(schedule))) {
      $0.respondingStates[schedule.id] = .rejecting
    }
    await store.receive(\.view) {
      $0.respondingStates[schedule.id] = nil
      $0.schedules[0].votes = ScheduleVotesModel(
        accepted: [],
        declined: ["current-user"],
        until: schedule.votes.until
      )
    }
    await store.finish()

    #expect(removedScheduleID.value == schedule.id)
  }

  @Test("이미 응답 중인 일정에 acceptTapped 하면 무시한다")
  func acceptTapped_whileResponding_isIgnored() async {
    let schedule = makeSchedule()
    var state = GroupScheduleList.Feature.State(
      group: makeGroup(),
      schedules: [schedule],
      currentUserId: "current-user",
      groupMembers: nil
    )
    state.respondingStates[schedule.id] = .rejecting

    let store = TestStore(initialState: state) {
      GroupScheduleList.Feature()
    }

    await store.send(.view(.acceptTapped(schedule)))
  }
}
