import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Calendar Overlay View

/// Home 화면 위에 표시되는 캘린더 오버레이
/// 날짜 탭 시 선택된 주(row)만 남기고 나머지 행이 접히며, 해당 주가 하단으로 내려감
struct CalendarOverlayView: View {
  let availableHeight: CGFloat
  let currentMonth: Date
  let selectedDate: Date
  let prevMonthDays: [OverlayCalendarModels.DayItem]
  let days: [OverlayCalendarModels.DayItem]
  let nextMonthDays: [OverlayCalendarModels.DayItem]
  let weatherState: OverlayWeatherState
  let weatherLocationText: String?
  let detailMode: Bool
  let scheduleItems: [HomeModels.ScheduleItem]
  let prevDayScheduleItems: [HomeModels.ScheduleItem]
  let nextDayScheduleItems: [HomeModels.ScheduleItem]
  let weekDays: [OverlayCalendarModels.DayItem]
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void
  let onWeatherCardTapped: () -> Void
  let onBackToMonth: () -> Void
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void

  // MARK: - State

  // MARK: - Grid Layout Constants

  private let weekdayHeight: CGFloat = 24
  private let rowHeight: CGFloat = 44
  private let gridSpacing: CGFloat = 6

  /// detail mode에서 보이는 날짜 행 영역 (선택된 주 1행)
  private var compactGridHeight: CGFloat { rowHeight }

  /// 전체 6행 그리드 높이
  private var fullGridHeight: CGFloat { 6 * rowHeight + 5 * gridSpacing }

  private let weekdayLabels = [
    LocalizedStrings.Calendar.weekdayMon,
    LocalizedStrings.Calendar.weekdayTue,
    LocalizedStrings.Calendar.weekdayWed,
    LocalizedStrings.Calendar.weekdayThu,
    LocalizedStrings.Calendar.weekdayFri,
    LocalizedStrings.Calendar.weekdaySat,
    LocalizedStrings.Calendar.weekdaySun,
  ]

  /// 42셀을 6행으로 분할
  private var dayRows: [[OverlayCalendarModels.DayItem]] {
    stride(from: 0, to: days.count, by: 7).map {
      Array(days[$0..<min($0 + 7, days.count)])
    }
  }

  /// 선택된 날짜가 포함된 행 인덱스
  private var selectedRowIndex: Int {
    let calendar = Calendar.promiseDisplay
    return dayRows.firstIndex { row in
      row.contains { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    } ?? 0
  }

  // MARK: - Detail Week Data

  /// 이전 주 데이터 (selectedDate - 7일 기준)
  private var detailPrevWeekDays: [OverlayCalendarModels.DayItem] {
    guard let prevDate = Calendar.promiseDisplay.date(byAdding: .day, value: -7, to: selectedDate) else {
      return []
    }
    return OverlayCalendarModels.generateWeekDays(
      for: prevDate,
      selectedDate: selectedDate,
      currentMonth: currentMonth,
      scheduleCountsByDate: [:]
    )
  }

  /// 현재 주 데이터 (selectedDate 기준)
  private var detailCurrentWeekDays: [OverlayCalendarModels.DayItem] {
    OverlayCalendarModels.generateWeekDays(
      for: selectedDate,
      selectedDate: selectedDate,
      currentMonth: currentMonth,
      scheduleCountsByDate: [:]
    )
  }

  /// 다음 주 데이터 (selectedDate + 7일 기준)
  private var detailNextWeekDays: [OverlayCalendarModels.DayItem] {
    guard let nextDate = Calendar.promiseDisplay.date(byAdding: .day, value: 7, to: selectedDate) else {
      return []
    }
    return OverlayCalendarModels.generateWeekDays(
      for: nextDate,
      selectedDate: selectedDate,
      currentMonth: currentMonth,
      scheduleCountsByDate: [:]
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      // MARK: 상단 섹션 (헤더 + 일정 + 요일) — 흰색 카드, rounded bottom
      VStack(spacing: 0) {
        headerSection
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        // 일정 리스트 (항상 존재, detail mode에서 확장)
        dayScheduleList
          .frame(maxHeight: detailMode ? .infinity : 0)
          .opacity(detailMode ? 1 : 0)
          .clipped()

        // Spacer (항상 존재, detail mode에서 확장 → 그리드를 아래로 밀어냄)
        Spacer(minLength: 0)
          .frame(maxHeight: 0)

        // 요일 헤더 — 흰색 영역 하단
        weekdayHeaderRow
          .padding(.horizontal, 20)
          .padding(.bottom, 12)
      }
      .background(Color(.systemBackground))
      .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
      .background(
        UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20)
          .fill(Color(.systemBackground))
          .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
          .mask {
            VStack(spacing: 0) {
              Color.clear
              Color.black.frame(height: 20)
            }
          }
      )

      // 상단 카드 아래 인셋 그라데이션
      LinearGradient(
        colors: [Color.black.opacity(0.02), Color.clear],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 8)
      .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))

      // MARK: 하단 섹션 (날짜 그리드 + 날씨) — 회색, 꽉 채움
      if detailMode {
        detailWeekPagerView
          .padding(.horizontal, 20)
          .padding(.bottom, 8)
      } else {
        dateRowsGrid
          .padding(.horizontal, 20)
      }

      Spacer(minLength: 0)

      bottomCard
        .padding(.horizontal, 20)
        .offset(y: detailMode ? 160 : 0)
        .frame(height: detailMode ? 0 : nil)
        .opacity(detailMode ? 0 : 1)
        .padding(.bottom, 16)
    }
  }

  // MARK: - Date Rows Grid

  private var dateRowsGrid: some View {
    CalendarMonthPager(
      prevDays: prevMonthDays,
      currentDays: days,
      nextDays: nextMonthDays,
      onDateSelected: onDateSelected,
      onPreviousMonth: onPreviousMonth,
      onNextMonth: onNextMonth,
      detailMode: detailMode,
      selectedRowIndex: selectedRowIndex
    )
    .frame(height: detailMode ? compactGridHeight : fullGridHeight)
    .clipped()
  }

  // MARK: - Detail Week Pager

  private var detailWeekPagerView: some View {
    DetailWeekPager(
      prevWeekDays: detailPrevWeekDays,
      currentWeekDays: detailCurrentWeekDays,
      nextWeekDays: detailNextWeekDays,
      onDateSelected: onDateSelected,
      onPreviousWeek: {
        if let prev = Calendar.promiseDisplay.date(byAdding: .day, value: -7, to: selectedDate) {
          onDateSelected(prev)
        }
      },
      onNextWeek: {
        if let next = Calendar.promiseDisplay.date(byAdding: .day, value: 7, to: selectedDate) {
          onDateSelected(next)
        }
      }
    )
    .frame(height: rowHeight)
  }

  /// 요일 헤더 행
  private var weekdayHeaderRow: some View {
    HStack(spacing: 0) {
      ForEach(weekdayLabels.indices, id: \.self) { i in
        Text(weekdayLabels[i])
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.pmgray.n400)
          .frame(maxWidth: .infinity)
          .frame(height: weekdayHeight)
      }
    }
  }


  // MARK: - Header Section

  @ViewBuilder
  private var headerSection: some View {
    if detailMode {
      dayDetailHeader
    } else {
      calendarHeader
    }
  }

  // MARK: - Month Header

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

  // MARK: - Day Detail Header

  private var dayDetailHeader: some View {
    HStack(alignment: .top) {
      Button(action: onBackToMonth) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }

      VStack(alignment: .leading, spacing: 0) {
        Text(selectedWeekdayString)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)

        Text(selectedDateString)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(action: onClose) {
        Image(systemName: "xmark")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .adaptiveGlassBackground(cornerRadius: 16)
      }
    }
  }

  // MARK: - Day Schedule List

  private var dayScheduleList: some View {
    DayTimelinePager(
      selectedDate: selectedDate,
      prevDayScheduleItems: prevDayScheduleItems,
      currentDayScheduleItems: scheduleItems,
      nextDayScheduleItems: nextDayScheduleItems,
      onScheduleItemTapped: onScheduleItemTapped,
      onPreviousDay: {
        if let prev = Calendar.promiseDisplay.date(byAdding: .day, value: -1, to: selectedDate) {
          onDateSelected(prev)
        }
      },
      onNextDay: {
        if let next = Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: selectedDate) {
          onDateSelected(next)
        }
      }
    )
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
        SkeletonView(cornerRadius: 4)
          .frame(width: 80, height: 14)
        Spacer()
        SkeletonView(cornerRadius: 6)
          .frame(width: 100, height: 36)
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

  @ViewBuilder
  private func weatherCard(_ weather: HourlyForecast) -> some View {
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    let content = ZStack {
      weatherGradient(for: weather.condition)

      Image(systemName: weather.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 80))
        .opacity(0.3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .offset(x: 20, y: -10)

      VStack(alignment: .leading, spacing: 4) {
        Text(weather.condition.description)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.8))

        Spacer()

        HStack(alignment: .bottom, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(weather.temperature.rounded()))°C")
              .font(.system(size: 36, weight: .bold))
              .foregroundStyle(.white)
            Text(todayDateString)
              .font(.system(size: 13))
              .foregroundStyle(.white.opacity(0.7))
          }

          Spacer(minLength: 8)

          Text(weatherReferenceText(for: weather))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .truncationMode(.tail)
            .frame(maxWidth: 180, alignment: .trailing)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 130)
    .compositingGroup()
    .clipShape(shape)

    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        content
          .glassEffect(.regular, in: .rect(cornerRadius: 20))
          .clipShape(shape)
      }
      .clipShape(shape)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    } else {
      content
        .background(.ultraThinMaterial, in: shape)
        .overlay(
          shape
            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .clipShape(shape)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
  }

  private func weatherGradient(for condition: WeatherCondition) -> LinearGradient {
    switch condition {
    case .clear:
      LinearGradient(colors: [.orange.opacity(0.8), .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .cloudy:
      LinearGradient(colors: [.gray.opacity(0.6), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .overcast:
      LinearGradient(colors: [.gray.opacity(0.7), .gray.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .rain, .shower:
      LinearGradient(colors: [.blue.opacity(0.7), .indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .rainSnow, .snow:
      LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .unknown:
      LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  // MARK: - Formatters

  private enum Formatters {
    static let displayTimeZone = Calendar.promiseDisplay.timeZone

    static let year: DateFormatter = {
      let f = DateFormatter(); f.timeZone = displayTimeZone; f.dateFormat = "yyyy"; return f
    }()
    static let month: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.dateFormat = "MMMM"; return f
    }()
    static let todayDate: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.setLocalizedDateFormatFromTemplate("MMMMd"); return f
    }()
    static let weekday: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.dateFormat = "EEEE"; return f
    }()
    static let shortDate: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.setLocalizedDateFormatFromTemplate("MMMd"); return f
    }()
    static let weatherReferenceTime: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.setLocalizedDateFormatFromTemplate("j:mm"); return f
    }()
  }

  // MARK: - Computed Helpers

  private var yearString: String { Formatters.year.string(from: currentMonth) }
  private var monthString: String { Formatters.month.string(from: currentMonth) }
  private var todayDateString: String { Formatters.todayDate.string(from: Date()) }
  private var selectedWeekdayString: String { Formatters.weekday.string(from: selectedDate) }
  private var selectedDateString: String { Formatters.shortDate.string(from: selectedDate) }

  private func weatherReferenceText(for weather: HourlyForecast) -> String {
    let timeText = Formatters.weatherReferenceTime.string(from: weather.dateTime)
    let locationText = weatherLocationText?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nonEmpty ?? LocalizedStrings.Calendar.weatherCurrentLocation
    return LocalizedStrings.Calendar.weatherReference("\(timeText) · \(locationText)")
  }
}

private extension String {
  var nonEmpty: String? {
    isEmpty ? nil : self
  }
}

// MARK: - Preview

#Preview("월간") {
  CalendarOverlayView(
    availableHeight: 600,
    currentMonth: Date(),
    selectedDate: Date(),
    prevMonthDays: [],
    days: OverlayCalendarModels.generateMonthDays(
      for: Date(), selectedDate: Date(), scheduleCountsByDate: [:]
    ),
    nextMonthDays: [],
    weatherState: .loaded(HourlyForecast(
      dateTime: Date(), temperature: 14, feelsLikeTemperature: 10,
      condition: .clear, precipitationProbability: 10, humidity: 50, windSpeed: 3.0
    )),
    weatherLocationText: "서울 중구",
    detailMode: false,
    scheduleItems: [],
    prevDayScheduleItems: [],
    nextDayScheduleItems: [],
    weekDays: [],
    onClose: {}, onDateSelected: { _ in }, onPreviousMonth: {}, onNextMonth: {},
    onWeatherCardTapped: {}, onBackToMonth: {}, onScheduleItemTapped: { _ in }
  )
  .auroraBackground()
}

#Preview("일간 상세") {
  CalendarOverlayView(
    availableHeight: 600,
    currentMonth: Date(),
    selectedDate: Date(),
    prevMonthDays: [],
    days: OverlayCalendarModels.generateMonthDays(
      for: Date(), selectedDate: Date(), scheduleCountsByDate: [:]
    ),
    nextMonthDays: [],
    weatherState: .needsPermission,
    weatherLocationText: nil,
    detailMode: true,
    scheduleItems: [],
    prevDayScheduleItems: [],
    nextDayScheduleItems: [],
    weekDays: [],
    onClose: {}, onDateSelected: { _ in }, onPreviousMonth: {}, onNextMonth: {},
    onWeatherCardTapped: {}, onBackToMonth: {}, onScheduleItemTapped: { _ in }
  )
  .auroraBackground()
}
