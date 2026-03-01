import Foundation

private let promiseDisplayTimeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

// MARK: - Promise-specific Date Extensions

public extension Date {
  /// 약속 시간까지 남은 시간을 사용자 친화적으로 표시
  var timeUntilPromiseString: String {
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
  
  /// 약속 날짜를 표시용으로 포맷팅
  var promiseDateString: String {
    let calendar = Calendar.promiseDisplay
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
  
  /// 약속 시간을 표시용으로 포맷팅 (12/24시간 설정 적용)
  var promiseTimeString: String {
    LocalizedDateFormatters.timeString(from: self)
  }
  
  /// 약속 날짜와 시간을 함께 표시
  var promiseDateTimeString: String {
    let dateString = promiseDateString
    let timeString = promiseTimeString
    
    if dateString == LocalizedStrings.DateFormat.today || dateString == LocalizedStrings.DateFormat.tomorrow || dateString == LocalizedStrings.DateFormat.yesterday {
      return "\(dateString) \(timeString)"
    } else {
      return "\(dateString) \(timeString)"
    }
  }
  
  /// 약속이 곧 시작되는지 확인 (30분 이내)
  var isPromiseSoon: Bool {
    let interval = self.timeIntervalSinceNow
    return interval > 0 && interval <= 1800 // 30분 = 1800초
  }
  
  /// 약속이 임박했는지 확인 (15분 이내)
  var isPromiseImminent: Bool {
    let interval = self.timeIntervalSinceNow
    return interval > 0 && interval <= 900 // 15분 = 900초
  }
  
  /// 약속이 늦었는지 확인
  var isPromiseLate: Bool {
    return self.timeIntervalSinceNow < 0
  }
  
  /// 약속 시간을 기준으로 알림 시간들을 생성
  func promiseReminderTimes(intervals: [Int] = [60, 30, 15]) -> [Date] {
    return intervals.compactMap { interval in
      self.addingTimeInterval(-Double(interval * 60))
    }.filter { $0 > Date() } // 미래 시간만 반환
  }
  
  /// 약속이 이번 주인지 확인
  var isThisWeekPromise: Bool {
    let calendar = Calendar.current
    let now = Date()
    return calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear)
  }
  
  /// 약속이 다음 주인지 확인
  var isNextWeekPromise: Bool {
    let calendar = Calendar.current
    guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) else {
      return false
    }
    return calendar.isDate(self, equalTo: nextWeek, toGranularity: .weekOfYear)
  }
  
  /// 약속이 이번 달인지 확인
  var isThisMonthPromise: Bool {
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

  /// 약속 날짜를 그룹핑하기 위한 키 생성 (YYYY-MM-DD)
  var promiseGroupingKey: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: self)
  }
}

// MARK: - Calendar Extensions for Promise

public extension Calendar {
  /// 약속 표시/분류용 캘린더 (KST 기준)
  static var promiseDisplay: Calendar {
    var calendar = Calendar.current
    calendar.timeZone = promiseDisplayTimeZone
    return calendar
  }

  /// 두 날짜가 같은 약속 그룹인지 확인 (같은 날인지)
  func isSamePromiseDay(_ date1: Date, _ date2: Date) -> Bool {
    return isDate(date1, equalTo: date2, toGranularity: .day)
  }
  
  /// 약속을 위한 주의 시작일 (월요일) 반환
  func startOfWeekForPromise(from date: Date) -> Date {
    let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return self.date(from: components) ?? date
  }
  
  /// 약속을 위한 월의 시작일 반환
  func startOfMonthForPromise(from date: Date) -> Date {
    let components = dateComponents([.year, .month], from: date)
    return self.date(from: components) ?? date
  }
  
  /// 약속 날짜들을 주별로 그룹핑
  func groupPromisesByWeek<T>(_ promises: [T], dateKeyPath: KeyPath<T, Date>) -> [Date: [T]] {
    var grouped: [Date: [T]] = [:]
    
    for promise in promises {
      let promiseDate = promise[keyPath: dateKeyPath]
      let weekStart = startOfWeekForPromise(from: promiseDate)
      
      if grouped[weekStart] == nil {
        grouped[weekStart] = []
      }
      grouped[weekStart]?.append(promise)
    }
    
    return grouped
  }
  
  /// 약속 날짜들을 월별로 그룹핑
  func groupPromisesByMonth<T>(_ promises: [T], dateKeyPath: KeyPath<T, Date>) -> [Date: [T]] {
    var grouped: [Date: [T]] = [:]
    
    for promise in promises {
      let promiseDate = promise[keyPath: dateKeyPath]
      let monthStart = startOfMonthForPromise(from: promiseDate)
      
      if grouped[monthStart] == nil {
        grouped[monthStart] = []
      }
      grouped[monthStart]?.append(promise)
    }
    
    return grouped
  }
}

// MARK: - TimeInterval Extensions for Promise

public extension TimeInterval {
  /// 약속까지 남은 시간을 분으로 변환
  var minutesUntilPromise: Int {
    return Int(self / 60)
  }
  
  /// 약속까지 남은 시간을 시간으로 변환
  var hoursUntilPromise: Int {
    return Int(self / 3600)
  }
  
  /// 약속까지 남은 시간을 일로 변환
  var daysUntilPromise: Int {
    return Int(self / 86400)
  }
  
  /// 약속 알림에 적합한 시간인지 확인
  var isValidReminderInterval: Bool {
    return self > 0 && self <= 86400 * 7 // 1주일 이내
  }
}
