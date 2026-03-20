import ActivityKit
import AppIntents
import Foundation
import os.log
import PromisoShared

// MARK: - Widget Logger

private let logger = Logger(subsystem: "com.promiso.widget", category: "VoteIntent")

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
    // channelId 유효성 확인
    guard !channelId.isEmpty else {
      logger.error("VoteResponse: channelId empty")
      return .result()
    }

    // Firebase Functions HTTP 호출
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

// MARK: - Firebase Functions HTTP Client

private func callVoteResponseFunction(
  channelId: String,
  scheduleId: String,
  userId: String,
  response: String,
  totalMemberCount: Int,
  currentStateJSON: String
) async {
  let region = "asia-northeast3"
  let functionName = "widgetVoteResponse"
  let projectId = LiveActivityIntentKey.firebaseProjectId

  // 에뮬레이터 분기: App Group에 에뮬레이터 호스트가 있으면 로컬, 없으면 프로덕션
  let baseURL: String
  if let emulatorHost = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
    .string(forKey: LiveActivityIntentKey.emulatorHostKey), !emulatorHost.isEmpty {
    baseURL = "http://\(emulatorHost):5001/\(projectId)/\(region)/\(functionName)"
  } else {
    baseURL = "https://\(region)-\(projectId).cloudfunctions.net/\(functionName)"
  }

  guard let url = URL(string: baseURL) else { return }

  // App Group에서 인증 토큰 읽기 (Widget 전용 토큰 우선, 없으면 ID Token 사용)
  let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)
  let authToken = defaults?.string(forKey: LiveActivityIntentKey.widgetTokenKey)
    ?? defaults?.string(forKey: LiveActivityIntentKey.authTokenKey)

  let requestBody: [String: Any] = [
    "channelId": channelId,
    "scheduleId": scheduleId,
    "userId": userId,
    "response": response,
    "totalMemberCount": totalMemberCount,
    "currentStateJSON": currentStateJSON
  ]

  guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else { return }

  var request = URLRequest(url: url)
  request.httpMethod = "POST"
  request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  request.setValue(userId, forHTTPHeaderField: "X-User-Id")
  request.httpBody = httpBody

  if let authToken {
    request.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
  }

  do {
    let (data, httpResponse) = try await URLSession.shared.data(for: request)
    if let httpResponse = httpResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
      let body = String(data: data, encoding: .utf8) ?? ""
      logger.error("VoteResponse failed(\(httpResponse.statusCode)): \(body)")
    } else {
      logger.info("VoteResponse success: \(response) for \(scheduleId)")
    }
  } catch {
    logger.error("VoteResponse error: \(error.localizedDescription)")
  }
}
