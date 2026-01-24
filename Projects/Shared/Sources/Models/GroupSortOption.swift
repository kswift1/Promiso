import Foundation

/// 그룹 정렬 방식
public enum GroupSortOption: Sendable, Equatable {
  case joinedRecent               // 최신 가입순 (↓)
  case joinedOldest               // 오래된 순 (↑)
  case nameAscending              // 가나다순 (ㄱ→ㅎ)
  case nameDescending             // 가나다순 역순 (ㅎ→ㄱ)
  case custom(order: [String])    // 직접 설정 (그룹 ID 배열)

  /// 정렬 기준 (가입일/가나다/직접설정)
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
      return false
    case .joinedOldest, .nameAscending:
      return true
    case .custom:
      return true
    }
  }

  /// 토글된 옵션 반환
  public var toggled: GroupSortOption {
    switch self {
    case .joinedRecent: return .joinedOldest
    case .joinedOldest: return .joinedRecent
    case .nameAscending: return .nameDescending
    case .nameDescending: return .nameAscending
    case .custom(let order): return .custom(order: order)
    }
  }

  /// 커스텀 순서 배열 (custom이 아닌 경우 빈 배열)
  public var customOrder: [String] {
    if case .custom(let order) = self {
      return order
    }
    return []
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

// MARK: - Codable (Firestore 저장용)

extension GroupSortOption: Codable {
  private enum CodingKeys: String, CodingKey {
    case type
    case order
  }

  public init(from decoder: Decoder) throws {
    // 단순 문자열로 저장된 경우 (이전 버전 호환)
    if let container = try? decoder.singleValueContainer(),
       let typeString = try? container.decode(String.self) {
      self = Self.fromTypeString(typeString)
      return
    }

    // Object 형태로 저장된 경우
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    if type == "custom" {
      let order = try container.decodeIfPresent([String].self, forKey: .order) ?? []
      self = .custom(order: order)
    } else {
      self = Self.fromTypeString(type)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .joinedRecent:
      try container.encode("joinedRecent", forKey: .type)
    case .joinedOldest:
      try container.encode("joinedOldest", forKey: .type)
    case .nameAscending:
      try container.encode("nameAscending", forKey: .type)
    case .nameDescending:
      try container.encode("nameDescending", forKey: .type)
    case .custom(let order):
      try container.encode("custom", forKey: .type)
      try container.encode(order, forKey: .order)
    }
  }

  private static func fromTypeString(_ type: String) -> GroupSortOption {
    switch type {
    case "joinedRecent": return .joinedRecent
    case "joinedOldest": return .joinedOldest
    case "nameAscending": return .nameAscending
    case "nameDescending": return .nameDescending
    case "custom": return .custom(order: [])
    default: return .joinedRecent
    }
  }
}

// MARK: - Functions API 변환

extension GroupSortOption {
  /// Functions API용 Dictionary 반환
  public func write() -> [String: Any] {
    switch self {
    case .joinedRecent:
      return ["type": "joinedRecent"]
    case .joinedOldest:
      return ["type": "joinedOldest"]
    case .nameAscending:
      return ["type": "nameAscending"]
    case .nameDescending:
      return ["type": "nameDescending"]
    case .custom(let order):
      return ["type": "custom", "order": order]
    }
  }

  /// Functions API 응답에서 읽어서 생성
  public static func read(from data: [String: Any]?) -> GroupSortOption {
    guard let data = data,
          let type = data["type"] as? String else {
      return .joinedRecent
    }

    if type == "custom" {
      let order = data["order"] as? [String] ?? []
      return .custom(order: order)
    } else {
      return fromTypeString(type)
    }
  }
}
