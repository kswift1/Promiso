import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Error

public enum ImageUploadError: Error, Equatable, Sendable {
  case compressionFailed
  case uploadFailed(String)
  case allFailed
  case invalidTarget

  public var localizedDescription: String {
    switch self {
    case .compressionFailed:
      return LocalizedStrings.Error.imageCompressionFailed
    case .uploadFailed(let message):
      return LocalizedStrings.Error.imageUploadFailed(message)
    case .allFailed:
      return LocalizedStrings.Error.imageUploadAllFailed
    case .invalidTarget:
      return LocalizedStrings.Error.imageUploadFailed("Invalid upload target")
    }
  }
}

// MARK: - Client

@DependencyClient
public struct ImageUploadClient: Sendable {
  /// 다중 이미지 업로드 (압축 + 병렬 업로드, 순서 보장)
  /// - Parameters:
  ///   - images: 업로드할 이미지 Data 배열
  ///   - basePath: Storage 기본 경로 (e.g. "schedule_images/{id}")
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
    struct UploadTarget: Decodable {
      let objectPath: String
      let uploadUrl: String
      let publicUrl: String
      let expiresAt: Date
      let contentType: String
    }

    struct DeleteTarget: Decodable {
      let objectPath: String
      let deleteUrl: String
      let expiresAt: Date
    }

    struct IssueUploadTargetsBody: Encodable {
      let basePath: String
      let count: Int
      let contentType: String
    }

    struct IssueDeleteTargetsBody: Encodable {
      let targets: [String]
    }

    return ImageUploadClient(
      uploadImages: { images, basePath in
        guard !images.isEmpty else { return [] }
        let api = RustAPIClient()
        let targets: [UploadTarget] = try await api.post(
          "/api/v1/media/upload-urls",
          body: IssueUploadTargetsBody(
            basePath: basePath,
            count: images.count,
            contentType: "image/jpeg"
          )
        )

        guard targets.count == images.count else {
          throw ImageUploadError.invalidTarget
        }

        // 병렬 업로드, UUID 파일명 사용 (수정 시 기존 파일 덮어쓰기 방지)
        let results: [(Int, String)] = try await withThrowingTaskGroup(
          of: (Int, String).self
        ) { group in
          for (index, imageData) in images.enumerated() {
            let target = targets[index]
            group.addTask {
              let compressed = compressImageDataForUpload(imageData) ?? imageData
              guard let uploadURL = URL(string: target.uploadUrl) else {
                throw ImageUploadError.invalidTarget
              }

              var request = URLRequest(url: uploadURL)
              request.httpMethod = "PUT"
              request.setValue(target.contentType, forHTTPHeaderField: "Content-Type")
              request.httpBody = compressed

              let (_, response) = try await URLSession.shared.data(for: request)
              guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageUploadError.invalidTarget
              }
              guard (200..<300).contains(httpResponse.statusCode) else {
                throw ImageUploadError.uploadFailed("HTTP \(httpResponse.statusCode)")
              }

              return (index, target.publicUrl)
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
        let targets = urls
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty && isManagedImageTarget($0) }

        guard !targets.isEmpty else { return }

        let api = RustAPIClient()
        guard let deleteTargets: [DeleteTarget] = try? await api.post(
          "/api/v1/media/delete-urls",
          body: IssueDeleteTargetsBody(targets: targets)
        ) else {
          return
        }

        await withTaskGroup(of: Void.self) { group in
          for target in deleteTargets {
            group.addTask {
              guard let deleteURL = URL(string: target.deleteUrl) else { return }

              var request = URLRequest(url: deleteURL)
              request.httpMethod = "DELETE"

              _ = try? await URLSession.shared.data(for: request)
            }
          }
        }
      }
    )
  }()
}

private func isManagedImageTarget(_ target: String) -> Bool {
  target.hasPrefix("profile_images/")
    || target.hasPrefix("group_images/")
    || target.hasPrefix("schedule_images/")
    || target.hasPrefix("personal_event_images/")
    || target.hasPrefix("gs://")
    || target.contains("storage.googleapis.com/")
    || target.contains("firebasestorage.googleapis.com/")
}
