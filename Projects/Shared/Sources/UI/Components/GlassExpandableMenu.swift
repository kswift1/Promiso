import SwiftUI

// MARK: - Glass Menu Animation Type

public enum GlassMenuAnimationType: String, CaseIterable, Sendable {
  case bouncy
  case smooth
  case snappy

  public var animation: Animation {
    switch self {
    case .bouncy: .bouncy(duration: 0.55, extraBounce: 0.05)
    case .smooth: .smooth(duration: 0.55, extraBounce: 0.05)
    case .snappy: .snappy(duration: 0.55, extraBounce: 0.05)
    }
  }
}

// MARK: - Expandable Glass Menu

/// iOS 26 Liquid Glass 스타일의 확장 가능한 메뉴 컴포넌트
/// 작은 버튼이 스프링 애니메이션으로 패널로 확장되며 morphing 효과 적용
///
/// Usage:
/// ```swift
/// @State private var progress: CGFloat = 0
///
/// GlassExpandableMenu(
///   alignment: .bottomTrailing,
///   progress: progress
/// ) {
///   // Expanded content
///   VStack {
///     Button("Action 1") { }
///     Button("Action 2") { }
///   }
/// } label: {
///   // Collapsed label (FAB button)
///   Image(systemName: "plus")
///     .frame(width: 56, height: 56)
///     .onTapGesture {
///       withAnimation(.bouncy) { progress = 1 }
///     }
/// }
/// ```
public struct GlassExpandableMenu<Content: View, Label: View>: View, Animatable {
  public var alignment: Alignment
  public var progress: CGFloat
  public var labelSize: CGSize
  public var cornerRadius: CGFloat
  public var labelBackgroundColor: Color?
  @ViewBuilder public var content: Content
  @ViewBuilder public var label: Label

  @State private var contentSize: CGSize = .zero

  public var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  /// - Parameters:
  ///   - labelBackgroundColor: iOS 26 미만에서 collapsed 상태의 배경색 (nil이면 material 사용)
  public init(
    alignment: Alignment,
    progress: CGFloat,
    labelSize: CGSize = .init(width: 56, height: 56),
    cornerRadius: CGFloat = 28,
    labelBackgroundColor: Color? = nil,
    @ViewBuilder content: () -> Content,
    @ViewBuilder label: () -> Label
  ) {
    self.alignment = alignment
    self.progress = progress
    self.labelSize = labelSize
    self.cornerRadius = cornerRadius
    self.labelBackgroundColor = labelBackgroundColor
    self.content = content()
    self.label = label()
  }

  public var body: some View {
    if #available(iOS 26, *) {
      iOS26Content
    } else {
      fallbackContent
    }
  }

  // MARK: - iOS 26+ Glass Effect

  @available(iOS 26, *)
  private var iOS26Content: some View {
    GlassEffectContainer {
      morphingContent
        .clipShape(dynamicShape)
        .glassEffect(.regular, in: dynamicShape)
    }
    .scaleEffect(
      x: 1 - (blurProgress * 0.35),
      y: 1 + (blurProgress * 0.45),
      anchor: scaleAnchor
    )
    .offset(y: offset * blurProgress)
  }

  // MARK: - Fallback (iOS 25 이하)

  private var fallbackContent: some View {
    morphingContent
      .background {
        ZStack {
          // Material background (expanded)
          dynamicShape
            .fill(.ultraThinMaterial)
            .opacity(progress)

          // Solid color background (collapsed)
          if let bgColor = labelBackgroundColor {
            dynamicShape
              .fill(bgColor)
              .opacity(1 - progress)
          } else {
            dynamicShape
              .fill(.ultraThinMaterial)
              .opacity(1 - progress)
          }
        }
      }
      .clipShape(dynamicShape)
      .scaleEffect(
        x: 1 - (blurProgress * 0.35),
        y: 1 + (blurProgress * 0.45),
        anchor: scaleAnchor
      )
      .offset(y: offset * blurProgress)
      .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
  }

  /// collapsed(원형) ↔ expanded(둥근 사각형) 자연스러운 전환
  private var dynamicShape: RoundedRectangle {
    // progress 0: cornerRadius = labelSize.width/2 (원형)
    // progress 1: cornerRadius = cornerRadius (둥근 사각형)
    let circleRadius = min(labelSize.width, labelSize.height) / 2
    let currentRadius = circleRadius + (cornerRadius - circleRadius) * progress
    return RoundedRectangle(cornerRadius: currentRadius)
  }

  // MARK: - Morphing Content

  @ViewBuilder
  private var morphingContent: some View {
    let widthDiff = contentSize.width - labelSize.width
    let heightDiff = contentSize.height - labelSize.height

    let rWidth = widthDiff * contentOpacity
    let rHeight = heightDiff * contentOpacity

    ZStack(alignment: alignment) {
      content
        .compositingGroup()
        .scaleEffect(contentScale)
        .blur(radius: 14 * blurProgress)
        .opacity(contentOpacity)
        .background {
          GeometryReader { geo in
            Color.clear
              .onAppear { contentSize = geo.size }
              .onChange(of: geo.size) { _, newValue in contentSize = newValue }
          }
        }
        .fixedSize()
        .frame(
          width: labelSize.width + rWidth,
          height: labelSize.height + rHeight
        )

      label
        .compositingGroup()
        .blur(radius: 14 * blurProgress)
        .opacity(1 - labelOpacity)
        .frame(width: labelSize.width, height: labelSize.height)
    }
    .compositingGroup()
  }

  // MARK: - Animation Properties

  private var labelOpacity: CGFloat {
    min(progress / 0.35, 1)
  }

  private var contentOpacity: CGFloat {
    max(progress - 0.35, 0) / 0.65
  }

  private var contentScale: CGFloat {
    guard contentSize.width > 0, contentSize.height > 0 else { return 1 }
    let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
    return minAspectScale + (1 - minAspectScale) * progress
  }

  private var blurProgress: CGFloat {
    // 0 -> 0.5 -> 0
    progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
  }

  private var offset: CGFloat {
    switch alignment {
    case .bottom, .bottomLeading, .bottomTrailing: return -80
    case .top, .topLeading, .topTrailing: return 80
    default: return 0
    }
  }

  private var scaleAnchor: UnitPoint {
    switch alignment {
    case .bottomLeading: .bottomLeading
    case .bottom: .bottom
    case .bottomTrailing: .bottomTrailing
    case .topLeading: .topLeading
    case .top: .top
    case .topTrailing: .topTrailing
    case .leading: .leading
    case .trailing: .trailing
    default: .center
    }
  }
}

// MARK: - Preview

#Preview("GlassExpandableMenu") {
  GlassExpandableMenuPreview()
}

private struct GlassExpandableMenuPreview: View {
  @State private var progress: CGFloat = 0
  @State private var animationType: GlassMenuAnimationType = .bouncy

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
      .onTapGesture {
        withAnimation(animationType.animation) {
          progress = 0
        }
      }

      VStack {
        Picker("Animation", selection: $animationType) {
          ForEach(GlassMenuAnimationType.allCases, id: \.self) { type in
            Text(type.rawValue.capitalized).tag(type)
          }
        }
        .pickerStyle(.segmented)
        .padding()

        Spacer()
      }

      GlassExpandableMenu(
        alignment: .bottomTrailing,
        progress: progress
      ) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(["새 약속", "그룹 만들기", "그룹 참여"], id: \.self) { title in
            Button {
              withAnimation(animationType.animation) {
                progress = 0
              }
            } label: {
              HStack(spacing: 14) {
                Circle()
                  .fill(Color.primary.opacity(0.1))
                  .frame(width: 40, height: 40)

                Text(title)
                  .font(.system(size: 16, weight: .medium))
                  .foregroundStyle(.primary)

                Spacer(minLength: 20)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 8)
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(.blue)
          .frame(width: 56, height: 56)
          .contentShape(Circle())
          .onTapGesture {
            withAnimation(animationType.animation) {
              progress = 1
            }
          }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
      .padding(20)
    }
  }
}
