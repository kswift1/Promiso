import Foundation
import Nuke

/// Nuke ImagePipeline 커스텀 설정
///
/// 앱 시작 시 `configure()`를 호출하여 디스크/메모리 캐시를 활성화한다.
/// 기본 `ImagePipeline.shared`는 디스크 캐시(`DataCache`)가 비활성화되어 있어
/// 앱 재시작 시 모든 이미지를 다시 다운로드하는 문제가 있다.
public enum ImagePipelineConfigurator {

  /// ImagePipeline.shared를 커스텀 설정으로 교체
  ///
  /// - Note: `AppDelegate.didFinishLaunchingWithOptions`에서 1회 호출
  public static func configure() {
    var config = ImagePipeline.Configuration.withDataCache(
      name: AppConstants.ImageCache.diskCacheName,
      sizeLimit: AppConstants.ImageCache.diskCacheSizeLimit
    )

    // 메모리 캐시 설정
    let imageCache = ImageCache()
    imageCache.costLimit = AppConstants.ImageCache.memoryCacheCostLimit
    imageCache.countLimit = AppConstants.ImageCache.memoryCacheCountLimit
    config.imageCache = imageCache

    ImagePipeline.shared = ImagePipeline(
      configuration: config,
      delegate: FirebaseImageCacheDelegate.shared
    )
  }
}

// MARK: - ImagePipelineDelegate

/// Firebase Storage URL의 캐시 키를 정규화하는 Delegate
///
/// Firebase download URL은 `?alt=media&token=xxx` 쿼리가 포함되는데,
/// 토큰이 갱신되면 같은 이미지인데도 캐시 미스가 발생한다.
/// 쿼리 파라미터를 제거하여 경로 기반으로 캐시 키를 생성한다.
private final class FirebaseImageCacheDelegate: ImagePipelineDelegate {
  static let shared = FirebaseImageCacheDelegate()

  func cacheKey(for request: ImageRequest, pipeline: ImagePipeline) -> String? {
    guard let url = request.url, isFirebaseStorageURL(url) else {
      return nil
    }
    return normalizedCacheKey(for: url)
  }

  // MARK: - Private

  private func isFirebaseStorageURL(_ url: URL) -> Bool {
    let host = url.host ?? ""
    return host.contains("firebasestorage.googleapis.com")
      || host.contains("storage.googleapis.com")
  }

  private func normalizedCacheKey(for url: URL) -> String {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url.absoluteString
    }
    components.query = nil
    components.fragment = nil
    return components.string ?? url.absoluteString
  }
}
