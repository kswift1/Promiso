import Foundation
import FirebaseFirestore

// MARK: - Promise DTO

/// Firestore promises/{promiseId} 문서 DTO
///
/// **votes Map 방식**:
/// - votes.accepted: 참여 확정 userId 배열
/// - votes.declined: 참여 불가 userId 배열
/// - votes.until: 투표 마감 시각
/// - pending: memberIds - accepted - declined (계산)
public struct PromiseDTO: Codable {
  // MARK: - 기본 정보
  public let title: String
  public let emoji: String?
  public let description: String?

  // MARK: - 관계
  public let hostId: String
  public let groupId: String

  // MARK: - 확정 조건
  public let minimumParticipants: Int

  // MARK: - 투표 정보
  public let votes: VotesDTO

  // MARK: - 시간
  public let startAt: Timestamp
  public let endAt: Timestamp?

  // MARK: - 위치
  public let location: LocationDTO?

  // MARK: - LiveActivity 설정
  /// LiveActivity 시작 시간 (약속 시간 N분 전)
  public let trackingStartMinutesBefore: Int?

  // MARK: - 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  public let isDeleted: Bool

  public init(
    title: String,
    emoji: String? = nil,
    description: String? = nil,
    hostId: String,
    groupId: String,
    minimumParticipants: Int = 2,
    votes: VotesDTO,
    startAt: Timestamp,
    endAt: Timestamp? = nil,
    location: LocationDTO? = nil,
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp(),
    isDeleted: Bool = false
  ) {
    self.title = title
    self.emoji = emoji
    self.description = description
    self.hostId = hostId
    self.groupId = groupId
    self.minimumParticipants = minimumParticipants
    self.votes = votes
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.trackingStartMinutesBefore = trackingStartMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
  }
}

// MARK: - Votes DTO

/// votes Map DTO
public struct VotesDTO: Codable {
  public let accepted: [String]
  public let declined: [String]
  public let until: Timestamp

  public init(
    accepted: [String] = [],
    declined: [String] = [],
    until: Timestamp = Timestamp()
  ) {
    self.accepted = accepted
    self.declined = declined
    self.until = until
  }
}

// MARK: - Location DTO

/// location Map DTO
public struct LocationDTO: Codable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

// MARK: - Model -> DTO 변환

extension PromiseDTO {
  /// Model에서 DTO 생성
  public init(model: PromiseModel) {
    self.init(
      title: model.title,
      emoji: model.emoji,
      description: model.description,
      hostId: model.hostId,
      groupId: model.groupId,
      minimumParticipants: model.minimumParticipants,
      votes: VotesDTO(model: model.votes),
      startAt: Timestamp(date: model.startAt),
      endAt: model.endAt.map { Timestamp(date: $0) },
      location: model.location.map { LocationDTO(model: $0) },
      trackingStartMinutesBefore: model.trackingStartMinutesBefore,
      createdAt: Timestamp(date: model.createdAt),
      updatedAt: Timestamp(date: model.updatedAt),
      isDeleted: model.isDeleted
    )
  }
}

extension VotesDTO {
  /// Model에서 DTO 생성
  public init(model: PromiseVotesModel) {
    self.init(
      accepted: model.accepted,
      declined: model.declined,
      until: Timestamp(date: model.until)
    )
  }
}

extension LocationDTO {
  /// Model에서 DTO 생성
  public init(model: LocationInfoModel) {
    self.init(name: model.name)
  }
}
