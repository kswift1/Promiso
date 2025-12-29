import Foundation

// MARK: - Analytics Event

/// 분석 이벤트를 정의하는 프로토콜
public protocol AnalyticsEvent {
  var name: String { get }
  var parameters: [String: Any] { get }
}

// MARK: - Common Analytics Events

/// 공통 분석 이벤트들
public enum AppAnalyticsEvent: AnalyticsEvent {
  case appLaunched
  case appTerminated
  case screenViewed(String)
  case buttonTapped(String)
  case featureUsed(String)
  case error(String, String) // error type, message
  case userAction(String, [String: Any]) // action name, parameters
  
  public var name: String {
    switch self {
    case .appLaunched:
      return "app_launched"
    case .appTerminated:
      return "app_terminated"
    case .screenViewed:
      return "screen_viewed"
    case .buttonTapped:
      return "button_tapped"
    case .featureUsed:
      return "feature_used"
    case .error:
      return "error_occurred"
    case .userAction(let action, _):
      return "user_action_\(action)"
    }
  }
  
  public var parameters: [String: Any] {
    switch self {
    case .appLaunched:
      return [
        "timestamp": Date().timeIntervalSince1970,
        "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown"
      ]
    case .appTerminated:
      return ["timestamp": Date().timeIntervalSince1970]
    case .screenViewed(let screenName):
      return [
        "screen_name": screenName,
        "timestamp": Date().timeIntervalSince1970
      ]
    case .buttonTapped(let buttonName):
      return [
        "button_name": buttonName,
        "timestamp": Date().timeIntervalSince1970
      ]
    case .featureUsed(let featureName):
      return [
        "feature_name": featureName,
        "timestamp": Date().timeIntervalSince1970
      ]
    case .error(let errorType, let message):
      return [
        "error_type": errorType,
        "error_message": message,
        "timestamp": Date().timeIntervalSince1970
      ]
    case .userAction(_, let parameters):
      var params = parameters
      params["timestamp"] = Date().timeIntervalSince1970
      return params
    }
  }
}

// MARK: - Analytics Protocol

/// 분석 서비스를 정의하는 프로토콜
public protocol AnalyticsProtocol: Sendable {
  func track(_ event: AnalyticsEvent)
  func setUserProperty(_ value: String, forName name: String)
  func setUserId(_ userId: String?)
  func flush()
  func reset()
}

// MARK: - Analytics Implementation

/// 메인 분석 서비스 구현
public final class Analytics: AnalyticsProtocol, @unchecked Sendable {
  private let isDebugMode: Bool
  private let queue = DispatchQueue(label: "analytics", qos: .utility)
  private var eventBuffer: [AnalyticsEvent] = []
  private let maxBufferSize = 50
  
  public init(isDebugMode: Bool = false) {
    self.isDebugMode = isDebugMode
  }
  
  public func track(_ event: AnalyticsEvent) {
    queue.async { [weak self] in
      self?.trackInternal(event)
    }
  }
  
  public func setUserProperty(_ value: String, forName name: String) {
    queue.async { [weak self] in
      self?.setUserPropertyInternal(value, forName: name)
    }
  }
  
  public func setUserId(_ userId: String?) {
    queue.async { [weak self] in
      self?.setUserIdInternal(userId)
    }
  }
  
  public func flush() {
    queue.async { [weak self] in
      self?.flushInternal()
    }
  }
  
  public func reset() {
    queue.async { [weak self] in
      self?.resetInternal()
    }
  }
}

// MARK: - Private Methods

private extension Analytics {
  func trackInternal(_ event: AnalyticsEvent) {
    if isDebugMode {
      logDebug("Analytics: \(event.name) - \(event.parameters)", category: "Analytics")
    }
    
    eventBuffer.append(event)
    
    if eventBuffer.count >= maxBufferSize {
      flushInternal()
    }
    
    // 실제 분석 서비스 (Firebase, Mixpanel 등)로 전송
    // 여기서는 로그만 출력
    sendToAnalyticsService(event)
  }
  
  func setUserPropertyInternal(_ value: String, forName name: String) {
    if isDebugMode {
      logDebug("Analytics User Property: \(name) = \(value)", category: "Analytics")
    }
    
    // 실제 분석 서비스에 사용자 속성 설정
    // Firebase Analytics: Analytics.setUserProperty(value, forName: name)
  }
  
  func setUserIdInternal(_ userId: String?) {
    if isDebugMode {
      logDebug("Analytics User ID: \(userId ?? "nil")", category: "Analytics")
    }
    
    // 실제 분석 서비스에 사용자 ID 설정
    // Firebase Analytics: Analytics.setUserID(userId)
  }
  
  func flushInternal() {
    if isDebugMode {
      logDebug("Analytics: Flushing \(eventBuffer.count) events", category: "Analytics")
    }
    
    // 실제로는 서버에 일괄 전송
    eventBuffer.removeAll()
  }
  
  func resetInternal() {
    if isDebugMode {
      logDebug("Analytics: Reset", category: "Analytics")
    }
    
    eventBuffer.removeAll()
    // 실제 분석 서비스 리셋
  }
  
  func sendToAnalyticsService(_ event: AnalyticsEvent) {
    // 실제 분석 서비스로 이벤트 전송
    // 예: Firebase Analytics
    // Analytics.logEvent(event.name, parameters: event.parameters)
    
    // 예: Custom Analytics API
    // analyticsAPI.send(event: event)
    
    // 디버그 모드에서는 콘솔에 출력
    if isDebugMode {
      print("📊 Analytics Event: \(event.name)")
      for (key, value) in event.parameters {
        print("   \(key): \(value)")
      }
    }
  }
}

// MARK: - Analytics Dependency

/// TCA Dependency로 Analytics 등록
public struct AnalyticsClient: Sendable {
  public var track: @Sendable (AnalyticsEvent) -> Void
  public var setUserProperty: @Sendable (String, String) -> Void
  public var setUserId: @Sendable (String?) -> Void
  public var flush: @Sendable () -> Void
  public var reset: @Sendable () -> Void
  
  public init(
    track: @escaping @Sendable (AnalyticsEvent) -> Void,
    setUserProperty: @escaping @Sendable (String, String) -> Void,
    setUserId: @escaping @Sendable (String?) -> Void,
    flush: @escaping @Sendable () -> Void,
    reset: @escaping @Sendable () -> Void
  ) {
    self.track = track
    self.setUserProperty = setUserProperty
    self.setUserId = setUserId
    self.flush = flush
    self.reset = reset
  }
}

// TODO: TCA Dependencies 라이브러리 통합 후 활성화
// extension AnalyticsClient: DependencyKey {
//   public static let liveValue: AnalyticsClient = {
//     let analytics = Analytics(isDebugMode: true) // Production에서는 false
//     
//     return AnalyticsClient(
//       track: analytics.track,
//       setUserProperty: analytics.setUserProperty,
//       setUserId: analytics.setUserId,
//       flush: analytics.flush,
//       reset: analytics.reset
//     )
//   }()
//   
//   public static let testValue: AnalyticsClient = AnalyticsClient(
//     track: { _ in },
//     setUserProperty: { _, _ in },
//     setUserId: { _ in },
//     flush: {},
//     reset: {}
//   )
// }

// extension DependencyValues {
//   public var analytics: AnalyticsClient {
//     get { self[AnalyticsClient.self] }
//     set { self[AnalyticsClient.self] = newValue }
//   }
// }

// MARK: - Analytics Helper

/// 분석 이벤트 추적을 위한 편의 함수들
public enum AnalyticsHelper {
  // TODO: TCA Dependencies 라이브러리 통합 후 활성화
  // @Dependency(\.analytics) static var analytics

  public static func trackScreenView(_ screenName: String) {
    // TODO: TCA Dependencies 라이브러리 통합 후 활성화
    // analytics.track(AppAnalyticsEvent.screenViewed(screenName))
    print("Analytics: Screen viewed - \(screenName)")
  }

  public static func trackButtonTap(_ buttonName: String) {
    // TODO: TCA Dependencies 라이브러리 통합 후 활성화
    // analytics.track(AppAnalyticsEvent.buttonTapped(buttonName))
    print("Analytics: Button tapped - \(buttonName)")
  }

  public static func trackFeatureUse(_ featureName: String) {
    // TODO: TCA Dependencies 라이브러리 통합 후 활성화
    // analytics.track(AppAnalyticsEvent.featureUsed(featureName))
    print("Analytics: Feature used - \(featureName)")
  }

  public static func trackError(_ error: Error, type: String = "unknown") {
    // TODO: TCA Dependencies 라이브러리 통합 후 활성화
    // analytics.track(AppAnalyticsEvent.error(type, error.localizedDescription))
    print("Analytics: Error tracked - \(type): \(error.localizedDescription)")
  }

  public static func trackUserAction(_ action: String, parameters: [String: Any] = [:]) {
    // TODO: TCA Dependencies 라이브러리 통합 후 활성화
    // analytics.track(AppAnalyticsEvent.userAction(action, parameters))
    print("Analytics: User action - \(action): \(parameters)")
  }
}
