//
//  EmojiModelsTests.swift
//  PromisoShared
//
//  EmojiEntry 모델 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Emoji/EmojiModels.swift`
//
//  ## 테스트 목적
//  - EmojiEntry JSON 디코딩: 전체 필드 디코딩
//  - EmojiEntry JSON 디코딩: 선택적 필드 nil 처리
//  - EmojiSuggestion: Hashable 동작 확인
//

import Foundation
import Testing
@testable import PromisoShared

@Suite("EmojiEntry 모델 테스트")
struct EmojiEntryTests {

  @Test("전체 필드가 포함된 JSON 디코딩 성공")
  func decodingWithAllFields() throws {
    let json = """
    {
      "unicode": "🍿",
      "label": "팝콘",
      "tags": ["영화", "간식", "극장"],
      "hexcode": "1F37F",
      "group": 4,
      "order": 120
    }
    """
    let data = json.data(using: .utf8)!
    let entry = try JSONDecoder().decode(EmojiEntry.self, from: data)

    #expect(entry.unicode == "🍿")
    #expect(entry.label == "팝콘")
    #expect(entry.tags == ["영화", "간식", "극장"])
    #expect(entry.hexcode == "1F37F")
    #expect(entry.group == 4)
    #expect(entry.order == 120)
  }

  @Test("선택적 필드가 없는 JSON 디코딩 성공")
  func decodingWithMinimalFields() throws {
    let json = """
    {
      "unicode": "😀"
    }
    """
    let data = json.data(using: .utf8)!
    let entry = try JSONDecoder().decode(EmojiEntry.self, from: data)

    #expect(entry.unicode == "😀")
    #expect(entry.label == nil)
    #expect(entry.tags == nil)
    #expect(entry.hexcode == nil)
    #expect(entry.group == nil)
    #expect(entry.order == nil)
  }

  @Test("배열 형태의 JSON 디코딩 성공")
  func decodingArray() throws {
    let json = """
    [
      {"unicode": "🍕", "label": "피자", "tags": ["음식"]},
      {"unicode": "🎉", "label": "파티", "tags": ["축하"]}
    ]
    """
    let data = json.data(using: .utf8)!
    let entries = try JSONDecoder().decode([EmojiEntry].self, from: data)

    #expect(entries.count == 2)
    #expect(entries[0].unicode == "🍕")
    #expect(entries[1].unicode == "🎉")
  }
}

@Suite("EmojiSuggestion 모델 테스트")
struct EmojiSuggestionTests {

  @Test("동일한 값이면 Hashable 동일")
  func hashableEquality() {
    let suggestion1 = EmojiSuggestion(emoji: "🍕", score: 5, reason: "tag")
    let suggestion2 = EmojiSuggestion(emoji: "🍕", score: 5, reason: "tag")
    #expect(suggestion1 == suggestion2)
  }

  @Test("다른 값이면 Hashable 다름")
  func hashableInequality() {
    let suggestion1 = EmojiSuggestion(emoji: "🍕", score: 5, reason: "tag")
    let suggestion2 = EmojiSuggestion(emoji: "🎉", score: 3, reason: "label")
    #expect(suggestion1 != suggestion2)
  }

  @Test("Set에서 중복 제거")
  func setDeduplication() {
    let suggestion1 = EmojiSuggestion(emoji: "🍕", score: 5, reason: "tag")
    let suggestion2 = EmojiSuggestion(emoji: "🍕", score: 5, reason: "tag")
    let suggestion3 = EmojiSuggestion(emoji: "🎉", score: 3, reason: "label")

    let set: Set<EmojiSuggestion> = [suggestion1, suggestion2, suggestion3]
    #expect(set.count == 2)
  }
}
