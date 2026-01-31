import AppIntents
import WidgetKit

/// 위젯 새로고침 Intent (iOS 17+)
struct RefreshWidgetIntent: AppIntent {
  static var title: LocalizedStringResource = "위젯 새로고침"
  static var description = IntentDescription("위젯 데이터를 새로고침합니다")

  func perform() async throws -> some IntentResult {
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}
