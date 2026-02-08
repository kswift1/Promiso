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
    .dawn: RandomMessage(emoji: "🌅", title: "새벽 일정을 마쳤어요", subtitle: ""),
    .morning: RandomMessage(emoji: "☀️", title: "오전 일정 완료!", subtitle: ""),
    .lunch: RandomMessage(emoji: "🍽️", title: "점심 일정을 마쳤어요", subtitle: ""),
    .afternoon: RandomMessage(emoji: "⛅", title: "오후 일정을 마쳤어요", subtitle: ""),
    .evening: RandomMessage(emoji: "🌆", title: "저녁 일정 완료!", subtitle: ""),
    .night: RandomMessage(emoji: "🌙", title: "오늘 일정을 모두 마쳤어요", subtitle: ""),
  ]

  static let randomMessages: [RandomMessage] = [
    RandomMessage(emoji: "🎉", title: "오늘 일정을 모두 마쳤어요", subtitle: ""),
    RandomMessage(emoji: "✅", title: "모든 약속을 잘 지켰어요", subtitle: ""),
    RandomMessage(emoji: "🏆", title: "오늘도 완벽한 하루!", subtitle: ""),
    RandomMessage(emoji: "💪", title: "일정 완료!", subtitle: ""),
    RandomMessage(emoji: "🌟", title: "모든 일정을 마쳤어요", subtitle: ""),
    RandomMessage(emoji: "👏", title: "약속 완료!", subtitle: ""),
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
