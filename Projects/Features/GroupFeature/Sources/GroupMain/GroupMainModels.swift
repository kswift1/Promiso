import PromisoShared
import ResourceKit
import SwiftUI
import UIKit

public enum GroupMain {}

// MARK: - Promise Filter

extension GroupMain {
  /// 약속 목록 필터 (Apple Mail 스타일)
  public enum PromiseFilter: String, CaseIterable, Sendable, CategoryFilterItem {
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
    /// 약속 상세 화면
    case promise(promiseId: String, groupId: String)
    /// 약속 목록에서 특정 약속으로 스크롤 (필터 적용)
    case promiseInList(promiseId: String, groupId: String, filter: PromiseFilter)
  }
}

// MARK: - Onboarding
// TODO: onboarding - 추후 고도화 필요 (튜토리얼, 샘플 데이터 등)

extension GroupMain {
  /// 온보딩용 Mock 그룹 ID
  static let onboardingGroupId = "__onboarding__"

  /// 온보딩 카드 타입
  public enum OnboardingCard: CaseIterable, Identifiable {
    case createGroup
    case joinGroup

    public var id: Self { self }

    var title: String {
      switch self {
      case .createGroup: return LocalizedStrings.GroupMain.createGroupCard
      case .joinGroup: return LocalizedStrings.GroupMain.joinGroupCard
      }
    }

    var subtitle: String {
      switch self {
      case .createGroup: return LocalizedStrings.GroupMain.createGroupCardSubtitle
      case .joinGroup: return LocalizedStrings.GroupMain.joinGroupCardSubtitle
      }
    }

    var icon: String {
      switch self {
      case .createGroup: return "person.3.fill"
      case .joinGroup: return "link.circle.fill"
      }
    }

    var color: Color {
      switch self {
      case .createGroup: return .blue
      case .joinGroup: return .green
      }
    }
  }
}
