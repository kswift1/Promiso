import SwiftUI

// MARK: - Weather Tooltip (Level 2)

/// 플로팅 팝오버 - 행동 추천 + 날씨 상세
public struct WeatherTooltip: View {
  private let forecast: HourlyForecast
  private let advices: [WeatherAdvice]
  private let referenceTimeText: String?

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
    VStack(alignment: .leading, spacing: 12) {
      // 행동 추천 (있을 때만)
      if !advices.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(Array(advices.enumerated()), id: \.offset) { _, advice in
            HStack(spacing: 8) {
              Image(systemName: advice.icon)
                .font(.system(size: 14))
                .foregroundStyle(advice.color)
                .frame(width: 20)

              Text(advice.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            }
          }
        }

        Divider()
      }

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

      // 체감온도
      Text("체감 \(Int(forecast.feelsLikeTemperature.rounded()))°")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)

      // 상세 정보
      VStack(spacing: 6) {
        weatherDetailRow(
          icon: "drop.fill",
          label: "강수확률",
          value: "\(forecast.precipitationProbability)%",
          color: .blue
        )

        weatherDetailRow(
          icon: "wind",
          label: "바람",
          value: String(format: "%.1fm/s", forecast.windSpeed),
          color: .teal
        )
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
    .frame(width: 240)
  }

  // MARK: - Detail Row

  private func weatherDetailRow(
    icon: String,
    label: String,
    value: String,
    color: Color
  ) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundStyle(color)
        .frame(width: 16)

      Text(label)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
    }
  }

}

// MARK: - Preview

#Preview {
  Color.clear
    .popover(isPresented: .constant(true)) {
      WeatherTooltip(
        forecast: HourlyForecast(
          dateTime: Date(),
          temperature: 18,
          feelsLikeTemperature: 15,
          condition: .cloudy,
          precipitationProbability: 70,
          humidity: 65,
          windSpeed: 5.2,
          precipitationAmount: "1mm"
        ),
        referenceTimeText: "오후 2:00"
      )
    }
}
