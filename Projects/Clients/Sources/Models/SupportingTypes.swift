import Foundation
import FirebaseFirestore

// MARK: - Promise Status

public enum PromiseStatus: String, CaseIterable, Codable, Sendable {
  case draft = "draft"           // 초안
  case pending = "pending"       // 대기 중
  case active = "active"         // 활성 (확정됨)
  case completed = "completed"   // 완료
  case cancelled = "cancelled"   // 취소
}

// MARK: - Promise Votes Model

/// 투표 정보 (votes Map)
public struct PromiseVotesModel: Hashable, Codable, Equatable, Sendable {
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

// MARK: - Location Info Model

public struct LocationInfoModel: Hashable, Codable, Equatable, Sendable {
  public let name: String
  public let address: String?
  public let latitude: Double?
  public let longitude: Double?
  
  public init(
    name: String,
    address: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil
  ) {
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
  }
}

// MARK: - Proposal

public struct Proposal: Hashable, Codable, Equatable {
  public let id: String
  public let title: String
  public let description: String?
  public let fromUserId: String
  public let toUserId: String
  public let promiseId: String?
  public let status: ProposalStatus
  public let createdAt: Date
  public let updatedAt: Date
  
  public init(
    id: String,
    title: String,
    description: String? = nil,
    fromUserId: String,
    toUserId: String,
    promiseId: String? = nil,
    status: ProposalStatus,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.fromUserId = fromUserId
    self.toUserId = toUserId
    self.promiseId = promiseId
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

extension PromiseVotesModel {
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
    self.init(name: dto.name)
  }
}
