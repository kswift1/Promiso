import Foundation
import Shared

// MARK: - UserProfile → Domain Model Conversion
// Adapter Layer의 책임: DTO를 Domain Model로 변환

extension UserProfile {
  /// UserProfile (DTO) → UserModel (Domain) 변환
  /// Adapter Layer에서 변환 책임을 가짐
  public func toDomain(uid: String) -> UserModel {
    return UserModel(
      id: uid,
      email: email ?? "",
      nickname: nickname,
      pinnedGroupId: pinnedGroupId,
      profileImageUrl: profile?.url,
      profileType: {
        switch profile?.type {
        case .storagePath: return .firebase
        case .externalURL: return .url
        case .some(.none), nil: return .none
        }
      }(),
      providerId: provider?.type,
      providerUid: provider?.uid,
      providerType: provider?.type,
      notificationEnabled: notificationSettings.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
