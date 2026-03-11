import Foundation

// MARK: - Expanded Event Instance

/// 반복 규칙에서 계산된 단일 인스턴스
public struct ExpandedEventInstance: Identifiable, Equatable, Hashable, Sendable {
  /// 고유 ID (recurringEventId + dateKey)
  public var id: String { "\(recurringEventId)_\(dateKey)" }

  /// 원본 반복 일정 ID
  public let recurringEventId: String
  /// 이 인스턴스의 날짜 키 ("yyyy-MM-dd")
  public let dateKey: String
  /// 시작 시각 (날짜 + 시간)
  public let startAt: Date
  /// 종료 시각
  public let endAt: Date?
  /// 제목 (override 적용됨)
  public let title: String
  /// 이모지
  public let emoji: String?
  /// 장소 (override 적용됨)
  public let location: LocationInfoModel?
  /// 리마인더 (분)
  public let reminderMinutesBefore: Int?
  /// override 적용 여부
  public let isOverridden: Bool

  public init(
    recurringEventId: String,
    dateKey: String,
    startAt: Date,
    endAt: Date?,
    title: String,
    emoji: String?,
    location: LocationInfoModel?,
    reminderMinutesBefore: Int?,
    isOverridden: Bool
  ) {
    self.recurringEventId = recurringEventId
    self.dateKey = dateKey
    self.startAt = startAt
    self.endAt = endAt
    self.title = title
    self.emoji = emoji
    self.location = location
    self.reminderMinutesBefore = reminderMinutesBefore
    self.isOverridden = isOverridden
  }
}

// MARK: - Recurring Event Expander

/// 반복 규칙을 특정 날짜 범위의 인스턴스로 확장하는 유틸리티
public enum RecurringEventExpander {
  /// 반복 일정을 특정 날짜 범위 내의 인스턴스로 확장
  /// - Parameters:
  ///   - event: 반복 일정 모델
  ///   - rangeStart: 범위 시작일 (포함)
  ///   - rangeEnd: 범위 종료일 (미포함, half-open interval)
  /// - Returns: 확장된 인스턴스 배열 (startAt 오름차순)
  public static func expand(
    event: RecurringPersonalEventModel,
    from rangeStart: Date,
    to rangeEnd: Date
  ) -> [ExpandedEventInstance] {
    let calendar = Calendar.current
    let recurrence = event.recurrence

    // 실제 시작일: seriesStartDate와 rangeStart 중 늦은 쪽
    let effectiveStart = max(event.seriesStartDate, rangeStart)

    // 실제 종료일: seriesEndDate와 rangeEnd 중 이른 쪽
    // seriesEndDate는 inclusive이므로 +1일하여 exclusive 범위로 변환
    let effectiveEnd: Date
    if let seriesEnd = recurrence.seriesEndDate {
      let dayAfterSeriesEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: seriesEnd)) ?? seriesEnd
      effectiveEnd = min(dayAfterSeriesEnd, rangeEnd)
    } else {
      effectiveEnd = rangeEnd
    }

    guard effectiveStart <= effectiveEnd else { return [] }

    // 해당 범위의 모든 날짜 생성
    let candidateDates = generateCandidateDates(
      frequency: recurrence.frequency,
      daysOfWeek: recurrence.daysOfWeek,
      dayOfMonth: recurrence.dayOfMonth,
      from: effectiveStart,
      to: effectiveEnd,
      calendar: calendar
    )

    // 인스턴스 생성
    return candidateDates.compactMap { date -> ExpandedEventInstance? in
      let key = dateKeyString(from: date, calendar: calendar)

      // excludedDates 체크
      if event.excludedDates.contains(key) { return nil }

      // override 체크
      let override = event.overrides[key]
      if override?.isCancelled == true { return nil }

      // 시작 시각 계산
      let effectiveStartTime = override?.startTime ?? event.startTime
      guard let startAt = calendar.date(
        bySettingHour: effectiveStartTime.hour ?? 0,
        minute: effectiveStartTime.minute ?? 0,
        second: 0,
        of: date
      ) else { return nil }

      // 종료 시각 계산
      let effectiveEndTime = override?.endTime ?? event.endTime
      let endAt: Date?
      if let endTime = effectiveEndTime {
        let endHour = endTime.hour ?? 0
        let endMinute = endTime.minute ?? 0
        var endDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date)!
        // 종료시간이 시작시간보다 이전이면 다음 날
        if endDate <= startAt {
          endDate = calendar.date(byAdding: .day, value: 1, to: endDate)!
        }
        endAt = endDate
      } else {
        endAt = nil
      }

      return ExpandedEventInstance(
        recurringEventId: event.id,
        dateKey: key,
        startAt: startAt,
        endAt: endAt,
        title: override?.title ?? event.title,
        emoji: event.emoji,
        location: override?.location ?? event.location,
        reminderMinutesBefore: event.reminderMinutesBefore,
        isOverridden: override != nil
      )
    }
    .sorted { $0.startAt < $1.startAt }
  }

  // MARK: - Private Helpers

  /// 반복 주기에 따른 후보 날짜 생성
  private static func generateCandidateDates(
    frequency: RecurrenceRule.Frequency,
    daysOfWeek: [Int]?,
    dayOfMonth: Int?,
    from rangeStart: Date,
    to rangeEnd: Date,
    calendar: Calendar
  ) -> [Date] {
    switch frequency {
    case .daily:
      return generateDailyDates(from: rangeStart, to: rangeEnd, calendar: calendar)

    case .weekly:
      guard let weekdays = daysOfWeek, !weekdays.isEmpty else { return [] }
      return generateWeeklyDates(
        weekdays: weekdays,
        from: rangeStart,
        to: rangeEnd,
        calendar: calendar
      )

    case .monthly:
      guard let day = dayOfMonth else { return [] }
      return generateMonthlyDates(
        dayOfMonth: day,
        from: rangeStart,
        to: rangeEnd,
        calendar: calendar
      )
    }
  }

  private static func generateDailyDates(
    from start: Date,
    to end: Date,
    calendar: Calendar
  ) -> [Date] {
    var dates: [Date] = []
    var current = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)

    while current < endDay {
      dates.append(current)
      guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
      current = next
    }
    return dates
  }

  private static func generateWeeklyDates(
    weekdays: [Int],
    from start: Date,
    to end: Date,
    calendar: Calendar
  ) -> [Date] {
    var dates: [Date] = []
    var current = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)

    while current < endDay {
      let weekday = calendar.component(.weekday, from: current)
      if weekdays.contains(weekday) {
        dates.append(current)
      }
      guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
      current = next
    }
    return dates
  }

  private static func generateMonthlyDates(
    dayOfMonth: Int,
    from start: Date,
    to end: Date,
    calendar: Calendar
  ) -> [Date] {
    var dates: [Date] = []
    guard var currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) else {
      return []
    }
    let startDay = calendar.startOfDay(for: start)
    let endDay = calendar.startOfDay(for: end)

    // 최대 24개월 반복 (안전장치)
    for _ in 0..<24 {
      let monthRange = calendar.range(of: .day, in: .month, for: currentMonth)
      // 월 오버플로우 방지 (예: 2월 31일은 생성하지 않고 건너뜀)
      if monthRange?.contains(dayOfMonth) == true {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = dayOfMonth

        if let date = calendar.date(from: components) {
          let startOfDate = calendar.startOfDay(for: date)
          if startOfDate >= startDay && startOfDate < endDay {
            dates.append(startOfDate)
          }
          if startOfDate >= endDay {
            break
          }
        }
      }

      guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { break }
      if calendar.startOfDay(for: nextMonth) >= endDay {
        break
      }
      currentMonth = nextMonth
    }
    return dates
  }

  /// Date를 "yyyy-MM-dd" 문자열로 변환
  private static func dateKeyString(from date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d",
      components.year ?? 0,
      components.month ?? 0,
      components.day ?? 0
    )
  }
}
