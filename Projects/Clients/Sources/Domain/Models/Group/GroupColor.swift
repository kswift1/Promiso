import SwiftUI
import PromisoShared

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
    let isKoreanLocale = LocaleManager.appLocale.language.languageCode?.identifier == "ko"
    switch self {
    case .red: return isKoreanLocale ? "레드" : "Red"
    case .coral: return isKoreanLocale ? "코랄" : "Coral"
    case .orange: return isKoreanLocale ? "오렌지" : "Orange"
    case .yellow: return isKoreanLocale ? "옐로" : "Yellow"
    case .lime: return isKoreanLocale ? "라임" : "Lime"
    case .green: return isKoreanLocale ? "그린" : "Green"
    case .mint: return isKoreanLocale ? "민트" : "Mint"
    case .blue: return isKoreanLocale ? "블루" : "Blue"
    case .navy: return isKoreanLocale ? "네이비" : "Navy"
    case .purple: return isKoreanLocale ? "퍼플" : "Purple"
    case .lavender: return isKoreanLocale ? "라벤더" : "Lavender"
    case .magenta: return isKoreanLocale ? "마젠타" : "Magenta"
    case .pink: return isKoreanLocale ? "핑크" : "Pink"
    case .wine: return isKoreanLocale ? "와인" : "Wine"
    case .brown: return isKoreanLocale ? "브라운" : "Brown"
    case .graphite: return isKoreanLocale ? "그래파이트" : "Graphite"
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
