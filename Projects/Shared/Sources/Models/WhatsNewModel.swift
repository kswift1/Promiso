import Foundation

// MARK: - WhatsNewModel

/// What's New 화면에 표시할 신규 기능 안내 데이터
public struct WhatsNewModel: Equatable, Identifiable, Sendable {
  public var id: String { version }
  public let version: String
  public let enabled: Bool
  public let items: [Item]

  public init(version: String, enabled: Bool, items: [Item]) {
    self.version = version
    self.enabled = enabled
    self.items = items
  }
}

// MARK: - Item

extension WhatsNewModel {
  /// What's New 개별 항목
  public struct Item: Equatable, Identifiable, Sendable {
    public var id: Int { displayOrder }
    public let title: String
    public let description: String
    public let imageURL: URL?
    public let displayOrder: Int

    public init(title: String, description: String, imageURL: URL?, displayOrder: Int) {
      self.title = title
      self.description = description
      self.imageURL = imageURL
      self.displayOrder = displayOrder
    }
  }
}

// MARK: - Preview

extension WhatsNewModel {
  public static let example = WhatsNewModel(
    version: "1.3.1",
    enabled: true,
    items: [
      .init(title: "도보 경로 안내", description: "약속 장소까지 걸어가는 길을 안내해요", imageURL: nil, displayOrder: 0),
      .init(title: "투표 실시간 현황", description: "투표 결과를 실시간으로 확인할 수 있어요", imageURL: nil, displayOrder: 1),
    ]
  )
}
