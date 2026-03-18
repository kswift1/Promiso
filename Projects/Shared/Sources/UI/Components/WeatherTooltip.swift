import SwiftUI

// MARK: - Weather Tooltip (Level 2)

/// 플로팅 팝오버 - 날씨 요약 + 핵심 수치 + 자연어 제안
/// rangeForecasts가 있으면 일정 시간 구간 min~max 범위 표시
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

  // MARK: - Timeline

  private static let highPrecipitationThreshold = 50

  private var showTimeline: Bool {
    forecastSource == .shortTerm && rangeForecasts.count > 1
  }

  private var sortedRangeForecasts: [HourlyForecast] {
    rangeForecasts.sorted { $0.dateTime < $1.dateTime }
  }

  /// 타임라인이 여러 날에 걸치는지 여부
  private var spansMultipleDays: Bool {
    guard let first = sortedRangeForecasts.first,
          let last = sortedRangeForecasts.last else { return false }
    return !Calendar.current.isDate(first.dateTime, inSameDayAs: last.dateTime)
  }

  // MARK: - Body

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 날씨 요약 헤더
      HStack(spacing: 8) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 22))
          .frame(width: 32, height: 32)
          .background(
            Circle()
              .fill(Color.cyan.opacity(0.12))
          )

        Text(forecast.condition.description)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.primary)

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text(intRangeText(tempRange, suffix: "°"))
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Weather.feelsLikeRange(intRangeText(feelsRange, suffix: "°")))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }

      // 시간대별 타임라인
      if showTimeline {
        Divider()

        VStack(alignment: .leading, spacing: 8) {
          Text(LocalizedStrings.Weather.hourlyForecast)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
              ForEach(sortedRangeForecasts, id: \.dateTime) { hourForecast in
                hourlyColumn(hourForecast)
              }
            }
          }
        }
      }

      // 핵심 수치 그리드
      Divider()

      HStack(spacing: 0) {
        weatherStat(
          icon: "drop.fill",
          label: LocalizedStrings.Weather.precipitationLabel,
          value: intRangeText(precipRange, suffix: "%"),
          color: precipRange.max >= 50 ? .blue : .secondary
        )

        Spacer()

        if forecastSource == .midTerm {
          weatherStat(
            icon: "thermometer.medium",
            label: LocalizedStrings.Weather.tempRangeLabel,
            value: intRangeText(tempRange, suffix: "°"),
            color: .secondary
          )
        } else {
          weatherStat(
            icon: "wind",
            label: LocalizedStrings.Weather.wind,
            value: windRangeText,
            color: windRange.max >= 8 ? .purple : .secondary
          )
        }

        Spacer()

        if forecastSource == .midTerm {
          weatherStat(
            icon: "sun.max.fill",
            label: LocalizedStrings.Weather.weatherLabel,
            value: forecast.condition.description,
            color: forecast.condition.iconColor
          )
        } else {
          weatherStat(
            icon: "humidity.fill",
            label: LocalizedStrings.Weather.humidity,
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
          LocalizedStrings.Weather.midTermSource : LocalizedStrings.Weather.shortTermSource)
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
        if let timeText = referenceTimeText {
          Text(LocalizedStrings.Weather.referenceTime(timeText))
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .padding(16)
    .frame(width: 280)
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

  private func hourlyColumn(_ hourForecast: HourlyForecast) -> some View {
    let isHighPrecip = hourForecast.precipitationProbability >= Self.highPrecipitationThreshold
    let hour = Calendar.current.component(.hour, from: hourForecast.dateTime)

    return VStack(spacing: 6) {
      // 시간 (여러 날에 걸치면 날짜도 표시)
      VStack(spacing: 1) {
        if spansMultipleDays {
          Text(hourForecast.dateTime.formatted(.dateTime.month(.defaultDigits).day()))
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
        }
        Text(LocalizedStrings.Weather.hourLabel(hour))
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }

      // 날씨 아이콘
      Image(systemName: hourForecast.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 16))
        .frame(width: 24, height: 24)
        .background(
          Circle()
            .fill(Color.cyan.opacity(0.12))
        )

      // 온도
      Text("\(Int(hourForecast.temperature.rounded()))°")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)

      // 강수확률
      Text("\(hourForecast.precipitationProbability)%")
        .font(.system(size: 11, weight: isHighPrecip ? .semibold : .regular))
        .foregroundStyle(isHighPrecip ? .blue : .secondary)
    }
    .frame(width: 48)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isHighPrecip ? Color.blue.opacity(0.08) : .clear)
    )
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

#Preview("일정 구간 타임라인") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 5,
      feelsLikeTemperature: 2,
      condition: .cloudy,
      precipitationProbability: 30,
      humidity: 55,
      windSpeed: 4.0
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
        temperature: 4,
        feelsLikeTemperature: 1,
        condition: .rain,
        precipitationProbability: 70,
        humidity: 75,
        windSpeed: 6.0,
        precipitationAmount: "2mm"
      ),
      HourlyForecast(
        dateTime: Date().addingTimeInterval(10800),
        temperature: 3,
        feelsLikeTemperature: 0,
        condition: .rain,
        precipitationProbability: 85,
        humidity: 80,
        windSpeed: 7.0,
        precipitationAmount: "5mm"
      ),
      HourlyForecast(
        dateTime: Date().addingTimeInterval(14400),
        temperature: 5,
        feelsLikeTemperature: 2,
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
