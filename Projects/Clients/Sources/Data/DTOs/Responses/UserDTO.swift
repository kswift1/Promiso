import Foundation
import PromisoShared

/// Firebase Functions User 응답 DTO
struct UserDTO: Codable {
  let userId: String
  let name: String
  let nickname: String
  let email: String?
  let provider: String?
  let metaData: MetadataDTO
  let profile: ProfileImageDTO?
  let groups: [String: UserGroupInfoDTO]?

  struct MetadataDTO: Codable {
    let createdAt: FirebaseTimestampDTO
    let updatedAt: FirebaseTimestampDTO
  }

  struct ProfileImageDTO: Codable {
    let url: String
    let thumbUrl: String?
    let updatedAt: FirebaseTimestampDTO

    var isValid: Bool {
      url != "<null>"
    }
  }

  struct UserGroupInfoDTO: Codable {
    let groupName: String
    let role: GroupRole
    let joinedAt: FirebaseTimestampDTO
    let notifications: GroupNotificationSettings?
    let hasNewActivity: Bool?
    let imageUrl: String?

    private enum CodingKeys: String, CodingKey {
      case groupName
      case role
      case joinedAt
      case notifications
      case notificationPreferences
      case hasNewActivity
      case imageUrl
    }

    init(
      groupName: String,
      role: GroupRole,
      joinedAt: FirebaseTimestampDTO,
      notifications: GroupNotificationSettings?,
      hasNewActivity: Bool?,
      imageUrl: String?
    ) {
      self.groupName = groupName
      self.role = role
      self.joinedAt = joinedAt
      self.notifications = notifications
      self.hasNewActivity = hasNewActivity
      self.imageUrl = imageUrl
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      groupName = try container.decode(String.self, forKey: .groupName)
      role = try container.decode(GroupRole.self, forKey: .role)
      joinedAt = try container.decode(FirebaseTimestampDTO.self, forKey: .joinedAt)
      hasNewActivity = try container.decodeIfPresent(Bool.self, forKey: .hasNewActivity)
      imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)

      if let settings = try? container.decode(GroupNotificationSettings.self, forKey: .notifications) {
        notifications = settings
      } else if let enabled = try? container.decode(Bool.self, forKey: .notifications) {
        let legacyPreferences = try? container.decode([String: Bool].self, forKey: .notificationPreferences)
        notifications = GroupNotificationPreferences.fromLegacy(
          enabled: enabled,
          preferences: legacyPreferences
        )
      } else {
        notifications = nil
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(groupName, forKey: .groupName)
      try container.encode(role, forKey: .role)
      try container.encode(joinedAt, forKey: .joinedAt)
      try container.encodeIfPresent(notifications, forKey: .notifications)
      try container.encodeIfPresent(hasNewActivity, forKey: .hasNewActivity)
      try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
    }
  }

  struct FirebaseTimestampDTO: Codable {
    let _seconds: TimeInterval
    let _nanoseconds: TimeInterval?

    var date: Date {
      Date(timeIntervalSince1970: _seconds + (_nanoseconds ?? 0) / 1_000_000_000)
    }
  }
}

// MARK: - Model Conversion

extension UserDTO {
  func toModel() -> UserPrivateModel {
    let profileImage: ProfileImage? = if let profile = profile, profile.isValid {
      ProfileImage(
        url: profile.url,
        thumbUrl: profile.thumbUrl == "<null>" ? nil : profile.thumbUrl,
        updatedAt: profile.updatedAt.date
      )
    } else {
      nil
    }

    let groupsModel: [UserGroupInfo] = groups?.map { (groupId, dto) in
      UserGroupInfo(
        id: groupId,
        name: dto.groupName,
        role: dto.role,
        joinedAt: dto.joinedAt.date,
        notifications: dto.notifications,
        hasNewActivity: dto.hasNewActivity ?? false,
        imageUrl: dto.imageUrl
      )
    } ?? []

    return UserPrivateModel(
      userId: userId,
      name: name,
      nickname: nickname,
      email: email ?? "",
      provider: provider ?? "",
      profile: profileImage,
      metadata: Metadata(
        createdAt: metaData.createdAt.date,
        updatedAt: metaData.updatedAt.date
      ),
      groups: groupsModel
    )
  }
}
