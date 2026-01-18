import ActivityKit
import AppIntents
import Foundation
import PromisoShared

// MARK: - Depart Intent

struct DepartIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "출발"
  static var description = IntentDescription("출발 상태로 변경합니다")

  @Parameter(title: "약속 ID")
  var promiseId: String

  @Parameter(title: "사용자 ID")
  var oderId: String

  init() {
    self.promiseId = ""
    self.oderId = ""
  }

  init(promiseId: String, oderId: String) {
    self.promiseId = promiseId
    self.oderId = oderId
  }

  func perform() async throws -> some IntentResult {
    // UserDefaults에 저장 (앱에서 나중에 처리용)
    let status = DepartureStatus(
      promiseId: promiseId,
      oderId: oderId,
      timestamp: Date()
    )
    if let data = try? JSONEncoder().encode(status) {
      UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
        .set(data, forKey: LiveActivityIntentKey.departureKey)
    }

    // Live Activity UI 즉시 업데이트 시도
    await updateActivityStatus(promiseId: promiseId, participantId: oderId, newStatus: .departed)

    return .result()
  }
}

// MARK: - Arrive Intent

struct ArriveIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "도착"
  static var description = IntentDescription("도착 상태로 변경합니다")

  @Parameter(title: "약속 ID")
  var promiseId: String

  @Parameter(title: "사용자 ID")
  var oderId: String

  init() {
    self.promiseId = ""
    self.oderId = ""
  }

  init(promiseId: String, oderId: String) {
    self.promiseId = promiseId
    self.oderId = oderId
  }

  func perform() async throws -> some IntentResult {
    // UserDefaults에 저장 (앱에서 나중에 처리용)
    let status = ArrivalStatus(
      promiseId: promiseId,
      oderId: oderId,
      timestamp: Date()
    )
    if let data = try? JSONEncoder().encode(status) {
      UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
        .set(data, forKey: LiveActivityIntentKey.arrivalKey)
    }

    // Live Activity UI 즉시 업데이트 시도
    await updateActivityStatus(promiseId: promiseId, participantId: oderId, newStatus: .arrived)

    return .result()
  }
}

// MARK: - Helper

private func updateActivityStatus(promiseId: String, participantId: String, newStatus: ParticipantStatus) async {
  // 디버그: Intent 호출 확인
  let debugInfo: [String: Any] = [
    "timestamp": Date().timeIntervalSince1970,
    "promiseId": promiseId,
    "participantId": participantId,
    "newStatus": newStatus.rawValue,
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

  // 디버그: 현재 participants 확인
  let participantIds = currentState.participants.map { $0.id }
  UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .set(participantIds, forKey: "liveActivity.debug.participantIds")

  let updatedState = currentState.updating(participantId: participantId, status: newStatus)
  let content = ActivityContent(state: updatedState, staleDate: nil)

  await activity.update(content)

  UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .set("update_called", forKey: "liveActivity.debug.result")
}
