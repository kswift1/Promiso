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

  if await performAuthenticatedWidgetPost(
    to: url,
    userId: userId,
    body: httpBody,
    logContext: "VoteResponse"
  ) {
    logger.info("VoteResponse success: \(response) for \(scheduleId)")
  }
}
