import SwiftUI

// MARK: - Weather Tooltip (Level 2)

/// 플로팅 팝오버 - 날씨 요약 + 핵심 수치 + 자연어 제안
/// rangeForecasts가 있으면 약속 시간 구간 min~max 범위 표시
public struct WeatherTooltip: View {
  private let forecast: HourlyForecast
  private let rangeForecasts: [HourlyForecast]
  private let suggestions: [WeatherSuggestion]
  private let referenceTimeText: String?
  private let forecastSource: ForecastSource

  public init(
    forecast: HourlyForecast,
    rangeForecasts: [HourlyForecast] = [],
    advices: [WeatherAdvice] = [],
    referenceTimeText: String? = nil,
    forecastSource: ForecastSource = .shortTerm
  ) {
    self.forecast = forecast
    self.rangeForecasts = rangeForecasts
    self.suggestions = WeatherSuggestion.from(forecast: forecast)
    self.referenceTimeText = referenceTimeText
    self.forecastSource = forecastSource
  }

  // MARK: - Range Computations

  private var allForecasts: [HourlyForecast] {
    rangeForecasts.isEmpty ? [forecast] : rangeForecasts
  }

  private var hasRange: Bool {
    rangeForecasts.count > 1
  }

  private var tempRange: (min: Int, max: Int) {
    let temps = allForecasts.map { Int($0.temperature.rounded()) }
    return (temps.min() ?? 0, temps.max() ?? 0)
  }

  private var feelsRange: (min: Int, max: Int) {
    let feels = allForecasts.map { Int($0.feelsLikeTemperature.rounded()) }
    return (feels.min() ?? 0, feels.max() ?? 0)
  }

  private var precipRange: (min: Int, max: Int) {
    let probs = allForecasts.map(\.precipitationProbability)
    return (probs.min() ?? 0, probs.max() ?? 0)
  }

  private var windRange: (min: Double, max: Double) {
    let speeds = allForecasts.map(\.windSpeed)
    return (speeds.min() ?? 0, speeds.max() ?? 0)
  }

  private var humidityRange: (min: Int, max: Int) {
    let vals = allForecasts.map(\.humidity)
    return (vals.min() ?? 0, vals.max() ?? 0)
  }

  // MARK: - Body

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 날씨 요약 헤더
      HStack(spacing: 8) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 22))

        Text(forecast.condition.description)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.primary)

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text(intRangeText(tempRange, suffix: "°"))
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.primary)

          Text("체감 \(intRangeText(feelsRange, suffix: "°"))")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }

      // 핵심 수치 그리드
      Divider()

      HStack(spacing: 0) {
        weatherStat(
          icon: "drop.fill",
          label: "강수",
          value: intRangeText(precipRange, suffix: "%"),
          color: precipRange.max >= 50 ? .blue : .secondary
        )

        Spacer()

        if forecastSource == .midTerm {
          weatherStat(
            icon: "thermometer.medium",
            label: "최저/최고",
            value: intRangeText(tempRange, suffix: "°"),
            color: .secondary
          )
        } else {
          weatherStat(
            icon: "wind",
            label: "바람",
            value: windRangeText,
            color: windRange.max >= 8 ? .purple : .secondary
          )
        }

        Spacer()

        if forecastSource == .midTerm {
          weatherStat(
            icon: "sun.max.fill",
            label: "날씨",
            value: forecast.condition.description,
            color: forecast.condition.iconColor
          )
        } else {
          weatherStat(
            icon: "humidity.fill",
            label: "습도",
            value: intRangeText(humidityRange, suffix: "%"),
            color: humidityRange.max >= 80 ? .teal : .secondary
          )
        }
      }

      // 자연어 제안
      if !suggestions.isEmpty {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
            HStack(alignment: .top, spacing: 8) {
              Image(systemName: suggestion.icon)
                .font(.system(size: 12))
                .foregroundStyle(suggestion.color)
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)

              Text(suggestion.message)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }

      // 출처 · 기준 시각
      HStack(spacing: 0) {
        Spacer()
        Text(forecastSource == .midTerm ?
          "기상청 중기예보" : "기상청 단기예보")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
        if let timeText = referenceTimeText {
          Text(" · 기준: \(timeText)")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
    }
    .padding(16)
    .frame(width: 260)
  }

  // MARK: - Helpers

  private func intRangeText(_ range: (min: Int, max: Int), suffix: String) -> String {
    if range.min == range.max {
      return "\(range.min)\(suffix)"
    }
    return "\(range.min)~\(range.max)\(suffix)"
  }

  private var windRangeText: String {
    let lo = Int(windRange.min.rounded())
    let hi = Int(windRange.max.rounded())
    if lo == hi {
      return "\(lo)m/s"
    }
    return "\(lo)~\(hi)m/s"
  }

  private func weatherStat(
    icon: String,
    label: String,
    value: String,
    color: Color
  ) -> some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: 14))
        .foregroundStyle(color)

      Text(value)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.primary)

      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Preview

#Preview("비 오는 날") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 14,
      feelsLikeTemperature: 10,
      condition: .rain,
      precipitationProbability: 80,
      humidity: 75,
      windSpeed: 6.0,
      precipitationAmount: "3mm"
    ),
    referenceTimeText: "2월 18일 14:30"
  )
}

#Preview("약속 구간 범위") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 5,
      feelsLikeTemperature: 2,
      condition: .clear,
      precipitationProbability: 0,
      humidity: 45,
      windSpeed: 3.0
    ),
    rangeForecasts: [
      HourlyForecast(
        dateTime: Date(),
        temperature: 5,
        feelsLikeTemperature: 2,
        condition: .clear,
        precipitationProbability: 0,
        humidity: 45,
        windSpeed: 3.0
      ),
      HourlyForecast(
        dateTime: Date().addingTimeInterval(3600),
        temperature: 7,
        feelsLikeTemperature: 4,
        condition: .cloudy,
        precipitationProbability: 20,
        humidity: 55,
        windSpeed: 5.0
      ),
      HourlyForecast(
        dateTime: Date().addingTimeInterval(7200),
        temperature: 8,
        feelsLikeTemperature: 5,
        condition: .cloudy,
        precipitationProbability: 30,
        humidity: 60,
        windSpeed: 4.0
      ),
    ],
    referenceTimeText: "2월 18일 14:00"
  )
}

#Preview("한겨울 폭설") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: -5,
      feelsLikeTemperature: -12,
      condition: .snow,
      precipitationProbability: 90,
      humidity: 70,
      windSpeed: 8.5,
      precipitationAmount: "5cm"
    ),
    referenceTimeText: "1월 10일 09:00"
  )
}

#Preview("한여름 무더위") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 34,
      feelsLikeTemperature: 37,
      condition: .clear,
      precipitationProbability: 10,
      humidity: 85,
      windSpeed: 1.5
    ),
    referenceTimeText: "7월 25일 15:00"
  )
}

#Preview("강풍 주의") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 12,
      feelsLikeTemperature: 5,
      condition: .cloudy,
      precipitationProbability: 40,
      humidity: 55,
      windSpeed: 15.0
    ),
    referenceTimeText: "4월 3일 11:00"
  )
}
