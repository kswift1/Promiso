import Foundation

extension RemoteImage {
  /// RemoteImage를 다운로드 가능한 URL로 변환
  ///
  /// - Returns: URL (externalURL인 경우 바로 반환, legacy storagePath는 지원하지 않음)
  public func toURL() async throws -> URL? {
    switch type {
    case .externalURL:
      return URL(string: url)

    case .storagePath:
      // Firebase Storage 의존 제거 후에는 legacy storagePath를 더 이상 해석하지 않는다.
      return nil
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

actor RemoteImageURLCache {
  static let shared = RemoteImageURLCache()

  private struct CacheEntry {
    let url: URL
    let expiresAt: Date
    var lastAccessedAt: Date

    init(url: URL, expiresAt: Date, lastAccessedAt: Date = Date()) {
      self.url = url
      self.expiresAt = expiresAt
      self.lastAccessedAt = lastAccessedAt
    }
  }

  private var entries: [String: CacheEntry] = [:]

  /// 현재 캐시 엔트리 수
  var count: Int {
    entries.count
  }

  func url(for key: String) -> URL? {
    guard var entry = entries[key] else { return nil }
    if entry.expiresAt <= Date() {
      entries[key] = nil
      return nil
    }
    entry.lastAccessedAt = Date()
    entries[key] = entry
    return entry.url
  }

  func set(_ url: URL, for key: String) {
    let expiresAt = Date().addingTimeInterval(AppConstants.TimeIntervals.cacheExpiry)
    entries[key] = CacheEntry(url: url, expiresAt: expiresAt)
    evictIfNeeded()
  }

  /// 만료된 엔트리 일괄 삭제
  ///
  /// - Returns: 삭제된 엔트리 수
  @discardableResult
  func removeExpired() -> Int {
    let now = Date()
    let expiredKeys = entries.filter { $0.value.expiresAt <= now }.map(\.key)
    for key in expiredKeys {
      entries[key] = nil
    }
    return expiredKeys.count
  }

  // MARK: - Private

  private func evictIfNeeded() {
    let maxEntries = AppConstants.ImageCache.urlCacheMaxEntries
    guard entries.count > maxEntries else { return }
    let sortedKeys = entries
      .sorted { $0.value.lastAccessedAt < $1.value.lastAccessedAt }
      .prefix(entries.count - maxEntries)
      .map(\.key)
    for key in sortedKeys {
      entries[key] = nil
    }
  }
}
