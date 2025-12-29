import Shared
import FirebaseStorage
import Foundation
import UIKit

public final class FirebaseGroupImageUploader: GroupImageUploaderProtocol {
  private let storage: Storage

  public init(storage: Storage = Storage.storage()) {
    self.storage = storage
  }

  public func uploadGroupImage(creatorId: String, imageData: Data) async throws -> String {
    let uploadData = compressImageDataForUpload(imageData) ?? imageData

    let photoPath = "group_images/tmp/\(creatorId)/\(UUID().uuidString).jpg"
    let ref = storage.reference().child(photoPath)

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    _ = try await ref.putDataAsync(uploadData, metadata: metadata)
    return photoPath
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

private extension StorageReference {
  func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
    try await withCheckedThrowingContinuation { continuation in
      putData(data, metadata: metadata) { metadata, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let metadata {
          continuation.resume(returning: metadata)
        } else {
          continuation.resume(throwing: CreateGroupUseCaseError.unknown)
        }
      }
    }
  }
}

