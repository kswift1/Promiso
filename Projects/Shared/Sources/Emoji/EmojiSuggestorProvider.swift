// EmojiSuggestorProvider.swift
import Foundation

public enum EmojiSuggestorProvider {
  public static let shared: EmojiSuggester = {
    let entries = (try? EmojiLoader.loadCompact()) ?? []
    return EmojiSuggester(entries: entries)
  }()
}
