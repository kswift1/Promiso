import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseCore
import Domain

/// 사용자 프로필 관련 Firestore CRUD 및 쿼리 작업을 담당하는 Repository
public class FirebaseUserRepository: UserRepositoryProtocol {
  private let db = Firestore.firestore()
  private let storage: Storage

  public init() {
    if let bucket = FirebaseApp.app()?.options.storageBucket {
      self.storage = Storage.storage(url: "gs://\(bucket)")
    } else {
      self.storage = Storage.storage()
    }
  }

  // MARK: - CRUD Operations

  /// 사용자 생성
  public func createUser(_ user: UserModel) async throws -> String {
    let data = userToFirestoreData(user)
    let ref = db.environmentCollection("users").document(user.id)
    try await ref.setData(data)
    return user.id
  }

  /// 사용자 업데이트
  public func updateUser(_ user: UserModel) async throws {
    var data = userToFirestoreData(user)
    data["updatedAt"] = Timestamp(date: Date())

    let ref = db.environmentCollection("users").document(user.id)
    try await ref.updateData(data)
  }

  /// 사용자 삭제 (soft delete)
  public func deleteUser(id: String) async throws {
    let ref = db.environmentCollection("users").document(id)
    try await ref.updateData([
      "isDeleted": true,
      "updatedAt": Timestamp(date: Date())
    ])
  }

  /// 사용자 조회
  public func getUser(id: String) async throws -> UserModel? {
    let ref = db.environmentCollection("users").document(id)
    let document = try await ref.getDocument()

    guard document.exists else { return nil }
    guard let data = document.data() else { return nil }

    return try firestoreDataToUser(id: id, data: data)
  }

  // MARK: - Query Operations

  /// 여러 사용자 조회
  public func getUsersByIds(_ ids: [String]) async throws -> [UserModel] {
    guard !ids.isEmpty else { return [] }

    // Firestore 'in' 쿼리는 최대 10개까지만 가능
    let chunks = ids.chunked(into: 10)
    var allUsers: [UserModel] = []

    for chunk in chunks {
      let query = db.environmentCollection("users")
        .whereField(FieldPath.documentID(), in: chunk)

      let snapshot = try await query.getDocuments()
      let users = try snapshot.documents.compactMap { document -> UserModel? in
        try firestoreDataToUser(id: document.documentID, data: document.data())
      }
      allUsers.append(contentsOf: users)
    }

    return allUsers
  }

  /// 사용자 검색 (닉네임으로)
  public func searchUsers(query: String) async throws -> [UserModel] {
    // Firestore는 full-text search를 지원하지 않으므로
    // 닉네임 prefix 매칭으로 구현
    let lowercaseQuery = query.lowercased()

    let querySnapshot = try await db.environmentCollection("users")
      .whereField("nickname_lowercase", isGreaterThanOrEqualTo: lowercaseQuery)
      .whereField("nickname_lowercase", isLessThan: lowercaseQuery + "\u{f8ff}")
      .limit(to: 20)
      .getDocuments()

    return try querySnapshot.documents.compactMap { document in
      try firestoreDataToUser(id: document.documentID, data: document.data())
    }
  }

  // MARK: - Profile Operations

  /// 프로필 이미지 업로드
  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    let storageRef = storage.reference()
    let profileImageRef = storageRef.child("profile_images/\(uid).jpg")

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    _ = try await profileImageRef.putDataAsync(imageData, metadata: metadata)
    let downloadURL = try await profileImageRef.downloadURL()

    return downloadURL
  }

  /// 프로필 존재 여부 확인
  public func hasProfile(uid: String) async throws -> Bool {
    let document = try await db.environmentCollection("users").document(uid).getDocument()
    return document.exists
  }

  // MARK: - Helper Methods

  private func userToFirestoreData(_ user: UserModel) -> [String: Any] {
    var data: [String: Any] = [
      "email": user.email,
      "nickname": user.nickname,
      "nickname_lowercase": user.nickname.lowercased(),
      "profileType": user.profileType.rawValue,
      "notificationEnabled": user.notificationEnabled,
      "createdAt": Timestamp(date: user.createdAt),
      "updatedAt": Timestamp(date: user.updatedAt)
    ]

    if let pinnedGroupId = user.pinnedGroupId {
      data["pinnedGroupId"] = pinnedGroupId
    }

    if let profileImageUrl = user.profileImageUrl {
      data["profileImageUrl"] = profileImageUrl
    }

    return data
  }

  private func firestoreDataToUser(id: String, data: [String: Any]) throws -> UserModel {
    guard let email = data["email"] as? String,
          let nickname = data["nickname"] as? String else {
      throw UserRepositoryError.invalidData
    }

    let profileTypeString = data["profileType"] as? String ?? "FIREBASE"
    let profileType = ProfileType(rawValue: profileTypeString) ?? .firebase

    let notificationEnabled = data["notificationEnabled"] as? Bool ?? true
    let pinnedGroupId = data["pinnedGroupId"] as? String
    let profileImageUrl = data["profileImageUrl"] as? String

    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

    return UserModel(
      id: id,
      email: email,
      nickname: nickname,
      pinnedGroupId: pinnedGroupId,
      profileImageUrl: profileImageUrl,
      profileType: profileType,
      notificationEnabled: notificationEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

// MARK: - Errors

public enum UserRepositoryError: Error, LocalizedError {
  case invalidData
  case userNotFound
  case uploadFailed
  case networkError

  public var errorDescription: String? {
    switch self {
    case .invalidData:
      return "사용자 데이터 형식이 올바르지 않습니다."
    case .userNotFound:
      return "사용자를 찾을 수 없습니다."
    case .uploadFailed:
      return "업로드에 실패했습니다."
    case .networkError:
      return "네트워크 연결을 확인해주세요."
    }
  }
}

// MARK: - Helper Extensions

extension StorageReference {
  /// StorageReference의 putDataAsync를 async/await로 래핑
  fileprivate func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
    return try await withCheckedThrowingContinuation { continuation in
      self.putData(data, metadata: metadata) { metadata, error in
        if let error = error {
          continuation.resume(throwing: error)
        } else if let metadata = metadata {
          continuation.resume(returning: metadata)
        } else {
          continuation.resume(throwing: UserRepositoryError.uploadFailed)
        }
      }
    }
  }
}

extension Array {
  /// 배열을 지정된 크기로 청크 분할
  fileprivate func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0 ..< Swift.min($0 + size, count)])
    }
  }
}
