import Foundation

private let scheduleDisplayTimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

// MARK: - Schedule-specific Date Extensions

public extension Date {
  /// 일정 시간까지 남은 시간을 사용자 친화적으로 표시
  var timeUntilScheduleString: String {
    let interval = self.timeIntervalSinceNow
    
    if interval < 0 {
      return LocalizedStrings.DateFormat.passed
    } else if interval < 60 {
      return LocalizedStrings.DateFormat.secondsLater(Int(interval))
    } else if interval < 3600 {
      let minutes = Int(interval / 60)
      return LocalizedStrings.DateFormat.minutesLater(minutes)
    } else if interval < 86400 {
      let hours = Int(interval / 3600)
      let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
      if minutes > 0 {
        return LocalizedStrings.DateFormat.hoursMinutesLater(hours, minutes)
      } else {
        return LocalizedStrings.DateFormat.hoursLater(hours)
      }
    } else {
      let days = Int(interval / 86400)
      let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
      if hours > 0 {
        return LocalizedStrings.DateFormat.daysHoursLater(days, hours)
      } else {
        return LocalizedStrings.DateFormat.daysLater(days)
      }
    }
  }
  
  /// 일정 날짜를 표시용으로 포맷팅
  var scheduleDateString: String {
    let calendar = Calendar.scheduleDisplay
    let now = Date()
    
    if calendar.isDateInToday(self) {
      return LocalizedStrings.DateFormat.today
    } else if calendar.isDateInTomorrow(self) {
      return LocalizedStrings.DateFormat.tomorrow
    } else if calendar.isDateInYesterday(self) {
      return LocalizedStrings.DateFormat.yesterday
    } else if let daysFromNow = calendar.dateComponents([.day], from: now, to: self).day {
      if abs(daysFromNow) < 7 {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = LocaleManager.appLocale
        return formatter.string(from: self)
      }
    }

    return LocalizedDateFormatters.monthDayString(from: self)
  }
  
  /// 일정 시간을 표시용으로 포맷팅 (12/24시간 설정 적용)
  var scheduleTimeString: String {
    LocalizedDateFormatters.timeString(from: self)
  }
  
  /// 일정 날짜와 시간을 함께 표시
  var scheduleDateTimeString: String {
    let dateString = scheduleDateString
    let timeString = scheduleTimeString
    
    if dateString == LocalizedStrings.DateFormat.today || dateString == LocalizedStrings.DateFormat.tomorrow || dateString == LocalizedStrings.DateFormat.yesterday {
      return "\(dateString) \(timeString)"
    } else {
      return "\(dateString) \(timeString)"
    }
  }
  
  /// 일정이 곧 시작되는지 확인 (30분 이내)
  var isScheduleSoon: Bool {
    let interval = self.timeIntervalSinceNow
    return interval > 0 && interval <= 1800 // 30분 = 1800초
  }
  
  /// 일정이 임박했는지 확인 (15분 이내)
  var isScheduleImminent: Bool {
    let interval = self.timeIntervalSinceNow
    return interval > 0 && interval <= 900 // 15분 = 900초
  }
  
  /// 일정이 늦었는지 확인
  var isScheduleLate: Bool {
    return self.timeIntervalSinceNow < 0
  }
  
  /// 일정 시간을 기준으로 알림 시간들을 생성
  func scheduleReminderTimes(intervals: [Int] = [60, 30, 15]) -> [Date] {
    return intervals.compactMap { interval in
      self.addingTimeInterval(-Double(interval * 60))
    }.filter { $0 > Date() } // 미래 시간만 반환
  }
  
  /// 일정이 이번 주인지 확인
  var isThisWeekSchedule: Bool {
    let calendar = Calendar.current
    let now = Date()
    return calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear)
  }
  
  /// 일정이 다음 주인지 확인
  var isNextWeekSchedule: Bool {
    let calendar = Calendar.current
    guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) else {
      return false
    }
    return calendar.isDate(self, equalTo: nextWeek, toGranularity: .weekOfYear)
  }
  
  /// 일정이 이번 달인지 확인
  var isThisMonthSchedule: Bool {
    let calendar = Calendar.current
    let now = Date()
    return calendar.isDate(self, equalTo: now, toGranularity: .month)
  }
  
  /// 두 날짜 사이의 소요 시간을 한글 텍스트로 반환 (예: "1시간 30분", "2일 3시간")
  func durationText(to end: Date, prefix: String = "") -> String {
    let interval = end.timeIntervalSince(self)
    guard interval > 0 else { return "" }

    let days = Int(interval / 86400)
    let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
    let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

    var parts: [String] = []
    if days > 0 { parts.append(LocalizedStrings.DateFormat.durationDays(days)) }
    if hours > 0 { parts.append(LocalizedStrings.DateFormat.durationHours(hours)) }
    if minutes > 0 { parts.append(LocalizedStrings.DateFormat.durationMinutes(minutes)) }

    guard !parts.isEmpty else { return prefix + LocalizedStrings.DateFormat.durationMinutes(0) }
    return prefix + parts.joined(separator: " ")
  }

  /// 일정 날짜를 그룹핑하기 위한 키 생성 (YYYY-MM-DD)
  var scheduleGroupingKey: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: self)
  }
}

// MARK: - Calendar Extensions for Schedule

public extension Calendar {
  /// 일정 표시/분류용 캘린더 (KST 기준)
  static var scheduleDisplay: Calendar {
    var calendar = Calendar.current
    calendar.timeZone = scheduleDisplayTimeZone
    return calendar
  }

  /// 두 날짜가 같은 일정 그룹인지 확인 (같은 날인지)
  func isSameScheduleDay(_ date1: Date, _ date2: Date) -> Bool {
    return isDate(date1, equalTo: date2, toGranularity: .day)
  }
  
  /// 일정을 위한 주의 시작일 (월요일) 반환
  func startOfWeekForSchedule(from date: Date) -> Date {
    let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return self.date(from: components) ?? date
  }
  
  /// 일정을 위한 월의 시작일 반환
  func startOfMonthForSchedule(from date: Date) -> Date {
    let components = dateComponents([.year, .month], from: date)
    return self.date(from: components) ?? date
  }
  
  /// 일정 날짜들을 주별로 그룹핑
  func groupSchedulesByWeek<T>(_ schedules: [T], dateKeyPath: KeyPath<T, Date>) -> [Date: [T]] {
    var grouped: [Date: [T]] = [:]
    
    for schedule in schedules {
      let scheduleDate = schedule[keyPath: dateKeyPath]
      let weekStart = startOfWeekForSchedule(from: scheduleDate)
      
      if grouped[weekStart] == nil {
        grouped[weekStart] = []
      }
      grouped[weekStart]?.append(schedule)
    }
    
    return grouped
  }
  
  /// 일정 날짜들을 월별로 그룹핑
  func groupSchedulesByMonth<T>(_ schedules: [T], dateKeyPath: KeyPath<T, Date>) -> [Date: [T]] {
    var grouped: [Date: [T]] = [:]
    
    for schedule in schedules {
      let scheduleDate = schedule[keyPath: dateKeyPath]
      let monthStart = startOfMonthForSchedule(from: scheduleDate)
      
      if grouped[monthStart] == nil {
        grouped[monthStart] = []
      }
      grouped[monthStart]?.append(schedule)
    }
    
    return grouped
  }
}

// MARK: - TimeInterval Extensions for Schedule

public extension TimeInterval {
  /// 일정까지 남은 시간을 분으로 변환
  var minutesUntilSchedule: Int {
    return Int(self / 60)
  }
  
  /// 일정까지 남은 시간을 시간으로 변환
  var hoursUntilSchedule: Int {
    return Int(self / 3600)
  }
  
  /// 일정까지 남은 시간을 일로 변환
  var daysUntilSchedule: Int {
    return Int(self / 86400)
  }
  
  /// 일정 알림에 적합한 시간인지 확인
  var isValidReminderInterval: Bool {
    return self > 0 && self <= 86400 * 7 // 1주일 이내
  }
}
