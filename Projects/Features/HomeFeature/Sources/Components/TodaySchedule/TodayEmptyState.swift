import SwiftUI
import PromisoShared

// MARK: - Today Empty State

/// 오늘 일정이 없을 때 표시하는 뷰
struct TodayEmptyState: View {
  private let message: RandomMessage

  init() {
    self.message = TimeBasedMessageGenerator.generate(
      timeMessages: Self.timeMessages,
      randomMessages: Self.randomMessages
    )
  }

  var body: some View {
    VStack(spacing: 12) {
      Text(message.emoji)
        .font(.system(size: 48))

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

// MARK: - Messages

extension TodayEmptyState {
  static let timeMessages: [TimeOfDay: RandomMessage] = [
    .dawn: RandomMessage(
      emoji: "🌅",
      title: "고요한 새벽이에요",
      subtitle: "평온한 아침을 맞이하세요"
    ),
    .morning: RandomMessage(
      emoji: "☀️",
      title: "상쾌한 아침이에요",
      subtitle: "활기찬 하루를 시작해보세요"
    ),
    .lunch: RandomMessage(
      emoji: "🌤️",
      title: "느긋한 점심시간이에요",
      subtitle: "맛있는 식사 즐기세요"
    ),
    .afternoon: RandomMessage(
      emoji: "⛅",
      title: "여유로운 오후예요",
      subtitle: "편안한 시간을 즐겨보세요"
    ),
    .evening: RandomMessage(
      emoji: "🌆",
      title: "편안한 저녁이에요",
      subtitle: "하루를 마무리하는 시간"
    ),
    .night: RandomMessage(
      emoji: "🌙",
      title: "고요한 밤이에요",
      subtitle: "편안한 휴식을 취하세요"
    ),
  ]

  static let randomMessages: [RandomMessage] = [
    RandomMessage(emoji: "💫", title: "나만의 시간이에요", subtitle: "소중한 시간을 가져보세요"),
    RandomMessage(emoji: "🌈", title: "여유로운 하루예요", subtitle: "천천히 숨을 고르는 시간"),
    RandomMessage(emoji: "✨", title: "자유로운 시간이에요", subtitle: "하고 싶었던 일을 해보세요"),
    RandomMessage(emoji: "🎨", title: "특별한 일정이 없어요", subtitle: "취미 생활을 즐겨보세요"),
    RandomMessage(emoji: "📚", title: "느긋한 하루예요", subtitle: "좋아하는 책을 펼쳐보세요"),
    RandomMessage(emoji: "🎵", title: "평온한 시간이에요", subtitle: "음악과 함께하는 여유"),
    RandomMessage(emoji: "🏃", title: "여유가 있는 날이에요", subtitle: "가벼운 산책은 어떠세요?"),
    RandomMessage(emoji: "🍵", title: "한가한 시간이에요", subtitle: "따뜻한 차 한잔의 여유"),
    RandomMessage(emoji: "🧘", title: "조용한 하루예요", subtitle: "마음을 비우는 시간"),
    RandomMessage(emoji: "🌱", title: "나를 위한 시간이에요", subtitle: "자신을 돌보는 시간을 가져요"),
    RandomMessage(emoji: "☕", title: "여유있는 오늘이에요", subtitle: "편안하게 쉬어가는 하루"),
    RandomMessage(emoji: "🌿", title: "평화로운 하루예요", subtitle: "자연스럽게 흐르는 시간"),
  ]
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
