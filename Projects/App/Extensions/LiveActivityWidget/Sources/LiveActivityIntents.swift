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
    // 1. 백엔드 API 직접 호출 (APNs 브로드캐스트)
    await callUpdateETAFunction(
      promiseId: promiseId,
      estimatedMinutes: estimatedMinutes
    )

    // 2. Live Activity UI 즉시 업데이트 (로컬 - 백엔드 응답 전 UX 개선용)
    await updateActivityETA(
      promiseId: promiseId,
      participantId: userId,
      estimatedArrivalMinutes: estimatedMinutes
    )

    return .result()
  }
}

// MARK: - Firebase Functions HTTP Client

private func callUpdateETAFunction(promiseId: String, estimatedMinutes: Int) async {
  // Firebase Functions 설정
  let region = "asia-northeast3"
  let functionName = "updateETA"

  // 환경에 따른 URL 결정
  let baseURL: String
  let projectId = LiveActivityIntentKey.firebaseProjectId

  #if DEBUG
  // 에뮬레이터 사용 시
  if let emulatorHost = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .string(forKey: LiveActivityIntentKey.emulatorHostKey) {
    baseURL = "http://\(emulatorHost):5001/\(projectId)/\(region)/\(functionName)"
  } else {
    baseURL = "https://\(region)-\(projectId).cloudfunctions.net/\(functionName)"
  }
  #else
  baseURL = "https://\(region)-\(projectId).cloudfunctions.net/\(functionName)"
  #endif

  guard let url = URL(string: baseURL) else {
    #if DEBUG
    print("[UpdateETAIntent] Invalid URL: \(baseURL)")
    #endif
    return
  }

  // 요청 데이터
  let requestBody: [String: Any] = [
    "data": [
      "promiseId": promiseId,
      "estimatedMinutes": estimatedMinutes
    ]
  ]

  guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
    #if DEBUG
    print("[UpdateETAIntent] JSON serialization failed")
    #endif
    return
  }

  // HTTP 요청 생성
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.httpBody = httpBody

  // Auth 토큰 확인 (App Group에서 읽기)
  let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)

  // 토큰 만료 체크
  if let expiry = defaults?.object(forKey: LiveActivityIntentKey.authTokenExpiryKey) as? Date,
     expiry < Date() {
    #if DEBUG
    print("[UpdateETAIntent] 토큰 만료됨 - 백엔드 요청 스킵")
    #endif
    return  // 토큰 만료 시 백엔드 요청 스킵 (로컬 UI만 업데이트됨)
  }

  // Auth 토큰이 있으면 추가
  if let authToken = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey) {
    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
  }

  // 요청 실행
  do {
    let (_, response) = try await URLSession.shared.data(for: request)
    #if DEBUG
    if let httpResponse = response as? HTTPURLResponse {
      print("[UpdateETAIntent] Response status: \(httpResponse.statusCode)")
    }
    #endif
  } catch {
    #if DEBUG
    print("[UpdateETAIntent] Request failed: \(error)")
    #endif
  }
}

// MARK: - Helper

private func updateActivityETA(promiseId: String, participantId: String, estimatedArrivalMinutes: Int) async {
  #if DEBUG
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
  #endif

  // promiseId로 Activity 찾기
  guard let activity = Activity<PromiseActivityAttributes>.activities
    .first(where: { $0.attributes.promiseId == promiseId }) else {
    #if DEBUG
    UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
      .set("activity_not_found", forKey: "liveActivity.debug.error")
    #endif
    return
  }

  let currentState = activity.content.state
  let updatedState = currentState.updating(
    participantId: participantId,
    estimatedArrivalMinutes: estimatedArrivalMinutes
  )
  let content = ActivityContent(state: updatedState, staleDate: nil)

  await activity.update(content)

  #if DEBUG
  UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .set("update_called", forKey: "liveActivity.debug.result")
  #endif
}
