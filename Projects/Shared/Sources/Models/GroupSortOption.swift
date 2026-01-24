import Foundation

/// 그룹 정렬 방식
public enum GroupSortOption: String, Sendable, CaseIterable, Codable {
  case joinedRecent = "최신 가입순"
  case joinedOldest = "오래된 순"
  case nameAscending = "가나다순"
  // case custom = "직접 설정"  // Phase 2에서 구현

  public var title: String {
    rawValue
  }

  public var icon: String {
    switch self {
    case .joinedRecent: return "clock.arrow.circlepath"
    case .joinedOldest: return "clock"
    case .nameAscending: return "textformat.abc"
    }
  }
}
