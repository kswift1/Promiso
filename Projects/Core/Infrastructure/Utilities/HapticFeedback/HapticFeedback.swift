import UIKit
import Dependencies

// MARK: - Haptic Feedback Types

/// 햅틱 피드백 타입 정의
public enum HapticFeedbackType {
  case impact(UIImpactFeedbackGenerator.FeedbackStyle)
  case notification(UINotificationFeedbackGenerator.FeedbackType)
  case selection
}

// MARK: - Haptic Feedback Protocol

/// 햅틱 피드백 서비스 프로토콜
public protocol HapticFeedbackProtocol: Sendable {
  func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) async
  func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) async
  func selection() async
  func feedback(_ type: HapticFeedbackType) async
}

// MARK: - Haptic Feedback Implementation

/// 햅틱 피드백 서비스 구현
public final class HapticFeedback: HapticFeedbackProtocol, @unchecked Sendable {
  private let impactLight = UIImpactFeedbackGenerator(style: .light)
  private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
  private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
  private let notification = UINotificationFeedbackGenerator()
  private let selection = UISelectionFeedbackGenerator()
  
  public init() {
    // 피드백 제너레이터 준비 (성능 향상)
    impactLight.prepare()
    impactMedium.prepare()
    impactHeavy.prepare()
    notification.prepare()
    selection.prepare()
  }
  
  public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) async {
    await MainActor.run {
      let generator: UIImpactFeedbackGenerator
      
      switch style {
      case .light:
        generator = impactLight
      case .medium:
        generator = impactMedium
      case .heavy:
        generator = impactHeavy
      @unknown default:
        generator = impactMedium
      }
      
      generator.impactOccurred()
    }
  }
  
  public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) async {
    await MainActor.run {
      notification.notificationOccurred(type)
    }
  }
  
  public func selection() async {
    await MainActor.run {
      selection.selectionChanged()
    }
  }
  
  public func feedback(_ type: HapticFeedbackType) async {
    switch type {
    case .impact(let style):
      await impact(style)
    case .notification(let feedbackType):
      await notification(feedbackType)
    case .selection:
      await selection()
    }
  }
}

// MARK: - Haptic Feedback Client

/// TCA Dependency로 사용할 햅틱 피드백 클라이언트
public struct HapticFeedbackClient: Sendable {
  public var light: @Sendable () async -> Void
  public var medium: @Sendable () async -> Void
  public var heavy: @Sendable () async -> Void
  public var success: @Sendable () async -> Void
  public var warning: @Sendable () async -> Void
  public var error: @Sendable () async -> Void
  public var selection: @Sendable () async -> Void
  public var feedback: @Sendable (HapticFeedbackType) async -> Void
  
  public init(
    light: @escaping @Sendable () async -> Void,
    medium: @escaping @Sendable () async -> Void,
    heavy: @escaping @Sendable () async -> Void,
    success: @escaping @Sendable () async -> Void,
    warning: @escaping @Sendable () async -> Void,
    error: @escaping @Sendable () async -> Void,
    selection: @escaping @Sendable () async -> Void,
    feedback: @escaping @Sendable (HapticFeedbackType) async -> Void
  ) {
    self.light = light
    self.medium = medium
    self.heavy = heavy
    self.success = success
    self.warning = warning
    self.error = error
    self.selection = selection
    self.feedback = feedback
  }
}

 extension HapticFeedbackClient: DependencyKey {
   public static let liveValue: HapticFeedbackClient = {
     let hapticFeedback = HapticFeedback()
     
     return HapticFeedbackClient(
       light: { await hapticFeedback.impact(.light) },
       medium: { await hapticFeedback.impact(.medium) },
       heavy: { await hapticFeedback.impact(.heavy) },
       success: { await hapticFeedback.notification(.success) },
       warning: { await hapticFeedback.notification(.warning) },
       error: { await hapticFeedback.notification(.error) },
       selection: { await hapticFeedback.selection() },
       feedback: { await hapticFeedback.feedback($0) }
     )
   }()
   
   public static let testValue: HapticFeedbackClient = HapticFeedbackClient(
     light: { },
     medium: { },
     heavy: { },
     success: { },
     warning: { },
     error: { },
     selection: { },
     feedback: { _ in }
   )
   
   public static let previewValue: HapticFeedbackClient = testValue
 }

 extension DependencyValues {
   public var hapticFeedback: HapticFeedbackClient {
     get { self[HapticFeedbackClient.self] }
     set { self[HapticFeedbackClient.self] = newValue }
   }
 }

// MARK: - Convenience Extensions

public extension HapticFeedbackClient {
  /// 버튼 탭에 적합한 가벼운 햅틱
  func buttonTap() async {
    await light()
  }
  
  /// 토글이나 스위치에 적합한 햅틱
  func toggle() async {
    await selection()
  }
  
  /// 중요한 액션 확인에 적합한 햅틱
  func confirm() async {
    await medium()
  }
  
  /// 삭제나 취소 액션에 적합한 햅틱
  func destructive() async {
    await heavy()
  }
}
