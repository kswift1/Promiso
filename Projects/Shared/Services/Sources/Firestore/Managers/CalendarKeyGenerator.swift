import Foundation

/// Firestore 달력 인덱스 생성을 위한 유틸리티 클래스
public class CalendarKeyGenerator {
  private let calendar: Calendar
  private let timeZone: TimeZone
  
  public init(
    calendar: Calendar = Calendar.current,
    timeZone: TimeZone = TimeZone(identifier: "Asia/Seoul") ?? TimeZone.current
  ) {
    self.calendar = calendar
    self.timeZone = timeZone
  }
  
  // MARK: - Date Key Generation
  
  /// YYYYMM 형식의 월 키 생성 (예: "202401")
  public func generateYyyymmKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMM"
    return formatter.string(from: date)
  }
  
  /// YYYYMMDD 형식의 일 키 생성 (예: "20240115")
  public func generateYyyymmddKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMdd"
    return formatter.string(from: date)
  }
  
  /// YYYYMMDDHH 형식의 시간 키 생성 (예: "2024011514")
  public func generateYyyymmddhhKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMddHH"
    return formatter.string(from: date)
  }
  
  /// YYYYMMDDHHMM 형식의 분 키 생성 (예: "202401151430")
  public func generateYyyymmddhhmmKey(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMddHHmm"
    return formatter.string(from: date)
  }
  
  // MARK: - Date Range Generation
  
  /// 특정 월의 모든 날짜 키 생성
  public func generateMonthKeys(for date: Date) -> [String] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: date) else {
      return []
    }
    
    var keys: [String] = []
    var currentDate = monthInterval.start
    
    while currentDate < monthInterval.end {
      keys.append(generateYyyymmddKey(for: currentDate))
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
    return keys
  }
  
  /// 특정 주의 모든 날짜 키 생성
  public func generateWeekKeys(for date: Date) -> [String] {
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
      return []
    }
    
    var keys: [String] = []
    var currentDate = weekInterval.start
    
    while currentDate < weekInterval.end {
      keys.append(generateYyyymmddKey(for: currentDate))
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
    return keys
  }
  
  /// 날짜 범위의 모든 날짜 키 생성
  public func generateDateRangeKeys(from startDate: Date, to endDate: Date) -> [String] {
    var keys: [String] = []
    var currentDate = startDate
    
    while currentDate <= endDate {
      keys.append(generateYyyymmddKey(for: currentDate))
      currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
    }
    
    return keys
  }
  
  // MARK: - Date Parsing
  
  /// YYYYMM 키에서 Date 객체 생성
  public func dateFromYyyymmKey(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMM"
    return formatter.date(from: key)
  }
  
  /// YYYYMMDD 키에서 Date 객체 생성
  public func dateFromYyyymmddKey(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMdd"
    return formatter.date(from: key)
  }
  
  /// YYYYMMDDHH 키에서 Date 객체 생성
  public func dateFromYyyymmddhhKey(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMddHH"
    return formatter.date(from: key)
  }
  
  /// YYYYMMDDHHMM 키에서 Date 객체 생성
  public func dateFromYyyymmddhhmmKey(_ key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMddHHmm"
    return formatter.date(from: key)
  }
  
  // MARK: - Utility Methods
  
  /// 오늘 날짜 키 생성
  public var todayKey: String {
    return generateYyyymmddKey(for: Date())
  }
  
  /// 이번 달 키 생성
  public var thisMonthKey: String {
    return generateYyyymmKey(for: Date())
  }
  
  /// 내일 날짜 키 생성
  public var tomorrowKey: String {
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    return generateYyyymmddKey(for: tomorrow)
  }
  
  /// 어제 날짜 키 생성
  public var yesterdayKey: String {
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    return generateYyyymmddKey(for: yesterday)
  }
  
  /// 특정 날짜가 오늘인지 확인
  public func isToday(_ date: Date) -> Bool {
    return calendar.isDateInToday(date)
  }
  
  /// 특정 날짜가 내일인지 확인
  public func isTomorrow(_ date: Date) -> Bool {
    return calendar.isDateInTomorrow(date)
  }
  
  /// 특정 날짜가 어제인지 확인
  public func isYesterday(_ date: Date) -> Bool {
    return calendar.isDateInYesterday(date)
  }
  
  /// 두 날짜가 같은 날인지 확인
  public func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    return calendar.isDate(date1, inSameDayAs: date2)
  }
  
  // MARK: - Time Zone Support
  
  /// 다른 타임존의 날짜 키 생성
  public func generateYyyymmddKey(for date: Date, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMMdd"
    return formatter.string(from: date)
  }
  
  /// 다른 타임존의 월 키 생성
  public func generateYyyymmKey(for date: Date, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "yyyyMM"
    return formatter.string(from: date)
  }
  
  /// 현재 설정된 타임존 반환
  public var currentTimeZone: TimeZone {
    return timeZone
  }
  
  /// 타임존 식별자 반환 (예: "Asia/Seoul")
  public var timeZoneIdentifier: String {
    return timeZone.identifier
  }
}
