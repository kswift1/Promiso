//
//  PersonalFeatureTests.swift
//  PersonalFeature
//
//  Personal.Feature 테스트
//
//  ## 테스트 대상
//  - `PersonalFeature/Sources/PersonalFeature.swift`
//
//  ## 테스트 목적
//  - Reducer 액션 처리 검증
//  - 딥링크를 통한 개인 일정 상세 열기 검증
//

import Testing
import ComposableArchitecture
import Clients
import CreatePromiseFeature
import SharedFeature
@testable import PersonalFeature

@Suite("Personal.Feature 테스트")
@MainActor
struct PersonalFeatureTests {

  @Test("eventTapped 시 eventDetail 표시")
  func eventTapped_presentsEventDetail() async {
    let event = makeEvent(id: "event-1", title: "테스트 일정")
    let store = makeStore(key: "event-tapped")

    await store.send(.view(.eventTapped(event))) {
      $0.eventDetail = PersonalEventDetail.Feature.State(event: event)
    }
  }

  @Test("openEventFromDeeplink 시 이벤트 조회 후 eventDetail 표시")
  func openEventFromDeeplink_fetchesAndPresentsDetail() async {
    let event = makeEvent(id: "deeplink-event", title: "딥링크 일정")
    let store = makeStore(key: "deeplink-event") {
      $0.personalEventClient.getEvent = { eventId in
        #expect(eventId == "deeplink-event")
        return event
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.openEventFromDeeplink(eventId: "deeplink-event")))
    await store.receive(\.view) {
      $0.eventDetail = PersonalEventDetail.Feature.State(event: event)
    }
  }

  @Test("openEventFromDeeplink 시 이벤트 없으면 eventDetail nil 유지")
  func openEventFromDeeplink_eventNotFound_doesNothing() async {
    let store = makeStore(key: "deeplink-not-found") {
      $0.personalEventClient.getEvent = { _ in nil }
    }

    await store.send(.view(.openEventFromDeeplink(eventId: "nonexistent")))
    #expect(store.state.eventDetail == nil)
  }

  @Test("filterChanged 시 selectedFilter 업데이트")
  func filterChanged_updatesFilter() async {
    let store = makeStore(key: "filter-changed")

    await store.send(.view(.filterChanged(.future))) {
      $0.selectedFilter = .future
    }
  }

  @Test("createNewEventTapped 시 createEvent 표시")
  func createNewEventTapped_presentsCreateEvent() async {
    let store = makeStore(key: "create-event")
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.createNewEventTapped))
    #expect(store.state.createEvent != nil)
  }
}

// MARK: - Helpers

extension PersonalFeatureTests {
  func makeStore(
    key: String,
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<PersonalMode.Feature> {
    @Shared(.inMemory("personal-test-\(key)")) var currentUser = UserPrivateModel(
      userId: "test-user",
      name: "테스트",
      nickname: "테스트유저",
      email: "test@example.com",
      provider: "apple",
      metadata: .init()
    )
    return TestStore(
      initialState: PersonalMode.Feature.State(currentUser: $currentUser)
    ) {
      PersonalMode.Feature()
    } withDependencies: {
      $0.personalEventClient.subscribeToActiveEvents = { _ in
        AsyncStream { _ in }
      }
      $0.personalEventClient.getEvent = { _ in nil }
      $0.localNotificationClient.pendingIds = { [] }
      $0.calendarSyncClient.syncPersonalEvents = { _ in CalendarSyncResult() }
      configure(&$0)
    }
  }

  func makeEvent(
    id: String = "event-1",
    title: String = "테스트 일정"
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: id,
      title: title,
      emoji: "📅",
      startAt: Date().addingTimeInterval(3600),
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}
