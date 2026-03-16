import ComposableArchitecture
import Testing
@testable import CreateScheduleFeature
@testable import PromisoShared

@Suite("CreateRecurringPersonalEvent.Feature reducer 테스트")
@MainActor
struct CreateRecurringPersonalEventFeatureTests {

  private struct TestError: Error {}

  private struct ScheduledRepeatingNotification: Equatable {
    var id: String
    var title: String
    var body: String
    var components: DateComponents
    var userInfo: [String: String]
  }

  nonisolated private func makeEvent(
    title: String = "반복 운동",
    startTime: DateComponents = DateComponents(hour: 9, minute: 30),
    endTime: DateComponents? = nil,
    reminderMinutesBefore: Int? = nil,
    recurrence: RecurrenceRule = .weekly([2, 4]),
    seriesStartDate: Date = Date(timeIntervalSince1970: 1_710_000_000)
  ) -> RecurringPersonalEventModel {
    RecurringPersonalEventModel(
      id: "recurring-1",
      title: title,
      startTime: startTime,
      endTime: endTime,
      reminderMinutesBefore: reminderMinutesBefore,
      recurrence: recurrence,
      seriesStartDate: seriesStartDate
    )
  }

  nonisolated private func makeLocation(
    name: String = "강남역",
    address: String = "서울 강남구",
    latitude: Double = 37.4979,
    longitude: Double = 127.0276
  ) -> LocationInfoModel {
    LocationInfoModel(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude
    )
  }

  @Test("frequencyChanged 시 recurrence를 선택 주기에 맞게 재구성한다")
  func frequencyChanged_rebuildsRecurrence() async {
    let event = makeEvent()
    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event)
    ) {
      CreateRecurringPersonalEvent.Feature()
    }

    await store.send(.view(.frequencyChanged(.monthly))) {
      $0.selectedFrequency = .monthly
      $0.event.recurrence = .monthly(day: 1)
    }
  }

  @Test("weekdayToggled 시 마지막 요일은 유지한다")
  func weekdayToggled_lastWeekday_doesNothing() async {
    let event = makeEvent(recurrence: .weekly([2]))
    let selectionCount = LockIsolated(0)

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {
        selectionCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.weekdayToggled(2)))
    await store.finish()

    #expect(store.state.selectedWeekdays == Set([2]))
    #expect(store.state.event.recurrence == .weekly([2]))
    #expect(selectionCount.value == 0)
  }

  @Test("toggleUseEndTime 시 종료 시간이 없으면 1시간 뒤로 채운다")
  func toggleUseEndTime_setsDefaultEndTime() async {
    let selectionCount = LockIsolated(0)
    let event = makeEvent(startTime: DateComponents(hour: 9, minute: 30), endTime: nil)

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {
        selectionCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.toggleUseEndTime)) {
      $0.useEndTime = true
      $0.event.endTime = DateComponents(hour: 10, minute: 30)
    }
    await store.finish()

    #expect(selectionCount.value == 1)
  }

  @Test("toggleUseSeriesEndDate 시 기본 종료일을 3개월 뒤로 설정한다")
  func toggleUseSeriesEndDate_enablesDefaultEndDate() async {
    let selectionCount = LockIsolated(0)
    let seriesStartDate = Date(timeIntervalSince1970: 1_710_000_000)
    let event = makeEvent(seriesStartDate: seriesStartDate)
    let expectedEndDate = Calendar.current.date(
      byAdding: .month,
      value: 3,
      to: seriesStartDate
    ) ?? seriesStartDate

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {
        selectionCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.toggleUseSeriesEndDate)) {
      $0.useSeriesEndDate = true
      $0.event.recurrence = .weekly([2, 4], until: expectedEndDate)
    }
    await store.finish()

    #expect(selectionCount.value == 1)
  }

  @Test("toggleUseSeriesEndDate 해제 시 종료일 없이 recurrence를 다시 만든다")
  func toggleUseSeriesEndDate_disablesAndRebuildsRecurrence() async {
    let selectionCount = LockIsolated(0)
    let endDate = Date(timeIntervalSince1970: 1_720_000_000)
    let event = makeEvent(recurrence: .weekly([2, 4], until: endDate))

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {
        selectionCount.withValue { $0 += 1 }
      }
    }

    #expect(store.state.useSeriesEndDate == true)

    await store.send(.view(.toggleUseSeriesEndDate)) {
      $0.useSeriesEndDate = false
      $0.event.recurrence = .weekly(Array($0.selectedWeekdays))
    }
    await store.finish()

    #expect(selectionCount.value == 1)
    #expect(store.state.event.recurrence.frequency == .weekly)
    #expect(Set(store.state.event.recurrence.daysOfWeek ?? []) == Set([2, 4]))
    #expect(store.state.event.recurrence.seriesEndDate == nil)
  }

  @Test("saveTapped 생성 성공 시 반복 알림을 다시 예약하고 완료 delegate를 보낸다")
  func saveTapped_createWithReminder_schedulesNotifications() async {
    let createdEvent = LockIsolated<RecurringPersonalEventModel?>(nil)
    let cancelledIDs = LockIsolated<[String]>([])
    let scheduledNotifications = LockIsolated<[ScheduledRepeatingNotification]>([])
    let successCount = LockIsolated(0)

    let event = makeEvent(reminderMinutesBefore: 30, recurrence: .weekly([2, 4]))

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event, mode: .create)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.recurringPersonalEventClient.createEvent = { event in
        createdEvent.setValue(event)
        return "created-id"
      }
      $0.localNotificationClient.cancelAll = { ids in
        cancelledIDs.setValue(ids)
      }
      $0.localNotificationClient.scheduleRepeating = { id, title, body, components, userInfo in
        scheduledNotifications.withValue {
          $0.append(
            ScheduledRepeatingNotification(
              id: id,
              title: title,
              body: body,
              components: components,
              userInfo: userInfo
            )
          )
        }
      }
      $0.hapticFeedback.success = {
        successCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.saveTapped)) {
      $0.isSaving = true
      $0.errorMessage = nil
    }
    await store.receive(\.internal.saveSuccess) {
      $0.isSaving = false
    }
    await store.receive(\.delegate.eventCreated)
    await store.finish()

    #expect(createdEvent.value == event)
    #expect(successCount.value == 1)
    #expect(cancelledIDs.value.count == 9)
    #expect(cancelledIDs.value.contains("recurring-created-id-daily"))
    #expect(cancelledIDs.value.contains("recurring-created-id-monthly"))
    #expect(cancelledIDs.value.contains("recurring-created-id-weekly-2"))
    #expect(cancelledIDs.value.contains("recurring-created-id-weekly-4"))
    #expect(scheduledNotifications.value.map(\.id) == [
      "recurring-created-id-weekly-2",
      "recurring-created-id-weekly-4"
    ])
    #expect(scheduledNotifications.value.allSatisfy { $0.title == "🔄 반복 운동" })
    #expect(
      scheduledNotifications.value.allSatisfy {
        $0.body == LocalizedStrings.Personal.notificationStartsInMinutes(30)
      }
    )
    #expect(scheduledNotifications.value.map { $0.components.weekday } == [2 as Int?, 4 as Int?])
    #expect(scheduledNotifications.value.map { $0.components.hour } == [9 as Int?, 9 as Int?])
    #expect(scheduledNotifications.value.map { $0.components.minute } == [0 as Int?, 0 as Int?])
    #expect(
      scheduledNotifications.value.allSatisfy {
        $0.userInfo["recurringEventId"] == "created-id"
      }
    )
  }

  @Test("saveTapped 실패 시 에러를 저장하고 에러 햅틱을 보낸다")
  func saveTapped_failure_setsError() async {
    let errorCount = LockIsolated(0)
    let event = makeEvent()

    let store = TestStore(
      initialState: CreateRecurringPersonalEvent.Feature.State(event: event, mode: .create)
    ) {
      CreateRecurringPersonalEvent.Feature()
    } withDependencies: {
      $0.recurringPersonalEventClient.createEvent = { _ in
        throw TestError()
      }
      $0.hapticFeedback.error = {
        errorCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.saveTapped)) {
      $0.isSaving = true
      $0.errorMessage = nil
    }
    await store.receive(\.internal.saveFailed) {
      $0.isSaving = false
      $0.errorMessage = LocalizedStrings.Error.serverError
    }
    await store.finish()

    #expect(errorCount.value == 1)
  }

  @Test("locationPicker delegate 수신 시 위치를 반영하고 시트를 닫는다")
  func locationPickerLocationSelected_updatesEventLocation() async {
    let location = makeLocation()
    var state = CreateRecurringPersonalEvent.Feature.State(event: makeEvent())
    state.locationPicker = LocationPicker.Feature.State()

    let store = TestStore(initialState: state) {
      CreateRecurringPersonalEvent.Feature()
    }

    await store.send(.locationPicker(.presented(.delegate(.locationSelected(location))))) {
      $0.event.location = location
      $0.locationPicker = nil
    }
  }
}
