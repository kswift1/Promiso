import SwiftUI
import PromisoShared

// MARK: - Promise Detail Weather Section (Level 3)

/// 약속 상세보기 날씨 섹션 - 행동 추천 + 약속 시간 요약 + 시간대별 예보
struct PromiseDetailWeatherSection: View {
  let weatherInfo: WeatherInfo
  let startAt: Date
  let endAt: Date?

  @State private var selectedForecast: HourlyForecast?

  private var displayedForecast: HourlyForecast? {
    selectedForecast ?? targetForecast
  }

  private var targetForecast: HourlyForecast? {
    if let endAt = endAt, endAt.timeIntervalSince(startAt) >= 7200 {
      return weatherInfo.worstCaseForecast(from: startAt, to: endAt)
    }
    return weatherInfo.forecast(for: startAt)
  }

  private var advices: [WeatherAdvice] {
    guard let forecast = displayedForecast else { return [] }
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

  private var spansMultipleDays: Bool {
    guard let first = timeRangeForecasts.first,
          let last = timeRangeForecasts.last else { return false }
    return !Calendar.current.isDate(first.dateTime, inSameDayAs: last.dateTime)
  }

  var body: some View {
    VStack(spacing: 0) {
      PromiseDetailSectionHeader(title: "날씨")

      VStack(spacing: 12) {
        // 약속 시간 날씨 요약
        if let forecast = displayedForecast {
          VStack(alignment: .leading, spacing: 8) {
            Text(displayedTimeLabel)
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
        if let forecast = displayedForecast {
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

        // 행동 추천
        if !advices.isEmpty {
          Divider()
            .padding(.horizontal, 16)

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
          .padding(.bottom, 12)
        }
      }
      .adaptiveGlassCard()
    }
  }

  // MARK: - Hourly Forecast Cell

  private func hourlyForecastCell(_ forecast: HourlyForecast) -> some View {
    let isSelected = selectedForecast?.dateTime == forecast.dateTime

    return VStack(spacing: 6) {
      if spansMultipleDays {
        Text(dayString(forecast.dateTime))
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(.primary)
      }

      Text(hourString(forecast.dateTime))
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isSelected ? .primary : .secondary)

      Image(systemName: forecast.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 20))

      Text("\(Int(forecast.temperature.rounded()))°")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.primary)
    }
    .frame(width: 52)
    .padding(.vertical, 8)
    .background(
      isSelected ?
        Color.pmindigo.n500.opacity(0.15) :
        isPromiseTime(forecast.dateTime) ?
          Color.pmindigo.n500.opacity(0.08) :
          Color.clear
    )
    .overlay(
      isSelected ?
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.pmindigo.n500.opacity(0.4), lineWidth: 1.5)
        : nil
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        if isSelected {
          selectedForecast = nil
        } else {
          selectedForecast = forecast
        }
      }
    }
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

  private var displayedTimeLabel: String {
    if let selected = selectedForecast {
      let hour = Calendar.current.component(.hour, from: selected.dateTime)
      if spansMultipleDays {
        return "\(dayString(selected.dateTime)) \(hour)시"
      }
      return "\(hour)시"
    }
    return "약속 시간 (\(startAt.formattedTime))"
  }

  private func hourString(_ date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    return "\(hour)시"
  }

  private func dayString(_ date: Date) -> String {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    return "\(month)/\(day)"
  }

  private func isPromiseTime(_ date: Date) -> Bool {
    let end = endAt ?? startAt.addingTimeInterval(7200)
    return date >= startAt && date <= end
  }

}
