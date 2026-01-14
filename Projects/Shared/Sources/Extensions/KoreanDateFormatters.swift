// MARK: - KoreanDateFormatters.swift
// 한국어 날짜 포맷터 캐시

import Foundation

/// 한국어 날짜 포맷터 캐시
/// DateFormatter 생성 비용을 줄이기 위해 싱글톤으로 관리
public enum KoreanDateFormatters {

  // MARK: - Cached Formatters

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

  /// 월일 (예: "1월 15일")
  public static let monthDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter
  }()

  /// 년월 (예: "2025년 1월")
  public static let yearMonth: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월"
    return formatter
  }()

  /// 날짜 (예: "2025-01-15")
  public static let date: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
  }()

  /// 시간 (예: "오후 3:30")
  public static let time: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter
  }()

  /// 전체 날짜시간 (예: "2025년 1월 15일 오후 3:30")
  public static let full: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
    return formatter
  }()
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
}
