import Foundation
import PromisoShared

// MARK: - Overlay Weather State

/// 캘린더 오버레이 하단 날씨 카드 상태
enum OverlayWeatherState: Equatable, Sendable {
  /// 위치 권한 미부여 (탭하면 권한 요청)
  case needsPermission
  /// 날씨 로딩 중
  case loading
  /// 날씨 로드 완료
  case loaded(HourlyForecast)
  /// 날씨 로드 실패
  case failed
}

// MARK: - Calendar Mode

/// 캘린더 오버레이 표시 모드
enum CalendarMode: Equatable, Sendable {
  /// 월간 달력 (6행 그리드 + 날씨 카드)
  case monthly
  /// 주간 달력 (선택된 주 1행 + 일정 리스트)
  case weekly
}

// MARK: - Overlay Calendar Models

enum OverlayCalendarModels {
  /// 오버레이 캘린더에서 표시할 날짜 셀 데이터
  struct DayItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let scheduleCount: Int

    init(
      date: Date,
      dayNumber: Int,
      isCurrentMonth: Bool = true,
      isSelected: Bool = false,
      isToday: Bool = false,
      scheduleCount: Int = 0
    ) {
      self.id = "\(dayNumber)-\(isCurrentMonth)"
      self.date = date
      self.dayNumber = dayNumber
      self.isCurrentMonth = isCurrentMonth
      self.isSelected = isSelected
      self.isToday = isToday
      self.scheduleCount = scheduleCount
    }
  }

  /// 시간대 구분
  enum TimePeriod: String, CaseIterable {
    case morning
    case afternoon
    case night

    var displayTitle: String {
      switch self {
      case .morning: return LocalizedStrings.Calendar.dayPeriodMorning
      case .afternoon: return LocalizedStrings.Calendar.dayPeriodAfternoon
      case .night: return LocalizedStrings.Calendar.dayPeriodNight
      }
    }

    var tintColor: TimePeriodColor {
      switch self {
      case .morning: return .morning
      case .afternoon: return .afternoon
      case .night: return .night
      }
    }

    static func from(hour: Int) -> TimePeriod {
      switch hour {
      case 0..<12: return .morning
      case 12..<18: return .afternoon
      default: return .night
      }
    }
  }

  /// 시간대별 색상 테마
  enum TimePeriodColor {
    case morning, afternoon, night
  }

  /// 선택된 날짜가 속한 주의 7일을 추출 (월요일 시작)
  static func extractWeekDays(
    from monthDays: [DayItem],
    selectedDate: Date
  ) -> [DayItem] {
    let calendar = Calendar.promiseDisplay
    // 42셀 = 6행 × 7열, 선택된 날짜의 행(row) 찾기
    guard let index = monthDays.firstIndex(where: {
      calendar.isDate($0.date, inSameDayAs: selectedDate)
    }) else {
      // 선택된 날짜가 현재 월에 없으면 첫 주 반환
      return Array(monthDays.prefix(7))
    }
    let rowStart = (index / 7) * 7
    let rowEnd = min(rowStart + 7, monthDays.count)
    return Array(monthDays[rowStart..<rowEnd])
  }

  /// selectedDate 기준으로 해당 주의 7일 DayItem 배열 생성 (월요일 시작)
  /// - Parameters:
  ///   - date: 기준 날짜 (이 날짜가 포함된 주를 생성)
  ///   - selectedDate: 현재 선택된 날짜 (isSelected 표시용)
  ///   - currentMonth: 현재 표시 중인 월 (isCurrentMonth 판단용)
  ///   - scheduleCountsByDate: 날짜별 일정 개수
  static func generateWeekDays(
    for date: Date,
    selectedDate: Date,
    currentMonth: Date,
    scheduleCountsByDate: [Date: Int]
  ) -> [DayItem] {
    let calendar = Calendar.promiseDisplay
    let today = Date()

    // 해당 주의 월요일 찾기
    // weekday: 일=1, 월=2, ..., 토=7
    let weekday = calendar.component(.weekday, from: date)
    let daysFromMonday = (weekday - 2 + 7) % 7
    guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) else {
      return []
    }

    return (0..<7).compactMap { offset in
      guard let dayDate = calendar.date(byAdding: .day, value: offset, to: monday) else {
        return nil
      }
      let dayNumber = calendar.component(.day, from: dayDate)
      let isCurrentMonth = calendar.isDate(dayDate, equalTo: currentMonth, toGranularity: .month)
      let dateKey = calendar.startOfDay(for: dayDate)
      let count = scheduleCountsByDate[dateKey] ?? 0

      return DayItem(
        date: dayDate,
        dayNumber: dayNumber,
        isCurrentMonth: isCurrentMonth,
        isSelected: calendar.isDate(dayDate, inSameDayAs: selectedDate),
        isToday: calendar.isDate(dayDate, inSameDayAs: today),
        scheduleCount: count
      )
    }
  }

  /// 현재 월의 날짜 배열을 생성
  static func generateMonthDays(
    for date: Date,
    selectedDate: Date,
    scheduleCountsByDate: [Date: Int]
  ) -> [DayItem] {
    let calendar = Calendar.promiseDisplay
    let today = Date()

    guard let monthInterval = calendar.dateInterval(of: .month, for: date),
          let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
    else { return [] }

    var days: [DayItem] = []

    // 월요일 시작 기준 오프셋 계산 (일=1, 월=2, ..., 토=7)
    // 월요일 시작이므로: 월=0, 화=1, ..., 일=6
    let offset = (firstWeekday - 2 + 7) % 7

    // 이전 월 placeholder
    if offset > 0 {
      for i in stride(from: offset, through: 1, by: -1) {
        if let prevDate = calendar.date(byAdding: .day, value: -i, to: monthInterval.start) {
          let dayNum = calendar.component(.day, from: prevDate)
          days.append(DayItem(
            date: prevDate,
            dayNumber: dayNum,
            isCurrentMonth: false
          ))
        }
      }
    }

    // 현재 월
    let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    for day in 1...daysInMonth {
      if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
        let dateKey = calendar.startOfDay(for: dayDate)
        let count = scheduleCountsByDate[dateKey] ?? 0
        days.append(DayItem(
          date: dayDate,
          dayNumber: day,
          isCurrentMonth: true,
          isSelected: calendar.isDate(dayDate, inSameDayAs: selectedDate),
          isToday: calendar.isDate(dayDate, inSameDayAs: today),
          scheduleCount: count
        ))
      }
    }

    // 다음 월 placeholder (42셀 = 6행으로 고정)
    let remaining = 42 - days.count
    if remaining > 0 {
      let lastDate = monthInterval.end
      for i in 0..<remaining {
        if let nextDate = calendar.date(byAdding: .day, value: i, to: lastDate) {
          let dayNum = calendar.component(.day, from: nextDate)
          days.append(DayItem(
            date: nextDate,
            dayNumber: dayNum,
            isCurrentMonth: false
          ))
        }
      }
    }

    return days
  }
}
