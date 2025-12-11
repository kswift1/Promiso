import Foundation

public struct ColorSpec: Equatable {
  public let assetName: String
  public let lightHex: String
  public let darkHex: String?
  
  public init(assetName: String, lightHex: String, darkHex: String?) {
    self.assetName = assetName
    self.lightHex = lightHex
    self.darkHex = darkHex
  }
}

/// Color spec의 단일 소스
public let colorSpecs: [ColorSpec] = [
  // Aurora
  .init(assetName: "PMAurora.Base",    lightHex: "#F9FAFB", darkHex: "#000000"),
  .init(assetName: "PMAurora.Purple",  lightHex: "#C084FC", darkHex: "#9333EA"),
  .init(assetName: "PMAurora.Indigo",  lightHex: "#818CF8", darkHex: "#4F46E5"),
  .init(assetName: "PMAurora.Pink",    lightHex: "#F9A8D4", darkHex: "#DB2777"),
  
  // Logo Background Gradient
  .init(assetName: "LogoBg.Primary",   lightHex: "#00B8FF", darkHex: "#6366F1"),
   .init(assetName: "LogoBg.Secondary", lightHex: "#7E2BFF", darkHex: "#A855F7"),
  
  // Brand
  .init(assetName: "PMBrand.Primary",   lightHex: "#4F46E5", darkHex: "#6366F1"),
  .init(assetName: "PMBrand.Secondary", lightHex: "#7C3AED", darkHex: "#A855F7"),
  
  // Indigo Scale
  .init(assetName: "PMIndigo.n50",  lightHex: "#EEF2FF", darkHex: "#1E1B4B"),
  .init(assetName: "PMIndigo.n100", lightHex: "#E0E7FF", darkHex: "#312E81"),
  .init(assetName: "PMIndigo.n200", lightHex: "#C7D2FE", darkHex: "#3730A3"),
  .init(assetName: "PMIndigo.n300", lightHex: "#A5B4FC", darkHex: "#4338CA"),
  .init(assetName: "PMIndigo.n400", lightHex: "#818CF8", darkHex: "#4F46E5"),
  .init(assetName: "PMIndigo.n500", lightHex: "#6366F1", darkHex: "#6366F1"),
  .init(assetName: "PMIndigo.n600", lightHex: "#4F46E5", darkHex: "#818CF8"),
  .init(assetName: "PMIndigo.n700", lightHex: "#4338CA", darkHex: "#A5B4FC"),
  .init(assetName: "PMIndigo.n800", lightHex: "#3730A3", darkHex: "#C7D2FE"),
  .init(assetName: "PMIndigo.n900", lightHex: "#312E81", darkHex: "#E0E7FF"),
  
  // Purple Scale
  .init(assetName: "PMPurple.n50",  lightHex: "#FAF5FF", darkHex: "#1E1B4B"),
  .init(assetName: "PMPurple.n100", lightHex: "#F3E8FF", darkHex: "#581C87"),
  .init(assetName: "PMPurple.n200", lightHex: "#E9D5FF", darkHex: "#6B21A8"),
  .init(assetName: "PMPurple.n300", lightHex: "#D8B4FE", darkHex: "#7E22CE"),
  .init(assetName: "PMPurple.n400", lightHex: "#C084FC", darkHex: "#9333EA"),
  .init(assetName: "PMPurple.n500", lightHex: "#A855F7", darkHex: "#A855F7"),
  .init(assetName: "PMPurple.n600", lightHex: "#9333EA", darkHex: "#C084FC"),
  .init(assetName: "PMPurple.n700", lightHex: "#7E22CE", darkHex: "#D8B4FE"),
  .init(assetName: "PMPurple.n800", lightHex: "#6B21A8", darkHex: "#E9D5FF"),
  .init(assetName: "PMPurple.n900", lightHex: "#581C87", darkHex: "#F3E8FF"),
  
  // Gray Scale
  .init(assetName: "PMGray.n50",  lightHex: "#F9FAFB", darkHex: "#18181B"),
  .init(assetName: "PMGray.n100", lightHex: "#F3F4F6", darkHex: "#27272A"),
  .init(assetName: "PMGray.n200", lightHex: "#E5E7EB", darkHex: "#3F3F46"),
  .init(assetName: "PMGray.n300", lightHex: "#D1D5DB", darkHex: "#52525B"),
  .init(assetName: "PMGray.n400", lightHex: "#9CA3AF", darkHex: "#71717A"),
  .init(assetName: "PMGray.n500", lightHex: "#6B7280", darkHex: "#A1A1AA"),
  .init(assetName: "PMGray.n600", lightHex: "#4B5563", darkHex: "#D4D4D8"),
  .init(assetName: "PMGray.n700", lightHex: "#374151", darkHex: "#E4E4E7"),
  .init(assetName: "PMGray.n800", lightHex: "#1F2937", darkHex: "#F4F4F5"),
  .init(assetName: "PMGray.n900", lightHex: "#111827", darkHex: "#FAFAFA"),
  
  // Text
  .init(assetName: "PMText.Primary",   lightHex: "#111827", darkHex: "#FFFFFF"),
  .init(assetName: "PMText.Secondary", lightHex: "#6B7280", darkHex: "#9CA3AF"),
  
  // Surface
  .init(assetName: "PMSurface.Glass",  lightHex: "#FFFFFF", darkHex: "#1E1E1E"),
  
  // Semantic Colors
  .init(assetName: "PMSuccess.n50",  lightHex: "#F0FDF4", darkHex: "#052E16"),
  .init(assetName: "PMSuccess.n100", lightHex: "#DCFCE7", darkHex: "#14532D"),
  .init(assetName: "PMSuccess.n500", lightHex: "#10B981", darkHex: "#34D399"),
  .init(assetName: "PMSuccess.n600", lightHex: "#059669", darkHex: "#6EE7B7"),
  
  .init(assetName: "PMWarning.n50",  lightHex: "#FFFBEB", darkHex: "#451A03"),
  .init(assetName: "PMWarning.n100", lightHex: "#FEF3C7", darkHex: "#78350F"),
  .init(assetName: "PMWarning.n500", lightHex: "#F59E0B", darkHex: "#FBBF24"),
  .init(assetName: "PMWarning.n600", lightHex: "#D97706", darkHex: "#FCD34D"),
  
  .init(assetName: "PMError.n50",  lightHex: "#FEF2F2", darkHex: "#450A0A"),
  .init(assetName: "PMError.n100", lightHex: "#FEE2E2", darkHex: "#7F1D1D"),
  .init(assetName: "PMError.n500", lightHex: "#EF4444", darkHex: "#F87171"),
  .init(assetName: "PMError.n600", lightHex: "#DC2626", darkHex: "#FCA5A5"),
  
  .init(assetName: "PMInfo.n50",  lightHex: "#EFF6FF", darkHex: "#172554"),
  .init(assetName: "PMInfo.n100", lightHex: "#DBEAFE", darkHex: "#1E3A8A"),
  .init(assetName: "PMInfo.n500", lightHex: "#3B82F6", darkHex: "#60A5FA"),
  .init(assetName: "PMInfo.n600", lightHex: "#2563EB", darkHex: "#93C5FD")
]

#if DEBUG

import SwiftUI

struct ColorPalettePreview: View {
  private let colorGroups: [(name: String, colors: [ColorSpec])]
  
  init(colorSpecs: [ColorSpec]) {
    // 그룹별로 자동 분류
    var groups: [String: [ColorSpec]] = [:]
    
    for spec in colorSpecs {
      let groupName = spec.assetName.components(separatedBy: ".").first ?? "Other"
      groups[groupName, default: []].append(spec)
    }
    
    self.colorGroups = groups
      .map { ($0.key, $0.value.sorted { $0.assetName < $1.assetName }) }
      .sorted { $0.name < $1.name }
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        ForEach(colorGroups, id: \.name) { group in
          VStack(alignment: .leading, spacing: 12) {
            // 그룹 이름
            Text(group.name)
              .font(.headline)
              .padding(.horizontal)
            
            // 색상들
            LazyVGrid(
              columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
              ],
              spacing: 12
            ) {
              ForEach(group.colors, id: \.assetName) { spec in
                ColorSwatch(spec: spec)
              }
            }
            .padding(.horizontal)
          }
        }
      }
      .padding(.vertical)
    }
  }
}

struct ColorSwatch: View {
  let spec: ColorSpec
  
  private var displayName: String {
    spec.assetName.components(separatedBy: ".").dropFirst().joined(separator: ".")
  }
  
  var body: some View {
    VStack(spacing: 6) {
      // 색상 박스 - 라이트/다크 반반
      VStack(spacing: 0) {
        // 라이트 모드
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: spec.lightHex))
          
          Text("L")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.primary)
            .opacity(0.3)
        }
        .frame(height: 40)
        
        // 다크 모드
        ZStack {
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(hex: spec.darkHex ?? ""))
          
          Text("D")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .opacity(0.3)
        }
        .frame(height: 40)
      }
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
      )
      
      // 이름
      Text(displayName)
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }
}

private extension Color {
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
}

// MARK: - Preview

#Preview("Light Mode") {
  ColorPalettePreview(colorSpecs: colorSpecs)
}

#Preview("Dark Mode") {
  ColorPalettePreview(colorSpecs: colorSpecs)
  .preferredColorScheme(.dark)
}


#endif
