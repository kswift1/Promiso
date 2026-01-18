import Foundation
import UIKit

// MARK: - LiveActivityImageStore

/// LiveActivity용 프로필 이미지 저장/로드 유틸리티
///
/// Widget은 네트워크 요청 불가 → 앱에서 App Group에 사전 캐싱 → Widget에서 FileManager로 로드
/// 캐싱 타이밍: `GroupMainFeature.groupMembersResponse(.success)` (APNs 원격 시작 대응)
public enum LiveActivityImageStore {

  // MARK: - Constants

  /// App Group Identifier (Entitlements 파일과 일치)
  private static let appGroupIdentifier = "group.com.promiso.shared"

  /// 이미지 저장 디렉토리명
  private static let imageDirectoryName = "LiveActivityImages"

  /// 저장 이미지 크기 (64x64 - Retina 대응)
  public static let imageSize: CGFloat = 64

  /// JPEG 압축 품질
  private static let compressionQuality: CGFloat = 0.8

  // MARK: - Directory Access

  /// App Group 컨테이너 URL
  private static var containerURL: URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )
  }

  /// 이미지 저장 디렉토리 URL
  private static var imageDirectoryURL: URL? {
    containerURL?.appendingPathComponent(imageDirectoryName, isDirectory: true)
  }

  // MARK: - Public API (앱에서 사용)

  /// 프로필 이미지를 App Group 컨테이너에 저장
  ///
  /// - Parameters:
  ///   - image: 저장할 원본 이미지
  ///   - userId: 사용자 ID (파일명에 사용)
  /// - Returns: 저장된 파일명 (성공 시), nil (실패 시)
  ///
  /// - Note: TaskGroup 내에서 호출하면 자동으로 병렬 처리됨
  @discardableResult
  public static func saveImage(_ image: UIImage, userId: String) -> String? {
    guard let directoryURL = imageDirectoryURL else {
      AppLogger.liveActivity.error("App Group 컨테이너 접근 실패")
      return nil
    }

    do {
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    } catch {
      AppLogger.liveActivity.error("디렉토리 생성 실패: \(error)")
      return nil
    }

    let resizedImage = image.resizedToSquare(size: imageSize)

    guard let jpegData = resizedImage.jpegData(compressionQuality: compressionQuality) else {
      AppLogger.liveActivity.error("JPEG 변환 실패: \(userId)")
      return nil
    }

    let fileName = makeFileName(userId: userId)
    let fileURL = directoryURL.appendingPathComponent(fileName)

    do {
      try jpegData.write(to: fileURL, options: .atomic)
      AppLogger.liveActivity.debug("프로필 이미지 캐싱 완료: \(fileName)")
      return fileName
    } catch {
      AppLogger.liveActivity.error("파일 저장 실패: \(error)")
      return nil
    }
  }

  /// 캐시된 모든 이미지 삭제 (로그아웃 시 호출)
  public static func clearCache() {
    guard let directoryURL = imageDirectoryURL else { return }

    do {
      if FileManager.default.fileExists(atPath: directoryURL.path) {
        try FileManager.default.removeItem(at: directoryURL)
        AppLogger.liveActivity.debug("캐시 전체 삭제 완료")
      }
    } catch {
      AppLogger.liveActivity.error("캐시 삭제 실패: \(error)")
    }
  }

  // MARK: - Public API (Widget에서 사용)

  /// 사용자 ID로 프로필 이미지 로드
  ///
  /// - Parameter userId: 사용자 ID
  /// - Returns: 로드된 UIImage, 실패 시 nil
  public static func loadImage(userId: String) -> UIImage? {
    guard let directoryURL = imageDirectoryURL else {
      AppLogger.liveActivity.error("🟣WIDGET🟣 App Group 접근 실패")
      return nil
    }

    let fileName = makeFileName(userId: userId)
    let fileURL = directoryURL.appendingPathComponent(fileName)

    // 파일 존재 체크 없이 바로 로드 시도 (I/O 1회)
    guard let data = try? Data(contentsOf: fileURL),
          let image = UIImage(data: data) else {
      AppLogger.liveActivity.debug("🟣WIDGET🟣 loadImage 실패: \(userId)")
      return nil
    }

    AppLogger.liveActivity.debug("🟣WIDGET🟣 loadImage 성공: \(userId)")
    return image
  }

  // MARK: - Helpers

  /// 사용자 ID로 파일명 생성
  ///
  /// - Parameter userId: 사용자 ID
  /// - Returns: 파일명 (예: "profile-abc123.jpg")
  public static func makeFileName(userId: String) -> String {
    "profile-\(userId).jpg"
  }

  // MARK: - Debug

  /// 캐시된 모든 이미지 파일명 목록 (디버그용)
  public static func listCachedFiles() -> [String] {
    guard let directoryURL = imageDirectoryURL else {
      AppLogger.liveActivity.debug("App Group 컨테이너 접근 실패")
      return []
    }

    do {
      let files = try FileManager.default.contentsOfDirectory(atPath: directoryURL.path)
      AppLogger.liveActivity.debug("캐시된 파일 목록: \(files)")
      return files
    } catch {
      AppLogger.liveActivity.debug("파일 목록 조회 실패: \(error)")
      return []
    }
  }
}

// MARK: - UIImage Extension

private extension UIImage {
  /// 이미지를 정사각형으로 크롭 후 리사이즈
  ///
  /// - Parameter size: 결과 이미지의 한 변 크기
  /// - Returns: 리사이즈된 정사각형 이미지
  func resizedToSquare(size: CGFloat) -> UIImage {
    let targetSize = CGSize(width: size, height: size)

    // 정사각형 크롭 영역 계산
    let originalSize = self.size
    let minDimension = min(originalSize.width, originalSize.height)
    let cropRect = CGRect(
      x: (originalSize.width - minDimension) / 2,
      y: (originalSize.height - minDimension) / 2,
      width: minDimension,
      height: minDimension
    )

    // 크롭 후 리사이즈
    let renderer = UIGraphicsImageRenderer(size: targetSize)
    return renderer.image { _ in
      // 크롭된 영역을 target 크기에 맞춰 그리기
      if let cgImage = self.cgImage?.cropping(to: cropRect) {
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: targetSize))
      } else {
        self.draw(in: CGRect(origin: .zero, size: targetSize))
      }
    }
  }
}
