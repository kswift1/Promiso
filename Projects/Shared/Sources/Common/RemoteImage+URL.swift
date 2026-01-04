import Foundation
import FirebaseStorage

extension RemoteImage {
  /// RemoteImage를 다운로드 가능한 URL로 변환
  ///
  /// - Returns: URL (externalURL인 경우 바로 반환, storagePath인 경우 Firebase Storage 다운로드 URL 생성)
  public func toURL() async throws -> URL? {
    switch type {
    case .externalURL:
      return URL(string: url)

    case .storagePath:
      if let cachedURL = await RemoteImageURLCache.shared.url(for: url) {
        return cachedURL
      }

      // Firebase Storage에서 다운로드 URL 가져오기
      let storage = Storage.storage()
      let storageRef = storage.reference().child(url)

      do {
        let downloadURL = try await storageRef.downloadURL()
        await RemoteImageURLCache.shared.set(downloadURL, for: url)
        return downloadURL
      } catch {
        print("Failed to get download URL for storage path: \(url), error: \(error)")
        return nil
      }
    }
  }

  /// 동기적으로 URL 문자열 반환 (externalURL인 경우만 사용)
  ///
  /// - Note: storagePath인 경우 nil 반환. 비동기 toURL() 사용 권장
  public var urlString: String? {
    switch type {
    case .externalURL:
      return url
    case .storagePath:
      return nil
    }
  }
}

private actor RemoteImageURLCache {
  static let shared = RemoteImageURLCache()

  private struct CacheEntry {
    let url: URL
    let expiresAt: Date
  }

  private var entries: [String: CacheEntry] = [:]

  func url(for key: String) -> URL? {
    guard let entry = entries[key] else { return nil }
    if entry.expiresAt <= Date() {
      entries[key] = nil
      return nil
    }
    return entry.url
  }

  func set(_ url: URL, for key: String) {
    let expiresAt = Date().addingTimeInterval(AppConstants.TimeIntervals.cacheExpiry)
    entries[key] = CacheEntry(url: url, expiresAt: expiresAt)
  }
}
