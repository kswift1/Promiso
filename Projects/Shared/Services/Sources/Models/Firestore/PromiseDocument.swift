import Foundation
import FirebaseFirestore

/// Firestore Promises 컬렉션 문서 모델
public struct PromiseDocument: Codable {
  // MARK: - 기본 정보
  public let emoji: String?
  public let title: String
  public let description: String?
  
  // MARK: - 확정 조건
  public let minimumParticipants: Int
  public let requiredCount: Int
  public let isConfirmed: Bool
  public let confirmedAt: Timestamp?
  
  // MARK: - 관계 (캐시 포함)
  public let hostId: String
  public let hostName: String // 캐시
  public let groupId: String
  public let groupName: String // 캐시
  
  // MARK: - 카운터 객체
  public let counts: PromiseCounts
  
  // MARK: - 시간
  public let startAt: Timestamp
  public let endAt: Timestamp?
  
  // MARK: - 달력 인덱스
  public let localYyyymm: String // 202401
  public let localYyyymmdd: String // 20240115
  public let localTz: String // Asia/Seoul
  
  // MARK: - 상태
  public let status: PromiseStatus
  
  // MARK: - 위치
  public let location: LocationInfo?
  
  // MARK: - 검색 최적화
  public let titleLower: String // 소문자 변환된 제목
  
  // MARK: - 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  public let isDeleted: Bool
  
  public init(
    emoji: String? = nil,
    title: String,
    description: String? = nil,
    minimumParticipants: Int,
    requiredCount: Int,
    isConfirmed: Bool = false,
    confirmedAt: Timestamp? = nil,
    hostId: String,
    hostName: String,
    groupId: String,
    groupName: String,
    counts: PromiseCounts = PromiseCounts(),
    startAt: Timestamp,
    endAt: Timestamp? = nil,
    localYyyymm: String,
    localYyyymmdd: String,
    localTz: String = "Asia/Seoul",
    status: PromiseStatus = .draft,
    location: LocationInfo? = nil,
    titleLower: String? = nil,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp(),
    isDeleted: Bool = false
  ) {
    self.emoji = emoji
    self.title = title
    self.description = description
    self.minimumParticipants = minimumParticipants
    self.requiredCount = requiredCount
    self.isConfirmed = isConfirmed
    self.confirmedAt = confirmedAt
    self.hostId = hostId
    self.hostName = hostName
    self.groupId = groupId
    self.groupName = groupName
    self.counts = counts
    self.startAt = startAt
    self.endAt = endAt
    self.localYyyymm = localYyyymm
    self.localYyyymmdd = localYyyymmdd
    self.localTz = localTz
    self.status = status
    self.location = location
    self.titleLower = titleLower ?? title.lowercased()
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
  }
}

// MARK: - PromiseCounts
public struct PromiseCounts: Codable {
  public let total: Int
  public let accepted: Int
  public let declined: Int
  public let tentative: Int
  
  // pending은 계산값: total - (accepted + declined + tentative)
  public var pending: Int {
    return total - (accepted + declined + tentative)
  }
  
  public init(
    total: Int = 0,
    accepted: Int = 0,
    declined: Int = 0,
    tentative: Int = 0
  ) {
    self.total = total
    self.accepted = accepted
    self.declined = declined
    self.tentative = tentative
  }
}

// MARK: - PromiseStatus
public enum PromiseStatus: String, Codable, CaseIterable {
  case draft = "draft"
  case active = "active"
  case cancelled = "cancelled"
  case completed = "completed"
}

// MARK: - LocationInfo
public struct LocationInfo: Codable {
  public let name: String
  public let address: String?
  public let latitude: Double?
  public let longitude: Double?
  public let placeId: String?
  
  public init(
    name: String,
    address: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    placeId: String? = nil
  ) {
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.placeId = placeId
  }
}

// MARK: - CodingKeys
extension PromiseDocument {
  enum CodingKeys: String, CodingKey {
    case emoji
    case title
    case description
    case minimumParticipants
    case requiredCount
    case isConfirmed
    case confirmedAt
    case hostId
    case hostName
    case groupId
    case groupName
    case counts
    case startAt
    case endAt
    case localYyyymm
    case localYyyymmdd
    case localTz
    case status
    case location
    case titleLower
    case createdAt
    case updatedAt
    case isDeleted
  }
}

extension PromiseCounts {
  enum CodingKeys: String, CodingKey {
    case total
    case accepted
    case declined
    case tentative
  }
}

extension LocationInfo {
  enum CodingKeys: String, CodingKey {
    case name
    case address
    case latitude
    case longitude
    case placeId
  }
}
