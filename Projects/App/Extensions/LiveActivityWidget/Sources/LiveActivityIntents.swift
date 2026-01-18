import ActivityKit
import AppIntents
import Foundation
import PromisoShared

// MARK: - Update ETA Intent

/// 도착 예상 시간 업데이트 Intent
struct UpdateETAIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "도착 예상 시간 변경"
  static var description = IntentDescription("도착 예상 시간을 변경합니다")

  @Parameter(title: "약속 ID")
  var promiseId: String

  @Parameter(title: "사용자 ID")
  var userId: String

  @Parameter(title: "도착 예상 시간 (분)")
  var estimatedMinutes: Int

  init() {
    self.promiseId = ""
    self.userId = ""
    self.estimatedMinutes = 0
  }

  init(promiseId: String, userId: String, estimatedMinutes: Int) {
    self.promiseId = promiseId
    self.userId = userId
    self.estimatedMinutes = estimatedMinutes
  }

  func perform() async throws -> some IntentResult {
    // UserDefaults에 저장 (앱에서 서버 동기화용)
    let update = ETAUpdate(
      promiseId: promiseId,
      userId: userId,
      estimatedMinutes: estimatedMinutes,
      timestamp: Date()
    )
    if let data = try? JSONEncoder().encode(update) {
      UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
        .set(data, forKey: LiveActivityIntentKey.etaUpdateKey)
    }

    // Live Activity UI 즉시 업데이트
    await updateActivityETA(
      promiseId: promiseId,
      participantId: userId,
      estimatedArrivalMinutes: estimatedMinutes
    )

    return .result()
  }
}

// MARK: - Helper

private func updateActivityETA(promiseId: String, participantId: String, estimatedArrivalMinutes: Int) async {
  // 디버그 로깅
  let debugInfo: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "promiseId": promiseId,
    "participantId": participantId,
    "estimatedArrivalMinutes": estimatedArrivalMinutes,
    "activitiesCount": Activity<PromiseActivityAttributes>.activities.count
  ]
  UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .set(debugInfo, forKey: "liveActivity.debug.lastIntent")

  // promiseId로 Activity 찾기
  guard let activity = Activity<PromiseActivityAttributes>.activities
    .first(where: { $0.attributes.promiseId == promiseId }) else {
    UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
      .set("activity_not_found", forKey: "liveActivity.debug.error")
    return
  }

  let currentState = activity.content.state
  let updatedState = currentState.updating(
    participantId: participantId,
    estimatedArrivalMinutes: estimatedArrivalMinutes
  )
  let content = ActivityContent(state: updatedState, staleDate: nil)

  await activity.update(content)

  UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .set("update_called", forKey: "liveActivity.debug.result")
}
