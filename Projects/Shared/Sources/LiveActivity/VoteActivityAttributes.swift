import ActivityKit
import Foundation

// MARK: - Vote Activity Attributes

/// 투표 응답 라이브액티비티의 고정 속성 (Activity 생성 시 설정, 이후 변경 불가)
public struct VoteActivityAttributes: ActivityAttributes, Equatable, Sendable {

  // MARK: - Attributes (고정 정보)

  /// 일정 고유 ID
  public let scheduleId: String

  /// 현재 사용자 ID
  public let currentUserId: String

  /// 일정 이모지
  public let emoji: String

  /// 일정 제목
  public let title: String

  /// 일정 장소명
  public let location: String?

  /// 일정 시간
  public let scheduledTime: Date

  /// 호스트 ID (투표 생성자)
  public let hostId: String

  /// 호스트 이름
  public let hostName: String?

  /// iOS 18 Broadcast 채널 ID
  public let channelId: String

  /// 그룹 이름
  public let groupName: String?

  /// 전체 참여자 수
  public let totalMemberCount: Int

  /// 일정 확정 최소 인원
  public let minimumParticipants: Int

  /// 투표 마감 시간 (scheduledTime - trackingStartMinutes, 최대 8시간)
  public let voteDeadline: Date

  // MARK: - CodingKeys

  private enum CodingKeys: String, CodingKey {
    case scheduleId
    case currentUserId
    case emoji
    case title
    case location
    case scheduledTime
    case hostId
    case hostName
    case channelId
    case groupName
    case totalMemberCount
    case minimumParticipants
    case voteDeadline
  }

  // MARK: - Initializer

  public init(
    scheduleId: String,
    currentUserId: String,
    emoji: String,
    title: String,
    location: String?,
    scheduledTime: Date,
    hostId: String,
    hostName: String? = nil,
    channelId: String,
    groupName: String? = nil,
    totalMemberCount: Int,
    minimumParticipants: Int = 2,
    voteDeadline: Date = Date()
  ) {
    self.scheduleId = scheduleId
    self.currentUserId = currentUserId
    self.emoji = emoji
    self.title = title
    self.location = location
    self.scheduledTime = scheduledTime
    self.hostId = hostId
    self.hostName = hostName
    self.channelId = channelId
    self.groupName = groupName
    self.totalMemberCount = totalMemberCount
    self.minimumParticipants = minimumParticipants
    self.voteDeadline = voteDeadline
  }

  // MARK: - Decodable (Unix timestamp → Date 변환)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.scheduleId = try container.decode(String.self, forKey: .scheduleId)
    self.currentUserId = try container.decode(String.self, forKey: .currentUserId)
    self.emoji = try container.decode(String.self, forKey: .emoji)
    self.title = try container.decode(String.self, forKey: .title)
    self.location = try container.decodeIfPresent(String.self, forKey: .location)
    self.hostId = try container.decodeIfPresent(String.self, forKey: .hostId) ?? ""
    self.hostName = try container.decodeIfPresent(String.self, forKey: .hostName)
    self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId) ?? ""
    self.groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
    self.totalMemberCount = try container.decode(Int.self, forKey: .totalMemberCount)
    self.minimumParticipants = try container.decodeIfPresent(Int.self, forKey: .minimumParticipants) ?? 2

    // scheduledTime: Unix timestamp (1970년 기준 초) → Date 변환
    let timestamp = try container.decode(Double.self, forKey: .scheduledTime)
    self.scheduledTime = Date(timeIntervalSince1970: timestamp)

    // voteDeadline: Unix timestamp → Date 변환
    if let deadlineTs = try container.decodeIfPresent(Double.self, forKey: .voteDeadline) {
      self.voteDeadline = Date(timeIntervalSince1970: deadlineTs)
    } else {
      self.voteDeadline = self.scheduledTime
    }
  }

  // MARK: - Encodable (Date → Unix timestamp 변환)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(scheduleId, forKey: .scheduleId)
    try container.encode(currentUserId, forKey: .currentUserId)
    try container.encode(emoji, forKey: .emoji)
    try container.encode(title, forKey: .title)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encode(hostId, forKey: .hostId)
    try container.encodeIfPresent(hostName, forKey: .hostName)
    try container.encode(channelId, forKey: .channelId)
    try container.encodeIfPresent(groupName, forKey: .groupName)
    try container.encode(totalMemberCount, forKey: .totalMemberCount)
    try container.encode(minimumParticipants, forKey: .minimumParticipants)

    // Date → Unix timestamp (1970년 기준 초) 변환
    try container.encode(scheduledTime.timeIntervalSince1970, forKey: .scheduledTime)
    try container.encode(voteDeadline.timeIntervalSince1970, forKey: .voteDeadline)
  }

  // MARK: - Content State (동적 정보)

  /// 투표 응답 라이브액티비티의 동적 상태 (실시간 업데이트 가능)
  public struct ContentState: Codable, Hashable, Sendable {

    /// 참여 응답한 사람들
    public let acceptedMembers: [VoteMember]

    /// 불참 응답한 사람들
    public let declinedMembers: [VoteMember]

    /// 아직 미응답한 사람 수
    public let pendingCount: Int

    /// 투표가 종료되었는지
    public let isFinalized: Bool

    public init(
      acceptedMembers: [VoteMember] = [],
      declinedMembers: [VoteMember] = [],
      pendingCount: Int,
      isFinalized: Bool = false
    ) {
      self.acceptedMembers = acceptedMembers
      self.declinedMembers = declinedMembers
      self.pendingCount = pendingCount
      self.isFinalized = isFinalized
    }
  }
}

// MARK: - Vote Member

/// 투표 참가자 정보
public struct VoteMember: Codable, Hashable, Identifiable, Sendable {

  /// 참가자 고유 ID
  public let id: String

  /// 참가자 표시 이름
  public let name: String

  public init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}
