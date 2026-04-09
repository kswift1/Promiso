import Foundation
import PromisoShared

// MARK: - Personal Event DTO

/// Firestore users/{userId}/personalEvents/{eventId} 문서 DTO
public struct PersonalEventDTO: Codable {
  // MARK: - 기본 정보
  public let title: String
  public let emoji: String?
  public let description: String?
  public let descriptionBlocks: [DescriptionBlock]?

  // MARK: - 시간
  public let startAt: Timestamp
  public let endAt: Timestamp?

  // MARK: - 위치
  public let location: LocationDTO?

  // MARK: - 이미지
  public let imageUrls: [String]?

  // MARK: - 알림
  public let reminderMinutesBefore: Int?

  // MARK: - 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp

  public init(
    title: String,
    emoji: String? = nil,
    description: String? = nil,
    descriptionBlocks: [DescriptionBlock]? = nil,
    startAt: Timestamp,
    endAt: Timestamp? = nil,
    location: LocationDTO? = nil,
    imageUrls: [String]? = nil,
    reminderMinutesBefore: Int? = nil,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp()
  ) {
    self.title = title
    self.emoji = emoji
    self.description = description
    self.descriptionBlocks = descriptionBlocks
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.imageUrls = imageUrls
    self.reminderMinutesBefore = reminderMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Model -> DTO 변환

extension PersonalEventDTO {
  /// Model에서 DTO 생성
  public init(model: PersonalEventModel) {
    self.init(
      title: model.title,
      emoji: model.emoji,
      // 하위 호환: 구버전 앱용으로 descriptionBlocks의 plainText를 description에 동기화
      description: model.descriptionBlocks.plainText ?? model.description,
      descriptionBlocks: model.descriptionBlocks.nilIfAllEmpty,
      startAt: Timestamp(date: model.startAt),
      endAt: model.endAt.map { Timestamp(date: $0) },
      location: model.location.map { LocationDTO(model: $0) },
      imageUrls: model.imageUrls.isEmpty ? nil : model.imageUrls,
      reminderMinutesBefore: model.reminderMinutesBefore,
      createdAt: Timestamp(date: model.createdAt),
      updatedAt: Timestamp(date: model.updatedAt)
    )
  }
}
