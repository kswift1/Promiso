// MARK: - LocalizedDateFormatters.swift
// 로컬라이징된 날짜 포맷터 캐시

import Foundation

/// 로컬라이징된 날짜 포맷터 캐시
/// DateFormatter 생성 비용을 줄이기 위해 싱글톤으로 관리
public enum LocalizedDateFormatters {

  // MARK: - Time Format Setting

  /// 24시간 형식 사용 여부 (true: 14:30, false: 오후 2:30)
  /// 기본값: false (12시간 형식)
  public static var use24HourFormat: Bool = false {
    didSet {
      updateTimeFormatters()
    }
  }

  /// 현재 앱 로케일이 한국어인지 여부
  private static var isKoreanLocale: Bool {
    LocaleManager.appLocale.language.languageCode?.identifier == "ko"
  }

  /// 한국어/비한국어 로케일별 포맷 분기
  private static func localeAwareDateFormat(korean: String, nonKorean: String) -> String {
    isKoreanLocale ? korean : nonKorean
  }

  /// 시간 포맷터 업데이트
  private static func updateTimeFormatters() {
    let format = use24HourFormat ? "HH:mm" : "a h:mm"
    time.dateFormat = format

    let fullFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "yyyy년 M월 d일 HH:mm", nonKorean: "MMM d, yyyy HH:mm")
      : localeAwareDateFormat(korean: "yyyy년 M월 d일 a h:mm", nonKorean: "MMM d, yyyy h:mm a")
    full.dateFormat = fullFormat

    let monthDayTimeFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "M월 d일 HH:mm", nonKorean: "MMM d HH:mm")
      : localeAwareDateFormat(korean: "M월 d일 a h:mm", nonKorean: "MMM d h:mm a")
    monthDayTime.dateFormat = monthDayTimeFormat

    let shortDateTimeFormat = use24HourFormat ? "M/d(E) HH:mm" : "M/d(E) a h:mm"
    shortDateTime.dateFormat = shortDateTimeFormat

    let monthDayHourFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "M월 d일 H시", nonKorean: "MMM d H")
      : localeAwareDateFormat(korean: "M월 d일 a h시", nonKorean: "MMM d h a")
    monthDayHour.dateFormat = monthDayHourFormat
  }

  /// 언어 변경 시 모든 포맷터의 locale과 dateFormat을 갱신
  public static func updateLocale() {
    let locale = LocaleManager.appLocale

    // 날짜 포맷터 (locale + dateFormat 모두 갱신)
    sectionHeader.locale = locale
    sectionHeader.dateFormat = localeAwareDateFormat(korean: "M월 d일 (E)", nonKorean: "MMM d (E)")

    weekday.locale = locale
    // weekday.dateFormat = "E"  // 로케일 무관 포맷은 locale만 갱신

    month.locale = locale
    month.dateFormat = localeAwareDateFormat(korean: "M월", nonKorean: "MMM")

    day.locale = locale
    // day.dateFormat = "d"  // 로케일 무관

    monthDay.locale = locale
    monthDay.dateFormat = localeAwareDateFormat(korean: "M월 d일", nonKorean: "MMM d")

    monthDayWeekday.locale = locale
    monthDayWeekday.dateFormat = localeAwareDateFormat(korean: "M월 d일 EEEE", nonKorean: "MMM d EEEE")

    yearMonth.locale = locale
    yearMonth.dateFormat = localeAwareDateFormat(korean: "yyyy년 M월", nonKorean: "yyyy MMM")

    yearMonthDay.locale = locale
    yearMonthDay.dateFormat = localeAwareDateFormat(korean: "yyyy년 M월 d일", nonKorean: "MMM d, yyyy")

    monthWeek.locale = locale
    monthWeek.dateFormat = localeAwareDateFormat(korean: "M월 W주차", nonKorean: "MMM W")

    date.locale = locale
    dateDot.locale = locale

    // 시간 포맷터 (locale 갱신 + 기존 updateTimeFormatters로 dateFormat 갱신)
    time.locale = locale
    full.locale = locale
    monthDayTime.locale = locale
    shortDateTime.locale = locale
    monthDayHour.locale = locale
    time12Hour.locale = locale
    amPm.locale = locale

    updateTimeFormatters()
  }

  // MARK: - Cached Formatters (날짜)

  /// 섹션 헤더용 (예: "1월 15일 (수)")
  public static let sectionHeader: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "M월 d일 (E)", nonKorean: "MMM d (E)")
    return formatter
  }()

  /// 요일만 (예: "수")
  public static let weekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "E"
    return formatter
  }()

  /// 월 (예: "1월")
  public static let month: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "M월", nonKorean: "MMM")
    return formatter
  }()

  /// 일 (예: "15")
  public static let day: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "d"
    return formatter
  }()

  /// 월일 (예: "1월 15일")
  public static let monthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "M월 d일", nonKorean: "MMM d")
    return formatter
  }()

  /// 월일 요일 (예: "1월 15일 수요일")
  public static let monthDayWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "M월 d일 EEEE", nonKorean: "MMM d EEEE")
    return formatter
  }()

  /// 년월 (예: "2025년 1월")
  public static let yearMonth: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "yyyy년 M월", nonKorean: "yyyy MMM")
    return formatter
  }()

  /// 년월일 (예: "2025년 1월 15일")
  public static let yearMonthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "yyyy년 M월 d일", nonKorean: "MMM d, yyyy")
    return formatter
  }()

  /// 월 주차 (예: "1월 3주차")
  public static let monthWeek: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = localeAwareDateFormat(korean: "M월 W주차", nonKorean: "MMM W")
    return formatter
  }()

  /// 날짜 (예: "2025-01-15")
  public static let date: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// 날짜 점 구분 (예: "2025.1.15.")
  public static let dateDot: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "yyyy.M.d."
    return formatter
  }()

  /// 월일 + 시 (24시간: "1월 15일 14시" / 12시간: "1월 15일 오후 2시")
  public static let monthDayHour: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "M월 d일 H시", nonKorean: "MMM d H")
      : localeAwareDateFormat(korean: "M월 d일 a h시", nonKorean: "MMM d h a")
    return formatter
  }()

  /// 짧은 날짜 + 시간 (24시간: "1/15(수) 14:30" / 12시간: "1/15(수) 오후 2:30")
  public static let shortDateTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = use24HourFormat ? "M/d(E) HH:mm" : "M/d(E) a h:mm"
    return formatter
  }()

  // MARK: - Cached Formatters (시간) - 동적

  /// 시간 (24시간: "14:30" / 12시간: "오후 2:30")
  public static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = use24HourFormat ? "HH:mm" : "a h:mm"
    return formatter
  }()

  /// 전체 날짜시간 (24시간: "2025년 1월 15일 14:30" / 12시간: "2025년 1월 15일 오후 2:30")
  public static let full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "yyyy년 M월 d일 HH:mm", nonKorean: "MMM d, yyyy HH:mm")
      : localeAwareDateFormat(korean: "yyyy년 M월 d일 a h:mm", nonKorean: "MMM d, yyyy h:mm a")
    return formatter
  }()

  /// 월일 + 시간 (24시간: "1월 15일 14:30" / 12시간: "1월 15일 오후 2:30")
  public static let monthDayTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = use24HourFormat
      ? localeAwareDateFormat(korean: "M월 d일 HH:mm", nonKorean: "MMM d HH:mm")
      : localeAwareDateFormat(korean: "M월 d일 a h:mm", nonKorean: "MMM d h:mm a")
    return formatter
  }()

  /// 12시간 형식 시간 (숫자만, 예: "2:30")
  public static let time12Hour: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "h:mm"
    return formatter
  }()

  /// AM/PM (예: "AM", "PM")
  public static let amPm: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
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

  /// 종료 시간 텍스트 (시작 시간 기준 같은 날이면 시간만, 다른 날이면 날짜 + 시간)
  public static func endTimeString(from endDate: Date, relativeTo startDate: Date) -> String {
    if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
      return timeString(from: endDate)
    } else {
      return "\(monthDayString(from: endDate)) \(timeString(from: endDate))"
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
    LocalizedDateFormatters.timeString(from: self)
  }

  /// 월일 문자열 (예: "1월 15일")
  public var formattedMonthDay: String {
    LocalizedDateFormatters.monthDayString(from: self)
  }

  /// 월일 + 시간 문자열 (예: "1월 15일 14:30")
  public var formattedMonthDayTime: String {
    LocalizedDateFormatters.monthDayTimeString(from: self)
  }
}
