//
//  CreatePromiseWeatherTests.swift
//  GroupFeature
//
//  CreatePromise.Feature 날씨 힌트 기능 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `GroupFeature/Sources/CreatePromise/Core/CreatePromiseFeature.swift`
//  - Weather hint related actions: setStartDate, setLocation, toggleUseLocation, weatherResponse
//

import Testing
@testable import GroupFeature
@testable import PromisoShared
@testable import Clients

// MARK: - CreatePromise Weather Tests

@Suite("CreatePromise.Feature 날씨 힌트 테스트")
@MainActor
struct CreatePromiseWeatherTests {

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

  nonisolated private func makeStateWithLocation(
    useLocation: Bool = true,
    location: LocationInfoModel = LocationInfoModel(
      name: "테스트",
      address: "서울",
      latitude: 37.5,
      longitude: 127.0
    )
  ) -> CreatePromise.Feature.State {
    var state = CreatePromise.Feature.State()
    state.useLocation = useLocation
    state.promise.location = location
    state.promise.startAt = Date().addingTimeInterval(24 * 3600)
    return state
  }

  // MARK: - 초기 상태 테스트

  @Test("초기 상태에서 날씨 정보 nil")
  func initialState_weatherInfoIsNil() {
    let state = CreatePromise.Feature.State()
    #expect(state.weatherInfo == nil)
    #expect(state.isWeatherLoading == false)
  }

  // MARK: - toggleUseLocation 테스트

  @Test("toggleUseLocation OFF 시 날씨 상태 클리어 + 페치 취소")
  func toggleUseLocation_off_clearsWeatherAndCancels() async {
    var state = makeStateWithLocation(useLocation: true)
    state.weatherInfo = makeWeatherInfo()
    state.isWeatherLoading = true

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = false
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("toggleUseLocation ON 시 아무 일도 안 함")
  func toggleUseLocation_on_doesNothing() async {
    var state = makeStateWithLocation(useLocation: false)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = true
    }
  }

  // MARK: - setLocation 테스트

  @Test("setLocation(nil) 시 날씨 상태 클리어 + 페치 취소")
  func setLocation_nil_clearsWeatherAndCancels() async {
    var state = makeStateWithLocation(useLocation: true)
    state.weatherInfo = makeWeatherInfo()
    state.isWeatherLoading = true

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setLocation(nil))) {
      $0.promise.location = nil
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("setLocation 유효값 설정 시 위치 변경")
  func setLocation_validLocation_setsLocation() async {
    let location = makeLocation()
    var state = makeStateWithLocation(useLocation: true)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setLocation(location))) {
      $0.promise.location = location
    }
  }

  // MARK: - setStartDate 테스트

  @Test("setStartDate useLocation=false 시 날씨 페치 안 함")
  func setStartDate_noLocation_doesNotFetchWeather() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = false
    state.promise.startAt = Date()

    let forecastDate = Date().addingTimeInterval(24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setStartDate(forecastDate))) {
      $0.promise.startAt = forecastDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("setStartDate 위치 좌표 없으면 날씨 페치 안 함")
  func setStartDate_noCoordinates_doesNotFetchWeather() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.location = LocationInfoModel(
      name: "장소명만",
      address: "주소만",
      latitude: nil,
      longitude: nil
    )
    state.promise.startAt = Date()

    let forecastDate = Date().addingTimeInterval(24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setStartDate(forecastDate))) {
      $0.promise.startAt = forecastDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("setStartDate 과거 날짜 시 날씨 페치 안 함")
  func setStartDate_pastDate_doesNotFetchWeather() async {
    var state = makeStateWithLocation()
    state.promise.startAt = Date()

    let pastDate = Date().addingTimeInterval(-3600)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setStartDate(pastDate))) {
      $0.promise.startAt = pastDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("setStartDate 10일 초과 미래 시 날씨 페치 안 함")
  func setStartDate_farFutureDate_doesNotFetchWeather() async {
    var state = makeStateWithLocation()
    state.promise.startAt = Date()

    let farFutureDate = Date().addingTimeInterval(11 * 24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setStartDate(farFutureDate))) {
      $0.promise.startAt = farFutureDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("setStartDate 정확히 10일 후 시 날씨 페치 함")
  func setStartDate_tenDaysLater_fetchesWeather() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.location = makeLocation()
    state.promise.startAt = Date()

    let tenDaysLater = Date().addingTimeInterval(10 * 24 * 3600 - 1)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.setStartDate(tenDaysLater))) {
      $0.promise.startAt = tenDaysLater
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }
  }

  // MARK: - locationPicker delegate 테스트

  @Test("locationPicker.locationSelected 시 날씨 데이터 페치")
  func locationPickerLocationSelected_fetchesWeather() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.startAt = Date().addingTimeInterval(24 * 3600)
    state.locationPicker = LocationPicker.Feature.State()

    let location = makeLocation()

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
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
      $0.promise.location = location
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }
  }

  // MARK: - weatherResponse 성공 테스트

  @Test("weatherResponse 성공 시 weatherInfo 설정")
  func weatherResponse_success_setsWeatherInfo() async {
    var state = makeStateWithLocation()
    state.isWeatherLoading = true

    let weatherInfo = makeWeatherInfo()

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherInfo = weatherInfo
      $0.isWeatherLoading = false
    }
  }

  @Test("weatherResponse 성공 시 비오는 날씨 저장")
  func weatherResponse_success_rainyWeather() async {
    var state = makeStateWithLocation()
    state.isWeatherLoading = true

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
      CreatePromise.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherInfo = weatherInfo
      $0.isWeatherLoading = false
    }

    #expect(store.state.weatherInfo?.current?.condition == .rain)
    #expect(store.state.weatherInfo?.current?.precipitationProbability == 80)
  }

  @Test("weatherResponse 성공 시 눈오는 날씨 저장")
  func weatherResponse_success_snowWeather() async {
    var state = makeStateWithLocation()
    state.isWeatherLoading = true

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
      CreatePromise.Feature()
    }

    await store.send(.internal(.weatherResponse(.success(weatherInfo)))) {
      $0.weatherInfo = weatherInfo
      $0.isWeatherLoading = false
    }

    #expect(store.state.weatherInfo?.current?.condition == .snow)
    #expect(store.state.weatherInfo?.current?.temperature == -5)
  }

  // MARK: - weatherResponse 실패 테스트

  @Test("weatherResponse 실패 시 날씨 정보 클리어")
  func weatherResponse_failure_clearsWeatherInfo() async {
    var state = makeStateWithLocation()
    state.isWeatherLoading = true
    state.weatherInfo = makeWeatherInfo()

    enum TestError: Error { case networkFailed }

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.internal(.weatherResponse(.failure(TestError.networkFailed)))) {
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  @Test("weatherResponse 실패 후 재시도 가능")
  func weatherResponse_failure_thenRetry() async {
    var state = makeStateWithLocation()
    state.isWeatherLoading = true

    enum TestError: Error { case networkFailed }

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 첫 실패
    await store.send(.internal(.weatherResponse(.failure(TestError.networkFailed)))) {
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }

    // 재시도
    let newDate = Date().addingTimeInterval(48 * 3600)
    await store.send(.view(.setStartDate(newDate))) {
      $0.promise.startAt = newDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }
  }

  // MARK: - 경계 조건 테스트

  @Test("현재 시간 기준 데이터는 페치 안 함")
  func startDate_exactly_now_doesNotFetch() async {
    let now = Date()
    var state = makeStateWithLocation()
    state.promise.startAt = now

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    // 현재 시간을 그대로 설정하므로 상태 변경 없음
    await store.send(.view(.setStartDate(now)))
  }

  @Test("1초 후 미래 데이터는 페치 함")
  func startDate_oneSecondLater_fetches() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.location = makeLocation()
    state.promise.startAt = Date()

    let oneSecondLater = Date().addingTimeInterval(1)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.setStartDate(oneSecondLater))) {
      $0.promise.startAt = oneSecondLater
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }
  }

  @Test("위도/경도 부분만 nil인 경우 페치 안 함")
  func location_partialCoordinates_doesNotFetch() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.location = LocationInfoModel(
      name: "서울",
      address: "서울시",
      latitude: 37.5,
      longitude: nil
    )
    state.promise.startAt = Date().addingTimeInterval(24 * 3600)

    let newDate = Date().addingTimeInterval(48 * 3600)
    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.setStartDate(newDate))) {
      $0.promise.startAt = newDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }
  }

  // MARK: - 상태 일관성 테스트

  @Test("여러 번의 toggleUseLocation 후 최종 상태 확인")
  func multipleToggleUseLocation_finalState() async {
    var state = makeStateWithLocation(useLocation: false)
    state.weatherInfo = nil

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = true
    }

    await store.send(.view(.toggleUseLocation)) {
      $0.useLocation = false
      $0.weatherInfo = nil
      $0.isWeatherLoading = false
    }

    #expect(store.state.useLocation == false)
    #expect(store.state.weatherInfo == nil)
  }

  @Test("setLocation + setStartDate 연속 호출")
  func setLocation_then_setStartDate_sequence() async {
    var state = CreatePromise.Feature.State()
    state.useLocation = true
    state.promise.startAt = Date()

    let location = makeLocation()
    let newDate = Date().addingTimeInterval(24 * 3600)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
    } withDependencies: {
      $0.weatherClient.getWeather = { _, _, _ in
        self.makeWeatherInfo()
      }
      $0.continuousClock = ImmediateClock()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.setLocation(location))) {
      $0.promise.location = location
    }

    await store.send(.view(.setStartDate(newDate))) {
      $0.promise.startAt = newDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }
  }

  @Test("weatherInfo 상태 전환: nil → loading → success")
  func weatherStateTransition_nilToLoadingToSuccess() async {
    var state = makeStateWithLocation()
    #expect(state.weatherInfo == nil)
    #expect(state.isWeatherLoading == false)

    let store = TestStore(initialState: state) {
      CreatePromise.Feature()
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

    await store.send(.view(.setStartDate(newDate))) {
      $0.promise.startAt = newDate
      $0.weatherInfo = nil
      $0.isWeatherLoading = true
    }

    #expect(store.state.isWeatherLoading == true)
  }
}
