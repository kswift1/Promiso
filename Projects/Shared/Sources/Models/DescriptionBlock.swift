import Foundation
import os.log

// MARK: - Checklist Item

public struct ChecklistItem: Identifiable, Equatable, Hashable, Sendable {
  public var id: String
  public var text: String
  public var isChecked: Bool

  public init(id: String = UUID().uuidString, text: String, isChecked: Bool = false) {
    self.id = id
    self.text = text
    self.isChecked = isChecked
  }
}

// MARK: - Description Block

public struct DescriptionBlock: Identifiable, Equatable, Hashable, Sendable {
  public var id: String
  public var content: BlockContent

  public enum BlockContent: Equatable, Hashable, Sendable {
    case text(String)
    case checklist([ChecklistItem])
    case bulletList([String])
  }

  public init(id: String = UUID().uuidString, content: BlockContent) {
    self.id = id
    self.content = content
  }
}

// MARK: - Codable (Firestore 호환)

extension ChecklistItem: Codable {
  // 기본 Codable 사용 (id, text, isChecked)
}

extension DescriptionBlock: Codable {
  private enum CodingKeys: String, CodingKey {
    case id, type, content, items
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "text":
      let text = try container.decode(String.self, forKey: .content)
      content = .text(text)
    case "checklist":
      let items = try container.decode([ChecklistItem].self, forKey: .items)
      content = .checklist(items)
    case "bulletList":
      let items = try container.decode([String].self, forKey: .items)
      content = .bulletList(items)
    default:
      // 알 수 없는 타입은 텍스트로 fallback
      let text = (try? container.decode(String.self, forKey: .content)) ?? ""
      Logger(subsystem: "com.promiso", category: "DescriptionBlock")
        .warning("알 수 없는 블록 타입: \(type, privacy: .public), 텍스트로 fallback")
      content = .text(text)
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)

    switch content {
    case .text(let text):
      try container.encode("text", forKey: .type)
      try container.encode(text, forKey: .content)
    case .checklist(let items):
      try container.encode("checklist", forKey: .type)
      try container.encode(items, forKey: .items)
    case .bulletList(let items):
      try container.encode("bulletList", forKey: .type)
      try container.encode(items, forKey: .items)
    }
  }
}

// MARK: - Convenience

extension DescriptionBlock {
  /// 블록을 플레인 텍스트로 변환
  public var plainText: String {
    switch content {
    case .text(let text):
      return text
    case .checklist(let items):
      return items.map { ($0.isChecked ? "☑" : "☐") + " " + $0.text }.joined(separator: "\n")
    case .bulletList(let items):
      return items.map { "• " + $0 }.joined(separator: "\n")
    }
  }

  /// 블록이 비어있는지 확인
  public var isEmpty: Bool {
    switch content {
    case .text(let text):
      return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .checklist(let items):
      return items.isEmpty
    case .bulletList(let items):
      return items.isEmpty || items.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
  }
}

extension Array where Element == DescriptionBlock {
  /// 블록 배열을 플레인 텍스트로 변환
  public var plainText: String? {
    let text = filter { !$0.isEmpty }
      .map { $0.plainText }
      .joined(separator: "\n\n")
    return text.isEmpty ? nil : text
  }
}
