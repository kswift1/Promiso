import PromisoShared
import SwiftUI
import UIKit

public enum GroupMain {}

// MARK: - Schedule Filter

extension GroupMain {
  /// 일정 목록 필터 (Apple Mail 스타일)
  public enum ScheduleFilter: String, CaseIterable, Sendable, CategoryFilterItem {
    case all
    case needResponse
    case responded
    case confirmed
    case past

    public var title: String {
      switch self {
      case .needResponse: return LocalizedStrings.GroupMain.filterNeedResponse
      case .responded: return LocalizedStrings.GroupMain.filterResponded
      case .confirmed: return LocalizedStrings.GroupMain.filterConfirmed
      case .all: return LocalizedStrings.GroupMain.filterAll
      case .past: return LocalizedStrings.GroupMain.filterPast
      }
    }

    public var icon: String {
      switch self {
      case .needResponse: return "envelope.badge"
      case .responded: return "clock.badge.checkmark"
      case .confirmed: return "checkmark.circle.fill"
      case .all: return "tray.fill"
      case .past: return "clock.arrow.circlepath"
      }
    }

    public var selectedColor: Color {
      switch self {
      case .needResponse: return .orange
      case .responded: return .blue
      case .confirmed: return .green
      case .all: return .pmindigo.n500
      case .past: return Color(UIColor.systemGray)
      }
    }

    public var hasSeparatorBefore: Bool {
      self == .past
    }
  }
}

// MARK: - Deeplink

extension GroupMain {
  /// 그룹 탭에서 처리할 딥링크 목적지
  public enum Deeplink: Equatable, Sendable {
    /// 그룹 상세 화면
    case group(groupId: String)
    /// 일정 상세 화면
    case schedule(scheduleId: String, groupId: String)
    /// 일정 목록에서 특정 일정으로 스크롤 (필터 적용)
    case scheduleInList(scheduleId: String, groupId: String, filter: ScheduleFilter)
  }
}

