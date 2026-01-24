import Foundation
import PromisoShared

// MARK: - User Profile Errors

/// 사용자 프로필 관련 에러
public enum UserProfileError: Error, LocalizedError, Equatable {
  case invalidData
  case userNotFound
  case uploadFailed
  case networkError
  case authenticationRequired
  case permissionDenied

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
    case .authenticationRequired:
      return "로그인이 필요합니다."
    case .permissionDenied:
      return "권한이 없습니다."
    }
  }
}

// MARK: - Provider Info

/// 인증 제공자 정보
public struct ProviderInfo: Equatable, Sendable {
  public let type: String
  public let uid: String
  public let email: String

  public init(type: String, uid: String, email: String) {
    self.type = type
    self.uid = uid
    self.email = email
  }
}

// MARK: - User Settings

/// 사용자 설정 정보
public struct UserSettings: Equatable, Sendable {
  public var notificationEnabled: Bool
  public var groupSortOption: GroupSortOption

  public init(
    notificationEnabled: Bool,
    groupSortOption: GroupSortOption
  ) {
    self.notificationEnabled = notificationEnabled
    self.groupSortOption = groupSortOption
  }
}
