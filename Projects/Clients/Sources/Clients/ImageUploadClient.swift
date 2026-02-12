import ComposableArchitecture
import FirebaseStorage
import Foundation

// MARK: - Error

public enum ImageUploadError: Error, Equatable, Sendable {
  case compressionFailed
  case uploadFailed(String)
  case allFailed

  public var localizedDescription: String {
    switch self {
    case .compressionFailed:
      return "이미지 압축에 실패했습니다"
    case .uploadFailed(let message):
      return "이미지 업로드 실패: \(message)"
    case .allFailed:
      return "모든 이미지 업로드에 실패했습니다"
    }
  }
}

// MARK: - Client

@DependencyClient
public struct ImageUploadClient: Sendable {
  /// 다중 이미지 업로드 (압축 + 병렬 업로드, 순서 보장)
  /// - Parameters:
  ///   - images: 업로드할 이미지 Data 배열
  ///   - basePath: Storage 기본 경로 (e.g. "promise_images/{id}")
  /// - Returns: 업로드된 이미지 download URL 배열 (순서 보장)
  public var uploadImages: @Sendable (
    _ images: [Data],
    _ basePath: String
  ) async throws -> [String]

  /// 이미지 삭제 (best-effort, 실패해도 throw 안 함)
  /// download URL 또는 storage path 모두 지원
  public var deleteImages: @Sendable (_ urls: [String]) async -> Void
}

// MARK: - Test & Preview Values

extension ImageUploadClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    uploadImages: { images, _ in
      try await Task.sleep(for: .seconds(1))
      return images.indices.map { "https://example.com/image_\($0).jpg" }
    },
    deleteImages: { _ in }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var imageUploadClient: ImageUploadClient {
    get { self[ImageUploadClient.self] }
    set { self[ImageUploadClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ImageUploadClient: DependencyKey {
  public static let liveValue: ImageUploadClient = {
    let storage = Storage.storage()

    return ImageUploadClient(
      uploadImages: { images, basePath in
        guard !images.isEmpty else { return [] }

        // 병렬 업로드, UUID 파일명 사용 (수정 시 기존 파일 덮어쓰기 방지)
        let results: [(Int, String)] = try await withThrowingTaskGroup(
          of: (Int, String).self
        ) { group in
          for (index, imageData) in images.enumerated() {
            group.addTask {
              let compressed = compressImageDataForUpload(imageData) ?? imageData
              let fileName = UUID().uuidString.lowercased()
              let path = "\(basePath)/\(fileName).jpg"
              let ref = storage.reference().child(path)

              let metadata = StorageMetadata()
              metadata.contentType = "image/jpeg"

              _ = try await ref.putDataAsync(compressed, metadata: metadata)
              let downloadURL = try await ref.downloadURL()
              return (index, downloadURL.absoluteString)
            }
          }

          var collected: [(Int, String)] = []
          for try await result in group {
            collected.append(result)
          }
          return collected
        }

        guard !results.isEmpty else {
          throw ImageUploadError.allFailed
        }

        // 인덱스 순으로 정렬하여 순서 보장
        return results.sorted { $0.0 < $1.0 }.map(\.1)
      },
      deleteImages: { urls in
        await withTaskGroup(of: Void.self) { group in
          for urlString in urls {
            guard !urlString.isEmpty else { continue }
            group.addTask {
              do {
                let ref: StorageReference
                if urlString.hasPrefix("https://") || urlString.hasPrefix("gs://") {
                  ref = storage.reference(forURL: urlString)
                } else {
                  ref = storage.reference().child(urlString)
                }
                try await ref.delete()
              } catch {
                // best-effort: 삭제 실패 무시
              }
            }
          }
        }
      }
    )
  }()
}
