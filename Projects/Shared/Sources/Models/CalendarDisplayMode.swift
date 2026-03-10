// MARK: - CalendarDisplayMode.swift
// 캘린더 표시 모드 (공유 모듈)

import Foundation

// MARK: - Calendar Display Mode

/// 캘린더 표시 모드 (3가지 모드)
public enum CalendarDisplayMode: String, Equatable, Sendable, CaseIterable {
  case week = "week"
  case month = "month"
  case monthExpanded = "monthExpanded"

  /// 다음 모드 (순환: week → month → monthExpanded → week)
  public var next: CalendarDisplayMode {
    switch self {
    case .week: return .month
    case .month: return .monthExpanded
    case .monthExpanded: return .week
    }
  }

  /// 모드별 SF Symbol 이름
  public var iconName: String {
    switch self {
    case .week: return "calendar.day.timeline.left"
    case .month: return "calendar"
    case .monthExpanded: return "square.grid.3x3"
    }
  }

  /// 모드 표시 이름
  public var label: String {
    switch self {
    case .week: return LocalizedStrings.Calendar.modeWeek
    case .month: return LocalizedStrings.Calendar.modeMonth
    case .monthExpanded: return LocalizedStrings.Calendar.modeMonthExpanded
    }
  }

  /// 설정 화면용 설명
  public var settingsDescription: String {
    switch self {
    case .week: return LocalizedStrings.Calendar.modeWeekDescription
    case .month: return LocalizedStrings.Calendar.modeMonthDescription
    case .monthExpanded: return LocalizedStrings.Calendar.modeMonthExpandedDescription
    }
  }

  /// 월간 모드인지 여부
  public var isMonthMode: Bool {
    self == .month || self == .monthExpanded
  }
}
