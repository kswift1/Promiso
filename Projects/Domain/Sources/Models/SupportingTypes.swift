import Foundation

// MARK: - Promise Status

public enum PromiseStatus: String, CaseIterable, Codable {
  case draft = "draft"           // 초안
  case pending = "pending"       // 대기 중
  case active = "active"         // 활성 (확정됨)
  case completed = "completed"   // 완료
  case cancelled = "cancelled"   // 취소
}

// MARK: - Promise Counts

public struct PromiseCounts: Hashable, Codable, Equatable {
  public let total: Int
  public let accepted: Int
  public let declined: Int
  public let pending: Int
  
  public init(
    total: Int = 0,
    accepted: Int = 0,
    declined: Int = 0,
    pending: Int = 0
  ) {
    self.total = total
    self.accepted = accepted
    self.declined = declined
    self.pending = pending
  }
  
  public var isConfirmed: Bool {
    return accepted >= 1 // 최소 1명 이상 수락하면 확정
  }
}

// MARK: - Location Info

public struct LocationInfo: Hashable, Codable, Equatable {
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
