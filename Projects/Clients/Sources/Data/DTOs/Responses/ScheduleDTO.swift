import Foundation
import FirebaseFirestore
import PromisoShared

// MARK: - Schedule DTO

/// Firestore schedules/{scheduleId} 문서 DTO
///
/// **votes Map 방식**:
/// - votes.accepted: 참여 확정 userId 배열
/// - votes.declined: 참여 불가 userId 배열
/// - votes.until: 투표 마감 시각
/// - pending: memberIds - accepted - declined (계산)
public struct ScheduleDTO: Codable {
  // MARK: - 기본 정보
  public let title: String
  public let emoji: String?
  public let description: String?
  public let descriptionBlocks: [DescriptionBlock]?

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

  // MARK: - 이미지
  public let imageUrls: [String]?

  // MARK: - LiveActivity 설정
  /// LiveActivity 시작 시간 (일정 시간 N분 전)
  public let trackingStartMinutesBefore: Int?

  // MARK: - 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp

  public init(
    title: String,
    emoji: String? = nil,
    description: String? = nil,
    descriptionBlocks: [DescriptionBlock]? = nil,
    hostId: String,
    groupId: String,
    minimumParticipants: Int = 2,
    votes: VotesDTO,
    startAt: Timestamp,
    endAt: Timestamp? = nil,
    location: LocationDTO? = nil,
    imageUrls: [String]? = nil,
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp()
  ) {
    self.title = title
    self.emoji = emoji
    self.description = description
    self.descriptionBlocks = descriptionBlocks
    self.hostId = hostId
    self.groupId = groupId
    self.minimumParticipants = minimumParticipants
    self.votes = votes
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.imageUrls = imageUrls
    self.trackingStartMinutesBefore = trackingStartMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
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

// MARK: - Model -> DTO 변환

extension ScheduleDTO {
  /// Model에서 DTO 생성
  public init(model: ScheduleModel) {
    self.init(
      title: model.title,
      emoji: model.emoji,
      // 하위 호환: 구버전 앱용으로 descriptionBlocks의 plainText를 description에 동기화
      description: model.descriptionBlocks.plainText ?? model.description,
      descriptionBlocks: model.descriptionBlocks.isEmpty ? nil : model.descriptionBlocks,
      hostId: model.hostId,
      groupId: model.groupId,
      minimumParticipants: model.minimumParticipants,
      votes: VotesDTO(model: model.votes),
      startAt: Timestamp(date: model.startAt),
      endAt: model.endAt.map { Timestamp(date: $0) },
      location: model.location.map { LocationDTO(model: $0) },
      imageUrls: model.imageUrls.isEmpty ? nil : model.imageUrls,
      trackingStartMinutesBefore: model.trackingStartMinutesBefore,
      createdAt: Timestamp(date: model.createdAt),
      updatedAt: Timestamp(date: model.updatedAt)
    )
  }
}

extension VotesDTO {
  /// Model에서 DTO 생성
  public init(model: ScheduleVotesModel) {
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
    self.init(
      name: model.name,
      address: model.address,
      latitude: model.latitude,
      longitude: model.longitude
    )
  }
}
