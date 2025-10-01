import Foundation

public struct EmojiSuggestion: Hashable, Sendable {
  public let emoji: String   // 실제 문자 (unicode)
  public let score: Int
  public let reason: String  // "tag" / "label"
}

public actor EmojiSuggester {
  private let entries: [EmojiEntry]
  private let stopwords: Set<String> = ["은","는","이","가","을","를","에","에서","과","와","도","의","로","으로","한",
                                        "하다","및","좀","또","그리고","혹은","또는","the","a","an","to","for","of","on"]
  public init(entries: [EmojiEntry]) { self.entries = entries }

  public func suggest(for title: String, topK: Int = 3) -> [EmojiSuggestion] {
    let tokens = tokenize(title)
    guard !tokens.isEmpty else { return [] }

    var map: [String: (score: Int, reason: String)] = [:]

    for e in entries {
      var s = 0
      var r = ""

      if let tags = e.tags {
        let hit = tags.filter { containsAny(tokens, in: $0) }.count
        if hit > 0 { s += hit * 3; r = "tag" }
      }
      if let label = e.label, containsAny(tokens, in: label) {
        s += 2; r = "label"
      }
      if s > 0 {
        let uni = String(e.unicode.prefix(1))
        guard !uni.isEmpty else { continue }
        let cur = map[uni] ?? (0, "")
        let newScore = cur.score + s
        let newReason = r.isEmpty ? cur.reason : r
        map[uni] = (newScore, newReason)
      }
    }

    let suggestions: [EmojiSuggestion] = map.map { (key, value) in
      EmojiSuggestion(emoji: key, score: value.score, reason: value.reason)
    }
    let sorted: [EmojiSuggestion] = suggestions.sorted { (l: EmojiSuggestion, r: EmojiSuggestion) -> Bool in
      if l.score == r.score {
        return l.emoji < r.emoji
      }
      return l.score > r.score
    }
    return Array(sorted.prefix(topK))
  }

  // MARK: - Helpers
  private func tokenize(_ s: String) -> [String] {
    let lowered = s.lowercased()
    let basic = lowered.replacingOccurrences(of: "[^0-9가-힣a-z\\s]", with: " ", options: .regularExpression)
    return basic.split(separator: " ")
      .map(String.init)
      .filter { !$0.isEmpty && !stopwords.contains($0) }
  }
  private func containsAny(_ tokens: [String], in text: String) -> Bool {
    let t = text.lowercased()
    return tokens.contains { token in t.contains(token) }
  }
}
