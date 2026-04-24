import ActivityKit
import AppIntents
import Foundation
import os.log
import PromisoShared

// MARK: - Widget Logger

private let logger = Logger(subsystem: "com.promiso.widget", category: "LiveActivity")

private func performAuthenticatedWidgetPost(
  to url: URL,
  userId: String,
  body: Data
) async -> Bool {
  let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)
  let widgetToken = defaults?.string(forKey: LiveActivityIntentKey.widgetTokenKey)
  let accessToken = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey)
  let deviceId = defaults?.string(forKey: LiveActivityIntentKey.widgetDeviceIdKey)

  guard let primaryToken = widgetToken ?? accessToken else {
    logger.error("WidgetETA: missing auth token")
    return false
  }

  let primaryStatus = await sendWidgetRequest(
    to: url,
    userId: userId,
    authToken: primaryToken,
    deviceId: deviceId,
    body: body
  )
  if primaryStatus == 200 {
    return true
  }

  if primaryStatus == 401,
     let widgetToken,
     primaryToken == widgetToken,
     let accessToken,
     accessToken != widgetToken {
    logger.info("WidgetETA: widget token 401 -> access token fallback")
    let fallbackStatus = await sendWidgetRequest(
      to: url,
      userId: userId,
      authToken: accessToken,
      deviceId: deviceId,
      body: body
    )
    return fallbackStatus == 200
  }

  return false
}

private func sendWidgetRequest(
  to url: URL,
  userId: String,
  authToken: String,
  deviceId: String?,
  body: Data
) async -> Int? {
  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue(userId, forHTTPHeaderField: "X-User-Id")
  request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
  request.httpBody = body

  if let deviceId {
    request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
  }

  do {
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      logger.error("WidgetETA: non-http response")
      return nil
    }

    if httpResponse.statusCode != 200 {
      let bodyText = String(data: data, encoding: .utf8) ?? ""
      logger.error("WidgetETA failed(\(httpResponse.statusCode)): \(bodyText.prefix(200))")
    }

    return httpResponse.statusCode
  } catch {
    logger.error("WidgetETA error: \(error.localizedDescription)")
    return nil
  }
}

// MARK: - Update ETA Intent

/// 도착 예상 시간 업데이트 Intent
struct UpdateETAIntent: LiveActivityIntent {
  static var title = LocalizedStringResource(
    "liveSchedule.intent.updateEta.title",
    defaultValue: "Update ETA",
    bundle: LocalizedStrings.bundle
  )
  static var description = IntentDescription(
    LocalizedStringResource(
      "liveSchedule.intent.updateEta.description",
      defaultValue: "Updates the estimated arrival time.",
      bundle: LocalizedStrings.bundle
    )
  )

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.scheduleId",
    defaultValue: "Schedule ID",
    bundle: LocalizedStrings.bundle
  ))
  var scheduleId: String

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.channelId",
    defaultValue: "Channel ID",
    bundle: LocalizedStrings.bundle
  ))
  var channelId: String

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.userId",
    defaultValue: "User ID",
    bundle: LocalizedStrings.bundle
  ))
  var userId: String

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.estimatedMinutes",
    defaultValue: "Estimated Arrival (Minutes)",
    bundle: LocalizedStrings.bundle
  ))
  var estimatedMinutes: Int

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.trackingDurationMinutes",
    defaultValue: "Tracking Duration (Minutes)",
    bundle: LocalizedStrings.bundle
  ))
  var trackingDurationMinutes: Int

  @Parameter(title: LocalizedStringResource(
    "liveSchedule.intent.updateEta.participantsJson",
    defaultValue: "Participants JSON",
    bundle: LocalizedStrings.bundle
  ))
  var participantsJSON: String

  init() {
    self.scheduleId = ""
    self.channelId = ""
    self.userId = ""
    self.estimatedMinutes = 0
    self.trackingDurationMinutes = 30
    self.participantsJSON = "[]"
  }

  init(
    scheduleId: String,
    channelId: String,
    userId: String,
    estimatedMinutes: Int,
    trackingDurationMinutes: Int,
    participantsJSON: String
  ) {
    self.scheduleId = scheduleId
    self.channelId = channelId
    self.userId = userId
    self.estimatedMinutes = estimatedMinutes
    self.trackingDurationMinutes = trackingDurationMinutes
    self.participantsJSON = participantsJSON
  }

  func perform() async throws -> some IntentResult {
    // 1. 필수값 확인
    guard !scheduleId.isEmpty, !channelId.isEmpty else {
      logger.error("UpdateETA: required parameter empty")
      return .result()
    }

    // 2. JSON에서 participants 파싱
    guard let data = participantsJSON.data(using: .utf8),
          let participants = try? JSONDecoder().decode([ParticipantState].self, from: data) else {
      logger.error("UpdateETA: JSON decode failed")
      return .result()
    }

    // 3. 현재 사용자의 ETA를 업데이트
    let updatedParticipants = participants.map { p in
      if p.id == userId {
        return ParticipantState(id: p.id, name: p.name, estimatedArrivalMinutes: estimatedMinutes)
      }
      return p
    }

    // 4. 서버 API 호출 → APNs Broadcast
    await callUpdateETAFunction(
      scheduleId: scheduleId,
      channelId: channelId,
      participants: updatedParticipants,
      trackingDurationMinutes: trackingDurationMinutes,
      userId: userId
    )

    return .result()
  }
}

// MARK: - Rust API HTTP Client

private func callUpdateETAFunction(
  scheduleId: String,
  channelId: String,
  participants: [ParticipantState],
  trackingDurationMinutes: Int,
  userId: String
) async {
  let baseURL: String
  if let emulatorHost = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .string(forKey: LiveActivityIntentKey.emulatorHostKey), !emulatorHost.isEmpty {
    baseURL = "http://\(emulatorHost):8080/api/v1/live-activity/widget/eta"
  } else {
    baseURL = "\(LiveActivityIntentKey.rustAPIBaseURL)/api/v1/live-activity/widget/eta"
  }

  guard let url = URL(string: baseURL) else { return }

  // participants를 서버 형식으로 변환
  let participantsData: [[String: Any]] = participants.map { p in
    var dict: [String: Any] = ["id": p.id, "name": p.name]
    dict["estimatedArrivalMinutes"] = p.estimatedArrivalMinutes ?? NSNull()
    return dict
  }

  let requestBody: [String: Any] = [
    "scheduleId": scheduleId,
    "channelId": channelId,
    "participants": participantsData,
    "trackingDurationMinutes": trackingDurationMinutes
  ]

  guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else { return }

  _ = await performAuthenticatedWidgetPost(to: url, userId: userId, body: httpBody)
}
