// MARK: - CreatePersonalEventReminderTests.swift
// CreatePersonalEvent 미리알림 시간 검증 테스트

import Testing
import PromisoShared
@testable import CreateScheduleFeature

// MARK: - CreatePersonalEvent 미리알림 검증 테스트

@Suite("CreatePersonalEvent 미리알림 시간 검증 테스트")
@MainActor
struct CreatePersonalEventReminderTests {

  // MARK: - Test Helpers

  private func makeEvent(
    startAt: Date = Date().addingTimeInterval(3600),
    reminderMinutesBefore: Int? = nil
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: "event-1",
      title: "테스트 일정",
      startAt: startAt,
      reminderMinutesBefore: reminderMinutesBefore
    )
  }

  // MARK: - reminderOptionSelected 검증

  @Test("미리알림 선택 - 시간 충분하면 pendingReminderMinutes 설정")
  func reminderOption_futureEnough_setsPending() async {
    let futureEvent = makeEvent(startAt: Date().addingTimeInterval(7200))
    let store = TestStore(
      initialState: CreatePersonalEvent.Feature.State(event: futureEvent)
    ) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.notificationClient.getAuthorizationStatus = { .authorized }
      $0.hapticFeedback.selection = {}
    }
    store.exhaustivity = .off

    await store.send(.view(.reminderOptionSelected(30))) {
      $0.reminderWarning = nil
      $0.pendingReminderMinutes = 30
    }
  }

  @Test("미리알림 선택 - 시간 부족하면 경고 표시 및 알림 차단")
  func reminderOption_notEnoughTime_showsWarning() async {
    let soonEvent = makeEvent(startAt: Date().addingTimeInterval(300))
    let store = TestStore(
      initialState: CreatePersonalEvent.Feature.State(event: soonEvent)
    ) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.error = {}
    }
    store.exhaustivity = .off

    await store.send(.view(.reminderOptionSelected(30))) {
      $0.reminderWarning = "일정 시작까지 남은 시간이 부족하여 알림을 설정할 수 없습니다"
      $0.event.reminderMinutesBefore = nil
      $0.pendingReminderMinutes = nil
    }
  }

  @Test("미리알림 '없음' 선택 시 경고 초기화")
  func reminderOption_none_clearsWarning() async {
    var event = makeEvent(startAt: Date().addingTimeInterval(300))
    event.reminderMinutesBefore = nil
    var state = CreatePersonalEvent.Feature.State(event: event)
    state.reminderWarning = "일정 시작까지 남은 시간이 부족하여 알림을 설정할 수 없습니다"

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }
    store.exhaustivity = .off

    await store.send(.view(.reminderOptionSelected(nil))) {
      $0.event.reminderMinutesBefore = nil
      $0.pendingReminderMinutes = nil
      $0.reminderWarning = nil
    }
  }

  // MARK: - startDateChanged 재검증

  @Test("시작일 변경 - 기존 알림이 더 이상 유효하지 않으면 경고 표시 및 해제")
  func startDateChanged_invalidatesReminder_showsWarning() async {
    let futureEvent = makeEvent(
      startAt: Date().addingTimeInterval(7200),
      reminderMinutesBefore: 60
    )
    let store = TestStore(
      initialState: CreatePersonalEvent.Feature.State(event: futureEvent)
    ) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    let newStartDate = Date().addingTimeInterval(600)
    await store.send(.view(.startDateChanged(newStartDate))) {
      $0.event.startAt = newStartDate
      $0.reminderWarning = "일정 시작까지 남은 시간이 부족하여 알림을 설정할 수 없습니다"
      $0.event.reminderMinutesBefore = nil
    }
  }

  @Test("시작일 변경 - 기존 알림이 여전히 유효하면 경고 없음")
  func startDateChanged_reminderStillValid_noWarning() async {
    let futureEvent = makeEvent(
      startAt: Date().addingTimeInterval(7200),
      reminderMinutesBefore: 30
    )
    let store = TestStore(
      initialState: CreatePersonalEvent.Feature.State(event: futureEvent)
    ) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    let newStartDate = Date().addingTimeInterval(10800)
    await store.send(.view(.startDateChanged(newStartDate))) {
      $0.event.startAt = newStartDate
      $0.reminderWarning = nil
    }
  }
}
