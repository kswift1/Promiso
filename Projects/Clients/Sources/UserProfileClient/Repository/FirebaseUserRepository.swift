import FirebaseFirestore
import FirebaseStorage
import FirebaseCore
import Foundation

// MARK: - Firestore / Storage Providers

public protocol FirestoreProviding {
  var db: Firestore { get }
}

public protocol StorageProviding {
  var storage: Storage { get }
}

public struct DefaultFirestoreProvider: FirestoreProviding {
  public let db: Firestore

  public init(app: FirebaseApp? = FirebaseApp.app()) {
    self.db = Firestore.firestore()
  }
}

public struct DefaultStorageProvider: StorageProviding {
  public let storage: Storage

  public init(app: FirebaseApp? = FirebaseApp.app()) {
    if let bucket = app?.options.storageBucket {
      self.storage = Storage.storage(url: "gs://\(bucket)")
    } else {
      self.storage = Storage.storage()
    }
  }
}

/// Firebase Firestore 및 Storage를 사용한 사용자 프로필 저장소 구현
public final class FirebaseUserRepository: UserRepositoryProtocol {
  private let firestore: FirestoreProviding
  private let storageProvider: StorageProviding
  private var db: Firestore { firestore.db }
  private var storage: Storage { storageProvider.storage }
  private let collectionName: String

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    storage: StorageProviding = DefaultStorageProvider(),
    collectionName: String = "users"
  ) {
    self.firestore = firestore
    self.storageProvider = storage
    self.collectionName = collectionName
  }

  // MARK: - UserRepositoryProtocol

  public func saveProfile(uid: String, profile: UserProfile) async throws {
    let data = profile.toFirestoreData()
    try await
    db.environmentCollection(collectionName).document(uid).setData(data, merge: true)
  }

  public func getProfile(uid: String) async throws -> UserProfile? {
    let document = try await db.environmentCollection(collectionName).document(uid).getDocument()

    guard document.exists, let data = document.data() else {
      return nil
    }

    return try UserProfile.fromFirestoreData(data)
  }

  public func uploadProfileImage(uid: String, imageData: Data) async throws -> URL {
    let storageRef = storage.reference()
    let profileImageRef = storageRef.child("profile_images/\(uid).jpg")

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    _ = try await profileImageRef.putDataAsync(imageData, metadata: metadata)
    let downloadURL = try await profileImageRef.downloadURL()

    return downloadURL
  }

  public func hasProfile(uid: String) async throws -> UserProfile? {
    try await getProfile(uid: uid)
  }
  
  public func isNicknameAvailable(_ nickname: String) async throws -> Bool {
    let snapshot = try await db.environmentCollection(collectionName)
      .whereField("nickname", isEqualTo: nickname)
      .limit(to: 1)
      .getDocuments()
    return snapshot.documents.isEmpty
  }

  public func updateProfile(uid: String, profile: UserProfile) async throws {
    var updatedProfile = profile
    // updatedAt을 현재 시간으로 업데이트
    updatedProfile = UserProfile(
      name: profile.name,
      nickname: profile.nickname,
      email: profile.email,
      provider: profile.provider,
      profile: profile.profile,
      pinnedGroupId: profile.pinnedGroupId,
      notificationSettings: profile.notificationSettings,
      createdAt: profile.createdAt,
      updatedAt: Date()
    )

    let data = updatedProfile.toFirestoreData()
    try await db.environmentCollection(collectionName).document(uid).updateData(data)
  }

  public func deleteProfile(uid: String) async throws {
    try await db.environmentCollection(collectionName).document(uid).delete()

    // 프로필 이미지도 삭제
    let storageRef = storage.reference()
    let profileImageRef = storageRef.child("profile_images/\(uid).jpg")
    try? await profileImageRef.delete()
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
          continuation.resume(throwing: UserProfileError.uploadFailed)
        }
      }
    }
  }
}
