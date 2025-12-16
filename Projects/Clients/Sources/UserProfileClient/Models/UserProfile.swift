import Foundation

// MARK: - UserProfile Model

public struct UserProfile: Codable, Equatable, Sendable {
  public let name: String
  public let nickname: String
  public let email: String?
  public let provider: ProviderInfo?
  public let profile: ProfileInfo?
  public let pinnedGroupId: String?
  public let notificationSettings: NotificationSettings
  public let createdAt: Date
  public let updatedAt: Date
  
  public init(
    name: String,
    nickname: String,
    email: String?,
    provider: ProviderInfo? = nil,
    profile: ProfileInfo? = nil,
    pinnedGroupId: String? = nil,
    notificationSettings: NotificationSettings = .default,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.name = name
    self.nickname = nickname
    self.email = email
    self.provider = provider
    self.profile = profile
    self.pinnedGroupId = pinnedGroupId
    self.notificationSettings = notificationSettings
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Provider Info

public struct ProviderInfo: Codable, Equatable, Sendable {
  public let uid: String
  public let type: String
  
  public init(uid: String, type: String) {
    self.uid = uid
    self.type = type
  }
}

// MARK: - Profile Info

public struct ProfileInfo: Codable, Equatable, Sendable {
  public enum InfoType: String, Codable, Equatable, Sendable {
    case storagePath
    case externalURL
    case none
  }
  
  public let type: InfoType
  public let url: String?
  
  public init(type: InfoType, url: String?) {
    self.type = type
    self.url = url
  }
}

// MARK: - NotificationSettings

public struct NotificationSettings: Codable, Equatable, Sendable {
  public let enabled: Bool
  
  public init(enabled: Bool) {
    self.enabled = enabled
  }
  
  public static let `default` = NotificationSettings(enabled: false)
}

// MARK: - Firestore Encoding/Decoding

extension UserProfile {
  public func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "name": name,
      "nickname": nickname,
      "notificationSettings": [
        "enabled": notificationSettings.enabled
      ],
      "metadata": [
        "createdAt": createdAt,
        "updatedAt": updatedAt
      ]
    ]
    
    if let email {
      data["email"] = email
    }
    
    if let provider {
      data["provider"] = [
        "uid": provider.uid,
        "type": provider.type
      ]
    }
    
    if let profile, profile.type != .none {
      data["profile"] = [
        "type": profile.type.rawValue,
        "url": profile.url as Any
      ]
    }
    
    if let pinnedGroupId {
      data["pinnedGroupId"] = pinnedGroupId
    }
    
    return data
  }
  
  public static func fromFirestoreData(_ data: [String: Any]) throws -> UserProfile {
    guard let name = data["name"] as? String,
          let nickname = data["nickname"] as? String,
          let notificationData = data["notificationSettings"] as? [String: Any],
          let notificationEnabled = notificationData["enabled"] as? Bool else {
      throw UserProfileError.invalidData
    }
    
    let email = data["email"] as? String
    let profileDict = data["profile"] as? [String: Any]
    let profileInfoType = (profileDict?["type"] as? String).flatMap(ProfileInfo.InfoType.init(rawValue:)) ?? .none
    let profileUrl = profileDict?["url"] as? String
    
    let providerDict = data["provider"] as? [String: Any]
    let providerId = providerDict?["type"] as? String
    let providerUid = providerDict?["uid"] as? String
    let pinnedGroupId = data["pinnedGroupId"] as? String
    
    let metadata = data["metadata"] as? [String: Any]
    let createdAt = (metadata?["createdAt"] as? Date) ?? (data["createdAt"] as? Date) ?? Date()
    let updatedAt = (metadata?["updatedAt"] as? Date) ?? (data["updatedAt"] as? Date) ?? Date()
    
    return UserProfile(
      name: name,
      nickname: nickname,
      email: email,
      provider: {
        if let providerId, let providerUid {
          return ProviderInfo(uid: providerUid, type: providerId)
        }
        return nil
      }(),
      profile: profileInfoType == .none ? nil : ProfileInfo(type: profileInfoType, url: profileUrl),
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
