import SwiftUI
import UIKit

// MARK: - Interactive Button Styles

/// 바운스 효과가 있는 버튼 스타일
public struct BounceButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
      .opacity(configuration.isPressed ? 0.8 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

/// 부드러운 스케일 효과 버튼 스타일
public struct ScaleButtonStyle: ButtonStyle {
  let scale: CGFloat
  let opacity: CGFloat

  public init(scale: CGFloat = 0.95, opacity: CGFloat = 0.9) {
    self.scale = scale
    self.opacity = opacity
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? scale : 1.0)
      .opacity(configuration.isPressed ? opacity : 1.0)
      .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
  }
}

/// 햅틱 + 바운스 효과 버튼 스타일
public struct HapticBounceButtonStyle: ButtonStyle {
  let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle

  public init(feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    self.feedbackStyle = feedbackStyle
  }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
      .opacity(configuration.isPressed ? 0.8 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _, isPressed in
        if isPressed {
          let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
          generator.impactOccurred()
        }
      }
  }
}

// MARK: - ButtonStyle Extensions

public extension ButtonStyle where Self == BounceButtonStyle {
  static var bounce: BounceButtonStyle { BounceButtonStyle() }
}

public extension ButtonStyle where Self == ScaleButtonStyle {
  static var scale: ScaleButtonStyle { ScaleButtonStyle() }
  static func scale(_ scale: CGFloat, opacity: CGFloat = 0.9) -> ScaleButtonStyle {
    ScaleButtonStyle(scale: scale, opacity: opacity)
  }
}

public extension ButtonStyle where Self == HapticBounceButtonStyle {
  static var hapticBounce: HapticBounceButtonStyle { HapticBounceButtonStyle() }
  static func hapticBounce(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> HapticBounceButtonStyle {
    HapticBounceButtonStyle(feedbackStyle: style)
  }
}

// MARK: - Pressable View Modifier (Button이 아닌 View용)

/// 누르기 효과를 추가하는 ViewModifier
public struct PressableModifier: ViewModifier {
  let onPress: () -> Void
  let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle?

  @State private var isPressed = false

  public init(
    feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle? = .light,
    onPress: @escaping () -> Void
  ) {
    self.feedbackStyle = feedbackStyle
    self.onPress = onPress
  }

  public func body(content: Content) -> some View {
    content
      .scaleEffect(isPressed ? 0.9 : 1.0)
      .opacity(isPressed ? 0.8 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            if !isPressed {
              isPressed = true
            }
          }
          .onEnded { _ in
            isPressed = false
            if let style = feedbackStyle {
              let generator = UIImpactFeedbackGenerator(style: style)
              generator.impactOccurred()
            }
            onPress()
          }
      )
  }
}

public extension View {
  /// 누르기 효과 + 햅틱 추가 (Button이 아닌 View용)
  func pressable(
    feedback: UIImpactFeedbackGenerator.FeedbackStyle? = .light,
    onPress: @escaping () -> Void
  ) -> some View {
    modifier(PressableModifier(feedbackStyle: feedback, onPress: onPress))
  }
}

// MARK: - Haptic Utilities

public enum Haptic {
  /// Impact 햅틱
  public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
  }

  /// Selection 햅틱 (가벼운 틱)
  public static func selection() {
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
  }

  /// Notification 햅틱
  public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
  }

  /// 성공 햅틱
  public static func success() {
    notification(.success)
  }

  /// 에러 햅틱
  public static func error() {
    notification(.error)
  }

  /// 경고 햅틱
  public static func warning() {
    notification(.warning)
  }
}

// MARK: - Adaptive Button Modifiers

public extension View {
  /// Primary 버튼 스타일 (iOS 26: glassProminent, 이전: 파란색 배경)
  func adaptivePrimaryButton() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(self.buttonStyle(.glassProminent))
    } else {
      return AnyView(
        self
          .background(Color.blue)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
  
  /// Secondary 버튼 스타일 (iOS 26: glass, 이전: 회색 배경)
  func adaptiveSecondaryButton(fallBackBackground: Color = .white) -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .buttonStyle(.glass)
          .tint(fallBackBackground)
      )
    } else {
      return AnyView(
        self
          .background(fallBackBackground)
          .foregroundStyle(.blue)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
  
  /// Destructive 버튼 스타일 (iOS 26: glassProminent, 이전: 빨간색 배경)
  func adaptiveDestructiveButton() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .buttonStyle(.glassProminent)
          .tint(.red)
      )
        
    } else {
      return AnyView(
        self
          .background(Color.red)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      )
    }
  }
}

// MARK: - Usage

struct ButtonExamples: View {
  @State private var showCreateGroup = false
  @State private var showJoinGroup = false
  
  var body: some View {
    VStack(spacing: 12) {
      // ✅ Primary Button
      Button(action: { showCreateGroup = true }) {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.title3)
          Text("그룹 만들기")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptivePrimaryButton()
      
      // ✅ Secondary Button
      Button(action: { showJoinGroup = true }) {
        HStack(spacing: 8) {
          Image(systemName: "link.circle.fill")
            .font(.title3)
          Text("초대 코드로 참여하기")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptiveSecondaryButton()
      
      // ✅ Destructive Button
      Button(action: {}) {
        HStack(spacing: 8) {
          Image(systemName: "trash.fill")
            .font(.title3)
          Text(LocalizedStrings.Common.deleteAction)
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptiveDestructiveButton()
    }
    .padding(.horizontal, 40)
  }
}

#Preview("Adaptive Buttons") {
  ButtonExamples()
}

#Preview("Interactive Styles") {
  VStack(spacing: 24) {
    // Bounce Style
    Button {
    } label: {
      Text("Bounce Style")
        .font(.headline)
        .frame(width: 200, height: 50)
        .background(Color.pmindigo.n500)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.bounce)

    // Scale Style
    Button {
    } label: {
      Text("Scale Style")
        .font(.headline)
        .frame(width: 200, height: 50)
        .background(Color.blue)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.scale)

    // Haptic Bounce Style
    Button {
    } label: {
      Text("Haptic Bounce")
        .font(.headline)
        .frame(width: 200, height: 50)
        .background(Color.green)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.hapticBounce)

    // Pressable Modifier (non-Button)
    Circle()
      .fill(Color.orange)
      .frame(width: 60, height: 60)
      .overlay(
        Image(systemName: "star.fill")
          .foregroundStyle(.white)
      )
      .pressable {
      }
  }
  .padding()
}
