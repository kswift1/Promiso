import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import PromisoShared

// MARK: - Request DTOs

/// 사용자 생성 요청
private struct CreateUserRequest: Encodable {
  let name: String?
  let nickname: String
  let provider: ProviderRequest

  struct ProviderRequest: Encodable {
    let type: String
    let uid: String
    let email: String
  }
}

/// 사용자 조회 요청
private struct GetUserRequest: Encodable {
  let userId: String?
  let isPublic: Bool?
}

/// 사용자 업데이트 요청
private struct UpdateUserRequest: Encodable {
  let nickname: String
}

/// 프로필 이미지 업로드 요청
private struct UploadProfileImageRequest: Encodable {
  let imagePath: String
}

/// 사용자 설정 조회 요청
private struct GetUserSettingsRequest: Encodable {
  // 프로젝트 분리 후 env 파라미터 불필요
  // 빈 struct이지만 일관성을 위해 유지
}

/// 사용자 설정 업데이트 요청
private struct UpdateUserSettingsRequest: Encodable {
  let notificationEnabled: Bool
}



// MARK: - Data Source

/// Firebase Functions를 통한 사용자 프로필 데이터 관리
public final class UserProfileRemoteDataSource: UserProfileRemoteDataSourceProtocol, @unchecked Sendable {
  private let functions: Functions
  private let storage: Storage
  private let db: Firestore

  public init(
    functions: Functions = DefaultFunctionsProvider().functions,
    storage: Storage = Storage.storage(),
    db: Firestore = Firestore.firestore()
  ) {
    self.functions = functions
    self.storage = storage
    self.db = db
  }

  // MARK: - User CRUD Operations

  /// 사용자 생성 (회원가입)
  /// - Parameters:
  ///   - name: 실명 (nil이면 닉네임으로 대체됨)
  ///   - nickname: 닉네임
  ///   - provider: 인증 제공자 정보
  /// - Returns: 생성된 사용자 ID
  public func createUser(
    name: String?,
    nickname: String,
    provider: ProviderInfo
  ) async throws -> String {
    let request = CreateUserRequest(
      name: name,
      nickname: nickname,
      provider: CreateUserRequest.ProviderRequest(
        type: provider.type,
        uid: provider.uid,
        email: provider.email
      )
    )

    let result = try await functions.httpsCallable("createUser").call(request.asDictionary())
    guard let response = result.data as? [String: Any],
          let userId = response["userId"] as? String else {
      throw UserProfileError.invalidData
    }

    return userId
  }

  /// 사용자 프로필 조회
  /// - Parameters:
  ///   - uid: 사용자 ID (nil이면 본인)
  ///   - isPublic: 공개 정보만 조회할지 여부 (true: auth 서브컬렉션 읽기 생략, 1회 읽기)
  /// - Returns: UserProfile (isPublic에 따라 .private 또는 .public)
  public func getProfileModel(uid: String? = nil, isPublic: Bool = false) async throws -> UserProfile {
    let request = GetUserRequest(
      userId: uid,
      isPublic: isPublic
    )

    let result = try await functions.httpsCallable("getUser").call(request.asDictionary())
    guard let response = result.data as? [String: Any] else {
      throw UserProfileError.invalidData
    }

    return try parseUserProfile(from: response, isPublic: isPublic)
  }

  /// 여러 사용자의 공개 프로필 조회 (배치)
  /// - Parameters:
  ///   - userIds: 사용자 ID 목록
  /// - Returns: 공개 프로필 배열 (조회 실패한 사용자는 제외됨)
  /// - Note: 병렬로 처리되며, 일부 실패해도 성공한 프로필만 반환
  public func getUsersByIds(userIds: [String]) async throws -> [UserPublicModel] {
    guard !userIds.isEmpty else { return [] }

    // 병렬로 각 사용자 조회
    let results = await withTaskGroup(of: (String, Result<UserProfile, Error>).self) { group in
      for userId in userIds {
        group.addTask {
          let result = await Result {
            try await self.getProfileModel(uid: userId, isPublic: true)
          }
          return (userId, result)
        }
      }

      var profiles: [(String, UserProfile)] = []
      for await (userId, result) in group {
        if case .success(let profile) = result {
          profiles.append((userId, profile))
        }
      }
      return profiles
    }

    // UserPublicModel으로 변환 (순서는 원본 userIds 순서 유지)
    return userIds.compactMap { userId in
      guard let (_, profile) = results.first(where: { $0.0 == userId }),
            case .public(let userPublic) = profile else {
        return nil
      }
      return userPublic
    }
  }

  /// 사용자 프로필 업데이트
  /// - Parameters:
  ///   - uid: 사용자 ID
  ///   - nickname: 변경할 닉네임
  public func updateProfile(uid: String, nickname: String) async throws {
    let request = UpdateUserRequest(
      nickname: nickname
    )

    _ = try await functions.httpsCallable("updateUser").call(request.asDictionary())
  }

  // MARK: - Profile Image Operations

  /// 프로필 이미지 업로드
  /// - Parameters:
  ///   - uid: 사용자 ID
  ///   - imageData: 이미지 데이터
  /// - Returns: 업로드된 이미지 URL
  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    // 1. Storage 경로 생성 (타임스탬프 추가로 충돌 방지)
    let timestamp = Int(Date().timeIntervalSince1970)
    let imagePath = "profile_images/\(uid)/\(timestamp).jpg"
    let profileImageRef = storage.reference().child(imagePath)

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    let uploadData = compressImageDataForUpload(imageData) ?? imageData

    do {
      _ = try await profileImageRef.putDataAsync(uploadData, metadata: metadata)
    } catch {
      print("❌ Storage upload error:", error)
      throw UserProfileError.uploadFailed
    }

    // 2. Storage 경로를 Functions에 전달
    let request = UploadProfileImageRequest(
      imagePath: imagePath
    )

    let result = try await functions.httpsCallable("uploadProfileImage").call(request.asDictionary())
    guard let response = result.data as? [String: Any],
          let profileData = response["profile"] as? [String: Any],
          let urlString = profileData["url"] as? String,
          let url = URL(string: urlString) else {
      throw UserProfileError.uploadFailed
    }

    return url
  }

  /// 프로필 이미지 삭제
  /// - Parameter uid: 사용자 ID
  public func deleteProfileImage(uid: String) async throws {
    let imagePath = "profile_images/\(uid)/main.jpg"
    let profileImageRef = storage.reference().child(imagePath)
    try await profileImageRef.delete()
  }

  // MARK: - Settings Operations

  /// 사용자 설정 조회
  /// - Returns: 알림 설정 활성화 여부
  public func getUserSettings() async throws -> Bool {
    let request = GetUserSettingsRequest()

    let result = try await functions.httpsCallable("getUserSettings").call(request.asDictionary())
    guard let response = result.data as? [String: Any],
          let notificationEnabled = response["notificationEnabled"] as? Bool else {
      throw UserProfileError.invalidData
    }

    return notificationEnabled
  }

  /// 사용자 설정 업데이트
  /// - Parameter notificationEnabled: 알림 활성화 여부
  public func updateUserSettings(notificationEnabled: Bool) async throws {
    let request = UpdateUserSettingsRequest(
      notificationEnabled: notificationEnabled
    )

    _ = try await functions.httpsCallable("updateUserSettings").call(request.asDictionary())
  }

  // MARK: - Utility Operations

  /// 닉네임 사용 가능 여부 확인
  /// - Parameter nickname: 확인할 닉네임
  /// - Returns: 사용 가능 여부
  public func isNicknameAvailable(_ nickname: String) async throws -> Bool {
    let request = ["nickname": nickname]

    let result = try await functions.httpsCallable("checkNicknameAvailable").call(request)
    guard let response = result.data as? [String: Any],
          let available = response["available"] as? Bool else {
      throw UserProfileError.invalidData
    }

    return available
  }
  
}

// MARK: - Private Helpers

private extension UserProfileRemoteDataSource {
  /// Functions 응답을 UserProfile로 파싱
  func parseUserProfile(from data: [String: Any], isPublic: Bool) throws -> UserProfile {
    let jsonData = try JSONSerialization.data(withJSONObject: data)
    let decoder = JSONDecoder()
    let dto = try decoder.decode(UserDTO.self, from: jsonData)
    let userPrivate = dto.toModel()

    if isPublic {
      return .public(userPrivate.toPublic())
    } else {
      return .private(userPrivate)
    }
  }
}

// MARK: - Encodable Extension

private extension Encodable {
  /// Encodable을 Dictionary로 변환
  func asDictionary() throws -> [String: Any] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(self)
    guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw UserProfileError.invalidData
    }
    return dictionary
  }
}

// MARK: - StorageReference Extension

private extension StorageReference {
  func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
    try await withCheckedThrowingContinuation { continuation in
      putData(data, metadata: metadata) { metadata, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let metadata {
          continuation.resume(returning: metadata)
        } else {
          continuation.resume(throwing: UserProfileError.uploadFailed)
        }
      }
    }
  }
}
