import ComposableArchitecture
import Testing
@testable import CreateScheduleFeature
@testable import PromisoShared

@Suite("RecurringPersonalEventDetail.Feature reducer 테스트")
@MainActor
struct RecurringPersonalEventDetailFeatureTests {

  private struct TestError: Error {}

  nonisolated private func makeRecurringEvent(
    id: String = "recurring-1",
    title: String = "반복 운동",
    reminderMinutesBefore: Int? = 10,
    recurrence: RecurrenceRule = .weekly([2, 4])
  ) -> RecurringPersonalEventModel {
    RecurringPersonalEventModel(
      id: id,
      title: title,
      startTime: DateComponents(hour: 19, minute: 0),
      endTime: DateComponents(hour: 20, minute: 0),
      reminderMinutesBefore: reminderMinutesBefore,
      recurrence: recurrence,
      seriesStartDate: Date(timeIntervalSince1970: 1_710_000_000)
    )
  }

  nonisolated private func makeInstance(
    recurringEventId: String = "recurring-1",
    dateKey: String = "2026-03-18"
  ) -> ExpandedEventInstance {
    ExpandedEventInstance(
      recurringEventId: recurringEventId,
      dateKey: dateKey,
      startAt: Date(timeIntervalSince1970: 1_710_000_000),
      endAt: Date(timeIntervalSince1970: 1_710_003_600),
      title: "반복 운동",
      emoji: nil,
      location: nil,
      reminderMinutesBefore: 10,
      isOverridden: false
    )
  }

  @Test("editTapped 시 반복 일정 편집 시트를 연다")
  func editTapped_presentsEditor() async {
    let event = makeRecurringEvent()
    let store = TestStore(
      initialState: RecurringPersonalEventDetail.Feature.State(recurringEvent: event)
    ) {
      RecurringPersonalEventDetail.Feature()
    }

    await store.send(.view(.editTapped)) {
      $0.editEvent = CreateRecurringPersonalEvent.Feature.State(
        event: event,
        mode: .edit
      )
    }
  }

  @Test("excludeInstanceTapped 시 선택 인스턴스를 제외하고 delegate를 보낸다")
  func excludeInstanceTapped_updatesExcludedDates() async {
    let updatedEvent = LockIsolated<RecurringPersonalEventModel?>(nil)
    let instance = makeInstance()
    let event = makeRecurringEvent()

    let store = TestStore(
      initialState: RecurringPersonalEventDetail.Feature.State(
        recurringEvent: event,
        selectedInstance: instance
      )
    ) {
      RecurringPersonalEventDetail.Feature()
    } withDependencies: {
      $0.recurringPersonalEventClient.updateEvent = { event in
        updatedEvent.setValue(event)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.excludeInstanceTapped))
    await store.receive(\.internal) {
      $0.recurringEvent.excludedDates.insert(instance.dateKey)
    }
    await store.receive(\.delegate)
    await store.finish()

    #expect(updatedEvent.value?.excludedDates == Set([instance.dateKey]))
  }

  @Test("confirmDeleteSeries 성공 시 반복 알림을 모두 취소하고 삭제 delegate를 보낸다")
  func confirmDeleteSeries_success_cancelsNotifications() async {
    let deletedEventID = LockIsolated<String?>(nil)
    let cancelledIDs = LockIsolated<[String]>([])
    let event = makeRecurringEvent(id: "recurring-77")

    let store = TestStore(
      initialState: RecurringPersonalEventDetail.Feature.State(recurringEvent: event)
    ) {
      RecurringPersonalEventDetail.Feature()
    } withDependencies: {
      $0.recurringPersonalEventClient.deleteEvent = { eventID in
        deletedEventID.setValue(eventID)
      }
      $0.localNotificationClient.cancelAll = { ids in
        cancelledIDs.setValue(ids)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.deleteTapped))
    #expect(store.state.deleteAlert != nil)
    await store.send(.alert(.presented(.confirmDeleteSeries))) {
      $0.isDeleting = true
    }
    await store.receive(\.internal) {
      $0.isDeleting = false
    }
    await store.receive(\.delegate)
    await store.finish()

    #expect(deletedEventID.value == "recurring-77")
    #expect(cancelledIDs.value.count == 9)
    #expect(cancelledIDs.value.contains("recurring-recurring-77-daily"))
    #expect(cancelledIDs.value.contains("recurring-recurring-77-monthly"))
    #expect(cancelledIDs.value.contains("recurring-recurring-77-weekly-1"))
    #expect(cancelledIDs.value.contains("recurring-recurring-77-weekly-7"))
  }

  @Test("confirmDeleteSeries 실패 시 deleting 상태를 복원한다")
  func confirmDeleteSeries_failure_restoresDeleting() async {
    let event = makeRecurringEvent()

    let store = TestStore(
      initialState: RecurringPersonalEventDetail.Feature.State(recurringEvent: event)
    ) {
      RecurringPersonalEventDetail.Feature()
    } withDependencies: {
      $0.recurringPersonalEventClient.deleteEvent = { _ in
        throw TestError()
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.deleteTapped))
    #expect(store.state.deleteAlert != nil)
    await store.send(.alert(.presented(.confirmDeleteSeries))) {
      $0.isDeleting = true
    }
    await store.receive(\.internal) {
      $0.isDeleting = false
    }
  }

  @Test("editEvent delegate.eventUpdated 수신 시 상태를 반영하고 delegate를 보낸다")
  func editEventDelegate_eventUpdated_updatesState() async {
    let event = makeRecurringEvent()
    var updated = event
    updated.title = "수정된 반복 운동"

    var state = RecurringPersonalEventDetail.Feature.State(recurringEvent: event)
    state.editEvent = CreateRecurringPersonalEvent.Feature.State(event: event, mode: .edit)

    let store = TestStore(initialState: state) {
      RecurringPersonalEventDetail.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.editEvent(.presented(.delegate(.eventUpdated(updated))))) {
      $0.recurringEvent = updated
      $0.editEvent = nil
    }
    await store.receive(\.delegate)
  }

  @Test("editEvent delegate.dismiss 수신 시 편집 시트를 닫는다")
  func editEventDelegate_dismiss_closesSheet() async {
    let event = makeRecurringEvent()
    var state = RecurringPersonalEventDetail.Feature.State(recurringEvent: event)
    state.editEvent = CreateRecurringPersonalEvent.Feature.State(event: event, mode: .edit)

    let store = TestStore(initialState: state) {
      RecurringPersonalEventDetail.Feature()
    }

    await store.send(.editEvent(.presented(.delegate(.dismiss)))) {
      $0.editEvent = nil
    }
  }
}
