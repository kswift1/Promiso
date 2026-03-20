import ComposableArchitecture
import Testing
@testable import CreateScheduleFeature
@testable import PromisoShared

@Suite("PersonalEventDetail.Feature reducer 테스트")
@MainActor
struct PersonalEventDetailFeatureTests {

  private struct TestError: Error {}

  nonisolated private func makeLocation(
    latitude: Double = 37.4979,
    longitude: Double = 127.0276
  ) -> LocationInfoModel {
    LocationInfoModel(
      name: "강남역",
      address: "서울 강남구",
      latitude: latitude,
      longitude: longitude
    )
  }

  nonisolated private func makeEvent(
    id: String = "event-1",
    title: String = "개인 일정",
    startAt: Date = Date().addingTimeInterval(24 * 3600),
    imageUrls: [String] = [],
    location: LocationInfoModel? = nil
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: id,
      title: title,
      startAt: startAt,
      location: location,
      imageUrls: imageUrls
    )
  }

  nonisolated private func makeWeatherInfo(
    fetchedAt: Date = Date()
  ) -> WeatherInfo {
    WeatherInfo(
      fetchedAt: fetchedAt,
      current: HourlyForecast(
        dateTime: fetchedAt,
        temperature: 22,
        feelsLikeTemperature: 21,
        condition: .clear,
        precipitationProbability: 10,
        humidity: 50,
        windSpeed: 2.0
      ),
      hourlyForecasts: [],
      dailyForecasts: []
    )
  }

  nonisolated private func makeDeleteAlert(
    eventTitle: String
  ) -> AlertState<PersonalEventDetail.Feature.Action.Alert> {
    AlertState {
      TextState(LocalizedStrings.Shared.deleteEvent)
    } actions: {
      ButtonState(role: .destructive, action: .confirmDelete) {
        TextState(LocalizedStrings.Common.delete)
      }
      ButtonState(role: .cancel) {
        TextState(LocalizedStrings.Common.cancel)
      }
    } message: {
      TextState(LocalizedStrings.Shared.deleteEventConfirm(eventTitle))
    }
  }

  @Test("onAppear 시 신선한 날씨 캐시를 사용하고 재조회하지 않는다")
  func onAppear_usesFreshCachedWeather() async {
    let fetchCount = LockIsolated(0)
    let event = makeEvent(id: "cached-event", location: makeLocation())
    let cachedWeather = makeWeatherInfo(fetchedAt: Date().addingTimeInterval(-3600))
    let fetchedWeather = makeWeatherInfo()

    var state = PersonalEventDetail.Feature.State(event: event)
    state.$weatherCache.withLock { $0 = [event.id: cachedWeather] }

    let store = TestStore(initialState: state) {
      PersonalEventDetail.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        fetchCount.withValue { $0 += 1 }
        return fetchedWeather
      }
    }

    await store.send(.view(.onAppear)) {
      $0.weatherInfo = cachedWeather
    }
    await store.finish()

    #expect(fetchCount.value == 0)
  }

  @Test("onAppear 시 stale 캐시가 있으면 최신 날씨로 갱신한다")
  func onAppear_refreshesStaleWeather() async {
    let event = makeEvent(id: "stale-event", location: makeLocation())
    let staleWeather = makeWeatherInfo(fetchedAt: Date().addingTimeInterval(-7 * 3600))
    let refreshedWeather = makeWeatherInfo(fetchedAt: Date())
    let requestedCoordinates = LockIsolated<[Double]>([])
    let weatherContinuation = LockIsolated<CheckedContinuation<WeatherInfo, Never>?>(nil)

    var state = PersonalEventDetail.Feature.State(event: event)
    state.$weatherCache.withLock { $0 = [event.id: staleWeather] }
    state.$isPro.withLock { $0 = true }

    let store = TestStore(initialState: state) {
      PersonalEventDetail.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { lat, lng, date in
        requestedCoordinates.setValue([lat, lng, date.timeIntervalSince1970])
        return await withCheckedContinuation { continuation in
          weatherContinuation.setValue(continuation)
        }
      }
    }

    await store.send(.view(.onAppear)) {
      $0.weatherInfo = staleWeather
    }
    await store.receive {
      guard case .internal(.fetchWeather) = $0 else { return false }
      return true
    }
    #expect(weatherContinuation.value != nil)
    weatherContinuation.value?.resume(returning: refreshedWeather)
    await store.receive(
      {
        guard case .internal(.weatherFetched(.success(let info))) = $0 else { return false }
        return info == refreshedWeather
      }
    ) {
      $0.weatherInfo = refreshedWeather
      $0.$weatherCache.withLock { $0[event.id] = refreshedWeather }
    }
    await store.finish()

    #expect(requestedCoordinates.value.count == 3)
    #expect(requestedCoordinates.value[0] == 37.4979)
    #expect(requestedCoordinates.value[1] == 127.0276)
  }

  @Test("editTapped 시 개인 일정 편집 시트를 연다")
  func editTapped_presentsEditor() async {
    let event = makeEvent()
    let store = TestStore(
      initialState: PersonalEventDetail.Feature.State(event: event)
    ) {
      PersonalEventDetail.Feature()
    }

    await store.send(.view(.editTapped)) {
      $0.editEvent = CreatePersonalEvent.Feature.State(
        event: event,
        mode: .edit
      )
    }
  }

  @Test("confirmDelete 성공 시 관련 리소스를 정리하고 삭제 delegate를 보낸다")
  func confirmDelete_success_cleansResources() async {
    let deletedEventID = LockIsolated<String?>(nil)
    let cancelledNotificationID = LockIsolated<String?>(nil)
    let removedCalendarEventID = LockIsolated<String?>(nil)
    let deletedImages = LockIsolated<[String]>([])
    let successCount = LockIsolated(0)

    let event = makeEvent(
      id: "personal-1",
      imageUrls: ["https://example.com/one.jpg", "", "schedule_images/personal-1/two.jpg"]
    )

    let store = TestStore(
      initialState: PersonalEventDetail.Feature.State(event: event)
    ) {
      PersonalEventDetail.Feature()
    } withDependencies: {
      $0.personalEventClient.deleteEvent = { eventID in
        deletedEventID.setValue(eventID)
      }
      $0.localNotificationClient.cancel = { notificationID in
        cancelledNotificationID.setValue(notificationID)
      }
      $0.calendarSyncClient.removePersonalEvent = { eventID in
        removedCalendarEventID.setValue(eventID)
      }
      $0.imageUploadClient.deleteImages = { urls in
        deletedImages.setValue(urls)
      }
      $0.hapticFeedback.success = {
        successCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.deleteTapped)) {
      $0.deleteAlert = makeDeleteAlert(eventTitle: event.title)
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.isDeleting = true
      $0.deleteAlert = nil
    }
    await store.receive(\.internal) {
      $0.isDeleting = false
    }
    await store.receive(\.delegate)
    await store.finish()

    #expect(deletedEventID.value == event.id)
    #expect(cancelledNotificationID.value == event.notificationId)
    #expect(removedCalendarEventID.value == event.id)
    #expect(deletedImages.value == [
      "https://example.com/one.jpg",
      "schedule_images/personal-1/two.jpg"
    ])
    #expect(successCount.value == 1)
  }

  @Test("confirmDelete 실패 시 deleting 상태를 복원하고 에러 햅틱을 보낸다")
  func confirmDelete_failure_restoresDeleting() async {
    let errorCount = LockIsolated(0)
    let event = makeEvent(id: "personal-failure")

    let store = TestStore(
      initialState: PersonalEventDetail.Feature.State(event: event)
    ) {
      PersonalEventDetail.Feature()
    } withDependencies: {
      $0.personalEventClient.deleteEvent = { _ in
        throw TestError()
      }
      $0.hapticFeedback.error = {
        errorCount.withValue { $0 += 1 }
      }
    }

    await store.send(.view(.deleteTapped)) {
      $0.deleteAlert = makeDeleteAlert(eventTitle: event.title)
    }

    await store.send(.alert(.presented(.confirmDelete))) {
      $0.isDeleting = true
      $0.deleteAlert = nil
    }
    await store.receive(\.internal) {
      $0.isDeleting = false
    }
    await store.finish()

    #expect(errorCount.value == 1)
  }

  @Test("editEvent delegate.eventUpdated 수신 시 상태를 갱신하고 delegate를 전달한다")
  func editEventDelegate_eventUpdated_updatesState() async {
    let event = makeEvent(id: "editable-event")
    var updated = event
    updated.title = "수정된 개인 일정"

    var state = PersonalEventDetail.Feature.State(event: event)
    state.editEvent = CreatePersonalEvent.Feature.State(event: event, mode: .edit)

    let store = TestStore(initialState: state) {
      PersonalEventDetail.Feature()
    }

    await store.send(.editEvent(.presented(.delegate(.eventUpdated(updated))))) {
      $0.event = updated
      $0.editEvent = nil
    }
    await store.receive(\.delegate)
  }
}
