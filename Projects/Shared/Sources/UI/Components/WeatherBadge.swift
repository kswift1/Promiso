import SwiftUI

// MARK: - Weather Badge (Level 1)

/// 카드용 날씨 뱃지 - 아이콘 + 온도 표시
/// 탭하면 WeatherTooltip 팝오버 표시
public struct WeatherBadge: View {
  private let forecast: HourlyForecast
  private let advices: [WeatherAdvice]
  private let referenceTimeText: String?
  @State private var showTooltip = false

  public init(
    forecast: HourlyForecast,
    advices: [WeatherAdvice] = [],
    referenceTimeText: String? = nil
  ) {
    self.forecast = forecast
    self.advices = advices.isEmpty ? WeatherAdvice.from(forecast: forecast) : advices
    self.referenceTimeText = referenceTimeText
  }

  public var body: some View {
    Button {
      showTooltip = true
    } label: {
      HStack(spacing: 4) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 12))

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.primary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(badgeBackground)
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
      WeatherTooltip(
        forecast: forecast,
        advices: advices,
        referenceTimeText: referenceTimeText
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  private var badgeBackground: some ShapeStyle {
    forecast.condition.iconColor.opacity(0.12)
  }
}

// MARK: - Preview

#Preview {
  HStack(spacing: 12) {
    WeatherBadge(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: 22,
        feelsLikeTemperature: 20,
        condition: .clear,
        precipitationProbability: 10,
        humidity: 55,
        windSpeed: 3.2
      )
    )

    WeatherBadge(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: 8,
        feelsLikeTemperature: 4,
        condition: .rain,
        precipitationProbability: 80,
        humidity: 75,
        windSpeed: 5.5,
        precipitationAmount: "2mm"
      )
    )

    WeatherBadge(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: -3,
        feelsLikeTemperature: -8,
        condition: .snow,
        precipitationProbability: 90,
        humidity: 80,
        windSpeed: 7.0
      )
    )
  }
  .padding()
}
