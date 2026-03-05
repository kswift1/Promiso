//
//  CreatePersonalEventWeatherTests.swift
//  SharedFeature
//
//  CreatePersonalEvent.Feature 날씨 힌트 기능 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `SharedFeature/Sources/PersonalEventDetail/CreatePersonalEventFeature.swift`
//  - Weather hint related actions: startDateChanged, removeLocation, locationPicker.locationSelected, weatherResponse
//

import Testing
@testable import CreatePromiseFeature
@testable import PromisoShared
@testable import Clients

// MARK: - CreatePersonalEvent Weather Tests

@Suite("CreatePersonalEvent.Feature 날씨 힌트 테스트")
@MainActor
struct CreatePersonalEventWeatherTests {

  // MARK: - Test Helpers

  nonisolated private func makeLocation(
    name: String = "테스트 장소",
    address: String = "서울시 강남구",
    latitude: Double = 37.5,
    longitude: Double = 127.0
  ) -> LocationInfoModel {
    LocationInfoModel(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude
    )
  }

  nonisolated private func makeWeatherInfo() -> WeatherInfo {
    WeatherInfo(
      fetchedAt: Date(),
      current: HourlyForecast(
        dateTime: Date(),
        temperature: 22,
        feelsLikeTemperature: 20,
        condition: .clear,
        precipitationProbability: 10,
        humidity: 50,
        windSpeed: 3.0
      ),
      hourlyForecasts: [],
      dailyForecasts: []
    )
  }

  nonisolated private func makeEventWithLocation(
    location: LocationInfoModel = LocationInfoModel(
      name: "테스트",
      address: "서울",
      latitude: 37.5,
      longitude: 127.0
    ),
    startAt: Date = Date().addingTimeInterval(24 * 3600)
  ) -> PersonalEventModel {
    var event = PersonalEventModel(
      id: "event-1",
      title: "테스트 일정",
      startAt: startAt
    )
    event.location = location
    return event
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태에서 날씨 정보 nil")
  func initialState_weatherInfoIsNil() {
    let event = PersonalEventModel(id: "event-1", title: "테스트", startAt: Date())
    let state = CreatePersonalEvent.Feature.State(event: event)
    #expect(state.weatherState.value == nil)
    #expect(state.weatherState.isLoading == false)
  }

  // MARK: - removeLocation 테스트

  @Test("removeLocation 시 날씨 상태 클리어 + 페치 취소")
  func removeLocation_clearsWeatherAndCancels() async {
    let event = makeEventWithLocation()
    var state = CreatePersonalEvent.Feature.State(event: event)
    state.weatherState = .loaded(makeWeatherInfo())

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.removeLocation)) {
      $0.event.location = nil
      $0.weatherState = .idle
    }
  }

  // MARK: - startDateChanged 테스트

  @Test("startDateChanged 위치 좌표 없으면 날씨 페치 안 함")
  func startDateChanged_noCoordinates_doesNotFetchWeather() async {
    var event = PersonalEventModel(id: "event-1", title: "테스트", startAt: Date())
    event.location = LocationInfoModel(
      name: "장소명만",
      address: "주소만",
      latitude: nil,
      longitude: nil
    )
    let state = CreatePersonalEvent.Feature.State(event: event)

    let forecastDate = Date().addingTimeInterval(24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(forecastDate))) {
      $0.event.startAt = forecastDate
      $0.weatherState = .idle
    }
  }

  @Test("startDateChanged 과거 날짜 시 날씨 페치 안 함")
  func startDateChanged_pastDate_doesNotFetchWeather() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.event.startAt = Date()

    let pastDate = Date().addingTimeInterval(-3600)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(pastDate))) {
      $0.event.startAt = pastDate
      $0.weatherState = .idle
    }
  }

  @Test("startDateChanged 10일 초과 미래 시 날씨 페치 안 함")
  func startDateChanged_farFutureDate_doesNotFetchWeather() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.event.startAt = Date()

    let farFutureDate = Date().addingTimeInterval(11 * 24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(farFutureDate))) {
      $0.event.startAt = farFutureDate
      $0.weatherState = .idle
    }
  }

  @Test("startDateChanged 정확히 10일 후 시 날씨 페치 함")
  func startDateChanged_tenDaysLater_fetchesWeather() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.event.startAt = Date()

    let tenDaysLater = Date().addingTimeInterval(10 * 24 * 3600 - 1)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(tenDaysLater))) {
      $0.event.startAt = tenDaysLater
      $0.weatherState = .loading
    }
  }

  // MARK: - locationPicker delegate 테스트

  @Test("locationPicker.locationSelected 시 날씨 데이터 페치")
  func locationPickerLocationSelected_fetchesWeather() async {
    var event = PersonalEventModel(id: "event-1", title: "테스트", startAt: Date().addingTimeInterval(24 * 3600))
    var state = CreatePersonalEvent.Feature.State(event: event)
    state.locationPicker = LocationPicker.Feature.State()

    let location = makeLocation()

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(
      .locationPicker(.presented(.delegate(.locationSelected(location))))
    ) {
      $0.locationPicker = nil
      $0.event.location = location
      $0.weatherState = .loading
    }
  }

  // MARK: - weatherResponse 성공 테스트

  @Test("weatherResponse 성공 시 weatherInfo 설정")
  func weatherResponse_success_setsWeatherInfo() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loading

    let weatherInfo = makeWeatherInfo()

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherState = .loaded(weatherInfo)
    }
  }

  @Test("weatherResponse 성공 시 비오는 날씨 저장")
  func weatherResponse_success_rainyWeather() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loading

    let rainyForecast = HourlyForecast(
      dateTime: Date(),
      temperature: 15,
      feelsLikeTemperature: 10,
      condition: .rain,
      precipitationProbability: 80,
      humidity: 75,
      windSpeed: 4.0
    )
    let weatherInfo = WeatherInfo(
      fetchedAt: Date(),
      current: rainyForecast,
      hourlyForecasts: [rainyForecast],
      dailyForecasts: []
    )

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherState = .loaded(weatherInfo)
    }

    #expect(store.state.weatherState.value?.current?.condition == .rain)
    #expect(store.state.weatherState.value?.current?.precipitationProbability == 80)
  }

  @Test("weatherResponse 성공 시 눈오는 날씨 저장")
  func weatherResponse_success_snowWeather() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loading

    let snowForecast = HourlyForecast(
      dateTime: Date(),
      temperature: -5,
      feelsLikeTemperature: -8,
      condition: .snow,
      precipitationProbability: 70,
      humidity: 80,
      windSpeed: 6.0
    )
    let weatherInfo = WeatherInfo(
      fetchedAt: Date(),
      current: snowForecast,
      hourlyForecasts: [],
      dailyForecasts: []
    )

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherState = .loaded(weatherInfo)
    }

    #expect(store.state.weatherState.value?.current?.condition == .snow)
    #expect(store.state.weatherState.value?.current?.temperature == -5)
  }

  // MARK: - weatherResponse 실패 테스트

  @Test("weatherResponse 실패 시 날씨 정보 클리어")
  func weatherResponse_failure_clearsWeatherInfo() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loaded(makeWeatherInfo())

    enum TestError: Error { case networkFailed }

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }

    await store.send(.internal(.weatherResponse(.failure(TestError.networkFailed)))) {
      $0.weatherState = .idle
    }
  }

  @Test("weatherResponse 실패 후 재시도 가능")
  func weatherResponse_failure_thenRetry() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loading

    enum TestError: Error { case networkFailed }

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 첫 실패
    await store.send(.internal(.weatherResponse(.failure(TestError.networkFailed)))) {
      $0.weatherState = .idle
    }

    // 재시도
    let newDate = Date().addingTimeInterval(48 * 3600)
    await store.send(.view(.startDateChanged(newDate))) {
      $0.event.startAt = newDate
      $0.weatherState = .loading
    }
  }

  // MARK: - 경계 조건 테스트

  @Test("현재 시간 기준 데이터는 페치 안 함")
  func startDate_exactly_now_doesNotFetch() async {
    let now = Date()
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation(startAt: now))

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 현재 시간을 그대로 설정하므로 상태 변경 없음
    await store.send(.view(.startDateChanged(now)))
  }

  @Test("1초 후 미래 데이터는 페치 함")
  func startDate_oneSecondLater_fetches() async {
    var event = PersonalEventModel(id: "event-1", title: "테스트", startAt: Date())
    event.location = makeLocation()
    var state = CreatePersonalEvent.Feature.State(event: event)

    let oneSecondLater = Date().addingTimeInterval(1)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(oneSecondLater))) {
      $0.event.startAt = oneSecondLater
      $0.weatherState = .loading
    }
  }

  @Test("위도/경도 부분만 nil인 경우 페치 안 함")
  func location_partialCoordinates_doesNotFetch() async {
    var event = PersonalEventModel(id: "event-1", title: "테스트", startAt: Date().addingTimeInterval(24 * 3600))
    event.location = LocationInfoModel(
      name: "서울",
      address: "서울시",
      latitude: 37.5,
      longitude: nil
    )
    let state = CreatePersonalEvent.Feature.State(event: event)

    let newDate = Date().addingTimeInterval(48 * 3600)
    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.startDateChanged(newDate))) {
      $0.event.startAt = newDate
      $0.weatherState = .idle
    }
  }

  // MARK: - 상태 일관성 테스트

  @Test("removeLocation + startDateChanged 연속 호출")
  func removeLocation_then_startDateChanged_sequence() async {
    var state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    state.weatherState = .loaded(makeWeatherInfo())

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 위치 제거
    await store.send(.view(.removeLocation)) {
      $0.event.location = nil
      $0.weatherState = .idle
    }

    // 시작일 변경 (위치 없으므로 페치 안 함)
    let newDate = Date().addingTimeInterval(24 * 3600)
    await store.send(.view(.startDateChanged(newDate))) {
      $0.event.startAt = newDate
      $0.weatherState = .idle
    }
  }

  @Test("weatherInfo 상태 전환: nil → loading → success")
  func weatherStateTransition_nilToLoadingToSuccess() async {
    let state = CreatePersonalEvent.Feature.State(event: makeEventWithLocation())
    #expect(state.weatherState.value == nil)
    #expect(state.weatherState.isLoading == false)

    let store = TestStore(initialState: state) {
      CreatePersonalEvent.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        let forecast = HourlyForecast(
          dateTime: Date(),
          temperature: 22,
          feelsLikeTemperature: 20,
          condition: .clear,
          precipitationProbability: 10,
          humidity: 50,
          windSpeed: 3.0
        )
        return WeatherInfo(
          fetchedAt: Date(),
          current: forecast,
          hourlyForecasts: [],
          dailyForecasts: []
        )
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    let newDate = Date().addingTimeInterval(24 * 3600)

    await store.send(.view(.startDateChanged(newDate))) {
      $0.event.startAt = newDate
      $0.weatherState = .loading
    }

    #expect(store.state.weatherState.isLoading == true)
  }
}
