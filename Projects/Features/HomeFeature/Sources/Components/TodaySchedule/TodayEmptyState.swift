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
      title: LocalizedStrings.Home.emptyDawnTitle,
      subtitle: LocalizedStrings.Home.emptyDawnSubtitle
    ),
    .morning: RandomMessage(
      emoji: "☀️",
      title: LocalizedStrings.Home.emptyMorningTitle,
      subtitle: LocalizedStrings.Home.emptyMorningSubtitle
    ),
    .lunch: RandomMessage(
      emoji: "🌤️",
      title: LocalizedStrings.Home.emptyLunchTitle,
      subtitle: LocalizedStrings.Home.emptyLunchSubtitle
    ),
    .afternoon: RandomMessage(
      emoji: "⛅",
      title: LocalizedStrings.Home.emptyAfternoonTitle,
      subtitle: LocalizedStrings.Home.emptyAfternoonSubtitle
    ),
    .evening: RandomMessage(
      emoji: "🌆",
      title: LocalizedStrings.Home.emptyEveningTitle,
      subtitle: LocalizedStrings.Home.emptyEveningSubtitle
    ),
    .night: RandomMessage(
      emoji: "🌙",
      title: LocalizedStrings.Home.emptyNightTitle,
      subtitle: LocalizedStrings.Home.emptyNightSubtitle
    ),
  ]

  static let randomMessages: [RandomMessage] = [
    RandomMessage(emoji: "💫", title: LocalizedStrings.Home.emptyRandom1Title, subtitle: LocalizedStrings.Home.emptyRandom1Subtitle),
    RandomMessage(emoji: "🌈", title: LocalizedStrings.Home.emptyRandom2Title, subtitle: LocalizedStrings.Home.emptyRandom2Subtitle),
    RandomMessage(emoji: "✨", title: LocalizedStrings.Home.emptyRandom3Title, subtitle: LocalizedStrings.Home.emptyRandom3Subtitle),
    RandomMessage(emoji: "🎨", title: LocalizedStrings.Home.emptyRandom4Title, subtitle: LocalizedStrings.Home.emptyRandom4Subtitle),
    RandomMessage(emoji: "📚", title: LocalizedStrings.Home.emptyRandom5Title, subtitle: LocalizedStrings.Home.emptyRandom5Subtitle),
    RandomMessage(emoji: "🎵", title: LocalizedStrings.Home.emptyRandom6Title, subtitle: LocalizedStrings.Home.emptyRandom6Subtitle),
    RandomMessage(emoji: "🏃", title: LocalizedStrings.Home.emptyRandom7Title, subtitle: LocalizedStrings.Home.emptyRandom7Subtitle),
    RandomMessage(emoji: "🍵", title: LocalizedStrings.Home.emptyRandom8Title, subtitle: LocalizedStrings.Home.emptyRandom8Subtitle),
    RandomMessage(emoji: "🧘", title: LocalizedStrings.Home.emptyRandom9Title, subtitle: LocalizedStrings.Home.emptyRandom9Subtitle),
    RandomMessage(emoji: "🌱", title: LocalizedStrings.Home.emptyRandom10Title, subtitle: LocalizedStrings.Home.emptyRandom10Subtitle),
    RandomMessage(emoji: "☕", title: LocalizedStrings.Home.emptyRandom11Title, subtitle: LocalizedStrings.Home.emptyRandom11Subtitle),
    RandomMessage(emoji: "🌿", title: LocalizedStrings.Home.emptyRandom12Title, subtitle: LocalizedStrings.Home.emptyRandom12Subtitle),
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
