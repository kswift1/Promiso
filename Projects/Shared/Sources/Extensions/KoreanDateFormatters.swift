// MARK: - KoreanDateFormatters.swift
// 한국어 날짜 포맷터 캐시

import Foundation

/// 한국어 날짜 포맷터 캐시
/// DateFormatter 생성 비용을 줄이기 위해 싱글톤으로 관리
public enum KoreanDateFormatters {

  // MARK: - Time Format Setting

  /// 24시간 형식 사용 여부 (true: 14:30, false: 오후 2:30)
  /// 기본값: false (12시간 형식)
  public static var use24HourFormat: Bool = false {
    didSet {
      updateTimeFormatters()
    }
  }

  /// 시간 포맷터 업데이트
  private static func updateTimeFormatters() {
    let format = use24HourFormat ? "HH:mm" : "a h:mm"
    time.dateFormat = format

    let fullFormat = use24HourFormat ? "yyyy년 M월 d일 HH:mm" : "yyyy년 M월 d일 a h:mm"
    full.dateFormat = fullFormat

    let monthDayTimeFormat = use24HourFormat ? "M월 d일 HH:mm" : "M월 d일 a h:mm"
    monthDayTime.dateFormat = monthDayTimeFormat

    let shortDateTimeFormat = use24HourFormat ? "M/d(E) HH:mm" : "M/d(E) a h:mm"
    shortDateTime.dateFormat = shortDateTimeFormat

    let monthDayHourFormat = use24HourFormat ? "M월 d일 H시" : "M월 d일 a h시"
    monthDayHour.dateFormat = monthDayHourFormat
  }

  // MARK: - Cached Formatters (날짜)

  /// 섹션 헤더용 (예: "1월 15일 (수)")
  public static let sectionHeader: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E)"
    return formatter
  }()

  /// 요일만 (예: "수")
  public static let weekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "E"
    return formatter
  }()

  /// 월 (예: "1월")
  public static let month: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월"
    return formatter
  }()

  /// 일 (예: "15")
  public static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "d"
    return formatter
  }()

  /// 월일 (예: "1월 15일")
  public static let monthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter
  }()

  /// 월일 요일 (예: "1월 15일 수요일")
  public static let monthDayWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 EEEE"
    return formatter
  }()

  /// 년월 (예: "2025년 1월")
  public static let yearMonth: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월"
    return formatter
  }()

  /// 년월일 (예: "2025년 1월 15일")
  public static let yearMonthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일"
    return formatter
  }()

  /// 월 주차 (예: "1월 3주차")
  public static let monthWeek: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 W주차"
    return formatter
  }()

  /// 날짜 (예: "2025-01-15")
  public static let date: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// 날짜 점 구분 (예: "2025.1.15.")
  public static let dateDot: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy.M.d."
    return formatter
  }()

  /// 월일 + 시 (24시간: "1월 15일 14시" / 12시간: "1월 15일 오후 2시")
  public static let monthDayHour: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = use24HourFormat ? "M월 d일 H시" : "M월 d일 a h시"
    return formatter
  }()

  /// 짧은 날짜 + 시간 (24시간: "1/15(수) 14:30" / 12시간: "1/15(수) 오후 2:30")
  public static let shortDateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = use24HourFormat ? "M/d(E) HH:mm" : "M/d(E) a h:mm"
    return formatter
  }()

  // MARK: - Cached Formatters (시간) - 동적

  /// 시간 (24시간: "14:30" / 12시간: "오후 2:30")
  public static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = use24HourFormat ? "HH:mm" : "a h:mm"
    return formatter
  }()

  /// 전체 날짜시간 (24시간: "2025년 1월 15일 14:30" / 12시간: "2025년 1월 15일 오후 2:30")
  public static let full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = use24HourFormat ? "yyyy년 M월 d일 HH:mm" : "yyyy년 M월 d일 a h:mm"
    return formatter
  }()

  /// 월일 + 시간 (24시간: "1월 15일 14:30" / 12시간: "1월 15일 오후 2:30")
  public static let monthDayTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = use24HourFormat ? "M월 d일 HH:mm" : "M월 d일 a h:mm"
    return formatter
  }()

  /// 12시간 형식 시간 (숫자만, 예: "2:30")
  public static let time12Hour: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "h:mm"
    return formatter
  }()

  /// AM/PM (예: "AM", "PM")
  public static let amPm: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "a"
    return formatter
  }()

  // MARK: - Convenience Methods

  /// 시간 문자열 (예: "14:30" 또는 "오후 2:30")
  public static func timeString(from date: Date) -> String {
    time.string(from: date)
  }

  /// 월일 문자열 (예: "1월 15일")
  public static func monthDayString(from date: Date) -> String {
    monthDay.string(from: date)
  }

  /// 월일 + 시간 문자열 (예: "1월 15일 14:30")
  public static func monthDayTimeString(from date: Date) -> String {
    monthDayTime.string(from: date)
  }

  /// 오늘이 아닌 날짜의 종료 시간 표시용
  /// 오늘이면 시간만, 아니면 날짜 + 시간
  public static func endTimeString(from date: Date) -> String {
    if Calendar.current.isDateInToday(date) {
      return timeString(from: date)
    } else {
      return "\(monthDayString(from: date))\n\(timeString(from: date))"
    }
  }
}

// MARK: - Date Extension

extension Date {

  /// 해당 날짜가 속한 주의 시작일 (일요일)
  public var startOfWeek: Date {
    let calendar = Calendar.current
    let weekday = calendar.component(.weekday, from: self)
    let daysToSubtract = weekday - 1
    return calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: self)) ?? self
  }

  /// 해당 날짜가 속한 월의 시작일
  public var startOfMonth: Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: self)
    return calendar.date(from: components) ?? self
  }

  /// 해당 월의 일수
  public var daysInMonth: Int {
    let calendar = Calendar.current
    let range = calendar.range(of: .day, in: .month, for: self)
    return range?.count ?? 30
  }

  /// 해당 월 1일의 요일 (1: 일요일 ~ 7: 토요일)
  public var firstWeekdayOfMonth: Int {
    let calendar = Calendar.current
    return calendar.component(.weekday, from: startOfMonth)
  }

  // MARK: - Formatted String Properties

  /// 시간 문자열 (예: "14:30" 또는 "오후 2:30")
  public var formattedTime: String {
    KoreanDateFormatters.timeString(from: self)
  }

  /// 월일 문자열 (예: "1월 15일")
  public var formattedMonthDay: String {
    KoreanDateFormatters.monthDayString(from: self)
  }

  /// 월일 + 시간 문자열 (예: "1월 15일 14:30")
  public var formattedMonthDayTime: String {
    KoreanDateFormatters.monthDayTimeString(from: self)
  }
}
