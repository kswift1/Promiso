import SwiftUI

/// 그룹별 개인 색상 설정
/// Firestore에 hex 문자열로 저장됨
public enum GroupColor: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
  case indigo = "#5856D6"
  case purple = "#AF52DE"
  case pink = "#FF2D55"
  case blue = "#007AFF"
  case cyan = "#32ADE6"
  case teal = "#30B0C7"
  case green = "#34C759"
  case mint = "#00C7BE"
  case yellow = "#FFCC00"
  case orange = "#FF9500"
  case red = "#FF3B30"
  case brown = "#A2845E"
  case lavender = "#C4B5FD"
  case rose = "#FB7185"
  case coral = "#F97068"
  case peach = "#FDBA74"
  case sky = "#7DD3FC"
  case sage = "#86EFAC"
  case wine = "#BE123C"
  case navy = "#1E3A5F"

  /// 사용자에게 표시할 이름
  public var displayName: String {
    switch self {
    case .indigo: return "인디고"
    case .purple: return "퍼플"
    case .pink: return "핑크"
    case .blue: return "블루"
    case .cyan: return "시안"
    case .teal: return "틸"
    case .green: return "그린"
    case .mint: return "민트"
    case .yellow: return "옐로"
    case .orange: return "오렌지"
    case .red: return "레드"
    case .brown: return "브라운"
    case .lavender: return "라벤더"
    case .rose: return "로즈"
    case .coral: return "코랄"
    case .peach: return "피치"
    case .sky: return "하늘"
    case .sage: return "세이지"
    case .wine: return "와인"
    case .navy: return "네이비"
    }
  }

  /// 대표 색상 (SwiftUI)
  public var color: Color {
    Color(hex: rawValue)
  }
}

private extension Color {
  /// Hex 문자열로부터 Color 생성
  /// - Parameter hex: "#RRGGBB" 형식의 hex 문자열
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r, g, b: UInt64
    r = (int >> 16) & 0xFF
    g = (int >> 8) & 0xFF
    b = int & 0xFF

    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: 1
    )
  }
}
