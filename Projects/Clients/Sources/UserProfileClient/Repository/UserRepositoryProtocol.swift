import Foundation

// MARK: - UserRepositoryProtocol

/// 사용자 프로필 데이터 저장소 인터페이스
public protocol UserRepositoryProtocol {
  /// 사용자 프로필을 저장소에 저장
  /// - Parameters:
  ///   - uid: 사용자 고유 식별자
  ///   - profile: 저장할 프로필 데이터
  func saveProfile(uid: String, profile: UserProfile) async throws

  /// 사용자 프로필을 저장소에서 가져오기
  /// - Parameter uid: 사용자 고유 식별자
  /// - Returns: 프로필 데이터 (없으면 nil)
  func getProfile(uid: String) async throws -> UserProfile?

  /// 프로필 이미지를 저장소에 업로드
  /// - Parameters:
  ///   - uid: 사용자 고유 식별자
  ///   - imageData: 업로드할 이미지 데이터
  /// - Returns: 업로드된 이미지의 다운로드 URL
  func uploadProfileImage(uid: String, imageData: Data) async throws -> URL

  /// 프로필이 존재하는지 확인
  /// - Parameter uid: 사용자 고유 식별자
  /// - Returns: 프로필 존재 여부
  func hasProfile(uid: String) async throws -> Bool
  
  /// 닉네임 사용 가능 여부 확인
  func isNicknameAvailable(_ nickname: String) async throws -> Bool

  /// 사용자 프로필 업데이트
  /// - Parameters:
  ///   - uid: 사용자 고유 식별자
  ///   - profile: 업데이트할 프로필 데이터
  func updateProfile(uid: String, profile: UserProfile) async throws

  /// 사용자 프로필 삭제
  /// - Parameter uid: 사용자 고유 식별자
  func deleteProfile(uid: String) async throws
}

// MARK: - Mock Repository (for testing/preview)

/// 테스트 및 프리뷰용 Mock Repository
public struct MockUserRepository: UserRepositoryProtocol {
  private var profiles: [String: UserProfile] = [:]

  public init() {}

  public func saveProfile(uid: String, profile: UserProfile) async throws {
    // Mock implementation
  }

  public func getProfile(uid: String) async throws -> UserProfile? {
    return UserProfile(
      name: "Mock User",
      nickname: "Mock User Nickname",
      email: "mock@example.com",
      profileType: .firebase,
      profileImageUrl: nil,
      profileImagePath: "profile_images/mock.jpg"
    )
  }

  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    return URL(string: "https://example.com/mock.jpg")!
  }

  public func hasProfile(uid: String) async throws -> Bool {
    return true
  }
  
  public func isNicknameAvailable(_ nickname: String) async throws -> Bool {
    return true
  }

  public func updateProfile(uid: String, profile: UserProfile) async throws {
    // Mock implementation
  }

  public func deleteProfile(uid: String) async throws {
    // Mock implementation
  }
}
