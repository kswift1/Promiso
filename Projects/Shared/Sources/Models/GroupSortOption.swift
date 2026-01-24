import Foundation

/// 그룹 정렬 방식
public enum GroupSortOption: String, Sendable, CaseIterable, Codable {
  case joinedRecent     // 최신 가입순 (↓)
  case joinedOldest     // 오래된 순 (↑)
  case nameAscending    // 가나다순 (ㄱ→ㅎ)
  case nameDescending   // 가나다순 역순 (ㅎ→ㄱ)
  case custom           // 직접 설정

  /// 정렬 기준 (가입순/가나다순/직접설정)
  public var sortType: SortType {
    switch self {
    case .joinedRecent, .joinedOldest:
      return .joined
    case .nameAscending, .nameDescending:
      return .name
    case .custom:
      return .custom
    }
  }

  /// 정렬 방향
  public var isAscending: Bool {
    switch self {
    case .joinedRecent, .nameDescending:
      return false  // 최신부터, ㅎ부터
    case .joinedOldest, .nameAscending:
      return true   // 오래된부터, ㄱ부터
    case .custom:
      return true   // 커스텀은 방향 개념 없음
    }
  }

  /// 토글된 옵션 반환
  public var toggled: GroupSortOption {
    switch self {
    case .joinedRecent: return .joinedOldest
    case .joinedOldest: return .joinedRecent
    case .nameAscending: return .nameDescending
    case .nameDescending: return .nameAscending
    case .custom: return .custom  // 커스텀은 토글 없음
    }
  }

  /// 정렬 타입
  public enum SortType: String {
    case joined = "가입일"
    case name = "가나다"
    case custom = "직접 설정"

    public var icon: String {
      switch self {
      case .joined: return "clock"
      case .name: return "textformat.abc"
      case .custom: return "hand.draw"
      }
    }
  }
}
