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
    // 1. 현재 Activity에서 channelId와 participants 가져오기
    guard let activity = Activity<PromiseActivityAttributes>.activities
      .first(where: { $0.attributes.promiseId == promiseId }) else {
      #if DEBUG
      print("[UpdateETAIntent] Activity not found for promiseId: \(promiseId)")
      #endif
      return .result()
    }

    let channelId = activity.attributes.channelId
    let trackingDurationMinutes = activity.attributes.trackingDurationMinutes
    let currentState = activity.content.state

    // 2. 현재 사용자의 ETA를 업데이트한 participants 생성
    let updatedParticipants = currentState.participants.map { participant in
      if participant.id == userId {
        return ParticipantState(
          id: participant.id,
          name: participant.name,
          estimatedArrivalMinutes: estimatedMinutes
        )
      }
      return participant
    }

    // 3. 로컬 UI 즉시 업데이트
    let updatedState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: trackingDurationMinutes,
      participants: updatedParticipants
    )
    let content = ActivityContent(state: updatedState, staleDate: nil)
    await activity.update(content)

    // 4. 백엔드 API 호출 (APNs Broadcast - Firestore 없이)
    await callUpdateETAFunction(
      channelId: channelId,
      participants: updatedParticipants,
      trackingDurationMinutes: trackingDurationMinutes,
      userId: userId
    )

    return .result()
  }
}

// MARK: - Firebase Functions HTTP Client

private func callUpdateETAFunction(
  channelId: String,
  participants: [ParticipantState],
  trackingDurationMinutes: Int,
  userId: String
) async {
  // Firebase Functions 설정
  let region = "asia-northeast3"
  let functionName = "widgetUpdateETA"
  let projectId = LiveActivityIntentKey.firebaseProjectId

  // 환경에 따른 URL 결정
  let baseURL: String
  #if DEBUG
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

  // App Group에서 인증 정보 읽기
  let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)
  let authToken = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey)

  // participants를 서버 형식으로 변환
  let participantsData: [[String: Any]] = participants.map { p in
    var dict: [String: Any] = [
      "id": p.id,
      "name": p.name
    ]
    if let eta = p.estimatedArrivalMinutes {
      dict["estimatedArrivalMinutes"] = eta
    } else {
      dict["estimatedArrivalMinutes"] = NSNull()
    }
    return dict
  }

  // 요청 데이터 (channelId + participants - Firestore 없이 Broadcast만)
  let requestBody: [String: Any] = [
    "channelId": channelId,
    "participants": participantsData,
    "trackingDurationMinutes": trackingDurationMinutes
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
  request.setValue(userId, forHTTPHeaderField: "X-User-Id")
  request.httpBody = httpBody

  // Auth 토큰이 있으면 헤더에 추가
  if let authToken = authToken {
    request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
  }

  // 요청 실행
  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    #if DEBUG
    if let httpResponse = response as? HTTPURLResponse {
      print("[UpdateETAIntent] Response status: \(httpResponse.statusCode)")
      if let responseString = String(data: data, encoding: .utf8) {
        print("[UpdateETAIntent] Response body: \(responseString)")
      }
    }
    #endif
  } catch {
    #if DEBUG
    print("[UpdateETAIntent] Request failed: \(error)")
    #endif
  }
}

