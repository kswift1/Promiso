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
  let detailMode: Bool
  let scheduleItems: [HomeModels.ScheduleItem]
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
    let calendar = Calendar.current
    return dayRows.firstIndex { row in
      row.contains { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    } ?? 0
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
          .frame(maxHeight: detailMode ? .infinity : 0)

        // 요일 헤더 — 흰색 영역 하단
        weekdayHeaderRow
          .padding(.horizontal, 20)
          .padding(.bottom, 12)
      }
      .background(Color(.systemBackground))
      .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))

      // MARK: 하단 섹션 (날짜 그리드 + 날씨) — 회색, 꽉 채움
      dateRowsGrid
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, detailMode ? 8 : 0)

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
    ScrollView {
      VStack(spacing: 12) {
        let grouped = groupedByTimePeriod
        ForEach(OverlayCalendarModels.TimePeriod.allCases, id: \.self) { period in
          if let items = grouped[period], !items.isEmpty {
            timePeriodSection(period: period, items: items)
          }
        }

        if scheduleItems.isEmpty {
          emptyScheduleView
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Time Period Section

  private func timePeriodSection(
    period: OverlayCalendarModels.TimePeriod,
    items: [HomeModels.ScheduleItem]
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(period.displayTitle)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(periodTitleColor(period))
        .padding(.leading, 4)

      VStack(spacing: 8) {
        ForEach(items) { item in
          Button {
            onScheduleItemTapped(item)
          } label: {
            scheduleItemRow(item)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(14)
      .background(periodBackgroundColor(period))
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }

  // MARK: - Schedule Item Row

  private func scheduleItemRow(_ item: HomeModels.ScheduleItem) -> some View {
    HStack(spacing: 12) {
      Text(item.displayEmoji)
        .font(.system(size: 24))
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        HStack(spacing: 6) {
          Text(timeString(for: item.startAt))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

          if let name = itemGroupName(item) {
            Text("·")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)

            Text(name)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
  }

  // MARK: - Empty Schedule

  private var emptyScheduleView: some View {
    VStack(spacing: 12) {
      Image(systemName: "calendar.badge.clock")
        .font(.system(size: 36))
        .foregroundStyle(.tertiary)

      Text(LocalizedStrings.Calendar.noSchedules)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
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

  private func weatherCard(_ weather: HourlyForecast) -> some View {
    ZStack {
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

  // MARK: - Computed Helpers

  private var yearString: String {
    let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: currentMonth)
  }

  private var monthString: String {
    let f = DateFormatter(); f.locale = .current; f.dateFormat = "MMMM"; return f.string(from: currentMonth)
  }

  private var todayDateString: String {
    let f = DateFormatter(); f.locale = .current; f.setLocalizedDateFormatFromTemplate("MMMMd"); return f.string(from: Date())
  }

  private var selectedWeekdayString: String {
    let f = DateFormatter(); f.locale = .current; f.dateFormat = "EEEE"; return f.string(from: selectedDate)
  }

  private var selectedDateString: String {
    let f = DateFormatter(); f.locale = .current; f.setLocalizedDateFormatFromTemplate("MMMd"); return f.string(from: selectedDate)
  }

  private var groupedByTimePeriod: [OverlayCalendarModels.TimePeriod: [HomeModels.ScheduleItem]] {
    Dictionary(grouping: scheduleItems) { item in
      OverlayCalendarModels.TimePeriod.from(hour: Calendar.current.component(.hour, from: item.startAt))
    }
  }

  private func timeString(for date: Date) -> String {
    let f = DateFormatter(); f.locale = .current; f.dateFormat = "a h:mm"; return f.string(from: date)
  }

  private func itemGroupName(_ item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p): return p.group?.name
    case .personalEvent: return nil
    }
  }

  private func periodTitleColor(_ period: OverlayCalendarModels.TimePeriod) -> Color {
    switch period {
    case .morning: Color(.systemGreen)
    case .afternoon: Color(.systemBlue)
    case .night: Color(.systemIndigo)
    }
  }

  private func periodBackgroundColor(_ period: OverlayCalendarModels.TimePeriod) -> Color {
    switch period {
    case .morning: Color(.systemGreen).opacity(0.08)
    case .afternoon: Color(.systemBlue).opacity(0.08)
    case .night: Color(.systemIndigo).opacity(0.08)
    }
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
    detailMode: false,
    scheduleItems: [],
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
    detailMode: true,
    scheduleItems: [],
    weekDays: [],
    onClose: {}, onDateSelected: { _ in }, onPreviousMonth: {}, onNextMonth: {},
    onWeatherCardTapped: {}, onBackToMonth: {}, onScheduleItemTapped: { _ in }
  )
  .auroraBackground()
}
