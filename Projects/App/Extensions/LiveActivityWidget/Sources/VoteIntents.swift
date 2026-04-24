import ActivityKit
import AppIntents
import Foundation
import os.log
import PromisoShared

// MARK: - Widget Logger

private let logger = Logger(subsystem: "com.promiso.widget", category: "VoteIntent")

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
    logger.error("VoteResponse: missing auth token")
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
    logger.info("VoteResponse: widget token 401 -> access token fallback")
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
      logger.error("VoteResponse: non-http response")
      return nil
    }

    if httpResponse.statusCode != 200 {
      let bodyText = String(data: data, encoding: .utf8) ?? ""
      logger.error("VoteResponse failed(\(httpResponse.statusCode)): \(bodyText.prefix(200))")
    }

    return httpResponse.statusCode
  } catch {
    logger.error("VoteResponse error: \(error.localizedDescription)")
    return nil
  }
}

// MARK: - Vote Response Intent

/// 참여 확인 투표 응답 Intent (잠금화면 버튼용)
struct VoteResponseIntent: LiveActivityIntent {
  static var title = LocalizedStringResource(
    "liveVote.intent.voteResponse.title",
    defaultValue: "Vote Response",
    bundle: LocalizedStrings.bundle
  )
  static var description = IntentDescription(
    LocalizedStringResource(
      "liveVote.intent.voteResponse.description",
      defaultValue: "Responds to a schedule vote.",
      bundle: LocalizedStrings.bundle
    )
  )

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.channelId",
    defaultValue: "Channel ID",
    bundle: LocalizedStrings.bundle
  ))
  var channelId: String

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.scheduleId",
    defaultValue: "Schedule ID",
    bundle: LocalizedStrings.bundle
  ))
  var scheduleId: String

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.userId",
    defaultValue: "User ID",
    bundle: LocalizedStrings.bundle
  ))
  var userId: String

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.response",
    defaultValue: "Response",
    bundle: LocalizedStrings.bundle
  ))
  var response: String  // "accepted" or "declined"

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.totalMemberCount",
    defaultValue: "Total Member Count",
    bundle: LocalizedStrings.bundle
  ))
  var totalMemberCount: Int

  @Parameter(title: LocalizedStringResource(
    "liveVote.intent.voteResponse.currentStateJSON",
    defaultValue: "Current State JSON",
    bundle: LocalizedStrings.bundle
  ))
  var currentStateJSON: String

  init() {
    self.channelId = ""
    self.scheduleId = ""
    self.userId = ""
    self.response = ""
    self.totalMemberCount = 0
    self.currentStateJSON = "{}"
  }

  init(
    channelId: String,
    scheduleId: String,
    userId: String,
    response: String,
    totalMemberCount: Int,
    currentStateJSON: String
  ) {
    self.channelId = channelId
    self.scheduleId = scheduleId
    self.userId = userId
    self.response = response
    self.totalMemberCount = totalMemberCount
    self.currentStateJSON = currentStateJSON
  }

  func perform() async throws -> some IntentResult {
    guard !channelId.isEmpty, !scheduleId.isEmpty, !userId.isEmpty else {
      logger.error("VoteResponse: required parameter empty (channelId=\(channelId.isEmpty), scheduleId=\(scheduleId.isEmpty), userId=\(userId.isEmpty))")
      return .result()
    }

    // Rust API 호출
    await callVoteResponseFunction(
      channelId: channelId,
      scheduleId: scheduleId,
      userId: userId,
      response: response,
      totalMemberCount: totalMemberCount,
      currentStateJSON: currentStateJSON
    )

    return .result()
  }
}

// MARK: - Rust API HTTP Client

private func callVoteResponseFunction(
  channelId: String,
  scheduleId: String,
  userId: String,
  response: String,
  totalMemberCount: Int,
  currentStateJSON: String
) async {
  let baseURL: String
  if let emulatorHost = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .string(forKey: LiveActivityIntentKey.emulatorHostKey), !emulatorHost.isEmpty {
    baseURL = "http://\(emulatorHost):8080/api/v1/live-activity/widget/vote"
  } else {
    baseURL = "\(LiveActivityIntentKey.rustAPIBaseURL)/api/v1/live-activity/widget/vote"
  }

  guard let url = URL(string: baseURL) else { return }

  let requestBody: [String: Any] = [
    "channelId": channelId,
    "scheduleId": scheduleId,
    "userId": userId,
    "response": response,
    "totalMemberCount": totalMemberCount,
    "currentStateJSON": currentStateJSON
  ]

  guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else { return }

  if await performAuthenticatedWidgetPost(to: url, userId: userId, body: httpBody) {
    logger.info("VoteResponse success: \(response) for \(scheduleId)")
  }
}
