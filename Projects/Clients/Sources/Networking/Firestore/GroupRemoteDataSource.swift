import Foundation
import FirebaseStorage
import FirebaseFirestore
import FirebaseFunctions
import Shared

public struct GroupCreationPayload: Sendable {
  public let name: String
  public let maxMembers: Int
  public let creatorId: String
  public let creatorName: String
  public let creatorNickname: String
  public let creatorProfileImageURL: String?
  public let photoData: Data?
  
  public init(
    name: String,
    maxMembers: Int,
    creatorId: String,
    creatorName: String,
    creatorNickname: String,
    creatorProfileImageURL: String?,
    photoData: Data?
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.creatorId = creatorId
    self.creatorName = creatorName
    self.creatorNickname = creatorNickname
    self.creatorProfileImageURL = creatorProfileImageURL
    self.photoData = photoData
  }
}

public enum GroupRemoteDataSourceError: Error, LocalizedError {
  case failedToGenerateInviteCode
  case invalidCreator
  case invalidResponse
  case imageUploadFailed
  
  public var errorDescription: String? {
    switch self {
    case .failedToGenerateInviteCode:
      return "초대 코드를 생성하지 못했어요. 잠시 후 다시 시도해주세요."
    case .invalidCreator:
      return "사용자 정보가 없어 그룹을 생성할 수 없어요."
    case .invalidResponse:
      return "서버 응답이 올바르지 않아요. 잠시 후 다시 시도해주세요."
    case .imageUploadFailed:
      return "그룹 사진 업로드에 실패했어요. 잠시 후 다시 시도해주세요."
    }
  }
}

public final class GroupRemoteDataSource: @unchecked Sendable {
  private let db: Firestore
  private let functions: Functions
  private let storage: Storage
  
  public init(
    db: Firestore = Firestore.firestore(),
    functions: Functions = Functions.functions(region: "asia-northeast3"),
    storage: Storage = Storage.storage()
  ) {
    self.db = db
    self.functions = functions
    self.storage = storage
  }
  
  public func createGroup(_ payload: GroupCreationPayload) async throws -> (id: String, inviteCode: String) {
    guard !payload.creatorId.isEmpty else { throw GroupRemoteDataSourceError.invalidCreator }
    
    var uploadedPhotoPath: String?
    if let photoData = payload.photoData {
      let uploadData = compressImageDataForUpload(photoData) ?? photoData
      let photoPath = "group_images/tmp/\(payload.creatorId)/\(UUID().uuidString).jpg"
      let ref = storage.reference().child(photoPath)

      let metadata = StorageMetadata()
      metadata.contentType = "image/jpeg"

      do {
        _ = try await ref.putDataAsync(uploadData, metadata: metadata)
        uploadedPhotoPath = photoPath
      } catch {
        throw GroupRemoteDataSourceError.imageUploadFailed
      }
    }

    do {
      var callableData: [String: Any] = [
        "name": payload.name,
        "maxMembers": payload.maxMembers,
      ]
      if let uploadedPhotoPath {
        callableData["photoPath"] = uploadedPhotoPath
      }

      let result = try await functions.httpsCallable("createGroup").call(callableData)
    
      guard let data = result.data as? [String: Any] else {
        throw GroupRemoteDataSourceError.invalidResponse
      }
    
      // 서버 구현에 따라 key가 id/groupId 등으로 달라질 수 있어 호환 처리
      let id = (data["id"] as? String) ?? (data["groupId"] as? String)
      let inviteCode = data["inviteCode"] as? String
    
      guard let id, let inviteCode else {
        throw GroupRemoteDataSourceError.invalidResponse
      }
    
      return (id, inviteCode)
    } catch {
      if let uploadedPhotoPath {
        await deleteStorageItemIfExists(path: uploadedPhotoPath)
      }
      throw error
    }
  }

  private func deleteStorageItemIfExists(path: String) async {
    let ref = storage.reference().child(path)
    try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      ref.delete { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }
}

// MARK: - GroupImageUploaderProtocol Implementation

extension GroupRemoteDataSource: GroupImageUploaderProtocol {
  public func uploadGroupImage(creatorId: String, imageData: Data) async throws -> String {
    let uploadData = compressImageDataForUpload(imageData) ?? imageData
    let photoPath = "group_images/tmp/\(creatorId)/\(UUID().uuidString).jpg"
    let ref = storage.reference().child(photoPath)

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    do {
      _ = try await ref.putDataAsync(uploadData, metadata: metadata)
      return photoPath
    } catch {
      throw GroupRemoteDataSourceError.imageUploadFailed
    }
  }

  public func deleteImage(at path: String) async throws {
    let ref = storage.reference().child(path)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      ref.delete { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }
}

// MARK: - GroupCreationGatewayProtocol Implementation

extension GroupRemoteDataSource: GroupCreationGatewayProtocol {
  public func createGroup(
    name: String,
    maxMembers: Int,
    creatorId: String,
    photoPath: String?
  ) async throws -> (id: String, inviteCode: String) {
    var callableData: [String: Any] = [
      "name": name,
      "maxMembers": maxMembers,
    ]
    if let photoPath {
      callableData["photoPath"] = photoPath
    }

    let result = try await functions.httpsCallable("createGroup").call(callableData)

    guard let data = result.data as? [String: Any] else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    let id = (data["id"] as? String) ?? (data["groupId"] as? String)
    let inviteCode = data["inviteCode"] as? String

    guard let id, let inviteCode else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    return (id, inviteCode)
  }
}

// MARK: - GroupRepositoryProtocol

extension GroupRemoteDataSource: GroupRepositoryProtocol {}
