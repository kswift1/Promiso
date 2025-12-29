import SwiftUI
import ResourceKit

/// 여러 줄 텍스트를 순차적으로 타이핑 애니메이션으로 보여주는 뷰.
public struct TypewriterLinesView: View {
  
  public struct LineStyle: Equatable {
    public let text: String
    public let font: Font
    public let style: AnyShapeStyle
    
    public init(text: String, font: Font, style: AnyShapeStyle) {
      self.text = text
      self.font = font
      self.style = style
    }
    
    public static func == (lhs: LineStyle, rhs: LineStyle) -> Bool {
      lhs.text == rhs.text && lhs.font == rhs.font
    }
  }
  
  let animated: Bool?
  let lines: [LineStyle]
  var typingAnimationCompleted: () -> Void
  var lineSpacingProvider: (Int) -> CGFloat
  var typingSpeed: Double
  var lineDelayProvider: (Int) -> Double

  @State private var currentLine = 0

  public init(
    animated: Bool?,
    lines: [LineStyle],
    typingAnimationCompleted: @escaping () -> Void,
    lineSpacingProvider: @escaping (Int) -> CGFloat = { _ in return 4 },
    typingSpeed: Double = 0.05,
    lineDelayProvider: @escaping (Int) -> Double = { _ in return 0.3 }
  ) {
    self.animated = animated
    self.lines = lines
    self.typingAnimationCompleted = typingAnimationCompleted
    self.lineSpacingProvider = lineSpacingProvider
    self.typingSpeed = typingSpeed
    self.lineDelayProvider = lineDelayProvider
  }
  
  @ViewBuilder
  public var body: some View {
    if let animated = animated {
      VStack(alignment: .leading, spacing: 0) {
        if animated {
          ForEach(0..<currentLine + 1, id: \.self) { index in
            if index < lines.count {
              let line = lines[index]
              if index == currentLine {
                TypewriterText(
                  text: line.text,
                  font: line.font,
                  style: line.style,
                  animated: animated
                ) {
                  if index < lines.count - 1 {
                    let extraDelay = lineDelayProvider(index)
                    DispatchQueue.main.asyncAfter(deadline: .now() + extraDelay) {
                      currentLine += 1
                    }
                  } else {
                    typingAnimationCompleted()
                  }
                }
                .padding(.bottom, spacingForLine(index))
              } else {
                Text(line.text)
                  .font(line.font)
                  .foregroundStyle(line.style)
                  .padding(.bottom, spacingForLine(index))
              }
            }
          }
        } else {
          ForEach(0..<lines.count, id: \.self) { index in
            Text(lines[index].text)
              .font(lines[index].font)
              .foregroundStyle(lines[index].style)
              .padding(.bottom, spacingForLine(index))
          }
        }
      }
      .onAppear {
        if !animated {
          typingAnimationCompleted()
        }
      }
    } else {
      EmptyView()
    }
  }
  
  private func spacingForLine(_ index: Int) -> CGFloat {
    lineSpacingProvider(index)
  }
}

/// 단일 타이핑 라인
public struct TypewriterText: View {
  public let text: String
  public let speed: Double
  public let font: Font
  public let style: AnyShapeStyle
  public let animated: Bool
  public var onComplete: () -> Void
  
  @State private var displayedText = ""
  @State private var showCursor = true
  
  public init(
    text: String,
    speed: Double = 0.05,
    font: Font,
    style: AnyShapeStyle,
    animated: Bool,
    onComplete: @escaping () -> Void
  ) {
    self.text = text
    self.speed = speed
    self.font = font
    self.style = style
    self.animated = animated
    self.onComplete = onComplete
  }
  
  public var body: some View {
    Text(displayedText + (animated && displayedText.count < text.count && showCursor ? "|" : ""))
      .font(font)
      .foregroundStyle(style)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      if animated {
        showCursor = true
        typeText()
      } else {
        displayedText = text
        onComplete()
      }
    }
  }
  
  private func typeText() {
    displayedText = ""
    for (index, character) in text.enumerated() {
      DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * speed) {
        displayedText.append(character)
        if index == text.count - 1 {
          onComplete()
        }
      }
    }
  }
}

#if DEBUG
#Preview {
  TypewriterLinesView(
    animated: true,
    lines: [
      .init(text: "약속을", font: .system(size: 32, weight: .bold), style: AnyShapeStyle(Color.primary)),
      .init(text: "더 특별하게.", font: .system(size: 32, weight: .bold), style: AnyShapeStyle(Color.blue)),
      .init(text: "소중한 순간들을", font: .system(size: 16, weight: .medium), style: AnyShapeStyle(Color.secondary)),
      .init(text: "Promiso와 함께하세요.", font: .system(size: 16, weight: .medium), style: AnyShapeStyle(Color.secondary))
    ],
    typingAnimationCompleted: {}
  )
  .padding()
}
#endif
