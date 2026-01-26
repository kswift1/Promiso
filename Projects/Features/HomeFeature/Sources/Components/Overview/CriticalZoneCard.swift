import SwiftUI
import PromisoShared

struct CriticalZoneCard: View {
  let data: CriticalZoneData
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // Header with reason badge
        HStack {
          reasonBadge
          Spacer()
          Image(systemName: "chevron.right")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        // Promise Info
        HStack(spacing: 12) {
          Text(data.promise.displayEmoji)
            .font(.system(size: 40))

          VStack(alignment: .leading, spacing: 6) {
            Text(data.promise.title)
              .font(.title3)
              .fontWeight(.bold)
              .lineLimit(2)

            if let location = data.promise.location {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.caption2)
                Text(location.name)
                  .font(.caption)
                  .lineLimit(1)
              }
              .foregroundStyle(.secondary)
            }

            timeInfo
          }
        }
      }
      .padding(20)
      .background(reasonGradient)
      .cornerRadius(20)
      .shadow(color: reasonColor.opacity(0.3), radius: 16, x: 0, y: 8)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var reasonBadge: some View {
    HStack(spacing: 6) {
      Image(systemName: reasonIcon)
        .font(.caption)

      Text(reasonText)
        .font(.caption)
        .fontWeight(.semibold)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(reasonColor)
    .cornerRadius(8)
  }

  @ViewBuilder
  private var timeInfo: some View {
    Text(timeText)
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundStyle(reasonColor)
  }

  // MARK: - Computed Properties

  private var reasonIcon: String {
    switch data.reason {
    case .liveActivity: return "antenna.radiowaves.left.and.right"
    case .inProgress: return "play.circle.fill"
    case .departureSoon: return "clock.fill"
    }
  }

  private var reasonText: String {
    switch data.reason {
    case .liveActivity: return "실시간 공유 중"
    case .inProgress: return "진행 중"
    case .departureSoon: return "출발 임박"
    }
  }

  private var reasonColor: Color {
    switch data.reason {
    case .liveActivity: return .blue
    case .inProgress: return .green
    case .departureSoon: return .orange
    }
  }

  private var reasonGradient: some ShapeStyle {
    LinearGradient(
      colors: [reasonColor.opacity(0.15), reasonColor.opacity(0.05)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  private var timeText: String {
    let now = Date()
    let promise = data.promise

    switch data.reason {
    case .liveActivity:
      return "지금 공유 중"

    case .inProgress:
      let endInterval = promise.endAt.timeIntervalSince(now)
      let minutes = Int(endInterval / 60)
      return "종료까지 \(minutes)분"

    case .departureSoon:
      let startInterval = promise.startAt.timeIntervalSince(now)
      let minutes = Int(startInterval / 60)
      return "\(minutes)분 후 출발"
    }
  }
}

// MARK: - Preview

#Preview("LiveActivity") {
  CriticalZoneCard(
    data: CriticalZoneData(
      reason: .liveActivity,
      promise: PromiseModel.mock(
        title: "저녁 약속",
        emoji: "🍽️",
        startAt: Date().addingTimeInterval(-1800),
        endAt: Date().addingTimeInterval(3600)
      )
    ),
    onTap: {}
  )
  .padding()
  .auroraBackground()
}

#Preview("진행 중") {
  CriticalZoneCard(
    data: CriticalZoneData(
      reason: .inProgress,
      promise: PromiseModel.mock(
        title: "점심 약속",
        emoji: "🍕",
        startAt: Date().addingTimeInterval(-600),
        endAt: Date().addingTimeInterval(5400)
      )
    ),
    onTap: {}
  )
  .padding()
  .auroraBackground()
}

#Preview("출발 임박") {
  CriticalZoneCard(
    data: CriticalZoneData(
      reason: .departureSoon,
      promise: PromiseModel.mock(
        title: "커피 타임",
        emoji: "☕",
        startAt: Date().addingTimeInterval(1200)
      )
    ),
    onTap: {}
  )
  .padding()
  .auroraBackground()
}
