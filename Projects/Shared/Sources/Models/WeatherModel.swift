import Foundation
import SwiftUI

// MARK: - Weather Condition

/// 날씨 상태 (기상청 SKY + PTY 코드 매핑)
public enum WeatherCondition: String, Equatable, Hashable, Sendable, Codable, CaseIterable {
  case clear        // 맑음
  case cloudy       // 구름많음
  case overcast     // 흐림
  case rain         // 비
  case rainSnow     // 비/눈
  case snow         // 눈
  case shower       // 소나기
  case unknown      // 알 수 없음

  /// SF Symbol 이름
  public var sfSymbolName: String {
    switch self {
    case .clear: return "sun.max.fill"
    case .cloudy: return "cloud.sun.fill"
    case .overcast: return "cloud.fill"
    case .rain: return "cloud.rain.fill"
    case .rainSnow: return "cloud.sleet.fill"
    case .snow: return "cloud.snow.fill"
    case .shower: return "cloud.heavyrain.fill"
    case .unknown: return "questionmark.circle"
    }
  }

  /// 아이콘 색상
  public var iconColor: Color {
    switch self {
    case .clear: return .orange
    case .cloudy: return .gray
    case .overcast: return .gray
    case .rain: return .blue
    case .rainSnow: return .cyan
    case .snow: return .cyan
    case .shower: return .blue
    case .unknown: return .gray
    }
  }

  /// 날씨 상태 설명
  public var description: String {
    switch self {
    case .clear: return LocalizedStrings.Weather.conditionClear
    case .cloudy: return LocalizedStrings.Weather.conditionCloudy
    case .overcast: return LocalizedStrings.Weather.conditionOvercast
    case .rain: return LocalizedStrings.Weather.conditionRain
    case .rainSnow: return LocalizedStrings.Weather.conditionRainSnow
    case .snow: return LocalizedStrings.Weather.conditionSnow
    case .shower: return LocalizedStrings.Weather.conditionShower
    case .unknown: return LocalizedStrings.Weather.conditionUnknown
    }
  }
}

// MARK: - Hourly Forecast

/// 시간대별 예보 데이터
public struct HourlyForecast: Equatable, Hashable, Sendable, Codable {
  public let dateTime: Date
  public let temperature: Double
  public let feelsLikeTemperature: Double
  public let condition: WeatherCondition
  public let precipitationProbability: Int
  public let humidity: Int
  public let windSpeed: Double
  public let precipitationAmount: String

  public init(
    dateTime: Date,
    temperature: Double,
    feelsLikeTemperature: Double,
    condition: WeatherCondition,
    precipitationProbability: Int,
    humidity: Int,
    windSpeed: Double,
    precipitationAmount: String = ""
  ) {
    self.dateTime = dateTime
    self.temperature = temperature
    self.feelsLikeTemperature = feelsLikeTemperature
    self.condition = condition
    self.precipitationProbability = precipitationProbability
    self.humidity = humidity
    self.windSpeed = windSpeed
    self.precipitationAmount = precipitationAmount
  }
}

// MARK: - Daily Forecast (중기예보)

/// 일별 예보 데이터 (중기예보 기반)
public struct DailyForecast: Equatable, Hashable, Sendable, Codable {
  public let date: Date
  public let minTemperature: Double
  public let maxTemperature: Double
  public let amCondition: WeatherCondition
  public let pmCondition: WeatherCondition
  public let amPrecipitationProbability: Int
  public let pmPrecipitationProbability: Int

  public init(
    date: Date,
    minTemperature: Double,
    maxTemperature: Double,
    amCondition: WeatherCondition,
    pmCondition: WeatherCondition,
    amPrecipitationProbability: Int,
    pmPrecipitationProbability: Int
  ) {
    self.date = date
    self.minTemperature = minTemperature
    self.maxTemperature = maxTemperature
    self.amCondition = amCondition
    self.pmCondition = pmCondition
    self.amPrecipitationProbability = amPrecipitationProbability
    self.pmPrecipitationProbability = pmPrecipitationProbability
  }

  /// 더 심각한 쪽의 날씨 상태
  public var representativeCondition: WeatherCondition {
    let amSeverity = conditionSeverity(amCondition)
    let pmSeverity = conditionSeverity(pmCondition)
    return amSeverity >= pmSeverity ? amCondition : pmCondition
  }

  /// 오전/오후 중 높은 강수확률
  public var maxPrecipitationProbability: Int {
    max(amPrecipitationProbability, pmPrecipitationProbability)
  }

  /// 평균 기온
  public var averageTemperature: Double {
    (minTemperature + maxTemperature) / 2
  }

  /// 약속 시간 기준 오전/오후 날씨 조건 반환
  public func condition(for date: Date) -> WeatherCondition {
    let hour = Calendar.current.component(.hour, from: date)
    return hour < 12 ? amCondition : pmCondition
  }

  /// 카드 표시용 HourlyForecast 변환
  public func toRepresentativeForecast(for date: Date) -> HourlyForecast {
    let hour = Calendar.current.component(.hour, from: date)
    let isAm = hour < 12
    return HourlyForecast(
      dateTime: date,
      temperature: averageTemperature,
      feelsLikeTemperature: averageTemperature,
      condition: isAm ? amCondition : pmCondition,
      precipitationProbability: isAm
        ? amPrecipitationProbability
        : pmPrecipitationProbability,
      humidity: 0,
      windSpeed: 0
    )
  }
}

/// 예보 출처
public enum ForecastSource: Equatable, Sendable {
  case shortTerm
  case midTerm
}

// MARK: - Weather Info

/// 날씨 정보 (특정 위치/시간대의 전체 예보)
public struct WeatherInfo: Equatable, Hashable, Sendable, Codable {
  public let fetchedAt: Date
  public let current: HourlyForecast?
  public let hourlyForecasts: [HourlyForecast]
  public let dailyForecasts: [DailyForecast]

  public init(
    fetchedAt: Date = Date(),
    current: HourlyForecast? = nil,
    hourlyForecasts: [HourlyForecast] = [],
    dailyForecasts: [DailyForecast] = []
  ) {
    self.fetchedAt = fetchedAt
    self.current = current
    self.hourlyForecasts = hourlyForecasts
    self.dailyForecasts = dailyForecasts
  }

  /// startAt 기준 가장 가까운 예보 조회 (단기 → 중기 fallback)
  public func forecast(for date: Date) -> HourlyForecast? {
    // 1. 단기예보에서 ±3시간 이내 검색
    if !hourlyForecasts.isEmpty {
      let closest = hourlyForecasts.min(by: { forecast1, forecast2 in
        abs(forecast1.dateTime.timeIntervalSince(date)) < abs(forecast2.dateTime.timeIntervalSince(date))
      })
      if let closest,
         abs(closest.dateTime.timeIntervalSince(date)) <= 10800 {
        return closest
      }
    }

    // 2. 중기예보에서 같은 날짜 검색 → HourlyForecast 변환
    let calendar = Calendar.current
    if let daily = dailyForecasts.first(where: {
      calendar.isDate($0.date, inSameDayAs: date)
    }) {
      return daily.toRepresentativeForecast(for: date)
    }

    // 3. 단기예보 중 가장 가까운 것 (±3시간 넘어도)
    if !hourlyForecasts.isEmpty {
      return hourlyForecasts.min(by: { forecast1, forecast2 in
        abs(forecast1.dateTime.timeIntervalSince(date)) < abs(forecast2.dateTime.timeIntervalSince(date))
      })
    }

    return current
  }

  /// 예보 출처 확인
  public func forecastSource(for date: Date) -> ForecastSource {
    if !hourlyForecasts.isEmpty {
      let closest = hourlyForecasts.min(by: { forecast1, forecast2 in
        abs(forecast1.dateTime.timeIntervalSince(date)) < abs(forecast2.dateTime.timeIntervalSince(date))
      })
      if let closest,
         abs(closest.dateTime.timeIntervalSince(date)) <= 10800 {
        return .shortTerm
      }
    }

    let calendar = Calendar.current
    if dailyForecasts.contains(where: {
      calendar.isDate($0.date, inSameDayAs: date)
    }) {
      return .midTerm
    }

    return .shortTerm
  }

  /// 약속 구간 내 시간대별 예보 필터
  public func forecasts(from start: Date, to end: Date?) -> [HourlyForecast] {
    guard let end = end else { return [] }
    return hourlyForecasts.filter { $0.dateTime >= start && $0.dateTime <= end }
  }

  /// 약속 구간(startAt~endAt) 내 worst-case 기반 예보 요약
  public func worstCaseForecast(from start: Date, to end: Date?) -> HourlyForecast? {
    guard let end = end else { return forecast(for: start) }

    let duration = end.timeIntervalSince(start)
    guard duration >= 7200 else { return forecast(for: start) }

    let rangeForecasts = hourlyForecasts.filter { forecast in
      forecast.dateTime >= start && forecast.dateTime <= end
    }

    guard !rangeForecasts.isEmpty else { return forecast(for: start) }

    let worstCondition = rangeForecasts
      .map(\.condition)
      .max(by: { conditionSeverity($0) < conditionSeverity($1) }) ?? .unknown

    let maxPrecipProb = rangeForecasts.map(\.precipitationProbability).max() ?? 0
    let minFeelsLike = rangeForecasts.map(\.feelsLikeTemperature).min() ?? 0
    let maxWindSpeed = rangeForecasts.map(\.windSpeed).max() ?? 0
    let avgTemp = rangeForecasts.map(\.temperature).reduce(0, +) / Double(rangeForecasts.count)
    let avgHumidity = rangeForecasts.map(\.humidity).reduce(0, +) / rangeForecasts.count

    return HourlyForecast(
      dateTime: start,
      temperature: avgTemp,
      feelsLikeTemperature: minFeelsLike,
      condition: worstCondition,
      precipitationProbability: maxPrecipProb,
      humidity: avgHumidity,
      windSpeed: maxWindSpeed
    )
  }
}

// MARK: - Weather Advice

/// 날씨 기반 행동 추천 메시지
public enum WeatherAdvice: Equatable, Sendable {
  case bringUmbrella
  case dressWarm
  case dressCool
  case strongWind
  case heavySnow
  case clearWeather
  case hotWeather

  public var message: String {
    switch self {
    case .bringUmbrella: return LocalizedStrings.Weather.adviceBringUmbrella
    case .dressWarm: return LocalizedStrings.Weather.adviceDressWarm
    case .dressCool: return LocalizedStrings.Weather.adviceDressCool
    case .strongWind: return LocalizedStrings.Weather.adviceStrongWind
    case .heavySnow: return LocalizedStrings.Weather.adviceHeavySnow
    case .clearWeather: return LocalizedStrings.Weather.adviceClearWeather
    case .hotWeather: return LocalizedStrings.Weather.adviceHotWeather
    }
  }

  public var icon: String {
    switch self {
    case .bringUmbrella: return "umbrella.fill"
    case .dressWarm: return "thermometer.snowflake"
    case .dressCool: return "tshirt.fill"
    case .strongWind: return "wind"
    case .heavySnow: return "snowflake"
    case .clearWeather: return "sun.max.fill"
    case .hotWeather: return "thermometer.sun.fill"
    }
  }

  public var color: Color {
    switch self {
    case .bringUmbrella: return .blue
    case .dressWarm: return .cyan
    case .dressCool: return .orange
    case .strongWind: return .purple
    case .heavySnow: return .cyan
    case .clearWeather: return .green
    case .hotWeather: return .red
    }
  }

  /// 날씨 데이터로부터 행동 추천 생성 (우선순위 기반, 최대 2개)
  public static func from(forecast: HourlyForecast) -> [WeatherAdvice] {
    var advices: [WeatherAdvice] = []

    // 눈 관련
    if forecast.condition == .snow && forecast.precipitationProbability >= 70 {
      advices.append(.heavySnow)
    }

    // 강풍
    if forecast.windSpeed >= 10 {
      advices.append(.strongWind)
    }

    // 비/눈 관련
    if forecast.precipitationProbability >= 50 ||
       forecast.condition == .rain ||
       forecast.condition == .shower ||
       forecast.condition == .rainSnow {
      advices.append(.bringUmbrella)
    }

    // 추위
    if forecast.feelsLikeTemperature <= 5 {
      advices.append(.dressWarm)
    }

    // 더위
    if forecast.feelsLikeTemperature >= 33 {
      advices.append(.hotWeather)
    }

    // 좋은 날씨 (다른 경고가 없을 때만)
    if advices.isEmpty &&
       forecast.condition == .clear &&
       forecast.feelsLikeTemperature >= 15 &&
       forecast.feelsLikeTemperature <= 28 {
      advices.append(.clearWeather)
    }

    return Array(advices.prefix(2))
  }
}

// MARK: - Weather Suggestion

public struct WeatherSuggestion: Equatable, Sendable {
  public let icon: String
  public let message: String
  public let color: Color

  public init(icon: String, message: String, color: Color) {
    self.icon = icon
    self.message = message
    self.color = color
  }

  public static func from(forecast: HourlyForecast) -> [WeatherSuggestion] {
    var suggestions: [WeatherSuggestion] = []

    let feels = forecast.feelsLikeTemperature
    let prob = forecast.precipitationProbability
    let wind = forecast.windSpeed
    let humidity = forecast.humidity

    // 1. 옷차림 (체감온도 기준)
    switch feels {
    case ..<(-10):
      suggestions.append(.init(icon: "thermometer.snowflake", message: LocalizedStrings.Weather.suggestExtremeCold, color: .cyan))
    case -10..<0:
      suggestions.append(.init(icon: "thermometer.snowflake", message: LocalizedStrings.Weather.suggestBelowFreezing, color: .cyan))
    case 0..<5:
      suggestions.append(.init(icon: "thermometer.low", message: LocalizedStrings.Weather.suggestVeryCold, color: .blue))
    case 5..<10:
      suggestions.append(.init(icon: "thermometer.low", message: LocalizedStrings.Weather.suggestChilly, color: .blue))
    case 10..<15:
      suggestions.append(.init(icon: "tshirt.fill", message: LocalizedStrings.Weather.suggestCool, color: .teal))
    case 15..<20:
      suggestions.append(.init(icon: "figure.walk", message: LocalizedStrings.Weather.suggestComfortable, color: .green))
    case 20..<25:
      suggestions.append(.init(icon: "tshirt.fill", message: LocalizedStrings.Weather.suggestWarm, color: .orange))
    case 25..<30:
      suggestions.append(.init(icon: "sun.max.fill", message: LocalizedStrings.Weather.suggestHot, color: .orange))
    case 30..<35:
      suggestions.append(.init(icon: "thermometer.sun.fill", message: LocalizedStrings.Weather.suggestVeryHot, color: .red))
    default:
      suggestions.append(.init(icon: "thermometer.sun.fill", message: LocalizedStrings.Weather.suggestExtremeHeat, color: .red))
    }

    // 2. 체감온도 차이 (바람 영향)
    let tempDiff = forecast.temperature - feels
    if tempDiff >= 5 {
      suggestions.append(.init(
        icon: "wind",
        message: LocalizedStrings.Weather.suggestFeelsLikeDiff(Int(feels.rounded()), Int(tempDiff.rounded())),
        color: .purple
      ))
    }

    // 3. 비/눈
    switch forecast.condition {
    case .snow:
      if prob >= 70 {
        suggestions.append(.init(icon: "snowflake", message: LocalizedStrings.Weather.suggestHeavySnow, color: .cyan))
      } else if prob >= 40 {
        suggestions.append(.init(icon: "snowflake", message: LocalizedStrings.Weather.suggestPossibleSnow, color: .cyan))
      }
    case .rain, .shower:
      if prob >= 70 {
        suggestions.append(.init(icon: "umbrella.fill", message: LocalizedStrings.Weather.suggestLikelyRain, color: .blue))
      } else if prob >= 40 {
        suggestions.append(.init(icon: "umbrella.fill", message: LocalizedStrings.Weather.suggestPossibleRain, color: .blue))
      }
    case .rainSnow:
      suggestions.append(.init(icon: "umbrella.fill", message: LocalizedStrings.Weather.suggestRainSnow, color: .blue))
    default:
      if prob >= 50 {
        suggestions.append(.init(icon: "umbrella.fill", message: LocalizedStrings.Weather.suggestPrecipChance(prob), color: .blue))
      }
    }

    // 4. 강풍 (8m/s 이상만, 약한 바람은 생략, 중기예보 0이면 스킵)
    if wind > 0 {
      if wind >= 14 {
        suggestions.append(.init(icon: "wind", message: LocalizedStrings.Weather.suggestStrongWind, color: .purple))
      } else if wind >= 8 {
        suggestions.append(.init(icon: "wind", message: LocalizedStrings.Weather.suggestModerateWind, color: .purple))
      }
    }

    // 5. 습도 (고온+고습일 때만, 건조는 10° 이상일 때만, 중기예보 0이면 스킵)
    if humidity > 0 {
      if humidity >= 80 && feels >= 25 {
        suggestions.append(.init(icon: "humidity.fill", message: LocalizedStrings.Weather.suggestHighHumidity, color: .teal))
      } else if humidity <= 30 && feels >= 10 {
        suggestions.append(.init(icon: "drop.degreesign", message: LocalizedStrings.Weather.suggestDry, color: .orange))
      }
    }

    // 6. 자외선 (맑고 따뜻할 때)
    if forecast.condition == .clear && feels >= 20 {
      suggestions.append(.init(icon: "sun.max.trianglebadge.exclamationmark", message: LocalizedStrings.Weather.suggestUvWarning, color: .orange))
    }

    // 7. 좋은 날씨 (다른 경고가 없을 때)
    if suggestions.count <= 1 &&
       (forecast.condition == .clear || forecast.condition == .cloudy) &&
       feels >= 15 && feels <= 28 &&
       wind < 8 && prob < 30 {
      suggestions.append(.init(icon: "leaf.fill", message: LocalizedStrings.Weather.suggestNiceWeather, color: .green))
    }

    return suggestions
  }
}

// MARK: - Private Helpers

/// 날씨 상태의 심각도 (worst-case 판단용)
private func conditionSeverity(_ condition: WeatherCondition) -> Int {
  switch condition {
  case .clear: return 0
  case .cloudy: return 1
  case .overcast: return 2
  case .shower: return 3
  case .rain: return 4
  case .rainSnow: return 5
  case .snow: return 6
  case .unknown: return -1
  }
}
