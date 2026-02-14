import Nuke
import UIKit

/// 공통 이미지 로딩 유틸리티 (재시도 로직 포함)
public enum ImageLoader {

  /// 최대 재시도 횟수
  public static let maxRetryCount = 3

  /// 이미지를 로드하고 실패 시 지수 백오프로 재시도
  ///
  /// - Parameters:
  ///   - url: 이미지 URL
  ///   - retryCount: 최대 재시도 횟수 (기본 3)
  /// - Returns: 로드된 UIImage, 모든 재시도 실패 시 nil
  public static func loadImage(from url: URL, retryCount: Int = maxRetryCount) async -> UIImage? {
    for attempt in 0..<retryCount {
      do {
        let request = ImageRequest(url: url)
        return try await ImagePipeline.shared.image(for: request)
      } catch {
        if attempt < retryCount - 1 {
          let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
          try? await Task.sleep(nanoseconds: delay)
        }
      }
    }
    return nil
  }
}
