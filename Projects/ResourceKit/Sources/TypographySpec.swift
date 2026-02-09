import Foundation

/// Typography 스펙 정의
public struct TypographySpec: Equatable {
  public let name: String
  public let size: CGFloat
  public let weight: FontWeight

  public init(name: String, size: CGFloat, weight: FontWeight = .regular) {
    self.name = name
    self.size = size
    self.weight = weight
  }

  public enum FontWeight: String, Equatable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
  }
}

/// Typography spec의 단일 소스
/// 전체 텍스트 크기를 조정하려면 여기서 size 값만 변경하면 됩니다.
public let typographySpecs: [TypographySpec] = [
  // MARK: - Large Titles
  .init(name: "largeTitle", size: 34, weight: .bold),
  .init(name: "largeTitleSemibold", size: 34, weight: .semibold),

  // MARK: - Titles
  .init(name: "title", size: 26, weight: .bold),
  .init(name: "titleSemibold", size: 26, weight: .semibold),
  .init(name: "titleMedium", size: 26, weight: .medium),

  .init(name: "title2", size: 22, weight: .bold),
  .init(name: "title2Semibold", size: 22, weight: .semibold),
  .init(name: "title2Medium", size: 22, weight: .medium),

  .init(name: "title3", size: 20, weight: .bold),
  .init(name: "title3Semibold", size: 20, weight: .semibold),
  .init(name: "title3Medium", size: 20, weight: .medium),

  // MARK: - Body Text
  .init(name: "headline", size: 17, weight: .semibold),
  .init(name: "headlineBold", size: 17, weight: .bold),

  .init(name: "body", size: 17, weight: .regular),
  .init(name: "bodyMedium", size: 17, weight: .medium),
  .init(name: "bodySemibold", size: 17, weight: .semibold),
  .init(name: "bodyBold", size: 17, weight: .bold),

  .init(name: "callout", size: 16, weight: .regular),
  .init(name: "calloutMedium", size: 16, weight: .medium),
  .init(name: "calloutSemibold", size: 16, weight: .semibold),

  // MARK: - Secondary Text
  .init(name: "subheadline", size: 15, weight: .regular),
  .init(name: "subheadlineMedium", size: 15, weight: .medium),
  .init(name: "subheadlineSemibold", size: 15, weight: .semibold),

  .init(name: "footnote", size: 14, weight: .regular),
  .init(name: "footnoteMedium", size: 14, weight: .medium),
  .init(name: "footnoteSemibold", size: 14, weight: .semibold),

  // MARK: - Captions
  .init(name: "caption", size: 13, weight: .regular),
  .init(name: "captionMedium", size: 13, weight: .medium),
  .init(name: "captionSemibold", size: 13, weight: .semibold),

  .init(name: "caption2", size: 12, weight: .regular),
  .init(name: "caption2Medium", size: 12, weight: .medium),
  .init(name: "caption2Semibold", size: 12, weight: .semibold),

  // MARK: - Micro
  .init(name: "micro", size: 11, weight: .regular),
  .init(name: "microMedium", size: 11, weight: .medium),
  .init(name: "microSemibold", size: 11, weight: .semibold),

  .init(name: "micro2", size: 10, weight: .regular),
  .init(name: "micro2Medium", size: 10, weight: .medium),
  .init(name: "micro2Semibold", size: 10, weight: .semibold)
]

#if DEBUG

import SwiftUI

struct TypographyPalettePreview: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        ForEach(typographySpecs, id: \.name) { spec in
          HStack {
            Text("Aa")
              .font(.system(size: spec.size, weight: spec.weight.swiftUIWeight))

            Spacer()

            VStack(alignment: .trailing) {
              Text(spec.name)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text("\(Int(spec.size))pt \(spec.weight.rawValue)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
          }
          .padding(.horizontal)

          Divider()
        }
      }
      .padding(.vertical)
    }
  }
}

extension TypographySpec.FontWeight {
  var swiftUIWeight: Font.Weight {
    switch self {
    case .ultraLight: return .ultraLight
    case .thin: return .thin
    case .light: return .light
    case .regular: return .regular
    case .medium: return .medium
    case .semibold: return .semibold
    case .bold: return .bold
    case .heavy: return .heavy
    case .black: return .black
    }
  }
}

#Preview("Typography") {
  TypographyPalettePreview()
}

#endif
