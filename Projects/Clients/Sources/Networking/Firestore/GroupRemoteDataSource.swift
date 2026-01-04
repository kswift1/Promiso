import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import Shared

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
  private let db: Firestore
  
  public init(
    functions: Functions = Functions.functions(region: "asia-northeast3"),
    storage: Storage = Storage.storage(),
    db: Firestore = Firestore.firestore()
  ) {
    self.functions = functions
    self.storage = storage
    self.db = db
  }
  
  /// 그룹 생성
  ///
  /// - Parameters:
  ///   - name: 그룹 이름
  ///   - maxMembers: 최대 인원 (2 이상)
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
    let groupId = UUID().uuidString

    // 1. 이미지 업로드 (선택적)
    var uploadedPhotoPath: String?
    if let photoData {
      uploadedPhotoPath = try await uploadGroupImage(
        groupId: groupId,
        imageData: photoData
      )
    }
    
    // 2. Firebase Functions 호출
    do {
      var callableData: [String: Any] = [
        "groupId": groupId,
        "name": name,
        "maxMembers": maxMembers,
      ]
      
      if let description {
        callableData["description"] = description
      }
      
      if let env = functionsEnvironmentParam() {
        callableData["env"] = env
      }
      
      if let uploadedPhotoPath {
        callableData["photo"] = [
          "type": "storagePath",
          "url": uploadedPhotoPath,
        ]
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
  
  private func functionsEnvironmentParam() -> String? {
    switch FirestoreEnvironmentManager.shared.current {
    case .dev:
      return nil
    case .stage:
      return "stage"
    case .release:
      return "prod"
    }
  }
  
  /// 사용자가 속한 그룹 목록 조회
  public func fetchGroups(userId: String) async throws -> [GroupModel] {
    let membershipSnapshot = try await db.environmentCollection("users")
      .document(userId)
      .collection("groups")
      .getDocuments()
    
    let groupIds = membershipSnapshot.documents.map { $0.documentID }
    guard !groupIds.isEmpty else { return [] }
    
    return try await fetchGroupsInParallel(ids: groupIds)
  }

  /// 그룹 ID 목록으로 상세 그룹 조회
  public func fetchGroupsByIds(ids: [String]) async throws -> [GroupModel] {
    guard !ids.isEmpty else { return [] }
    return try await fetchGroupsInParallel(ids: ids)
  }

  /// 단일 그룹 상세 조회
  public func fetchGroup(groupId: String) async throws -> GroupModel {
    let groupRef = db.environmentCollection("groups").document(groupId)
    let groupSnapshot = try await groupRef.getDocument()
    guard groupSnapshot.exists else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    let groupDocument = try groupSnapshot.data(as: GroupDocument.self)
    guard !groupDocument.isDeleted else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    return groupDocument.toModel(id: groupId)
  }

  private func fetchGroupsInParallel(ids: [String]) async throws -> [GroupModel] {
    try await withThrowingTaskGroup(of: GroupModel?.self) { group in
      for groupId in ids {
        group.addTask { [db] in
          let groupRef = db.environmentCollection("groups").document(groupId)
          let groupSnapshot = try await groupRef.getDocument()
          guard groupSnapshot.exists else { return nil }

          let groupDocument = try groupSnapshot.data(as: GroupDocument.self)
          guard !groupDocument.isDeleted else { return nil }

          return groupDocument.toModel(id: groupId)
        }
      }

      var groups: [GroupModel] = []
      for try await groupModel in group {
        if let groupModel {
          groups.append(groupModel)
        }
      }

      return groups
    }
  }

  /// 네비게이션용 그룹 요약 목록 조회
  public func fetchGroupSummaries(userId: String) async throws -> [GroupSummary] {
    let membershipSnapshot = try await db.environmentCollection("users")
      .document(userId)
      .collection("groups")
      .getDocuments()

    return membershipSnapshot.documents.compactMap { document in
      GroupSummary(documentId: document.documentID, data: document.data())
    }
  }

  /// 초대 코드로 그룹 미리보기
  ///
  /// - Parameters:
  ///   - inviteCode: 6자리 초대 코드
  /// - Returns: 그룹 정보
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 previewGroup을 호출합니다.
  /// 실제로 참여하지 않고 그룹 정보만 조회합니다.
  public func previewGroup(inviteCode: String) async throws -> GroupModel {
    var callableData: [String: Any] = [
      "inviteCode": inviteCode.uppercased()
    ]

    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
    }

    let result = try await functions.httpsCallable("previewGroup").call(callableData)

    guard let data = result.data as? [String: Any] else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    guard let groupId = data["groupId"] as? String else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    // 그룹 상세 정보 조회
    return try await fetchGroup(groupId: groupId)
  }

  /// 초대 코드로 그룹 참여
  ///
  /// - Parameters:
  ///   - inviteCode: 6자리 초대 코드
  ///   - userId: 참여하려는 사용자 ID (Firebase Auth UID)
  /// - Returns: 참여한 그룹 정보
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 joinGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. inviteCode로 그룹 조회
  /// 2. users/{userId}에서 사용자 정보 조회
  /// 3. groups/{groupId}/members/{userId} 생성
  /// 4. users/{userId}/groups/{groupId} 생성
  /// 5. memberCount 증가
  public func joinGroup(inviteCode: String, userId: String) async throws -> GroupModel {
    var callableData: [String: Any] = [
      "inviteCode": inviteCode.uppercased(),
      "userId": userId
    ]

    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
    }

    let result = try await functions.httpsCallable("joinGroup").call(callableData)

    guard let data = result.data as? [String: Any] else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    guard let groupId = data["groupId"] as? String else {
      throw GroupRemoteDataSourceError.invalidResponse
    }

    // 그룹 상세 정보 조회
    return try await fetchGroup(groupId: groupId)
  }


  // MARK: - Image Upload
  
  /// 그룹 이미지 업로드
  private func uploadGroupImage(
    groupId: String,
    imageData: Data
  ) async throws -> String {
    let uploadData = compressImageDataForUpload(imageData) ?? imageData
    let photoPath = "group_images/\(groupId)/main.jpg"
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

// MARK: - GroupSummary Mapping

private extension GroupSummary {
  init?(documentId: String, data: [String: Any]) {
    let groupName = data["groupName"] as? String ?? ""
    let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }

    let role = data["role"] as? String
    let notifications = data["notifications"] as? Bool
    let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()

    self.init(
      id: documentId,
      groupName: trimmedName,
      role: role,
      joinedAt: joinedAt,
      notifications: notifications
    )
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
