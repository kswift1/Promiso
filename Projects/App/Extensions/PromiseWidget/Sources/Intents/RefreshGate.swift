import Foundation

/// App Group 기반 throttle gate
/// 위젯 새로고침 버튼 "따닥" 방지
final class RefreshGate: @unchecked Sendable {
  static let shared = RefreshGate()

  private nonisolated(unsafe) let defaults = UserDefaults(suiteName: "group.com.promiso.shared")
  private let key = "widget.refresh.lastManualAt"

  private init() {}

  /// 최소 간격 내에 재요청이면 false 반환
  /// - Parameter seconds: 최소 간격 (기본 2초)
  /// - Returns: true면 실행 허용, false면 차단
  func tryAcquire(minInterval seconds: TimeInterval = 2.0) -> Bool {
    let now = Date().timeIntervalSince1970
    let last = defaults?.double(forKey: key) ?? 0

    if last > 0 && (now - last) < seconds {
      return false
    }

    defaults?.set(now, forKey: key)
    return true
  }
}
