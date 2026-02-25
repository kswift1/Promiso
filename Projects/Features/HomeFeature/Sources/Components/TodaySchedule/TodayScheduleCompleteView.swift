import SwiftUI
import PromisoShared

// MARK: - Today Schedule Complete View

/// 오늘 일정을 모두 마쳤을 때 표시하는 완료 메시지
struct TodayScheduleCompleteView: View {
  private let message: RandomMessage

  init() {
    self.message = TimeBasedMessageGenerator.generate(
      timeMessages: Self.timeMessages,
      randomMessages: Self.randomMessages
    )
  }

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // 타임라인 인디케이터 (TimelineItemView와 동일 구조)
      VStack(spacing: 0) {
        // 상단 라인 (위 아이템과 연결)
        Rectangle()
          .fill(Color.pmindigo.n300.opacity(0.5))
          .frame(width: 2, height: 10)

        // dot (active)
        Circle()
          .fill(Color.pmindigo.n500)
          .frame(width: 10, height: 10)
      }
      .frame(width: 16)

      HStack(spacing: 6) {
        Text(message.emoji)
          .font(.pmBody)

        Text(message.title)
          .font(.pmSubheadlineSemibold)
          .foregroundStyle(.secondary)
      }
      .padding(.leading, 8)
      .padding(.vertical, 8)

      Spacer(minLength: 0)
    }
  }
}

// MARK: - Messages

extension TodayScheduleCompleteView {
  static let timeMessages: [TimeOfDay: RandomMessage] = [
    .dawn: RandomMessage(emoji: "🌅", title: LocalizedStrings.Home.completeDawnTitle, subtitle: ""),
    .morning: RandomMessage(emoji: "☀️", title: LocalizedStrings.Home.completeMorningTitle, subtitle: ""),
    .lunch: RandomMessage(emoji: "🍽️", title: LocalizedStrings.Home.completeLunchTitle, subtitle: ""),
    .afternoon: RandomMessage(emoji: "⛅", title: LocalizedStrings.Home.completeAfternoonTitle, subtitle: ""),
    .evening: RandomMessage(emoji: "🌆", title: LocalizedStrings.Home.completeEveningTitle, subtitle: ""),
    .night: RandomMessage(emoji: "🌙", title: LocalizedStrings.Home.completeNightTitle, subtitle: ""),
  ]

  static let randomMessages: [RandomMessage] = [
    RandomMessage(emoji: "🎉", title: LocalizedStrings.Home.completeRandom1Title, subtitle: ""),
    RandomMessage(emoji: "✅", title: LocalizedStrings.Home.completeRandom2Title, subtitle: ""),
    RandomMessage(emoji: "🏆", title: LocalizedStrings.Home.completeRandom3Title, subtitle: ""),
    RandomMessage(emoji: "💪", title: LocalizedStrings.Home.completeRandom4Title, subtitle: ""),
    RandomMessage(emoji: "🌟", title: LocalizedStrings.Home.completeRandom5Title, subtitle: ""),
    RandomMessage(emoji: "👏", title: LocalizedStrings.Home.completeRandom6Title, subtitle: ""),
  ]
}

// MARK: - Preview

#Preview {
  VStack {
    TodayScheduleCompleteView()
  }
  .padding()
  .adaptiveGlassCard(cornerRadius: 20)
  .padding()
  .auroraBackground()
}
