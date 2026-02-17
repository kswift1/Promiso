import SwiftUI
import PromisoShared

// MARK: - Promise Detail Weather Section (Level 3)

/// 약속 상세보기 날씨 섹션 - 행동 추천 + 약속 시간 요약 + 시간대별 예보
struct PromiseDetailWeatherSection: View {
  let weatherInfo: WeatherInfo
  let startAt: Date
  let endAt: Date?

  private var targetForecast: HourlyForecast? {
    if let endAt = endAt, endAt.timeIntervalSince(startAt) >= 7200 {
      return weatherInfo.worstCaseForecast(from: startAt, to: endAt)
    }
    return weatherInfo.forecast(for: startAt)
  }

  private var advices: [WeatherAdvice] {
    guard let forecast = targetForecast else { return [] }
    return WeatherAdvice.from(forecast: forecast)
  }

  private var timeRangeForecasts: [HourlyForecast] {
    let end = endAt ?? startAt.addingTimeInterval(7200)
    // 약속 시간 1시간 전부터 종료 시간까지
    let rangeStart = startAt.addingTimeInterval(-3600)
    return weatherInfo.hourlyForecasts.filter { forecast in
      forecast.dateTime >= rangeStart && forecast.dateTime <= end
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      PromiseDetailSectionHeader(title: "날씨")

      VStack(spacing: 12) {
        // 행동 추천
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
          .padding(.horizontal, 16)
          .padding(.top, 12)

          Divider()
            .padding(.horizontal, 16)
        }

        // 약속 시간 날씨 요약
        if let forecast = targetForecast {
          VStack(alignment: .leading, spacing: 8) {
            Text("약속 시간 (\(startAt.formattedTime))")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.secondary)

            HStack(spacing: 12) {
              Image(systemName: forecast.condition.sfSymbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 28))

              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                  Text(forecast.condition.description)
                    .font(.system(size: 16, weight: .semibold))

                  Text("\(Int(forecast.temperature.rounded()))°")
                    .font(.system(size: 20, weight: .bold))
                }

                Text("체감 \(Int(forecast.feelsLikeTemperature.rounded()))°")
                  .font(.system(size: 13))
                  .foregroundStyle(.secondary)
              }

              Spacer()

              Text("강수 \(forecast.precipitationProbability)%")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(forecast.precipitationProbability >= 50 ? .blue : .secondary)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
        }

        // 시간대별 예보 (수평 스크롤)
        if !timeRangeForecasts.isEmpty {
          Divider()
            .padding(.horizontal, 16)

          VStack(alignment: .leading, spacing: 8) {
            Text("시간대별 예보")
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(Array(timeRangeForecasts.enumerated()), id: \.offset) { _, forecast in
                  hourlyForecastCell(forecast)
                }
              }
              .padding(.horizontal, 16)
            }
          }
          .padding(.vertical, 4)
        }

        // 하단 상세 정보
        if let forecast = targetForecast {
          Divider()
            .padding(.horizontal, 16)

          HStack(spacing: 0) {
            detailItem(
              label: "체감",
              value: "\(Int(forecast.feelsLikeTemperature.rounded()))°"
            )

            Divider()
              .frame(height: 24)

            detailItem(
              label: "습도",
              value: "\(forecast.humidity)%"
            )

            Divider()
              .frame(height: 24)

            detailItem(
              label: "바람",
              value: String(format: "%.1fm/s", forecast.windSpeed)
            )
          }
          .padding(.vertical, 8)
        }
      }
      .adaptiveGlassCard()
    }
  }

  // MARK: - Hourly Forecast Cell

  private func hourlyForecastCell(_ forecast: HourlyForecast) -> some View {
    VStack(spacing: 6) {
      Text(hourString(forecast.dateTime))
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)

      Image(systemName: forecast.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 20))

      Text("\(Int(forecast.temperature.rounded()))°")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.primary)

      Text("\(forecast.precipitationProbability)%")
        .font(.system(size: 11))
        .foregroundStyle(forecast.precipitationProbability >= 50 ? .blue : .secondary)
    }
    .frame(width: 52)
    .padding(.vertical, 8)
    .background(
      isPromiseTime(forecast.dateTime) ?
        Color.pmindigo.n500.opacity(0.08) :
        Color.clear
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  // MARK: - Detail Item

  private func detailItem(label: String, value: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)

      Text(value)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Helpers

  private func hourString(_ date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    return "\(hour)시"
  }

  private func isPromiseTime(_ date: Date) -> Bool {
    let end = endAt ?? startAt.addingTimeInterval(7200)
    return date >= startAt && date <= end
  }

}
