import Foundation
import FirebaseFirestore

// MARK: - Personal Event DTO

/// Firestore personalEvents/{eventId} 문서 DTO
public struct PersonalEventDTO: Codable {
  // MARK: - 기본 정보
  public let title: String
  public let emoji: String?
  public let description: String?

  // MARK: - 소유자
  public let userId: String

  // MARK: - 시간
  public let startAt: Timestamp
  public let endAt: Timestamp?

  // MARK: - 위치
  public let location: LocationDTO?

  // MARK: - 알림
  public let reminderMinutesBefore: Int?

  // MARK: - 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp

  public init(
    title: String,
    emoji: String? = nil,
    description: String? = nil,
    userId: String,
    startAt: Timestamp,
    endAt: Timestamp? = nil,
    location: LocationDTO? = nil,
    reminderMinutesBefore: Int? = nil,
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp()
  ) {
    self.title = title
    self.emoji = emoji
    self.description = description
    self.userId = userId
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
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
      description: model.description,
      userId: model.userId,
      startAt: Timestamp(date: model.startAt),
      endAt: model.endAt.map { Timestamp(date: $0) },
      location: model.location.map { LocationDTO(model: $0) },
      reminderMinutesBefore: model.reminderMinutesBefore,
      createdAt: Timestamp(date: model.createdAt),
      updatedAt: Timestamp(date: model.updatedAt)
    )
  }
}
