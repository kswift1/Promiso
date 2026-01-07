import Foundation
import FirebaseFirestore

import PromisoShared

/// Firebase Functions 응답 구조
private struct UserProfileResponse: Codable {
  let userId: String
  let name: String
  let nickname: String
  let email: String?
  let provider: String?
  let metaData: MetadataResponse
  let profile: ProfileImageResponse?
  let groups: [String: GroupInfoResponse]?

  struct MetadataResponse: Codable {
    let createdAt: FirebaseTimestamp
    let updatedAt: FirebaseTimestamp
  }

  struct ProfileImageResponse: Codable {
    let url: String
    let thumbUrl: String?
    let updatedAt: FirebaseTimestamp

    var isValid: Bool {
      url != "<null>"
    }
  }

  struct GroupInfoResponse: Codable {
    let groupName: String
    let role: GroupRole
    let joinedAt: FirebaseTimestamp
    let notifications: Bool

    func toModel() -> UserGroupInfo {
      UserGroupInfo(
        groupName: groupName,
        role: role,
        joinedAt: joinedAt.date,
        notifications: notifications
      )
    }
  }

  struct FirebaseTimestamp: Codable {
    let _seconds: TimeInterval
    let _nanoseconds: TimeInterval?

    var date: Date {
      Date(timeIntervalSince1970: _seconds + (_nanoseconds ?? 0) / 1_000_000_000)
    }
  }

  func toUserModel() -> UserPrivate {
    let profileImage: ProfileImage? = if let profile = profile, profile.isValid {
      ProfileImage(
        url: profile.url,
        thumbUrl: profile.thumbUrl == "<null>" ? nil : profile.thumbUrl,
        updatedAt: profile.updatedAt.date
      )
    } else {
      nil
    }

    let groupsModel: [String: UserGroupInfo] = groups?.mapValues { $0.toModel() } ?? [:]

    return UserPrivate(
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
