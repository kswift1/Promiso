import SwiftUI

/// Dot + capsule active indicator
public struct PagingIndicator: View {
  public let count: Int
  public let progress: Double // 0...(count-1) 진행도
  public var dotSize: CGFloat
  public var spacing: CGFloat
  public var inactiveOpacity: CGFloat
  public var activeColor: Color
  public var inactiveColor: Color
  public var stretchFactor: CGFloat
  
  public init(
    count: Int,
    progress: Double,
    dotSize: CGFloat = 7,
    spacing: CGFloat = 10,
    inactiveOpacity: CGFloat = 0.35,
    activeColor: Color = .primary,
    inactiveColor: Color = .primary,
    stretchFactor: CGFloat = 1.6
  ) {
    self.count = max(0, count)
    self.progress = progress
    self.dotSize = dotSize
    self.spacing = spacing
    self.inactiveOpacity = inactiveOpacity
    self.activeColor = activeColor
    self.inactiveColor = inactiveColor
    self.stretchFactor = stretchFactor
  }

  private func colorForDot(at index: Int) -> Color {
    if index < currentIndex {
      // 이미 본 페이지 - 진한 색 (visited)
      return activeColor.opacity(0.6)
    } else if index > currentIndex {
      // 안 본 페이지 - 연한 색 (unvisited)
      return inactiveColor.opacity(inactiveOpacity)
    } else {
      // 현재 페이지는 capsule로 표시되므로 기본 색상
      return inactiveColor.opacity(inactiveOpacity)
    }
  }
  
  public var body: some View {
    if count <= 1 {
      Circle()
        .fill(activeColor)
        .frame(width: dotSize, height: dotSize)
    } else {
      ZStack(alignment: .leading) {
        HStack(spacing: spacing) {
          ForEach(0..<count, id: \.self) { index in
            Circle()
              .fill(colorForDot(at: index))
              .frame(width: dotSize, height: dotSize)
          }
        }
        activeCapsule
          .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.82, blendDuration: 0.2), value: progress)
      }
      .frame(height: dotSize)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page indicator")
      .accessibilityValue("\(currentIndex + 1) of \(count)")
    }
  }
  
  private var clampedProgress: Double { min(max(progress, 0), Double(max(count - 1, 0))) }
  private var currentIndex: Int { Int(floor(clampedProgress)) }
  private var fraction: CGFloat { CGFloat(clampedProgress - Double(currentIndex)) }
  private var step: CGFloat { dotSize + spacing }
  
  private var activeCapsule: some View {
    let stretchPhase = min(fraction, 1 - fraction) * 2 // 0...1...0
    let extraWidth = step * stretchFactor * stretchPhase
    let capsuleWidth = dotSize + extraWidth
    let x = CGFloat(currentIndex) * step + (fraction * step)
    return Capsule(style: .continuous)
      .fill(
        LinearGradient(
          colors: [
            activeColor,
            activeColor.opacity(0.7)
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: capsuleWidth, height: dotSize)
      .offset(x: x)
  }
}

// Paging scroll progress helper (iOS17+)
private struct FirstPageMinXKey: PreferenceKey {
  static var defaultValue: CGFloat = .zero
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

public struct PagingProgressReader<Content: View>: View {
  public let pageCount: Int
  @Binding public var progress: Double
  private let content: () -> Content
  
  public init(pageCount: Int, progress: Binding<Double>, @ViewBuilder content: @escaping () -> Content) {
    self.pageCount = pageCount
    self._progress = progress
    self.content = content
  }
  
  public var body: some View {
    GeometryReader { proxy in
      let pageWidth = max(proxy.size.width, 1)
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          content()
        }
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.paging)
      .scrollIndicators(.hidden)
      .coordinateSpace(name: "PagingScroll")
      .overlay(alignment: .topLeading) {
        GeometryReader { geo in
          Color.clear
            .preference(
              key: FirstPageMinXKey.self,
              value: geo.frame(in: .named("PagingScroll")).minX
            )
        }
        .frame(width: 0, height: 0)
        .allowsHitTesting(false)
      }
      .onPreferenceChange(FirstPageMinXKey.self) { minX in
        let raw = -minX / pageWidth
        let clamped = min(max(raw, 0), CGFloat(max(pageCount - 1, 0)))
        progress = Double(clamped)
      }
    }
  }
}

#if DEBUG
struct PagingIndicatorDemo: View {
  private let colors: [Color] = [.red, .orange, .yellow, .green, .blue]
  @State private var progress: Double = 0
  
  var body: some View {
    VStack(spacing: 16) {
      PagingProgressReader(pageCount: colors.count, progress: $progress) {
        ForEach(colors.indices, id: \.self) { i in
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(colors[i].opacity(0.8))
            .overlay(
              Text("Page \(i + 1)")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            )
            .padding(.horizontal, 16)
            .containerRelativeFrame(.horizontal)
        }
      }
      .frame(height: 280)
      
      PagingIndicator(count: colors.count, progress: progress, activeColor: .blue)
    }
    .padding()
  }
}
#endif
