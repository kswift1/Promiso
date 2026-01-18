import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

import ResourceKit


// MARK: - Progress Color

/// 진행률 기반 색상 시스템 (앱 브랜드 톤 적용)
enum ProgressColor {
  /// 진행률에 따른 단일 색상
  static func forProgress(_ progress: Double) -> Color {
    switch progress {
    case 0.75...:
      return Color.pmindigo.n500
    case 0.50..<0.75:
      return Color.pmpurple.n500
    case 0.25..<0.50:
      return .orange
    default:
      return .gray
    }
  }

  /// 진행률에 따른 그라데이션 색상
  static func gradientColors(for progress: Double) -> [Color] {
    switch progress {
    case 0.75...:
      return [Color.pmindigo.n500, Color.pmpurple.n500]
    case 0.50..<0.75:
      return [Color.pmpurple.n500, Color.pmpurple.n400]
    case 0.25..<0.50:
      return [.orange, Color.pmpurple.n400]
    default:
      return [.gray, .orange]
    }
  }
}

// MARK: - Lock Screen Banner View

/// 잠금화면 라이브액티비티 배너 뷰
struct LockScreenBannerView: View {
  let context: ActivityViewContext<PromiseActivityAttributes>

  private var state: PromiseActivityAttributes.ContentState { context.state }
  private var attrs: PromiseActivityAttributes { context.attributes }

  private var trackingDuration: Int { state.trackingDurationMinutes }
  private var amPm: String { Calendar.current.component(.hour, from: attrs.scheduledTime) >= 12 ? "PM" : "AM" }
  private var timeText: String { attrs.scheduledTime.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }

  var body: some View {
    VStack(spacing: 14) {
      // MARK: - 헤더
      headerSection

      // MARK: - 레이싱 트랙
      RacingTrackView(
        participants: state.participants,
        trackingDurationMinutes: trackingDuration,
        currentUserId: attrs.currentUserId
      )
      .frame(height: 50)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 16)
    .foregroundStyle(.white)
    .activityBackgroundTint(.black)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack {
      // 왼쪽: 약속 정보
      VStack(alignment: .leading, spacing: 6) {
        Text(attrs.title)
          .font(.subheadline.weight(.bold))
          .lineLimit(1)

        if let location = attrs.location {
          HStack(spacing: 4) {
            Text("📍")
              .font(.caption2)
            Text(location)
              .font(.caption)
          }
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
        }
      }

      Spacer()

      // 오른쪽: 약속 시간
      VStack(alignment: .trailing, spacing: 2) {
        Text("약속")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.6))

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(amPm)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))

          Text(timeText)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
        }
      }
    }
  }
}

// MARK: - Preview Attributes

private let previewAttributes = PromiseActivityAttributes(
  promiseId: "preview-123",
  currentUserId: "user-1",
  title: "🍜 점심 모임",
  location: "강남역 11번 출구",
  scheduledTime: Date().addingTimeInterval(1080),
  trackingDurationMinutes: 30
)

// MARK: - Preview States

/// 1. 초기 상태 - 모두 대기
private let stateInitial = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

/// 2. 진행 중 - 일부 출발
private let stateInProgress = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 10),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 15),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 30),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

/// 3. 긴급 상태 - 거의 도착
private let stateUrgent = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 5),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 15),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 10)
  ]
)

/// 4. 거의 완료 - 대부분 도착
private let stateAlmostDone = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 5),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 0)
  ]
)

/// 5. 완료 - 모두 도착
private let stateCompleted = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 0)
  ]
)

/// 6. 다양한 진행률
private let stateMixed = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 10),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 20),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

// MARK: - Previews

#Preview("1. 초기 상태 (30분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInitial
}

#Preview("2. 진행 중 (18분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("3. 긴급 (8분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateUrgent
}

#Preview("4. 거의 완료 (3분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateAlmostDone
}

#Preview("5. 완료", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateCompleted
}

#Preview("6. 다양한 진행률", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateMixed
}

// MARK: - Dynamic Island Previews

#Preview("DI - Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Compact (Urgent)", as: .dynamicIsland(.compact), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateUrgent
}

#Preview("DI - Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}
