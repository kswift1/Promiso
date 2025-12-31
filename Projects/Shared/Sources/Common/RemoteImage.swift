import Foundation

/// 원격 이미지 정보 (Storage 경로 또는 외부 URL)
public struct RemoteImage: Codable, Equatable, Sendable {
  /// 이미지 소스 유형
  public enum SourceType: String, Codable, Sendable {
    /// Firebase Storage 경로
    case storagePath
    /// 외부 URL
    case externalURL
  }

  /// 이미지 소스 유형
  public let type: SourceType
  /// 이미지 경로/URL 문자열
  public let url: String

  public init(
    type: SourceType,
    url: String
  ) {
    self.type = type
    self.url = url
  }
}
