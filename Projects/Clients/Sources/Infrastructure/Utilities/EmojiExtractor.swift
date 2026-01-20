import Foundation

/// 텍스트에서 이모지를 추출하는 유틸리티
public enum EmojiExtractor {
  /// 텍스트에서 첫 번째 이모지 추출
  /// 국기(🇺🇸), 스킨톤(👍🏻), ZWJ 시퀀스(👨‍👩‍👧) 등 복합 이모지 지원
  public static func extractFirst(from text: String) -> String? {
    for character in text {
      if isEmoji(character) {
        return String(character)
      }
    }
    return nil
  }

  /// 텍스트에서 모든 이모지 추출
  public static func extractAll(from text: String) -> [String] {
    var emojis: [String] = []
    for character in text {
      if isEmoji(character) {
        emojis.append(String(character))
      }
    }
    return emojis
  }

  /// 주어진 문자가 이모지인지 확인
  /// 국기, 스킨톤, ZWJ 시퀀스 등 모든 이모지 타입 지원
  public static func isEmoji(_ character: Character) -> Bool {
    // 숫자(0-9), #, * 등은 이모지 속성이 있지만 실제 이모지가 아님
    // Variation Selector(FE0F)가 없으면 텍스트로 표시됨
    let dominated = character.unicodeScalars.contains { scalar in
      scalar.properties.isEmojiPresentation ||
        scalar.value == 0xFE0F  // Variation Selector-16 (이모지 표시)
    }

    // Regional Indicator (국기 이모지)
    let isRegionalIndicator = character.unicodeScalars.allSatisfy { scalar in
      (0x1F1E6...0x1F1FF).contains(scalar.value)
    } && character.unicodeScalars.count == 2

    if isRegionalIndicator {
      return true
    }

    guard let firstScalar = character.unicodeScalars.first else {
      return false
    }

    // 이모지 속성이 있고, 이모지 표시 방식이거나 복합 이모지인 경우
    return firstScalar.properties.isEmoji && (
      firstScalar.properties.isEmojiPresentation ||
        dominated ||
        character.unicodeScalars.count > 1  // 복합 이모지 (ZWJ, 스킨톤 등)
    )
  }
}
