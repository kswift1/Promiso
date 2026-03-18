import SwiftUI
import ResourceKit

// MARK: - Pro Weather Row

/// Pro 혜택 날씨 행 — 날씨 아이콘 + 온도 + 조언 텍스트 + 팝오버 버튼
///
/// ProBenefitCardView와 ProBonusFloatingView에서 공통으로 사용합니다.
public struct ProWeatherRow: View {
  let forecast: HourlyForecast
  let rangeForecasts: [HourlyForecast]
  let forecastSource: ForecastSource
  let referenceTimeText: String?

  @State private var showTooltip = false

  public init(
    forecast: HourlyForecast,
    rangeForecasts: [HourlyForecast] = [],
    forecastSource: ForecastSource = .shortTerm,
    referenceTimeText: String? = nil
  ) {
    self.forecast = forecast
    self.rangeForecasts = rangeForecasts
    self.forecastSource = forecastSource
    self.referenceTimeText = referenceTimeText
  }

  public var body: some View {
    Button {
      showTooltip = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 12))
          .frame(width: 22, height: 22)
          .background(
            Circle()
              .fill(Color.cyan.opacity(0.12))
          )

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)

        Text(adviceMessage(for: forecast))
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
      WeatherTooltip(
        forecast: forecast,
        rangeForecasts: rangeForecasts,
        referenceTimeText: referenceTimeText,
        forecastSource: forecastSource
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  // MARK: - Helpers

  private func adviceMessage(for forecast: HourlyForecast) -> String {
    if let advice = WeatherAdvice.from(forecast: forecast).first {
      return advice.message
    }
    return forecast.condition.description
  }
}

// MARK: - Previews

#Preview("맑은 날") {
  ProWeatherRow(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 22,
      feelsLikeTemperature: 20,
      condition: .clear,
      precipitationProbability: 5,
      humidity: 45,
      windSpeed: 2.0
    ),
    referenceTimeText: "3월 6일 14:00"
  )
  .padding()
}

#Preview("비 오는 날") {
  ProWeatherRow(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 10,
      feelsLikeTemperature: 7,
      condition: .rain,
      precipitationProbability: 80,
      humidity: 85,
      windSpeed: 5.0,
      precipitationAmount: "3mm"
    ),
    referenceTimeText: "3월 6일 18:00"
  )
  .padding()
}
