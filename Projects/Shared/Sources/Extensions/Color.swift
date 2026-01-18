import SwiftUI

public extension Color {
  init(hex: String) {
    let scanner = Scanner(string: hex)
    _ = scanner.scanString("#")

    var rgb: UInt64 = 0
    scanner.scanHexInt64(&rgb)

    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >> 8) & 0xFF) / 255
    let b = Double(rgb & 0xFF) / 255

    self.init(red: r, green: g, blue: b)
  }

  // MARK: - Status Colors (for LiveActivity)
  static let statusGreen = Color(hex: "#34C759")
  static let statusOrange = Color(hex: "#FF9500")
  static let statusBlue = Color(hex: "#007AFF")
  static let statusGray = Color(hex: "#8E8E93")
}
