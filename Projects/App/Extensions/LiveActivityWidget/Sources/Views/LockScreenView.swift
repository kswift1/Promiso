import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Time Color

/// 남은 시간에 따른 색상 시스템
enum TimeColor {
  static func forRemainingMinutes(_ minutes: Int) -> Color {
    switch minutes {
    case 30...:
      return .green
    case 10..<30:
      return .yellow
    case 1..<10:
      return .orange
    default:
      return .red
    }
  }

  static func gradientColors(for minutes: Int) -> [Color] {
    switch minutes {
    case 30...:
      return [.green, .mint]
    case 10..<30:
      return [.yellow, .orange]
    case 1..<10:
      return [.orange, .red]
    default:
      return [.red, .pink]
    }
  }
}

// MARK: - Lock Screen Banner View

/// 잠금화면 라이브액티비티 배너 뷰
struct LockScreenBannerView: View {
  let context: ActivityViewContext<PromiseActivityAttributes>

  private var state: PromiseActivityAttributes.ContentState { context.state }
  private var attrs: PromiseActivityAttributes { context.attributes }

  private var remainingMinutes: Int { state.remainingSeconds / 60 }
  private var timeColor: Color { TimeColor.forRemainingMinutes(remainingMinutes) }
  private var amPm: String { Calendar.current.component(.hour, from: attrs.scheduledTime) >= 12 ? "PM" : "AM" }
  private var timeText: String { attrs.scheduledTime.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }

  var body: some View {
    VStack(spacing: 14) {
      // MARK: - 헤더
      headerSection

      // MARK: - 레이싱 트랙
      RacingTrackView(
        participants: state.participants,
        baseProgress: state.baseProgress,
        remainingMinutes: remainingMinutes
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
  scheduledTime: Date().addingTimeInterval(1080)
)

// MARK: - Preview States

/// 1. 초기 상태 - 모두 대기 (30분 남음)
private let stateInitial = PromiseActivityAttributes.ContentState(
  remainingSeconds: 1800,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .pending),
    ParticipantState(id: "user-2", name: "민수", status: .pending),
    ParticipantState(id: "user-3", name: "지현", status: .pending),
    ParticipantState(id: "user-4", name: "서연", status: .pending)
  ]
)

/// 2. 진행 중 - 일부 출발 (18분 남음)
private let stateInProgress = PromiseActivityAttributes.ContentState(
  remainingSeconds: 1080,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .departed),
    ParticipantState(id: "user-2", name: "민수", status: .departed),
    ParticipantState(id: "user-3", name: "지현", status: .late),
    ParticipantState(id: "user-4", name: "서연", status: .pending)
  ]
)

/// 3. 긴급 상태 - 10분 미만 (8분 남음)
private let stateUrgent = PromiseActivityAttributes.ContentState(
  remainingSeconds: 480,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .departed),
    ParticipantState(id: "user-2", name: "민수", status: .arrived),
    ParticipantState(id: "user-3", name: "지현", status: .late),
    ParticipantState(id: "user-4", name: "서연", status: .departed)
  ]
)

/// 4. 거의 완료 - 대부분 도착 (3분 남음)
private let stateAlmostDone = PromiseActivityAttributes.ContentState(
  remainingSeconds: 180,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .arrived),
    ParticipantState(id: "user-2", name: "민수", status: .arrived),
    ParticipantState(id: "user-3", name: "지현", status: .departed),
    ParticipantState(id: "user-4", name: "서연", status: .arrived)
  ]
)

/// 5. 완료 - 모두 도착
private let stateCompleted = PromiseActivityAttributes.ContentState(
  remainingSeconds: 0,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .arrived),
    ParticipantState(id: "user-2", name: "민수", status: .arrived),
    ParticipantState(id: "user-3", name: "지현", status: .arrived),
    ParticipantState(id: "user-4", name: "서연", status: .arrived)
  ]
)

/// 6. 지각자 많음
private let stateManyLate = PromiseActivityAttributes.ContentState(
  remainingSeconds: 300,
  participants: [
    ParticipantState(id: "user-1", name: "나", status: .arrived),
    ParticipantState(id: "user-2", name: "민수", status: .late),
    ParticipantState(id: "user-3", name: "지현", status: .late),
    ParticipantState(id: "user-4", name: "서연", status: .pending)
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

#Preview("6. 지각자 많음", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateManyLate
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
