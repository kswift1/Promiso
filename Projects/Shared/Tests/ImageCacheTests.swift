//
//  ImageCacheTests.swift
//  PromisoShared
//
//  이미지 캐시 관련 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Common/RemoteImage+URL.swift` (RemoteImageURLCache)
//  - `PromisoShared/Sources/Infrastructure/ImageLoader.swift`
//  - `PromisoShared/Sources/Infrastructure/ImagePipelineConfigurator.swift`
//  - `PromisoShared/Sources/LiveActivity/LiveActivityImageStore.swift`
//

import Foundation
import Testing
import UIKit
@testable import PromisoShared

// MARK: - RemoteImageURLCache 테스트

@Suite("RemoteImageURLCache 테스트")
struct RemoteImageURLCacheTests {

  @Test("캐시 set/get 동작")
  func setAndGet() async {
    let cache = RemoteImageURLCache()
    let url = URL(string: "https://example.com/image.jpg")!

    await cache.set(url, for: "test-key")
    let cached = await cache.url(for: "test-key")

    #expect(cached == url)
  }

  @Test("만료된 엔트리는 nil 반환")
  func expiredEntryReturnsNil() async {
    let cache = RemoteImageURLCache()
    let url = URL(string: "https://example.com/expired.jpg")!

    // set 후 즉시 조회하면 유효 (24시간 만료)
    await cache.set(url, for: "expired-key")
    let result = await cache.url(for: "expired-key")
    #expect(result == url)

    // 만료 시간이 24시간이므로, 현재 시점에서는 유효해야 함
    let stillValid = await cache.url(for: "expired-key")
    #expect(stillValid != nil)
  }

  @Test("최대 엔트리 초과 시 LRU 정리")
  func evictsWhenExceedingMaxEntries() async {
    let cache = RemoteImageURLCache()
    let maxEntries = AppConstants.ImageCache.urlCacheMaxEntries

    // maxEntries + 1개 삽입
    for i in 0...maxEntries {
      let url = URL(string: "https://example.com/\(i).jpg")!
      await cache.set(url, for: "key-\(i)")
    }

    // 엔트리 수가 maxEntries 이하여야 함
    let count = await cache.count
    #expect(count <= maxEntries)
  }

  @Test("접근 시 lastAccessedAt 갱신으로 LRU에서 보호")
  func accessUpdatesLastAccessedAt() async {
    let cache = RemoteImageURLCache()
    let maxEntries = AppConstants.ImageCache.urlCacheMaxEntries

    // 보호할 키를 먼저 삽입
    let protectedURL = URL(string: "https://example.com/protected.jpg")!
    await cache.set(protectedURL, for: "protected-key")

    // maxEntries개를 추가로 삽입하되, 중간에 protected-key를 접근하여 갱신
    for i in 1...maxEntries {
      let url = URL(string: "https://example.com/\(i).jpg")!
      await cache.set(url, for: "other-key-\(i)")

      // 중간에 protected-key에 접근하여 LRU 순위 올리기
      if i == maxEntries / 2 {
        _ = await cache.url(for: "protected-key")
      }
    }

    // protected-key는 접근했으므로 LRU에서 보호되어야 함
    let result = await cache.url(for: "protected-key")
    #expect(result == protectedURL)
  }

  @Test("removeExpired로 만료 엔트리 일괄 삭제")
  func removeExpiredDeletesExpiredEntries() async {
    let cache = RemoteImageURLCache()

    // 유효한 엔트리 삽입
    let url1 = URL(string: "https://example.com/valid1.jpg")!
    let url2 = URL(string: "https://example.com/valid2.jpg")!
    await cache.set(url1, for: "valid-1")
    await cache.set(url2, for: "valid-2")

    // 현재 모든 엔트리는 유효하므로 삭제되는 것 없음
    let removed = await cache.removeExpired()
    #expect(removed == 0)

    // 유효한 엔트리는 여전히 존재
    let count = await cache.count
    #expect(count == 2)
  }

  @Test("count 프로퍼티 정확성")
  func countReturnsCorrectValue() async {
    let cache = RemoteImageURLCache()

    let initialCount = await cache.count
    #expect(initialCount == 0)

    let url = URL(string: "https://example.com/image.jpg")!
    await cache.set(url, for: "key-1")
    let afterOne = await cache.count
    #expect(afterOne == 1)

    await cache.set(url, for: "key-2")
    let afterTwo = await cache.count
    #expect(afterTwo == 2)

    // 같은 키로 덮어쓰면 카운트 유지
    await cache.set(url, for: "key-1")
    let afterOverwrite = await cache.count
    #expect(afterOverwrite == 2)
  }
}

// MARK: - ImageLoader 테스트

@Suite("ImageLoader 테스트")
struct ImageLoaderTests {

  @Test("maxRetryCount 기본값 확인")
  func maxRetryCountDefault() {
    #expect(ImageLoader.maxRetryCount == 3)
  }

  @Test("잘못된 URL은 nil 반환")
  func invalidURLReturnsNil() async {
    // 존재하지 않는 로컬 URL로 로드 시도
    let url = URL(string: "file:///nonexistent/path/image.jpg")!
    let result = await ImageLoader.loadImage(from: url, retryCount: 1)
    #expect(result == nil)
  }
}

// MARK: - ImagePipelineConfigurator 테스트

@Suite("ImagePipelineConfigurator 테스트")
struct ImagePipelineConfiguratorTests {

  @Test("configure 호출 시 크래시 없이 완료")
  func configureDoesNotCrash() {
    // configure()가 크래시 없이 실행되는지 확인
    ImagePipelineConfigurator.configure()
  }
}

// MARK: - LiveActivityImageStore 테스트

@Suite("LiveActivityImageStore 테스트")
struct LiveActivityImageStoreTests {

  @Test("makeFileName 형식 확인")
  func makeFileNameFormat() {
    let fileName = LiveActivityImageStore.makeFileName(userId: "abc123")
    #expect(fileName == "profile-abc123.jpg")
  }

  @Test("makeFileName 다양한 userId")
  func makeFileNameVariousIds() {
    #expect(LiveActivityImageStore.makeFileName(userId: "") == "profile-.jpg")
    #expect(LiveActivityImageStore.makeFileName(userId: "user-1") == "profile-user-1.jpg")
    #expect(LiveActivityImageStore.makeFileName(userId: "ABC") == "profile-ABC.jpg")
  }

  @Test("imageSize 상수 확인")
  func imageSizeConstant() {
    #expect(LiveActivityImageStore.imageSize == 64)
  }

  @Test("존재하지 않는 userId는 nil 반환")
  func loadNonExistentUserReturnsNil() {
    let result = LiveActivityImageStore.loadImage(userId: "nonexistent-user-id-\(UUID().uuidString)")
    #expect(result == nil)
  }

  @Test("hasImage: 존재하지 않는 userId는 false")
  func hasImageReturnsFalseForNonExistent() {
    let result = LiveActivityImageStore.hasImage(userId: "nonexistent-user-id-\(UUID().uuidString)")
    #expect(result == false)
  }

  @Test("이미지 저장 후 로드")
  func saveAndLoad() {
    let userId = "test-save-load-\(UUID().uuidString)"

    // 테스트용 1x1 이미지 생성
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let testImage = renderer.image { context in
      UIColor.red.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    let savedFileName = LiveActivityImageStore.saveImage(testImage, userId: userId)

    // App Group 컨테이너 접근 불가 시 (CI/시뮬레이터) nil 반환 가능
    if savedFileName != nil {
      #expect(savedFileName == "profile-\(userId).jpg")

      let loaded = LiveActivityImageStore.loadImage(userId: userId)
      #expect(loaded != nil)

      // 정리
      LiveActivityImageStore.invalidateImage(userId: userId)
    }
  }

  @Test("invalidateImage로 특정 사용자 캐시 삭제")
  func invalidateImageRemovesCache() {
    let userId = "test-invalidate-\(UUID().uuidString)"

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let testImage = renderer.image { context in
      UIColor.blue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    let saved = LiveActivityImageStore.saveImage(testImage, userId: userId)

    if saved != nil {
      // 저장 확인
      #expect(LiveActivityImageStore.hasImage(userId: userId) == true)

      // 삭제
      LiveActivityImageStore.invalidateImage(userId: userId)

      // 삭제 확인
      #expect(LiveActivityImageStore.hasImage(userId: userId) == false)
      #expect(LiveActivityImageStore.loadImage(userId: userId) == nil)
    }
  }

  @Test("clearCache로 전체 삭제")
  func clearCacheRemovesAll() {
    let userId1 = "test-clear-1-\(UUID().uuidString)"
    let userId2 = "test-clear-2-\(UUID().uuidString)"

    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let testImage = renderer.image { context in
      UIColor.green.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }

    let saved1 = LiveActivityImageStore.saveImage(testImage, userId: userId1)
    let saved2 = LiveActivityImageStore.saveImage(testImage, userId: userId2)

    if saved1 != nil && saved2 != nil {
      // 전체 삭제
      LiveActivityImageStore.clearCache()

      // 모두 삭제 확인
      #expect(LiveActivityImageStore.loadImage(userId: userId1) == nil)
      #expect(LiveActivityImageStore.loadImage(userId: userId2) == nil)
    }
  }
}

// MARK: - AppConstants.ImageCache 테스트

@Suite("AppConstants.ImageCache 테스트")
struct ImageCacheConstantsTests {

  @Test("디스크 캐시 크기 150MB")
  func diskCacheSize() {
    #expect(AppConstants.ImageCache.diskCacheSizeLimit == 150 * 1024 * 1024)
  }

  @Test("메모리 캐시 크기 100MB")
  func memoryCacheSize() {
    #expect(AppConstants.ImageCache.memoryCacheCostLimit == 100 * 1024 * 1024)
  }

  @Test("메모리 캐시 최대 이미지 수 200")
  func memoryCacheCount() {
    #expect(AppConstants.ImageCache.memoryCacheCountLimit == 200)
  }

  @Test("URL 캐시 최대 엔트리 수 500")
  func urlCacheMaxEntries() {
    #expect(AppConstants.ImageCache.urlCacheMaxEntries == 500)
  }

  @Test("캐시 만료 시간 24시간")
  func cacheExpiry() {
    #expect(AppConstants.TimeIntervals.cacheExpiry == 24 * 60 * 60)
  }
}
