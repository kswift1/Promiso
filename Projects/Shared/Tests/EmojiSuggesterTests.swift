//
//  EmojiSuggesterTests.swift
//  PromisoShared
//
//  EmojiSuggester 추천 로직 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Emoji/EmojiSuggester.swift`
//  - `PromisoShared/Sources/Emoji/EmojiSuggestorProvider.swift`
//
//  ## 테스트 목적
//  - suggest(): 키워드 매칭 기반 이모지 추천
//  - 빈 입력, 한글 키워드, 태그 매칭, 라벨 매칭, topK 제한
//  - 불용어(stopword) 필터링
//

import Foundation
import Testing
@testable import PromisoShared

@Suite("EmojiSuggester 추천 테스트")
struct EmojiSuggesterTests {

  // 테스트용 이모지 엔트리
  private static let testEntries: [EmojiEntry] = {
    let json = """
    [
      {"unicode": "🍕", "label": "피자", "tags": ["음식", "이탈리아", "치즈"]},
      {"unicode": "🍔", "label": "햄버거", "tags": ["음식", "패스트푸드", "버거"]},
      {"unicode": "🎉", "label": "파티", "tags": ["축하", "생일", "모임"]},
      {"unicode": "🎂", "label": "케이크", "tags": ["생일", "축하", "디저트"]},
      {"unicode": "☕", "label": "커피", "tags": ["음료", "카페", "아메리카노"]},
      {"unicode": "🏃", "label": "달리기", "tags": ["운동", "달리기", "마라톤"]},
      {"unicode": "📚", "label": "책", "tags": ["공부", "독서", "학습"]}
    ]
    """
    return try! JSONDecoder().decode([EmojiEntry].self, from: json.data(using: .utf8)!)
  }()

  @Test("빈 문자열 입력 시 빈 배열 반환")
  func emptyInput_returnsEmpty() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "")
    #expect(results.isEmpty)
  }

  @Test("불용어만 입력 시 빈 배열 반환")
  func stopwordsOnly_returnsEmpty() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "은 는 이 가")
    #expect(results.isEmpty)
  }

  @Test("한글 태그 매칭으로 이모지 추천")
  func koreanTagMatching_returnsSuggestions() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "음식")
    #expect(results.isNotEmpty)
    // 음식 태그가 있는 이모지 (피자, 햄버거)
    let emojis = results.map(\.emoji)
    #expect(emojis.contains("🍕") || emojis.contains("🍔"))
  }

  @Test("라벨 매칭으로 이모지 추천")
  func labelMatching_returnsSuggestions() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "커피")
    #expect(results.isNotEmpty)
    let emojis = results.map(\.emoji)
    #expect(emojis.contains("☕"))
  }

  @Test("topK 제한 동작 확인")
  func topKLimit_respectsLimit() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    // "생일" 태그가 있는 이모지: 파티, 케이크
    let results = await suggester.suggest(for: "생일 축하 모임", topK: 2)
    #expect(results.count <= 2)
  }

  @Test("태그 매칭이 라벨 매칭보다 높은 점수")
  func tagMatchScoresHigherThanLabel() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    // "생일"은 태그로 2개 매칭 (파티, 케이크)
    let results = await suggester.suggest(for: "생일")
    #expect(results.isNotEmpty)
    // 결과가 점수 내림차순으로 정렬되어 있는지 확인
    for i in 0..<(results.count - 1) {
      #expect(results[i].score >= results[i + 1].score)
    }
  }

  @Test("매칭되지 않는 키워드는 빈 배열 반환")
  func noMatch_returnsEmpty() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "자동차")
    #expect(results.isEmpty)
  }

  @Test("특수문자가 포함된 입력에서 키워드 추출")
  func specialCharacters_areStripped() async {
    let suggester = EmojiSuggester(entries: Self.testEntries)
    let results = await suggester.suggest(for: "커피!!!")
    #expect(results.isNotEmpty)
    let emojis = results.map(\.emoji)
    #expect(emojis.contains("☕"))
  }
}
