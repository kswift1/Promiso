import AppIntents
import os.log
import WidgetKit

/// 위젯 새로고침 Intent (iOS 17+)
/// 3겹 방어: Throttle + In-flight Dedup + Timeline Reload
struct RefreshWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "위젯 새로고침"
  static var description = IntentDescription("위젯 데이터를 새로고침합니다")

  private static let logger = Logger(subsystem: "com.promiso.widget", category: "Refresh")

  func perform() async throws -> some IntentResult {
    // 1) 더블탭 방지 (2초 throttle)
    guard RefreshGate.shared.tryAcquire(minInterval: 2.0) else {
      Self.logger.info("🚫 버튼 Throttle (2초)")
      return .result()
    }

    // 2) In-flight dedup: 이미 실행 중이면 합류
    await RefreshInFlight.shared.run {
      Self.logger.info("🔄 새로고침 버튼 탭")
      WidgetCenter.shared.reloadAllTimelines()
    }

    return .result()
  }
}
