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

  /// 한글 설명
  public var description: String {
    switch self {
    case .clear: return "맑음"
    case .cloudy: return "구름많음"
    case .overcast: return "흐림"
    case .rain: return "비"
    case .rainSnow: return "비/눈"
    case .snow: return "눈"
    case .shower: return "소나기"
    case .unknown: return "정보없음"
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

// MARK: - Weather Info

/// 날씨 정보 (특정 위치/시간대의 전체 예보)
public struct WeatherInfo: Equatable, Hashable, Sendable, Codable {
  public let fetchedAt: Date
  public let current: HourlyForecast?
  public let hourlyForecasts: [HourlyForecast]

  public init(
    fetchedAt: Date = Date(),
    current: HourlyForecast? = nil,
    hourlyForecasts: [HourlyForecast] = []
  ) {
    self.fetchedAt = fetchedAt
    self.current = current
    self.hourlyForecasts = hourlyForecasts
  }

  /// startAt 기준 가장 가까운 예보 조회
  public func forecast(for date: Date) -> HourlyForecast? {
    guard !hourlyForecasts.isEmpty else { return current }

    return hourlyForecasts.min(by: { forecast1, forecast2 in
      abs(forecast1.dateTime.timeIntervalSince(date)) < abs(forecast2.dateTime.timeIntervalSince(date))
    })
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
    case .bringUmbrella: return "우산을 챙기세요"
    case .dressWarm: return "겉옷을 준비하세요"
    case .dressCool: return "가볍게 입으세요"
    case .strongWind: return "바람이 강해요, 주의하세요"
    case .heavySnow: return "폭설 예보, 이동에 주의하세요"
    case .clearWeather: return "야외 활동하기 좋은 날씨예요"
    case .hotWeather: return "더위에 주의하세요"
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
      suggestions.append(.init(
        icon: "thermometer.snowflake",
        message: "한파 수준의 추위예요",
        color: .cyan
      ))
    case -10..<0:
      suggestions.append(.init(
        icon: "thermometer.snowflake",
        message: "영하로 내려가요. 단단히 입고 나오세요",
        color: .cyan
      ))
    case 0..<5:
      suggestions.append(.init(
        icon: "thermometer.low",
        message: "꽤 추워요. 두꺼운 겉옷이 필요해요",
        color: .blue
      ))
    case 5..<10:
      suggestions.append(.init(
        icon: "thermometer.low",
        message: "쌀쌀해요. 겉옷을 챙기세요",
        color: .blue
      ))
    case 10..<15:
      suggestions.append(.init(
        icon: "tshirt.fill",
        message: "선선해요. 가벼운 겉옷이면 충분해요",
        color: .teal
      ))
    case 15..<20:
      suggestions.append(.init(
        icon: "figure.walk",
        message: "활동하기 좋은 날씨예요",
        color: .green
      ))
    case 20..<25:
      suggestions.append(.init(
        icon: "tshirt.fill",
        message: "따뜻해요. 가볍게 입으세요",
        color: .orange
      ))
    case 25..<30:
      suggestions.append(.init(
        icon: "sun.max.fill",
        message: "더워요. 시원하게 입으세요",
        color: .orange
      ))
    case 30..<35:
      suggestions.append(.init(
        icon: "thermometer.sun.fill",
        message: "무더워요. 수분 보충에 신경 쓰세요",
        color: .red
      ))
    default:
      suggestions.append(.init(
        icon: "thermometer.sun.fill",
        message: "폭염 수준이에요. 야외 활동을 줄이세요",
        color: .red
      ))
    }

    // 2. 체감온도 차이 (바람 영향)
    let tempDiff = forecast.temperature - feels
    if tempDiff >= 5 {
      suggestions.append(.init(
        icon: "wind",
        message: "체감온도는 \(Int(feels.rounded()))°로 실제보다 \(Int(tempDiff.rounded()))도 낮아요",
        color: .purple
      ))
    }

    // 3. 비/눈
    switch forecast.condition {
    case .snow:
      if prob >= 70 {
        suggestions.append(.init(
          icon: "snowflake",
          message: "눈이 많이 올 수 있어요. 이동 시 여유를 두세요",
          color: .cyan
        ))
      } else if prob >= 40 {
        suggestions.append(.init(
          icon: "snowflake",
          message: "눈이 올 수 있어요. 길이 미끄러울 수 있어요",
          color: .cyan
        ))
      }
    case .rain, .shower:
      if prob >= 70 {
        suggestions.append(.init(
          icon: "umbrella.fill",
          message: "비 올 가능성이 높아요. 우산 필수예요",
          color: .blue
        ))
      } else if prob >= 40 {
        suggestions.append(.init(
          icon: "umbrella.fill",
          message: "비가 올 수 있어요. 우산을 챙기세요",
          color: .blue
        ))
      }
    case .rainSnow:
      suggestions.append(.init(
        icon: "umbrella.fill",
        message: "비와 눈이 섞여 내릴 수 있어요",
        color: .blue
      ))
    default:
      if prob >= 50 {
        suggestions.append(.init(
          icon: "umbrella.fill",
          message: "강수 확률 \(prob)%. 우산을 챙기세요",
          color: .blue
        ))
      }
    }

    // 4. 강풍 (8m/s 이상만, 약한 바람은 생략)
    if wind >= 14 {
      suggestions.append(.init(
        icon: "wind",
        message: "강풍이 예상돼요. 야외 활동에 주의하세요",
        color: .purple
      ))
    } else if wind >= 8 {
      suggestions.append(.init(
        icon: "wind",
        message: "바람이 제법 강해요",
        color: .purple
      ))
    }

    // 5. 습도 (고온+고습일 때만, 건조는 10° 이상일 때만)
    if humidity >= 80 && feels >= 25 {
      suggestions.append(.init(
        icon: "humidity.fill",
        message: "습도가 높아 체감온도가 더 높아요",
        color: .teal
      ))
    } else if humidity <= 30 && feels >= 10 {
      suggestions.append(.init(
        icon: "drop.degreesign",
        message: "공기가 건조해요. 물을 자주 마시세요",
        color: .orange
      ))
    }

    // 6. 자외선 (맑고 따뜻할 때)
    if forecast.condition == .clear && feels >= 20 {
      suggestions.append(.init(
        icon: "sun.max.trianglebadge.exclamationmark",
        message: "자외선이 강할 수 있어요. 선크림을 챙기세요",
        color: .orange
      ))
    }

    // 7. 좋은 날씨 (다른 경고가 없을 때)
    if suggestions.count <= 1 &&
       (forecast.condition == .clear || forecast.condition == .cloudy) &&
       feels >= 15 && feels <= 28 &&
       wind < 8 && prob < 30 {
      suggestions.append(.init(
        icon: "leaf.fill",
        message: "야외 활동하기 좋은 날씨예요",
        color: .green
      ))
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
