import Foundation
import FirebaseFirestore

/// Firestore Users 컬렉션 문서 모델
public struct UserDocument: Codable {
  // MARK: - 기본 정보
  public let name: String
  public let email: String
  public let profileImageUrl: String?
  
  // MARK: - 설정
  public let notificationSettings: UserDocumentNotificationSettings
  
  // MARK: - 타임스탬프
  public let createdAt: Timestamp
  public let updatedAt: Timestamp
  
  public init(
    name: String,
    email: String,
    profileImageUrl: String? = nil,
    notificationSettings: UserDocumentNotificationSettings = UserDocumentNotificationSettings(),
    createdAt: Timestamp = Timestamp(),
    updatedAt: Timestamp = Timestamp()
  ) {
    self.name = name
    self.email = email
    self.profileImageUrl = profileImageUrl
    self.notificationSettings = notificationSettings
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - UserDocumentNotificationSettings
public struct UserDocumentNotificationSettings: Codable {
  public let enabled: Bool
  public let defaultReminderMinutes: Int

  public init(
    enabled: Bool = true,
    defaultReminderMinutes: Int = 60
  ) {
    self.enabled = enabled
    self.defaultReminderMinutes = defaultReminderMinutes
  }
}

// MARK: - CodingKeys
extension UserDocument {
  enum CodingKeys: String, CodingKey {
    case name
    case email
    case profileImageUrl
    case notificationSettings
    case createdAt
    case updatedAt
  }
}

extension UserDocumentNotificationSettings {
  enum CodingKeys: String, CodingKey {
    case enabled
    case defaultReminderMinutes
  }
}
