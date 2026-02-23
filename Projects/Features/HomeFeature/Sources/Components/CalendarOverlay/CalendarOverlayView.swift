import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Calendar Overlay View

/// Home 화면 위에 표시되는 캘린더 오버레이
struct CalendarOverlayView: View {
  let availableHeight: CGFloat
  let currentMonth: Date
  let prevMonthDays: [OverlayCalendarModels.DayItem]
  let days: [OverlayCalendarModels.DayItem]
  let nextMonthDays: [OverlayCalendarModels.DayItem]
  let weatherState: OverlayWeatherState
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void
  let onWeatherCardTapped: () -> Void

  /// 헤더(~62) + 하단카드(~140) + spacing(16*2) + padding(horizontal 20*2, bottom 20) = ~254
  private var pagerHeight: CGFloat {
    let headerHeight: CGFloat = 70
    let bottomCardHeight: CGFloat = 140
    let spacings: CGFloat = 16 * 2
    let bottomPadding: CGFloat = 20
    let fixed = headerHeight + bottomCardHeight + spacings + bottomPadding
    return max(availableHeight - fixed, 200)
  }

  var body: some View {
    VStack(spacing: 16) {
      // Header
      calendarHeader

      // Month pager (UIKit UIScrollView 기반 좌우 스와이프)
      CalendarMonthPager(
        prevDays: prevMonthDays,
        currentDays: days,
        nextDays: nextMonthDays,
        onDateSelected: onDateSelected,
        onPreviousMonth: onPreviousMonth,
        onNextMonth: onNextMonth
      )
      .frame(height: pagerHeight)

      // Bottom card (weather or permission)
      bottomCard
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  // MARK: - Calendar Header

  private var calendarHeader: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 0) {
        Text(yearString)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)

        Text(monthString)
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.primary)
      }

      Spacer()

      HStack(spacing: 12) {
        Button(action: onPreviousMonth) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }

        Button(action: onNextMonth) {
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .adaptiveGlassBackground(cornerRadius: 16)
        }
      }
    }
  }

  // MARK: - Bottom Card

  @ViewBuilder
  private var bottomCard: some View {
    switch weatherState {
    case .needsPermission:
      permissionCard

    case .loading:
      loadingCard

    case .loaded(let weather):
      weatherCard(weather)

    case .failed:
      failedCard
    }
  }

  // MARK: - Permission Card

  private var permissionCard: some View {
    Button(action: onWeatherCardTapped) {
      HStack(spacing: 14) {
        Image(systemName: "location.fill")
          .font(.system(size: 22))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 40, height: 40)
          .background(Color.pmindigo.n500.opacity(0.12))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(LocalizedStrings.Calendar.weatherPermissionTitle)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Calendar.weatherPermissionDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .adaptiveGlassCard(cornerRadius: 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Loading Card

  private var loadingCard: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(.systemGray6))

      VStack(alignment: .leading, spacing: 4) {
        // 날씨 상태 텍스트 자리
        SkeletonView(cornerRadius: 4)
          .frame(width: 80, height: 14)

        Spacer()

        // 온도 자리
        SkeletonView(cornerRadius: 6)
          .frame(width: 100, height: 36)

        // 날짜 자리
        SkeletonView(cornerRadius: 4)
          .frame(width: 120, height: 14)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 130)
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }

  // MARK: - Failed Card

  private var failedCard: some View {
    Button(action: onWeatherCardTapped) {
      HStack(spacing: 14) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 22))
          .foregroundStyle(.secondary)
          .frame(width: 40, height: 40)
          .background(Color(.systemGray5))
          .clipShape(Circle())

        Text(LocalizedStrings.Calendar.weatherPermissionTitle)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.primary)

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .adaptiveGlassCard(cornerRadius: 16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Weather Card

  private func weatherCard(_ weather: HourlyForecast) -> some View {
    ZStack {
      // Background gradient
      weatherGradient(for: weather.condition)

      // Large decorative weather icon
      Image(systemName: weather.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 80))
        .opacity(0.3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .offset(x: 20, y: -10)

      // Content
      VStack(alignment: .leading, spacing: 4) {
        Text(weather.condition.description)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.8))

        Spacer()

        Text("\(Int(weather.temperature.rounded()))°C")
          .font(.system(size: 36, weight: .bold))
          .foregroundStyle(.white)

        Text(todayDateString)
          .font(.system(size: 13))
          .foregroundStyle(.white.opacity(0.7))
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 130)
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }

  private func weatherGradient(for condition: WeatherCondition) -> LinearGradient {
    switch condition {
    case .clear:
      return LinearGradient(
        colors: [.orange.opacity(0.8), .pink.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .cloudy:
      return LinearGradient(
        colors: [.gray.opacity(0.6), .blue.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .overcast:
      return LinearGradient(
        colors: [.gray.opacity(0.7), .gray.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .rain, .shower:
      return LinearGradient(
        colors: [.blue.opacity(0.7), .indigo.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .rainSnow, .snow:
      return LinearGradient(
        colors: [.cyan.opacity(0.5), .blue.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    case .unknown:
      return LinearGradient(
        colors: [.gray.opacity(0.5), .gray.opacity(0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }

  // MARK: - Computed

  private var yearString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter.string(from: currentMonth)
  }

  private var monthString: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "MMMM"
    return formatter.string(from: currentMonth)
  }

  private var todayDateString: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.setLocalizedDateFormatFromTemplate("MMMMd")
    return formatter.string(from: Date())
  }
}

// MARK: - Preview

#Preview("날씨 로드됨") {
  CalendarOverlayView(
    availableHeight: 600,
    currentMonth: Date(),
    prevMonthDays: OverlayCalendarModels.generateMonthDays(
      for: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
      selectedDate: Date(),
      scheduleCountsByDate: [:]
    ),
    days: OverlayCalendarModels.generateMonthDays(
      for: Date(),
      selectedDate: Date(),
      scheduleCountsByDate: [:]
    ),
    nextMonthDays: OverlayCalendarModels.generateMonthDays(
      for: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
      selectedDate: Date(),
      scheduleCountsByDate: [:]
    ),
    weatherState: .loaded(HourlyForecast(
      dateTime: Date(),
      temperature: 14,
      feelsLikeTemperature: 10,
      condition: .clear,
      precipitationProbability: 10,
      humidity: 50,
      windSpeed: 3.0
    )),
    onClose: {},
    onDateSelected: { _ in },
    onPreviousMonth: {},
    onNextMonth: {},
    onWeatherCardTapped: {}
  )
  .auroraBackground()
}

#Preview("권한 필요") {
  CalendarOverlayView(
    availableHeight: 600,
    currentMonth: Date(),
    prevMonthDays: [],
    days: OverlayCalendarModels.generateMonthDays(
      for: Date(),
      selectedDate: Date(),
      scheduleCountsByDate: [:]
    ),
    nextMonthDays: [],
    weatherState: .needsPermission,
    onClose: {},
    onDateSelected: { _ in },
    onPreviousMonth: {},
    onNextMonth: {},
    onWeatherCardTapped: {}
  )
  .auroraBackground()
}
