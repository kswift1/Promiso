import Foundation

/// Rust users API 응답 DTO
private struct RustUserPrivate: Decodable {
  let userId: String
  let name: String
  let nickname: String
  let email: String
  let provider: String
  let profileUrl: String?
  let notificationEnabled: Bool
  let createdAt: Date
  let updatedAt: Date
}

private struct RustUserPublic: Decodable {
  let userId: String
  let name: String
  let nickname: String
  let profileUrl: String?
  let createdAt: Date
  let updatedAt: Date
}

private struct RustCreateUserResponse: Decodable {
  let userId: String
  let createdAt: Date
}

private struct RustNicknameCheck: Decodable {
  let available: Bool
  let nickname: String
}

private struct RustSuccess: Decodable {
  let success: Bool?
  let profileUrl: String?
}

/// Rust API 요청 DTO
private struct CreateUserBody: Encodable {
  let name: String?
  let nickname: String
  let provider: ProviderBody
}

private struct ProviderBody: Encodable {
  let providerType: String
  let providerUid: String
  let email: String
}

private struct UpdateUserBody: Encodable {
  let nickname: String
}

private struct UploadProfileImageBody: Encodable {
  let imagePath: String
}

private struct BatchGetUsersBody: Encodable {
  let userIds: [String]
}

public actor UserRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  public func createUser(
    name: String?,
    nickname: String,
    providerType: String,
    providerUid: String,
    email: String
  ) async throws -> String {
    let body = CreateUserBody(
      name: name,
      nickname: nickname,
      provider: ProviderBody(
        providerType: providerType,
        providerUid: providerUid,
        email: email
      )
    )
    let response: RustCreateUserResponse = try await api.post("/api/v1/users", body: body)
    return response.userId
  }

  public func getMyProfile() async throws -> UserPrivateModel {
    let response: RustUserPrivate = try await api.get("/api/v1/users/me")
    return response.toModel()
  }

  public func getUserPublic(userId: String) async throws -> UserPublicModel {
    let response: RustUserPublic = try await api.get("/api/v1/users/\(userId)")
    return response.toModel()
  }

  public func updateNickname(_ nickname: String) async throws {
    let body = UpdateUserBody(nickname: nickname)
    let _: RustSuccess = try await api.patch("/api/v1/users/me", body: body)
  }

  public func uploadProfileImage(imagePath: String) async throws -> URL {
    let body = UploadProfileImageBody(imagePath: imagePath)
    let response: RustSuccess = try await api.post("/api/v1/users/me/profile-image", body: body)
    guard let urlString = response.profileUrl, let url = URL(string: urlString) else {
      throw RustAPIError.noData
    }
    return url
  }

  public func checkNicknameAvailable(_ nickname: String) async throws -> Bool {
    let encoded = nickname.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? nickname
    let response: RustNicknameCheck = try await api.get("/api/v1/users/nickname-check?q=\(encoded)")
    return response.available
  }

  public func getUsersByIds(_ userIds: [String]) async throws -> [UserPublicModel] {
    let body = BatchGetUsersBody(userIds: userIds)
    let response: [RustUserPublic] = try await api.post("/api/v1/users/batch", body: body)
    return response.map { $0.toModel() }
  }
}

// MARK: - DTO → Model 변환

extension RustUserPrivate {
  func toModel() -> UserPrivateModel {
    UserPrivateModel(
      userId: userId,
      name: name,
      nickname: nickname,
      email: email,
      provider: provider,
      profile: profileUrl.map { url in
        ProfileImage(
          url: url,
          thumbUrl: nil,
          updatedAt: updatedAt
        )
      },
      metadata: Metadata(createdAt: createdAt, updatedAt: updatedAt)
    )
  }
}

extension RustUserPublic {
  func toModel() -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: name,
      nickname: nickname,
      profile: profileUrl.map { url in
        ProfileImage(
          url: url,
          thumbUrl: nil,
          updatedAt: updatedAt
        )
      },
      metadata: Metadata(createdAt: createdAt, updatedAt: updatedAt)
    )
  }
}
