import SwiftUI

/// 그룹별 개인 색상 설정
/// Firestore에 hex 문자열로 저장됨
public enum GroupColor: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
  case red = "#FF3B30"
  case coral = "#FF6F61"
  case orange = "#FF9500"
  case yellow = "#FFCC00"
  case lime = "#84CC16"
  case green = "#34C759"
  case mint = "#00C7BE"
  case blue = "#007AFF"
  case navy = "#1E3F8A"
  case purple = "#AF52DE"
  case lavender = "#C4B5FD"
  case magenta = "#E040FB"
  case pink = "#FF6B9D"
  case wine = "#C2185B"
  case brown = "#A0845C"
  case graphite = "#8E8E93"

  /// 사용자에게 표시할 이름
  public var displayName: String {
    switch self {
    case .red: return "레드"
    case .coral: return "코랄"
    case .orange: return "오렌지"
    case .yellow: return "옐로"
    case .lime: return "라임"
    case .green: return "그린"
    case .mint: return "민트"
    case .blue: return "블루"
    case .navy: return "네이비"
    case .purple: return "퍼플"
    case .lavender: return "라벤더"
    case .magenta: return "마젠타"
    case .pink: return "핑크"
    case .wine: return "와인"
    case .brown: return "브라운"
    case .graphite: return "그래파이트"
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
