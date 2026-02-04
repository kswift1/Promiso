import SwiftUI
import PromisoShared

// MARK: - Today Empty State

/// 오늘 일정이 없을 때 표시하는 뷰
struct TodayEmptyState: View {
  private let message: EmptyMessage

  init() {
    self.message = EmptyMessage.generate()
  }

  var body: some View {
    VStack(spacing: 12) {
      // 이모지
      Text(message.emoji)
        .font(.system(size: 48))

      // 텍스트
      VStack(spacing: 4) {
        Text(message.title)
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Text(message.subtitle)
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}

// MARK: - Empty Message

private struct EmptyMessage {
  let emoji: String
  let title: String
  let subtitle: String

  /// 시간대와 확률에 따라 메시지 생성
  static func generate() -> EmptyMessage {
    // 20% 확률로 랜덤 응원 메시지
    if Int.random(in: 1...10) <= 2 {
      return randomMessages.randomElement()!
    }

    // 80% 시간대별 기본 메시지
    let timeOfDay = TimeOfDay.current
    return timeOfDay.message
  }

  /// 랜덤 응원 메시지들 (희망적인 톤)
  static let randomMessages: [EmptyMessage] = [
    EmptyMessage(
      emoji: "💫",
      title: "나만의 시간이에요",
      subtitle: "소중한 시간을 가져보세요"
    ),
    EmptyMessage(
      emoji: "🌈",
      title: "여유로운 하루예요",
      subtitle: "천천히 숨을 고르는 시간"
    ),
    EmptyMessage(
      emoji: "✨",
      title: "자유로운 시간이에요",
      subtitle: "하고 싶었던 일을 해보세요"
    ),
    EmptyMessage(
      emoji: "🎨",
      title: "특별한 일정이 없어요",
      subtitle: "취미 생활을 즐겨보세요"
    ),
    EmptyMessage(
      emoji: "📚",
      title: "느긋한 하루예요",
      subtitle: "좋아하는 책을 펼쳐보세요"
    ),
    EmptyMessage(
      emoji: "🎵",
      title: "평온한 시간이에요",
      subtitle: "음악과 함께하는 여유"
    ),
    EmptyMessage(
      emoji: "🏃",
      title: "여유가 있는 날이에요",
      subtitle: "가벼운 산책은 어떠세요?"
    ),
    EmptyMessage(
      emoji: "🍵",
      title: "한가한 시간이에요",
      subtitle: "따뜻한 차 한잔의 여유"
    ),
    EmptyMessage(
      emoji: "🧘",
      title: "조용한 하루예요",
      subtitle: "마음을 비우는 시간"
    ),
    EmptyMessage(
      emoji: "🌱",
      title: "나를 위한 시간이에요",
      subtitle: "자신을 돌보는 시간을 가져요"
    ),
    EmptyMessage(
      emoji: "☕",
      title: "여유있는 오늘이에요",
      subtitle: "편안하게 쉬어가는 하루"
    ),
    EmptyMessage(
      emoji: "🌿",
      title: "평화로운 하루예요",
      subtitle: "자연스럽게 흐르는 시간"
    )
  ]
}

// MARK: - Time of Day

private enum TimeOfDay {
  case dawn      // 04:00-06:00
  case morning   // 06:00-11:00
  case lunch     // 11:00-14:00
  case afternoon // 14:00-18:00
  case evening   // 18:00-21:00
  case night     // 21:00-04:00

  static var current: TimeOfDay {
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

  var message: EmptyMessage {
    switch self {
    case .dawn:
      return EmptyMessage(
        emoji: "🌅",
        title: "고요한 새벽이에요",
        subtitle: "평온한 아침을 맞이하세요"
      )
    case .morning:
      return EmptyMessage(
        emoji: "☀️",
        title: "상쾌한 아침이에요",
        subtitle: "활기찬 하루를 시작해보세요"
      )
    case .lunch:
      return EmptyMessage(
        emoji: "🌤️",
        title: "느긋한 점심시간이에요",
        subtitle: "맛있는 식사 즐기세요"
      )
    case .afternoon:
      return EmptyMessage(
        emoji: "⛅",
        title: "여유로운 오후예요",
        subtitle: "편안한 시간을 즐겨보세요"
      )
    case .evening:
      return EmptyMessage(
        emoji: "🌆",
        title: "편안한 저녁이에요",
        subtitle: "하루를 마무리하는 시간"
      )
    case .night:
      return EmptyMessage(
        emoji: "🌙",
        title: "고요한 밤이에요",
        subtitle: "편안한 휴식을 취하세요"
      )
    }
  }
}

// MARK: - Preview

#Preview {
  VStack {
    TodayEmptyState()
  }
  .padding()
  .background(Color(.systemGray6))
  .clipShape(RoundedRectangle(cornerRadius: 20))
  .padding()
  .auroraBackground()
}
