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
  let weatherInfo: WeatherInfo?
  let calendarMode: CalendarMode
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
  let onCreatePersonalEvent: (Date) -> Void
  let onCreatePromise: () -> Void
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]

  @State private var timelineZoomState = TimelineZoomState()

  private var isWeekly: Bool { calendarMode == .weekly }
  private var isWeatherDetail: Bool { calendarMode == .weatherDetail }

  // MARK: - Grid Layout Constants

  private let weekdayHeight: CGFloat = 24
  private let rowHeight: CGFloat = 46
  private let gridSpacing: CGFloat = 4

  /// weekly 모드에서 보이는 날짜 행 영역 (선택된 주 1행)
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
      // MARK: 상단 섹션 (헤더 + 일정/날씨상세 + 요일) — 흰색 카드, rounded bottom
      VStack(spacing: 0) {
        headerSection
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        // 일정 리스트 (항상 존재, weekly 모드에서 확장)
        dayScheduleList
          .frame(maxHeight: isWeekly ? .infinity : 0)
          .opacity(isWeekly ? 1 : 0)
          .clipped()

        // 날씨 상세 (항상 존재, weatherDetail 모드에서 확장 — 위에서 내려오는 효과)
        if isWeatherDetail {
          weatherDetailContent
            .padding(.horizontal, 20)
        } else {
          weatherDetailContent
            .padding(.horizontal, 20)
            .frame(maxHeight: 0)
            .opacity(0)
            .clipped()
        }

        // Spacer (항상 존재, weekly 모드에서 확장 → 그리드를 아래로 밀어냄)
        Spacer(minLength: 0)
          .frame(maxHeight: 0)

        // 요일 헤더 — 흰색 영역 하단 (weatherDetail 모드에서 축소)
        weekdayHeaderRow
          .padding(.horizontal, 20)
          .padding(.bottom, isWeatherDetail ? 0 : 12)
          .frame(height: isWeatherDetail ? 0 : nil)
          .opacity(isWeatherDetail ? 0 : 1)
          .clipped()
      }
      .background(isWeatherDetail ? Color(.secondarySystemBackground) : Color(.systemBackground))
      .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: isWeatherDetail ? 0 : 20, bottomTrailingRadius: isWeatherDetail ? 0 : 20))
      .background(
        UnevenRoundedRectangle(bottomLeadingRadius: isWeatherDetail ? 0 : 20, bottomTrailingRadius: isWeatherDetail ? 0 : 20)
          .fill(Color(.systemBackground))
          .shadow(color: .black.opacity(isWeatherDetail ? 0 : 0.06), radius: 8, x: 0, y: 4)
          .mask {
            VStack(spacing: 0) {
              Color.clear
              Color.black.frame(height: 20)
            }
          }
      )

      // 상단 카드 아래 인셋 그라데이션
      if !isWeatherDetail {
        LinearGradient(
          colors: [Color.black.opacity(0.02), Color.clear],
          startPoint: .top,
          endPoint: .bottom
        )
        .frame(height: 8)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
      }

      // MARK: 하단 섹션 (날짜 그리드 + 날씨) — 회색, 꽉 채움
      if isWeekly {
        detailWeekPagerView
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
      } else {
        VStack(spacing: 0) {
          dateRowsGrid
            .padding(.horizontal, 20)

          Spacer(minLength: 0)

          bottomCard
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: isWeatherDetail ? 0 : .infinity)
        .opacity(isWeatherDetail ? 0 : 1)
        .clipped()
      }
    }
    .background(Color(.secondarySystemBackground))
  }

  // MARK: - Date Rows Grid

  private var dateRowsGrid: some View {
    CalendarMonthPager(
      prevDays: prevMonthDays,
      currentDays: days,
      nextDays: nextMonthDays,
      onDateSelected: onDateSelected,
      onCreatePersonalEvent: onCreatePersonalEvent,
      onCreatePromise: onCreatePromise,
      onPreviousMonth: onPreviousMonth,
      onNextMonth: onNextMonth,
      calendarMode: calendarMode,
      selectedRowIndex: selectedRowIndex
    )
    .frame(height: isWeekly ? compactGridHeight : fullGridHeight)
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
    .frame(height: 56)
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
    if isWeatherDetail {
      weatherDetailHeader
    } else if isWeekly {
      dayDetailHeader
    } else {
      calendarHeader
    }
  }

  // MARK: - Month Header

  private var calendarHeader: some View {
    HStack(alignment: .center) {
      Text(yearMonthString)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.primary)
        .contentTransition(.numericText())
        .animation(.spring(duration: 0.3), value: currentMonth)

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
          .contentTransition(.numericText())

        Text(selectedDateString)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.secondary)
          .contentTransition(.numericText())
      }
      .animation(.spring(duration: 0.3), value: selectedDate)

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
      },
      onCreatePersonalEvent: onCreatePersonalEvent,
      onCreatePromise: onCreatePromise,
      calendarMode: calendarMode,
      currentUserId: currentUserId,
      weatherCache: weatherCache,
      groupColorMap: groupColorMap,
      zoomState: timelineZoomState
    )
  }


  // MARK: - Bottom Card

  @ViewBuilder
  private var bottomCard: some View {
    switch weatherState {
    case .needsPermission:
      permissionCard
    case .denied:
      deniedCard
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
      ZStack(alignment: .bottomTrailing) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "location.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 40, height: 40)
            .background(Color.pmindigo.n500.opacity(0.12))
            .clipShape(Circle())

          Spacer()

          Text(LocalizedStrings.Calendar.weatherPermissionTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Calendar.weatherPermissionDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
          .frame(width: 32, height: 32)
          .adaptiveGlassBackground(cornerRadius: 16)
          .padding(12)
      }
      .frame(height: 130)
      .adaptiveGlassCard(cornerRadius: 20)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Denied Card

  private var deniedCard: some View {
    Button(action: onWeatherCardTapped) {
      ZStack(alignment: .bottomTrailing) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "location.slash.fill")
            .font(.system(size: 22))
            .foregroundStyle(Color.pmerror.n500)
            .frame(width: 40, height: 40)
            .background(Color.pmerror.n500.opacity(0.12))
            .clipShape(Circle())

          Spacer()

          Text(LocalizedStrings.Calendar.weatherDeniedTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Calendar.weatherDeniedDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "gearshape")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .adaptiveGlassBackground(cornerRadius: 16)
          .padding(12)
      }
      .frame(height: 130)
      .adaptiveGlassCard(cornerRadius: 20)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Loading Card

  private var loadingCard: some View {
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
    .frame(height: 130)
    .adaptiveGlassCard(cornerRadius: 20)
  }

  // MARK: - Failed Card

  private var failedCard: some View {
    Button(action: onWeatherCardTapped) {
      ZStack(alignment: .bottomTrailing) {
        VStack(alignment: .leading, spacing: 8) {
          Image(systemName: "cloud.slash")
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
            .frame(width: 40, height: 40)
            .background(Color(.systemGray5))
            .clipShape(Circle())

          Spacer()

          Text(LocalizedStrings.Calendar.weatherFailedTitle)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Text(LocalizedStrings.Calendar.weatherFailedDescription)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "arrow.clockwise")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .adaptiveGlassBackground(cornerRadius: 16)
          .padding(12)
      }
      .frame(height: 130)
      .adaptiveGlassCard(cornerRadius: 20)
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
        if let tip = WeatherSuggestion.from(forecast: weather).first {
          HStack(spacing: 6) {
            Image(systemName: tip.icon)
              .font(.system(size: 11))
            Text(tip.message)
              .font(.system(size: 11, weight: .medium))
              .lineLimit(1)
          }
          .foregroundStyle(.white.opacity(0.8))
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(.white.opacity(0.15))
          .clipShape(Capsule())
        }

        Spacer()

        HStack(alignment: .bottom, spacing: 12) {
          VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Text(weather.condition.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
              Text("\(Int(weather.temperature.rounded()))°")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            }
            if let info = weatherInfo,
               let (low, high) = todayTemperatureRange(from: info) {
              Text("↑\(Int(high.rounded()))°  ↓\(Int(low.rounded()))°")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            }
          }

          Spacer(minLength: 8)

          Text(weatherReferenceText(for: weather))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.8)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(height: 130)
    .compositingGroup()
    .clipShape(shape)

    Button(action: onWeatherCardTapped) {
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
    .buttonStyle(.plain)
  }

  // MARK: - Weather Detail Header

  private var weatherDetailHeader: some View {
    HStack(alignment: .top) {
      Button(action: onBackToMonth) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }

      VStack(alignment: .leading, spacing: 0) {
        Text(LocalizedStrings.Calendar.weatherDetailTitle)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)

        if let locationText = weatherLocationText {
          Text(locationText)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.secondary)
        }
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

  // MARK: - Weather Detail Content

  @ViewBuilder
  private var weatherDetailContent: some View {
    if let info = weatherInfo, case .loaded(let current) = weatherState {
      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 16) {
          weatherDetailInfoBar(current, info: info)

          let dailySummaries = buildDailySummaries(from: info)
          if !dailySummaries.isEmpty {
            weatherDailySection(dailySummaries)
          }
        }
      }
    }
  }

  private func weatherDetailInfoBar(_ forecast: HourlyForecast, info: WeatherInfo) -> some View {
    let todayMinMax = todayTemperatureRange(from: info)

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 24))

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(.primary)

        Text(forecast.condition.description)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.secondary)

        Spacer()

        if let (low, high) = todayMinMax {
          Text("↑\(Int(high.rounded()))° ↓\(Int(low.rounded()))°")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }

      HStack(spacing: 16) {
        Label(
          LocalizedStrings.Calendar.weatherFeelsLike("\(Int(forecast.feelsLikeTemperature.rounded()))°"),
          systemImage: "thermometer.medium"
        )
        Label("\(forecast.humidity)%", systemImage: "humidity.fill")
        Label(
          String(format: "%.1fm/s", forecast.windSpeed),
          systemImage: "wind"
        )
      }
      .font(.system(size: 12, weight: .medium))
      .foregroundStyle(.secondary)
    }
    .padding(16)
    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
  }

  /// hourlyForecasts를 일별로 그룹핑하여 DailyForecast 배열 생성
  /// hourlyForecasts가 비어있으면 dailyForecasts fallback
  private func buildDailySummaries(from info: WeatherInfo) -> [DailyForecast] {
    // dailyForecasts가 이미 있으면 그대로 사용
    if !info.dailyForecasts.isEmpty {
      return info.dailyForecasts
    }

    // hourlyForecasts를 날짜별로 그룹핑
    let calendar = Calendar.promiseDisplay
    let grouped = Dictionary(grouping: info.hourlyForecasts) { forecast in
      calendar.startOfDay(for: forecast.dateTime)
    }

    return grouped.keys.sorted().compactMap { day -> DailyForecast? in
      guard let forecasts = grouped[day], forecasts.count >= 2 else { return nil }

      let minTemp = forecasts.map(\.temperature).min() ?? 0
      let maxTemp = forecasts.map(\.temperature).max() ?? 0
      let maxPrecip = forecasts.map(\.precipitationProbability).max() ?? 0

      // 가장 심각한 날씨 상태를 대표 조건으로
      let worstCondition = forecasts.map(\.condition)
        .max(by: { conditionSeverity($0) < conditionSeverity($1) }) ?? .unknown

      return DailyForecast(
        date: day,
        minTemperature: minTemp,
        maxTemperature: maxTemp,
        amCondition: worstCondition,
        pmCondition: worstCondition,
        amPrecipitationProbability: maxPrecip,
        pmPrecipitationProbability: maxPrecip
      )
    }
  }

  private func conditionSeverity(_ condition: WeatherCondition) -> Int {
    switch condition {
    case .clear: return 0
    case .cloudy: return 1
    case .overcast: return 2
    case .shower: return 3
    case .rain: return 4
    case .rainSnow: return 5
    case .snow: return 6
    case .unknown: return -1
    }
  }

  private func todayTemperatureRange(from info: WeatherInfo) -> (min: Double, max: Double)? {
    let calendar = Calendar.promiseDisplay
    let today = Date()

    // 1. dailyForecasts에서 오늘 데이터 확인
    if let daily = info.dailyForecasts.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
      return (daily.minTemperature, daily.maxTemperature)
    }

    // 2. hourlyForecasts에서 오늘 데이터로 계산
    let todayForecasts = info.hourlyForecasts.filter { calendar.isDate($0.dateTime, inSameDayAs: today) }
    guard todayForecasts.count >= 2 else { return nil }

    let minTemp = todayForecasts.map(\.temperature).min() ?? 0
    let maxTemp = todayForecasts.map(\.temperature).max() ?? 0
    return (minTemp, maxTemp)
  }

  private func weatherDailySection(_ forecasts: [DailyForecast]) -> some View {
    let calendar = Calendar.promiseDisplay
    let today = Date()

    return VStack(alignment: .leading, spacing: 12) {
      Text(LocalizedStrings.Calendar.weatherWeeklyTitle)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.primary)

      VStack(spacing: 0) {
        ForEach(Array(forecasts.enumerated()), id: \.offset) { index, daily in
          HStack(spacing: 0) {
            Text(dailyRowLabel(for: daily.date, today: today, calendar: calendar))
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.primary)
              .frame(width: 36, alignment: .leading)

            Image(systemName: daily.representativeCondition.sfSymbolName)
              .symbolRenderingMode(.multicolor)
              .font(.system(size: 18))
              .frame(width: 28)

            if daily.maxPrecipitationProbability > 0 {
              Text("\(daily.maxPrecipitationProbability)%")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 36, alignment: .leading)
            } else {
              Spacer().frame(width: 36)
            }

            Spacer()

            Text("\(Int(daily.minTemperature.rounded()))°")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)

            Text(" / ")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)

            Text("\(Int(daily.maxTemperature.rounded()))°")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.primary)
          }
          .padding(.vertical, 10)

          if index < forecasts.count - 1 {
            Divider().padding(.horizontal, 4)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 4)
      .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
  }

  private func dailyRowLabel(for date: Date, today: Date, calendar: Calendar) -> String {
    if calendar.isDate(date, inSameDayAs: today) {
      return LocalizedStrings.Calendar.weatherToday
    } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              calendar.isDate(date, inSameDayAs: tomorrow) {
      return LocalizedStrings.Calendar.weatherTomorrow
    } else {
      return Formatters.shortWeekday.string(from: date)
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
    static let yearMonth: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.setLocalizedDateFormatFromTemplate("yyyyMMMM"); return f
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
    static let hourOnly: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.setLocalizedDateFormatFromTemplate("j"); return f
    }()
    static let shortWeekday: DateFormatter = {
      let f = DateFormatter(); f.locale = .current; f.timeZone = displayTimeZone; f.dateFormat = "E"; return f
    }()
  }

  // MARK: - Computed Helpers

  private var yearString: String { Formatters.year.string(from: currentMonth) }
  private var monthString: String { Formatters.month.string(from: currentMonth) }
  private var yearMonthString: String { Formatters.yearMonth.string(from: currentMonth) }
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
    weatherInfo: nil,
    calendarMode: .monthly,
    scheduleItems: [],
    prevDayScheduleItems: [],
    nextDayScheduleItems: [],
    weekDays: [],
    onClose: {}, onDateSelected: { _ in }, onPreviousMonth: {}, onNextMonth: {},
    onWeatherCardTapped: {}, onBackToMonth: {}, onScheduleItemTapped: { _ in },
    onCreatePersonalEvent: { _ in }, onCreatePromise: {},
    currentUserId: "preview-user",
    weatherCache: [:],
    groupColorMap: [:]
  )
  .auroraBackground()
}

#Preview("주간 상세") {
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
    weatherInfo: nil,
    calendarMode: .weekly,
    scheduleItems: [],
    prevDayScheduleItems: [],
    nextDayScheduleItems: [],
    weekDays: [],
    onClose: {}, onDateSelected: { _ in }, onPreviousMonth: {}, onNextMonth: {},
    onWeatherCardTapped: {}, onBackToMonth: {}, onScheduleItemTapped: { _ in },
    onCreatePersonalEvent: { _ in }, onCreatePromise: {},
    currentUserId: "preview-user",
    weatherCache: [:],
    groupColorMap: [:]
  )
  .auroraBackground()
}
