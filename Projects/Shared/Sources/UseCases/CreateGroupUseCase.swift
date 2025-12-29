import Foundation

// MARK: - Create Group UseCase

public protocol CreateGroupUseCaseProtocol: Sendable {
  func execute(_ input: CreateGroupUseCaseInput) async throws -> CreateGroupUseCaseOutput
}

// MARK: - Ports (DIP)

public protocol GroupImageUploaderProtocol: Sendable {
  func uploadGroupImage(creatorId: String, imageData: Data) async throws -> String
  func deleteImage(at path: String) async throws
}

public protocol GroupCreationGatewayProtocol: Sendable {
  func createGroup(
    name: String,
    maxMembers: Int,
    creatorId: String,
    photoPath: String?
  ) async throws -> (id: String, inviteCode: String)
}

/// Group 관련 Repository가 제공해야 하는 기능 묶음(Port).
public protocol GroupRepositoryProtocol: GroupImageUploaderProtocol, GroupCreationGatewayProtocol {}

// MARK: - Errors

public enum CreateGroupUseCaseError: Error, LocalizedError, Equatable, Sendable {
  case invalidCreator
  case imageUploadFailed
  case invalidResponse
  case unknown

  public var errorDescription: String? {
    switch self {
    case .invalidCreator:
      return "사용자 정보가 없어 그룹을 생성할 수 없어요."
    case .imageUploadFailed:
      return "그룹 사진 업로드에 실패했어요. 잠시 후 다시 시도해주세요."
    case .invalidResponse:
      return "서버 응답이 올바르지 않아요. 잠시 후 다시 시도해주세요."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}

// MARK: - Default Implementation (Shared)

public final class DefaultCreateGroupUseCase: CreateGroupUseCaseProtocol {
  private let repository: GroupRepositoryProtocol

  public init(
    repository: GroupRepositoryProtocol
  ) {
    self.repository = repository
  }

  public func execute(_ input: CreateGroupUseCaseInput) async throws -> CreateGroupUseCaseOutput {
    guard !input.creatorId.isEmpty else {
      throw CreateGroupUseCaseError.invalidCreator
    }

    var uploadedPhotoPath: String?
    if let photoData = input.photoData {
      do {
        uploadedPhotoPath = try await repository.uploadGroupImage(
          creatorId: input.creatorId,
          imageData: photoData
        )
      } catch {
        throw CreateGroupUseCaseError.imageUploadFailed
      }
    }

    do {
      let result = try await repository.createGroup(
        name: input.name,
        maxMembers: input.maxMembers,
        creatorId: input.creatorId,
        photoPath: uploadedPhotoPath
      )
      return CreateGroupUseCaseOutput(id: result.id, inviteCode: result.inviteCode, photoPath: uploadedPhotoPath)
    } catch {
      if let uploadedPhotoPath {
        try? await repository.deleteImage(at: uploadedPhotoPath)
      }
      throw error
    }
  }
}

public struct CreateGroupUseCaseInput: Equatable, Sendable {
  public let name: String
  public let maxMembers: Int
  public let creatorId: String
  public let photoData: Data?

  public init(
    name: String,
    maxMembers: Int,
    creatorId: String,
    photoData: Data?
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.creatorId = creatorId
    self.photoData = photoData
  }
}

public struct CreateGroupUseCaseOutput: Equatable, Sendable {
  public let id: String
  public let inviteCode: String
  public let photoPath: String?

  public init(
    id: String,
    inviteCode: String,
    photoPath: String?
  ) {
    self.id = id
    self.inviteCode = inviteCode
    self.photoPath = photoPath
  }
}
