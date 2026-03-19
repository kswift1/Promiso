import Foundation

// MARK: - Recurrence Rule

/// 반복 일정의 반복 규칙
public struct RecurrenceRule: Codable, Equatable, Hashable, Sendable {
  /// 반복 주기
  public enum Frequency: String, Codable, Sendable, CaseIterable {
    case daily      // 매일
    case weekly     // 매주
    case monthly    // 매월
  }

  /// 반복 주기
  public let frequency: Frequency

  /// 반복 요일 (weekly용)
  /// 1=일요일, 2=월요일, ..., 7=토요일 (Calendar.component(.weekday) 기준)
  public let daysOfWeek: [Int]?

  /// 반복 일자 (monthly용, 1~31)
  public let dayOfMonth: Int?

  /// 시리즈 종료일 (nil = 무기한)
  public let seriesEndDate: Date?

  public init(
    frequency: Frequency,
    daysOfWeek: [Int]? = nil,
    dayOfMonth: Int? = nil,
    seriesEndDate: Date? = nil
  ) {
    self.frequency = frequency
    self.daysOfWeek = daysOfWeek
    self.dayOfMonth = dayOfMonth
    self.seriesEndDate = seriesEndDate
  }
}

// MARK: - Factory Methods

extension RecurrenceRule {
  /// 매일 반복
  public static func daily(until endDate: Date? = nil) -> RecurrenceRule {
    RecurrenceRule(frequency: .daily, seriesEndDate: endDate)
  }

  /// 매주 특정 요일 반복
  /// - Parameter weekdays: 1=일, 2=월, 3=화, 4=수, 5=목, 6=금, 7=토
  public static func weekly(_ weekdays: [Int], until endDate: Date? = nil) -> RecurrenceRule {
    RecurrenceRule(frequency: .weekly, daysOfWeek: weekdays, seriesEndDate: endDate)
  }

  /// 매월 특정 일자 반복
  public static func monthly(day: Int, until endDate: Date? = nil) -> RecurrenceRule {
    RecurrenceRule(frequency: .monthly, dayOfMonth: day, seriesEndDate: endDate)
  }
}

// MARK: - Display

extension RecurrenceRule {
  /// 사용자에게 보여줄 반복 규칙 설명
  public var displayText: String {
    let isKoreanLocale = LocaleManager.appLocale.language.languageCode?.identifier == "ko"
    switch frequency {
    case .daily:
      return isKoreanLocale ? "매일" : "Every day"
    case .weekly:
      guard let days = daysOfWeek, !days.isEmpty else { return isKoreanLocale ? "매주" : "Every week" }
      let sorted = days.sorted()
      // 평일(월~금) / 주말(토,일) 축약
      if isKoreanLocale {
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]  // 월~금
        let weekends: Set<Int> = [1, 7]             // 일, 토
        if Set(sorted) == weekdays { return "매주 평일" }
        if Set(sorted) == weekends { return "매주 주말" }
      }
      let dayNames = sorted.compactMap { Self.weekdayName(for: $0) }
      let joined = dayNames.joined(separator: ", ")
      return isKoreanLocale ? "매주 \(joined)" : "Every \(joined)"
    case .monthly:
      guard let day = dayOfMonth else { return isKoreanLocale ? "매월" : "Every month" }
      return isKoreanLocale ? "매월 \(day)일" : "Every month on day \(day)"
    }
  }

  private static func weekdayName(for weekday: Int) -> String? {
    guard (1...7).contains(weekday) else { return nil }

    let isKoreanLocale = LocaleManager.appLocale.language.languageCode?.identifier == "ko"
    if isKoreanLocale {
      let symbols = ["일", "월", "화", "수", "목", "금", "토"]
      return symbols[weekday - 1]
    }

    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    let symbols = formatter.shortWeekdaySymbols ?? formatter.veryShortWeekdaySymbols ?? []
    guard symbols.indices.contains(weekday - 1) else { return nil }
    return symbols[weekday - 1]
  }
}
