import Testing
import Foundation
@testable import Clients
@testable import PromisoShared

// MARK: - WeatherCondition Tests

@Suite("WeatherCondition")
struct WeatherConditionTests {

  @Test("SF Symbol 이름이 올바르게 매핑됨")
  func sfSymbolNames() {
    #expect(WeatherCondition.clear.sfSymbolName == "sun.max.fill")
    #expect(WeatherCondition.rain.sfSymbolName == "cloud.rain.fill")
    #expect(WeatherCondition.snow.sfSymbolName == "cloud.snow.fill")
    #expect(WeatherCondition.cloudy.sfSymbolName == "cloud.sun.fill")
    #expect(WeatherCondition.overcast.sfSymbolName == "cloud.fill")
    #expect(WeatherCondition.shower.sfSymbolName == "cloud.heavyrain.fill")
    #expect(WeatherCondition.rainSnow.sfSymbolName == "cloud.sleet.fill")
    #expect(WeatherCondition.unknown.sfSymbolName == "questionmark.circle")
  }

  @Test("한글 설명이 올바르게 매핑됨")
  func descriptions() {
    #expect(WeatherCondition.clear.description == "맑음")
    #expect(WeatherCondition.rain.description == "비")
    #expect(WeatherCondition.snow.description == "눈")
  }

  @Test("Codable 라운드트립")
  func codableRoundTrip() throws {
    let original = WeatherCondition.rain
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(WeatherCondition.self, from: data)
    #expect(original == decoded)
  }
}

// MARK: - WeatherInfo Tests

@Suite("WeatherInfo")
struct WeatherInfoTests {

  private func makeForecasts(count: Int, baseDate: Date = Date()) -> [HourlyForecast] {
    (0..<count).map { i in
      HourlyForecast(
        dateTime: baseDate.addingTimeInterval(Double(i) * 3600),
        temperature: 15 + Double(i),
        feelsLikeTemperature: 13 + Double(i),
        condition: i % 3 == 0 ? .clear : (i % 3 == 1 ? .cloudy : .rain),
        precipitationProbability: i * 10,
        humidity: 50 + i * 2,
        windSpeed: 2.0 + Double(i) * 0.5
      )
    }
  }

  @Test("forecast(for:)는 가장 가까운 시간의 예보를 반환")
  func forecastForDate() {
    let base = Date()
    let forecasts = makeForecasts(count: 6, baseDate: base)
    let info = WeatherInfo(fetchedAt: Date(), current: forecasts.first, hourlyForecasts: forecasts)

    // 3시간 후에 가장 가까운 예보 = index 3
    let target = base.addingTimeInterval(3 * 3600 + 300) // 3시간 5분
    let result = info.forecast(for: target)
    #expect(result != nil)
    #expect(result?.temperature == 18.0) // 15 + 3
  }

  @Test("forecast(for:)는 빈 예보 시 current를 반환")
  func forecastForDateEmpty() {
    let current = HourlyForecast(
      dateTime: Date(),
      temperature: 20,
      feelsLikeTemperature: 18,
      condition: .clear,
      precipitationProbability: 10,
      humidity: 55,
      windSpeed: 3.0
    )
    let info = WeatherInfo(fetchedAt: Date(), current: current, hourlyForecasts: [])
    let result = info.forecast(for: Date())
    #expect(result?.temperature == 20.0)
  }

  @Test("worstCaseForecast는 2시간 미만이면 단순 forecast 반환")
  func worstCaseShortDuration() {
    let base = Date()
    let forecasts = makeForecasts(count: 6, baseDate: base)
    let info = WeatherInfo(fetchedAt: Date(), current: nil, hourlyForecasts: forecasts)

    let end = base.addingTimeInterval(3600) // 1시간
    let result = info.worstCaseForecast(from: base, to: end)
    // 2시간 미만이므로 forecast(for:) 호출
    #expect(result != nil)
  }

  @Test("worstCaseForecast는 구간 내 최악값을 반환")
  func worstCaseLongDuration() {
    let base = Date()
    let forecasts = [
      HourlyForecast(dateTime: base, temperature: 20, feelsLikeTemperature: 18, condition: .clear, precipitationProbability: 10, humidity: 50, windSpeed: 2),
      HourlyForecast(dateTime: base.addingTimeInterval(3600), temperature: 18, feelsLikeTemperature: 15, condition: .cloudy, precipitationProbability: 30, humidity: 60, windSpeed: 4),
      HourlyForecast(dateTime: base.addingTimeInterval(7200), temperature: 15, feelsLikeTemperature: 12, condition: .rain, precipitationProbability: 80, humidity: 75, windSpeed: 8),
      HourlyForecast(dateTime: base.addingTimeInterval(10800), temperature: 16, feelsLikeTemperature: 14, condition: .cloudy, precipitationProbability: 40, humidity: 65, windSpeed: 5),
    ]
    let info = WeatherInfo(fetchedAt: Date(), current: nil, hourlyForecasts: forecasts)

    let end = base.addingTimeInterval(10800) // 3시간
    let result = info.worstCaseForecast(from: base, to: end)

    #expect(result != nil)
    #expect(result?.condition == .rain) // 가장 심각한 조건
    #expect(result?.precipitationProbability == 80) // 최고 강수확률
    #expect(result?.feelsLikeTemperature == 12) // 최저 체감온도
    #expect(result?.windSpeed == 8) // 최대 풍속
  }

  @Test("worstCaseForecast는 endAt nil이면 forecast(for:) 반환")
  func worstCaseNilEnd() {
    let base = Date()
    let forecasts = makeForecasts(count: 3, baseDate: base)
    let info = WeatherInfo(fetchedAt: Date(), current: nil, hourlyForecasts: forecasts)

    let result = info.worstCaseForecast(from: base, to: nil)
    #expect(result != nil)
  }
}

// MARK: - WeatherAdvice Tests

@Suite("WeatherAdvice")
struct WeatherAdviceTests {

  @Test("비 예보 시 우산 추천")
  func umbrellaAdvice() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 18,
      feelsLikeTemperature: 16,
      condition: .rain,
      precipitationProbability: 70,
      humidity: 80,
      windSpeed: 3.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.contains(.bringUmbrella))
  }

  @Test("추울 때 겉옷 추천")
  func warmAdvice() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 3,
      feelsLikeTemperature: -2,
      condition: .clear,
      precipitationProbability: 0,
      humidity: 40,
      windSpeed: 5.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.contains(.dressWarm))
  }

  @Test("더울 때 더위 주의 추천")
  func hotAdvice() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 35,
      feelsLikeTemperature: 38,
      condition: .clear,
      precipitationProbability: 0,
      humidity: 70,
      windSpeed: 1.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.contains(.hotWeather))
  }

  @Test("강풍 시 바람 주의 추천")
  func windAdvice() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 20,
      feelsLikeTemperature: 18,
      condition: .cloudy,
      precipitationProbability: 10,
      humidity: 50,
      windSpeed: 12.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.contains(.strongWind))
  }

  @Test("좋은 날씨에 야외활동 추천")
  func clearAdvice() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 22,
      feelsLikeTemperature: 20,
      condition: .clear,
      precipitationProbability: 0,
      humidity: 50,
      windSpeed: 2.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.contains(.clearWeather))
  }

  @Test("최대 2개까지만 추천")
  func maxTwoAdvices() {
    let forecast = HourlyForecast(
      dateTime: Date(),
      temperature: 2,
      feelsLikeTemperature: -5,
      condition: .snow,
      precipitationProbability: 90,
      humidity: 80,
      windSpeed: 15.0
    )
    let advices = WeatherAdvice.from(forecast: forecast)
    #expect(advices.count <= 2)
  }
}

// MARK: - WeatherDataSource Cache Key Tests

@Suite("WeatherDataSource Cache Key")
struct WeatherDataSourceCacheKeyTests {

  @Test("같은 좌표 그룹(소수점 2자리)은 같은 캐시 키 생성")
  func sameGridSameKey() {
    let date = Date()
    let key1 = WeatherDataSource.cacheKey(lat: 37.4981, lng: 127.0276, date: date)
    let key2 = WeatherDataSource.cacheKey(lat: 37.4989, lng: 127.0274, date: date)
    #expect(key1 == key2)
  }

  @Test("다른 좌표 그룹은 다른 캐시 키 생성")
  func differentGridDifferentKey() {
    let date = Date()
    let key1 = WeatherDataSource.cacheKey(lat: 37.49, lng: 127.02, date: date)
    let key2 = WeatherDataSource.cacheKey(lat: 37.51, lng: 127.04, date: date)
    #expect(key1 != key2)
  }

  @Test("같은 좌표라도 다른 시간은 다른 캐시 키 생성")
  func differentHourDifferentKey() {
    let date1 = Date()
    let date2 = date1.addingTimeInterval(3600)
    let key1 = WeatherDataSource.cacheKey(lat: 37.49, lng: 127.02, date: date1)
    let key2 = WeatherDataSource.cacheKey(lat: 37.49, lng: 127.02, date: date2)
    // 시간이 같으면 같은 키, 다르면 다른 키
    let hour1 = Calendar.current.component(.hour, from: date1)
    let hour2 = Calendar.current.component(.hour, from: date2)
    if hour1 != hour2 {
      #expect(key1 != key2)
    }
  }
}
