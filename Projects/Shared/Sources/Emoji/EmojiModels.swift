// EmojiModels.swift
import Foundation

public struct EmojiEntry: Decodable, Sendable {
  public let unicode: String          // "🍿"
  public let label: String?           // "팝콘"
  public let tags: [String]?          // ["영화", "간식", ...]
  public let hexcode: String?         // "1F37F"
  public let group: Int?              // 0 = Smileys ... (있을 수도, 없을 수도)
  public let order: Int?              // 정렬용 (있을 수도)
}
