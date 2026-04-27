import Foundation
import PromisoShared

// MARK: - Ranged Event

/// 시작/종료 시간을 가진 이벤트의 공통 인터페이스
public protocol RangedEvent {
  var startAt: Date { get }
  var endAt: Date? { get }
  var timeText: String { get }
}

extension RangedEvent {
  /// 시간 범위 텍스트 (같은 날: "14:00 ~ 16:00", 다른 날: "1월 27일 14:00 ~ 1월 28일 16:00")
  public var timeRangeText: String {
    guard let endAt = endAt else { return timeText }
    let calendar = Calendar.current
    if calendar.isDate(startAt, inSameDayAs: endAt) {
      return "\(timeText) ~ \(endAt.formattedTime)"
    } else {
      return "\(LocalizedDateFormatters.monthDayTimeString(from: startAt)) ~ \(LocalizedDateFormatters.monthDayTimeString(from: endAt))"
    }
  }
}

// MARK: - Schedule Votes Model

/// 투표 정보 (votes Map)
public struct ScheduleVotesModel: Hashable, Codable, Equatable, Sendable {
  /// 참여 확정한 userId 목록
  public let accepted: [String]
  /// 참여 불가한 userId 목록
  public let declined: [String]
  /// 투표 마감 시각
  public let until: Date

  public init(
    accepted: [String] = [],
    declined: [String] = [],
    until: Date = Date()
  ) {
    self.accepted = accepted
    self.declined = declined
    self.until = until
  }

  // MARK: - 계산 프로퍼티

  public var acceptedCount: Int { accepted.count }
  public var declinedCount: Int { declined.count }

  /// 투표한 인원 (accepted + declined)
  public var votedCount: Int { accepted.count + declined.count }

  /// pending 멤버 계산 (memberIds - accepted - declined)
  public func pendingMembers(memberIds: [String]) -> [String] {
    memberIds.filter { !accepted.contains($0) && !declined.contains($0) }
  }

  public func pendingCount(memberIds: [String]) -> Int {
    pendingMembers(memberIds: memberIds).count
  }

  /// 확정 여부 (accepted >= minimumParticipants)
  public func isConfirmed(minimumParticipants: Int) -> Bool {
    accepted.count >= minimumParticipants
  }

  /// 내 투표 상태
  public func myStatus(userId: String) -> VoteStatus {
    if accepted.contains(userId) { return .accepted }
    if declined.contains(userId) { return .declined }
    return .pending
  }
}

// MARK: - Vote Status

public enum VoteStatus: String, Codable, Equatable, Sendable {
  case pending   // 투표 대기 (계산)
  case accepted  // 참여 확정
  case declined  // 참여 불가
}


// MARK: - Proposal

public struct Proposal: Hashable, Codable, Equatable {
  public let id: String
  public let title: String
  public let description: String?
  public let fromUserId: String
  public let toUserId: String
  public let scheduleId: String?
  public let status: ProposalStatus
  public let createdAt: Date
  public let updatedAt: Date
  
  public init(
    id: String,
    title: String,
    description: String? = nil,
    fromUserId: String,
    toUserId: String,
    scheduleId: String? = nil,
    status: ProposalStatus,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.fromUserId = fromUserId
    self.toUserId = toUserId
    self.scheduleId = scheduleId
    self.status = status
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public enum ProposalStatus: String, CaseIterable, Codable {
  case pending = "pending"     // 대기 중
  case accepted = "accepted"   // 수락됨
  case declined = "declined"   // 거절됨
  case expired = "expired"     // 만료됨
}

// MARK: - DTO -> Model 변환

extension ScheduleVotesModel {
  /// DTO에서 Model 생성
  public init(dto: VotesDTO) {
    self.init(
      accepted: dto.accepted,
      declined: dto.declined,
      until: dto.until.dateValue()
    )
  }
}

extension LocationInfoModel {
  /// DTO에서 Model 생성
  public init(dto: LocationDTO) {
    self.init(
      name: dto.name,
      address: dto.address,
      latitude: dto.latitude,
      longitude: dto.longitude
    )
  }
}
