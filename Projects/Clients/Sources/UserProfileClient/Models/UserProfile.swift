import Foundation

// MARK: - UserProfile Model

public struct UserProfile: Codable, Equatable, Sendable {
  public let name: String
  public let nickname: String
  public let email: String?
  public let profileType: ProfileType
  public let profileImageUrl: String?
  public let profileImagePath: String?
  public let pinnedGroupId: String?
  public let notificationSettings: NotificationSettings
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    name: String,
    nickname: String,
    email: String?,
    profileType: ProfileType,
    profileImageUrl: String? = nil,
    profileImagePath: String? = nil,
    pinnedGroupId: String? = nil,
    notificationSettings: NotificationSettings = .default,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.name = name
    self.nickname = nickname
    self.email = email
    self.profileType = profileType
    self.profileImageUrl = profileImageUrl
    self.profileImagePath = profileImagePath
    self.pinnedGroupId = pinnedGroupId
    self.notificationSettings = notificationSettings
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - ProfileType

public enum ProfileType: String, Codable, Equatable, Sendable {
  case url = "URL"
  case firebase = "FIREBASE"
}

// MARK: - NotificationSettings

public struct NotificationSettings: Codable, Equatable, Sendable {
  public let enabled: Bool

  public init(enabled: Bool) {
    self.enabled = enabled
  }

  public static let `default` = NotificationSettings(enabled: true)
}

// MARK: - Firestore Encoding/Decoding

extension UserProfile {
  /// Firestore에 저장할 딕셔너리 형식으로 변환
  public func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "name": name,
      "nickname": nickname,
      "profileType": profileType.rawValue,
      "notificationSettings": [
        "enabled": notificationSettings.enabled
      ],
      "createdAt": createdAt,
      "updatedAt": updatedAt
    ]

    if let email = email {
      data["email"] = email
    }

    if let profileImageUrl = profileImageUrl {
      data["profileImageUrl"] = profileImageUrl
    }

    if let profileImagePath = profileImagePath {
      data["profileImagePath"] = profileImagePath
    }

    if let pinnedGroupId = pinnedGroupId {
      data["pinnedGroupId"] = pinnedGroupId
    }

    return data
  }

  /// Firestore 딕셔너리로부터 UserProfile 생성
  public static func fromFirestoreData(_ data: [String: Any]) throws -> UserProfile {
    guard let name = data["name"] as? String,
          let nickname = data["nickname"] as? String,
          let profileTypeString = data["profileType"] as? String,
          let profileType = ProfileType(rawValue: profileTypeString),
          let notificationData = data["notificationSettings"] as? [String: Any],
          let notificationEnabled = notificationData["enabled"] as? Bool else {
      throw UserProfileError.invalidData
    }

    let email = data["email"] as? String
    let profileImageUrl = data["profileImageUrl"] as? String
    let profileImagePath = data["profileImagePath"] as? String
    let pinnedGroupId = data["pinnedGroupId"] as? String

    // Firestore Timestamp를 Date로 변환
    let createdAt: Date
    let updatedAt: Date

    if let timestamp = data["createdAt"] as? Date {
      createdAt = timestamp
    } else {
      createdAt = Date()
    }

    if let timestamp = data["updatedAt"] as? Date {
      updatedAt = timestamp
    } else {
      updatedAt = Date()
    }

    return UserProfile(
      name: name,
      nickname: nickname,
      email: email,
      profileType: profileType,
      profileImageUrl: profileImageUrl,
      profileImagePath: profileImagePath,
      pinnedGroupId: pinnedGroupId,
      notificationSettings: NotificationSettings(enabled: notificationEnabled),
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

// MARK: - Errors

public enum UserProfileError: Error, LocalizedError {
  case invalidData
  case userNotFound
  case uploadFailed
  case networkError

  public var errorDescription: String? {
    switch self {
    case .invalidData:
      return "프로필 데이터 형식이 올바르지 않습니다."
    case .userNotFound:
      return "사용자를 찾을 수 없습니다."
    case .uploadFailed:
      return "프로필 업로드에 실패했습니다."
    case .networkError:
      return "네트워크 연결을 확인해주세요."
    }
  }
}
