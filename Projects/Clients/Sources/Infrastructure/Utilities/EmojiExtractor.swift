import Foundation

/// 텍스트에서 이모지를 추출하는 유틸리티
public enum EmojiExtractor {
  /// 텍스트에서 첫 번째 이모지 추출
  public static func extractFirst(from text: String) -> String? {
    for scalar in text.unicodeScalars {
      if scalar.properties.isEmoji && scalar.properties.isEmojiPresentation {
        return String(scalar)
      }
    }

    // Extended grapheme clusters (복합 이모지) 처리
    for character in text {
      if character.unicodeScalars.first?.properties.isEmoji == true {
        return String(character)
      }
    }

    return nil
  }

  /// 텍스트에서 모든 이모지 추출
  public static func extractAll(from text: String) -> [String] {
    var emojis: [String] = []

    for character in text {
      if character.unicodeScalars.first?.properties.isEmoji == true,
         character.unicodeScalars.first?.properties.isEmojiPresentation == true ||
           character.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation }) {
        emojis.append(String(character))
      }
    }

    return emojis
  }

  /// 주어진 문자가 이모지인지 확인
  public static func isEmoji(_ character: Character) -> Bool {
    guard let scalar = character.unicodeScalars.first else { return false }
    return scalar.properties.isEmoji && (
      scalar.properties.isEmojiPresentation ||
        character.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation })
    )
  }
}
