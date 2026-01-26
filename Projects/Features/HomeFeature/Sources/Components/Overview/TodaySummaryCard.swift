import SwiftUI
import PromisoShared

struct TodaySummaryCard: View {
  let todayCount: Int
  let nextPromise: PromiseModel?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "calendar.circle.fill")
          .font(.title2)
          .foregroundStyle(.blue)

        Text("오늘의 일정")
          .font(.headline)
          .fontWeight(.bold)

        Spacer()

        Text("\(todayCount)개")
          .font(.title3)
          .fontWeight(.bold)
          .foregroundStyle(.blue)
      }

      // Next Promise Info or Empty State
      if let promise = nextPromise {
        Divider()

        HStack(spacing: 8) {
          Text(promise.displayEmoji)
            .font(.title3)

          VStack(alignment: .leading, spacing: 4) {
            Text(promise.title)
              .font(.subheadline)
              .fontWeight(.semibold)
              .lineLimit(1)

            Text(timeUntil(promise.startAt))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } else if todayCount == 0 {
        Divider()

        Text("오늘은 약속이 없어요 😊")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .adaptiveGlassCard(cornerRadius: 16)
  }

  private func timeUntil(_ date: Date) -> String {
    let interval = date.timeIntervalSince(Date())

    if interval < 0 {
      return "진행 중"
    }

    let hours = Int(interval / 3600)
    let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

    if hours > 0 {
      return "\(hours)시간 \(minutes)분 후"
    } else {
      return "\(minutes)분 후"
    }
  }
}

// MARK: - Preview

#Preview("오늘 일정 있음") {
  TodaySummaryCard(
    todayCount: 3,
    nextPromise: PromiseModel.mock(
      title: "점심 약속",
      emoji: "🍕",
      startAt: Date().addingTimeInterval(3600)
    )
  )
  .padding()
  .auroraBackground()
}

#Preview("오늘 일정 없음") {
  TodaySummaryCard(
    todayCount: 0,
    nextPromise: nil
  )
  .padding()
  .auroraBackground()
}
