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
  .init(assetName: "Aurora.Base",    lightHex: "#F9FAFB", darkHex: "#000000"),
  .init(assetName: "Aurora.Purple",  lightHex: "#C084FC", darkHex: "#9333EA"),
  .init(assetName: "Aurora.Indigo",  lightHex: "#818CF8", darkHex: "#4F46E5"),
  .init(assetName: "Aurora.Pink",    lightHex: "#F9A8D4", darkHex: "#DB2777"),
  
  // Brand
  .init(assetName: "Brand.Primary",   lightHex: "#4F46E5", darkHex: "#6366F1"),
  .init(assetName: "Brand.Secondary", lightHex: "#7C3AED", darkHex: "#A855F7"),
  
  // Text
  .init(assetName: "Text.Primary",   lightHex: "#111827", darkHex: "#FFFFFF"),
  .init(assetName: "Text.Secondary", lightHex: "#6B7280", darkHex: "#9CA3AF"),
  
  // Surface
  .init(assetName: "Surface.Glass",  lightHex: "#FFFFFF", darkHex: "#1E1E1E")
]
