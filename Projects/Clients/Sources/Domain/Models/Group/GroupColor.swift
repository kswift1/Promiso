import SwiftUI

/// 그룹별 개인 색상 설정
/// Firestore에 rawValue(String)로 저장됨
public enum GroupColor: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
  case indigo
  case purple
  case pink
  case blue
  case cyan
  case teal
  case green
  case mint
  case yellow
  case orange
  case red
  case brown

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
    }
  }

  /// 대표 색상 (SwiftUI)
  public var color: Color {
    switch self {
    case .indigo: return .indigo
    case .purple: return .purple
    case .pink: return .pink
    case .blue: return .blue
    case .cyan: return .cyan
    case .teal: return .teal
    case .green: return .green
    case .mint: return .mint
    case .yellow: return .yellow
    case .orange: return .orange
    case .red: return .red
    case .brown: return .brown
    }
  }
}
