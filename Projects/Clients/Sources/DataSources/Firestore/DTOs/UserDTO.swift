import Foundation

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
    let notifications: Bool
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

    let groupsModel: [String: UserGroupInfo] = groups?.mapValues { dto in
      UserGroupInfo(
        groupName: dto.groupName,
        role: dto.role,
        joinedAt: dto.joinedAt.date,
        notifications: dto.notifications
      )
    } ?? [:]

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
