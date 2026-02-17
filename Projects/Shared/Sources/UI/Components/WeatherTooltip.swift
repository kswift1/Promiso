import SwiftUI

// MARK: - Weather Tooltip (Level 2)

/// 플로팅 팝오버 - 날씨 요약 + 자연어 제안
public struct WeatherTooltip: View {
  private let forecast: HourlyForecast
  private let suggestions: [WeatherSuggestion]
  private let referenceTimeText: String?

  public init(
    forecast: HourlyForecast,
    advices: [WeatherAdvice] = [],
    referenceTimeText: String? = nil
  ) {
    self.forecast = forecast
    self.suggestions = WeatherSuggestion.from(forecast: forecast)
    self.referenceTimeText = referenceTimeText
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 날씨 요약
      HStack(spacing: 8) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 20))

        Text(forecast.condition.description)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.primary)

        Spacer()

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.primary)
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

      // 기준 시각
      if let timeText = referenceTimeText {
        HStack {
          Spacer()
          Text("기준: \(timeText)")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
    }
    .padding(16)
    .frame(width: 260)
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

#Preview("맑고 쾌적한 날") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 22,
      feelsLikeTemperature: 21,
      condition: .clear,
      precipitationProbability: 5,
      humidity: 50,
      windSpeed: 2.0
    ),
    referenceTimeText: "3월 5일 13:00"
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

#Preview("흐리고 건조") {
  WeatherTooltip(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 8,
      feelsLikeTemperature: 5,
      condition: .overcast,
      precipitationProbability: 20,
      humidity: 25,
      windSpeed: 3.0
    ),
    referenceTimeText: "11월 20일 17:00"
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
