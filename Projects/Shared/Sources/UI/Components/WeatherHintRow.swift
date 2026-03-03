import SwiftUI

// MARK: - Weather Hint Row (Level 1)

/// 장소 카드 안에 인라인으로 들어가는 날씨 힌트 뷰
/// 탭하면 WeatherTooltip 팝오버 표시
public struct WeatherHintRow: View {
  private let forecast: HourlyForecast
  private let rangeForecasts: [HourlyForecast]
  private let forecastSource: ForecastSource
  private let minTemperature: Double?
  private let maxTemperature: Double?
  @State private var showTooltip = false

  public init(
    forecast: HourlyForecast,
    rangeForecasts: [HourlyForecast] = [],
    forecastSource: ForecastSource = .shortTerm,
    minTemperature: Double? = nil,
    maxTemperature: Double? = nil
  ) {
    self.forecast = forecast
    self.rangeForecasts = rangeForecasts
    self.forecastSource = forecastSource
    self.minTemperature = minTemperature
    self.maxTemperature = maxTemperature
  }

  public var body: some View {
    Button {
      showTooltip = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 13))

        temperatureText
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
          .fixedSize()

        Text(adviceMessage)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(rowBackground)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
      WeatherTooltip(
        forecast: forecast,
        rangeForecasts: rangeForecasts,
        forecastSource: forecastSource
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var temperatureText: some View {
    if forecastSource == .midTerm,
       let min = minTemperature,
       let max = maxTemperature {
      Text("\(Int(min.rounded()))~\(Int(max.rounded()))°")
    } else {
      Text("\(Int(forecast.temperature.rounded()))°")
    }
  }

  // MARK: - Helpers

  private var adviceMessage: String {
    if let advice = WeatherAdvice.from(forecast: forecast).first {
      return advice.message
    }
    return forecast.condition.description
  }

  private var rowBackground: some ShapeStyle {
    forecast.condition.iconColor.opacity(0.08)
  }
}

// MARK: - Loading State

extension WeatherHintRow {
  /// 날씨 데이터를 불러오는 중일 때 표시하는 로딩 뷰
  /// 레이아웃 점프를 최소화하기 위해 완성 상태와 동일한 패딩/크기를 사용합니다.
  public static func loading(dateText: String, locationName: String) -> some View {
    HStack(spacing: 6) {
      ProgressView()
        .controlSize(.mini)

      Text(LocalizedStrings.Weather.hintLoading(dateText, locationName))
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.secondary.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .contentShape(Rectangle())
  }
}

// MARK: - Preview

#Preview("맑은 날 (단기)") {
  WeatherHintRow(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 22,
      feelsLikeTemperature: 21,
      condition: .clear,
      precipitationProbability: 5,
      humidity: 50,
      windSpeed: 2.0
    )
  )
  .padding()
}

#Preview("비 오는 날 (단기)") {
  WeatherHintRow(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 14,
      feelsLikeTemperature: 10,
      condition: .rain,
      precipitationProbability: 80,
      humidity: 75,
      windSpeed: 6.0,
      precipitationAmount: "3mm"
    )
  )
  .padding()
}

#Preview("중기예보 (온도 범위)") {
  WeatherHintRow(
    forecast: HourlyForecast(
      dateTime: Date(),
      temperature: 9,
      feelsLikeTemperature: 6,
      condition: .cloudy,
      precipitationProbability: 20,
      humidity: 60,
      windSpeed: 3.5
    ),
    forecastSource: .midTerm,
    minTemperature: 6,
    maxTemperature: 12
  )
  .padding()
}

#Preview("로딩 상태") {
  WeatherHintRow.loading(dateText: "3월 15일", locationName: "강남구")
    .padding()
}
