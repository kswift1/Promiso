import Foundation

// MARK: - Random Message

/// 시간대별/랜덤 메시지 데이터
public struct RandomMessage: Sendable {
  public let emoji: String
  public let title: String
  public let subtitle: String

  public init(emoji: String, title: String, subtitle: String) {
    self.emoji = emoji
    self.title = title
    self.subtitle = subtitle
  }
}

// MARK: - Time of Day

/// 하루 시간대 구분
public enum TimeOfDay: Sendable {
  case dawn      // 04:00-06:00
  case morning   // 06:00-11:00
  case lunch     // 11:00-14:00
  case afternoon // 14:00-18:00
  case evening   // 18:00-21:00
  case night     // 21:00-04:00

  public static var current: TimeOfDay {
    let hour = Calendar.current.component(.hour, from: Date())

    switch hour {
    case 4..<6:
      return .dawn
    case 6..<11:
      return .morning
    case 11..<14:
      return .lunch
    case 14..<18:
      return .afternoon
    case 18..<21:
      return .evening
    default:
      return .night
    }
  }
}

// MARK: - Time Based Message Generator

/// 시간대 기반 + 랜덤 메시지 생성기
public enum TimeBasedMessageGenerator {
  /// 시간대별 메시지와 랜덤 메시지 중 하나를 선택하여 반환
  /// - Parameters:
  ///   - timeMessages: 시간대별 메시지 매핑
  ///   - randomMessages: 랜덤으로 선택될 메시지 목록
  ///   - randomPercent: 랜덤 메시지가 선택될 확률 (0-100, 기본 40%)
  public static func generate(
    timeMessages: [TimeOfDay: RandomMessage],
    randomMessages: [RandomMessage],
    randomPercent: Int = 40
  ) -> RandomMessage {
    // randomPercent 확률로 랜덤 메시지
    if !randomMessages.isEmpty, Int.random(in: 1...100) <= randomPercent, let message = randomMessages.randomElement() {
      return message
    }

    // 나머지는 시간대별 메시지
    let timeOfDay = TimeOfDay.current
    if let message = timeMessages[timeOfDay] {
      return message
    }

    // fallback
    return randomMessages.first ?? RandomMessage(
      emoji: "📅",
      title: "일정이 없어요",
      subtitle: ""
    )
  }
}
