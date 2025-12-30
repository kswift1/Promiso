import Foundation
import FirebaseStorage
import FirebaseFunctions

/// 그룹 생성 에러
public enum GroupRemoteDataSourceError: Error, LocalizedError {
  case invalidResponse
  case imageUploadFailed

  public var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "서버 응답이 올바르지 않아요. 잠시 후 다시 시도해주세요."
    case .imageUploadFailed:
      return "그룹 사진 업로드에 실패했어요. 잠시 후 다시 시도해주세요."
    }
  }
}

/// Firebase Functions를 통한 그룹 데이터 관리
///
/// 4-Layer 아키텍처:
/// - App → Features → Clients → Shared
/// - GroupRemoteDataSource는 Clients 레이어에 속함
public final class GroupRemoteDataSource: @unchecked Sendable {
  private let functions: Functions
  private let storage: Storage

  public init(
    functions: Functions = Functions.functions(region: "asia-northeast3"),
    storage: Storage = Storage.storage()
  ) {
    self.functions = functions
    self.storage = storage
  }

  /// 그룹 생성
  ///
  /// - Parameters:
  ///   - name: 그룹 이름
  ///   - maxMembers: 최대 인원 (2~10)
  ///   - description: 그룹 설명 (선택적)
  ///   - creatorId: 생성자 ID (Firebase Auth UID)
  ///   - photoData: 그룹 이미지 데이터 (선택적)
  /// - Returns: GroupCreationResult
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 createGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. users/{creatorId}에서 생성자 정보 조회
  /// 2. groups/{groupId} 생성
  /// 3. groups/{groupId}/members/{creatorId} 생성
  /// 4. users/{creatorId}/groups/{groupId} 생성
  public func createGroup(
    name: String,
    maxMembers: Int,
    description: String?,
    creatorId: String,
    photoData: Data?
  ) async throws -> GroupCreationResult {
    // 1. 이미지 업로드 (선택적)
    var uploadedPhotoPath: String?
    if let photoData {
      uploadedPhotoPath = try await uploadGroupImage(
        creatorId: creatorId,
        imageData: photoData
      )
    }

    // 2. Firebase Functions 호출
    do {
      var callableData: [String: Any] = [
        "name": name,
        "maxMembers": maxMembers,
      ]

      if let description {
        callableData["description"] = description
      }

      if let uploadedPhotoPath {
        callableData["photoPath"] = uploadedPhotoPath
      }

      let result = try await functions.httpsCallable("createGroup").call(callableData)

      guard let data = result.data as? [String: Any] else {
        throw GroupRemoteDataSourceError.invalidResponse
      }

      let id = data["id"] as? String
      let inviteCode = data["inviteCode"] as? String

      guard let id, let inviteCode else {
        throw GroupRemoteDataSourceError.invalidResponse
      }

      return GroupCreationResult(
        id: id,
        name: name,
        inviteCode: inviteCode
      )
    } catch {
      // 실패 시 업로드된 이미지 삭제
      if let uploadedPhotoPath {
        try? await deleteImage(at: uploadedPhotoPath)
      }
      throw error
    }
  }

  // MARK: - Image Upload

  /// 그룹 이미지 업로드
  private func uploadGroupImage(
    creatorId: String,
    imageData: Data
  ) async throws -> String {
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

  /// 이미지 삭제
  private func deleteImage(at path: String) async throws {
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
          continuation.resume(throwing: GroupRemoteDataSourceError.imageUploadFailed)
        }
      }
    }
  }
}
