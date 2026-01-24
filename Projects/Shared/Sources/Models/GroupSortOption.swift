import Foundation

/// 그룹 정렬 방식
public enum GroupSortOption: String, Sendable, CaseIterable, Codable {
  case joinedRecent
  case joinedOldest
  case nameAscending
  // case custom  // Phase 2에서 구현

  public var title: String {
    switch self {
    case .joinedRecent: return "최신 가입순"
    case .joinedOldest: return "오래된 순"
    case .nameAscending: return "가나다순"
    }
  }

  public var icon: String {
    switch self {
    case .joinedRecent: return "clock.arrow.circlepath"
    case .joinedOldest: return "clock"
    case .nameAscending: return "textformat.abc"
    }
  }
}
