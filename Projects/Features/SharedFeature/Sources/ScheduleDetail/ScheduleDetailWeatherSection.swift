import SwiftUI
import PromisoShared

// MARK: - Schedule Detail Weather Section (Level 3)

/// 일정 상세보기 날씨 섹션 - 행동 추천 + 일정 시간 요약 + 시간대별 예보
public struct ScheduleDetailWeatherSection: View {
  let weatherInfo: WeatherInfo
  let startAt: Date
  let endAt: Date?

  @State private var selectedForecast: HourlyForecast?
  @State private var selectedDailyForecast: DailyForecast?

  public init(weatherInfo: WeatherInfo, startAt: Date, endAt: Date?) {
    self.weatherInfo = weatherInfo
    self.startAt = startAt
    self.endAt = endAt
  }

  // MARK: - Short-term Computed Properties

  private var isMidTerm: Bool {
    weatherInfo.forecastSource(for: startAt) == .midTerm
  }

  private var displayedForecast: HourlyForecast? {
    selectedForecast ?? targetForecast
  }

  private var targetForecast: HourlyForecast? {
    if let endAt = endAt, endAt.timeIntervalSince(startAt) >= 7200 {
      return weatherInfo.worstCaseForecast(from: startAt, to: endAt)
    }
    return weatherInfo.forecast(for: startAt)
  }

  private var timeRangeForecasts: [HourlyForecast] {
    let end = endAt ?? startAt
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

  // MARK: - Mid-term Computed Properties

  private var targetDailyForecast: DailyForecast? {
    let calendar = Calendar.current
    return weatherInfo.dailyForecasts.first(where: {
      calendar.isDate($0.date, inSameDayAs: startAt)
    })
  }

  private var nearbyDailyForecasts: [DailyForecast] {
    let calendar = Calendar.current
    guard let targetIndex = weatherInfo.dailyForecasts.firstIndex(where: {
      calendar.isDate($0.date, inSameDayAs: startAt)
    }) else {
      return weatherInfo.dailyForecasts
    }
    let start = max(0, targetIndex - 1)
    let end = min(weatherInfo.dailyForecasts.count, targetIndex + 4)
    return Array(weatherInfo.dailyForecasts[start..<end])
  }

  // MARK: - Body

  public var body: some View {
    VStack(spacing: 0) {
      ScheduleDetailSectionHeader(title: LocalizedStrings.Weather.sectionTitle)

      VStack(spacing: 12) {
        if isMidTerm {
          midTermContent
        } else {
          shortTermContent
        }
      }
      .adaptiveGlassCard()
    }
  }

  // MARK: - Short-term Content

  @ViewBuilder
  private var shortTermContent: some View {
    // 일정 시간 날씨 요약
    if let forecast = displayedForecast {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Text(displayedTimeLabel)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

          Spacer()

          Text(LocalizedStrings.Weather.shortTermSource)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
        }

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

            Text(LocalizedStrings.Weather.feelsLike(Int(forecast.feelsLikeTemperature.rounded())))
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }

          Spacer()

          Text(LocalizedStrings.Weather.precipitation(forecast.precipitationProbability))
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
        Text(LocalizedStrings.Weather.hourlyForecast)
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
          label: LocalizedStrings.Weather.feelsLikeLabel,
          value: "\(Int(forecast.feelsLikeTemperature.rounded()))°"
        )

        Divider()
          .frame(height: 24)

        detailItem(
          label: LocalizedStrings.Weather.humidity,
          value: "\(forecast.humidity)%"
        )

        Divider()
          .frame(height: 24)

        detailItem(
          label: LocalizedStrings.Weather.wind,
          value: String(format: "%.1fm/s", forecast.windSpeed)
        )
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Mid-term Content

  private var displayedDaily: DailyForecast? {
    selectedDailyForecast ?? targetDailyForecast
  }

  @ViewBuilder
  private var midTermContent: some View {
    if let daily = displayedDaily {
      // 상단 요약
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 4) {
          Text(midTermTimeLabel)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

          Spacer()

          Text(LocalizedStrings.Weather.midTermSource)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
        }

        HStack(spacing: 16) {
          Image(systemName: daily.representativeCondition.sfSymbolName)
            .symbolRenderingMode(.multicolor)
            .font(.system(size: 32))

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
              Text("\(Int(daily.minTemperature.rounded()))°")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.blue)
              Text("/")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tertiary)
              Text("\(Int(daily.maxTemperature.rounded()))°")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
              Label(daily.amCondition.description, systemImage: daily.amCondition.sfSymbolName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
              Text("→")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
              Label(daily.pmCondition.description, systemImage: daily.pmCondition.sfSymbolName)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
          }

          Spacer()

          Text(LocalizedStrings.Weather.precipitation(daily.maxPrecipitationProbability))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(daily.maxPrecipitationProbability >= 50 ? .blue : .secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      // 일별 예보 (수평 스크롤)
      if nearbyDailyForecasts.count > 1 {
        Divider()
          .padding(.horizontal, 16)

        VStack(alignment: .leading, spacing: 8) {
          Text(LocalizedStrings.Weather.dailyForecast)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(Array(nearbyDailyForecasts.enumerated()), id: \.offset) { _, forecast in
                dailyForecastCell(forecast)
              }
            }
            .padding(.horizontal, 16)
          }
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var midTermTimeLabel: String {
    if let selected = selectedDailyForecast {
      return "\(dayString(selected.date)) (\(weekdayString(selected.date)))"
    }
    return LocalizedStrings.Weather.scheduleTime(startAt.formattedMonthDayTime)
  }

  // MARK: - Daily Forecast Cell

  private func dailyForecastCell(_ forecast: DailyForecast) -> some View {
    let calendar = Calendar.current
    let isTarget = calendar.isDate(forecast.date, inSameDayAs: startAt)
    let isSelected = selectedDailyForecast?.date == forecast.date

    let highlighted = isSelected || (selectedDailyForecast == nil && isTarget)

    return VStack(spacing: 6) {
      Text(dayString(forecast.date))
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(highlighted ? .primary : .secondary)

      Text(weekdayString(forecast.date))
        .font(.system(size: 10))
        .foregroundStyle(highlighted ? Color.pmindigo.n500 : Color(.tertiaryLabel))

      Image(systemName: forecast.representativeCondition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 20))

      VStack(spacing: 1) {
        Text("\(Int(forecast.maxTemperature.rounded()))°")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.red.opacity(0.8))

        Text("\(Int(forecast.minTemperature.rounded()))°")
          .font(.system(size: 12))
          .foregroundStyle(.blue.opacity(0.8))
      }
    }
    .frame(width: 52)
    .padding(.vertical, 8)
    .background(
      highlighted ? Color.pmindigo.n500.opacity(0.12) : Color.clear
    )
    .overlay(
      highlighted ?
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.pmindigo.n500.opacity(0.3), lineWidth: 1.5)
        : nil
    )
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        if isSelected {
          selectedDailyForecast = nil
        } else {
          selectedDailyForecast = forecast
        }
      }
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
        isScheduleTime(forecast.dateTime) ?
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
        return "\(dayString(selected.dateTime)) \(LocalizedStrings.Weather.hourLabel(hour))"
      }
      return LocalizedStrings.Weather.hourLabel(hour)
    }
    return LocalizedStrings.Weather.scheduleTime(startAt.formattedTime)
  }

  private func hourString(_ date: Date) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    return LocalizedStrings.Weather.hourLabel(hour)
  }

  private func dayString(_ date: Date) -> String {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    return "\(month)/\(day)"
  }

  private func weekdayString(_ date: Date) -> String {
    LocalizedDateFormatters.weekday.string(from: date)
  }

  private func isScheduleTime(_ date: Date) -> Bool {
    let end = endAt ?? startAt
    return date >= startAt && date <= end
  }

}
