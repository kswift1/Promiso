import Foundation

// MARK: - Schedule Extracted Info

/// 텍스트/이미지에서 추출된 일정 정보
public struct ScheduleExtractedInfo: Equatable, Sendable {
  /// 추출된 제목 (첫 번째 줄 또는 주요 키워드)
  public var title: String?

  /// 추출된 날짜/시간
  public var date: Date?

  /// 추출된 장소명
  public var location: String?

  /// 추출된 설명 (부가 정보)
  public var description: String?

  /// 원본 텍스트 (OCR 결과 또는 입력 텍스트)
  public var rawText: String

  /// 추출 소스
  public var source: Source

  public enum Source: Equatable, Sendable {
    case text
    case image
  }

  public init(
    title: String? = nil,
    date: Date? = nil,
    location: String? = nil,
    description: String? = nil,
    rawText: String = "",
    source: Source = .text
  ) {
    self.title = title
    self.date = date
    self.location = location
    self.description = description
    self.rawText = rawText
    self.source = source
  }

  /// 유효한 정보가 하나라도 있는지
  public var hasAnyInfo: Bool {
    title != nil || date != nil || location != nil
  }
}
