import ActivityKit
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

struct PromiseLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PromiseActivityAttributes.self) { context in
      // MARK: - Lock Screen UI
      LockScreenBannerView(context: context)
        .widgetURL(AppConstants.Deeplink.url(path: "live/\(context.attributes.promiseId)"))

    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Center (제목 + 장소 | 시간)
        DynamicIslandExpandedRegion(.center) {
          HStack(alignment: .top) {
            // 왼쪽: 약속 정보
            VStack(alignment: .leading, spacing: 4) {
              Text("\(context.attributes.emoji) \(context.attributes.title)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

              if let location = context.attributes.location {
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
              Text("약속 시간")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(context.attributes.scheduledTime.amPmText)
                  .font(.system(size: 10, weight: .medium, design: .monospaced))
                  .foregroundStyle(.white.opacity(0.6))

                Text(context.attributes.scheduledTime.timeOnlyText)
                  .font(.system(size: 16, weight: .bold, design: .monospaced))
                  .foregroundStyle(.white)
              }
            }
          }
          .padding(.horizontal, 8)
        }

        // MARK: - Expanded Bottom
        DynamicIslandExpandedRegion(.bottom) {
          SharedRacingTrackView(
            participants: context.state.participants,
            trackingDurationMinutes: context.state.trackingDurationMinutes,
            currentUserId: context.attributes.currentUserId
          )
          .frame(height: 44)
          .padding(.horizontal, 5)
          .padding(.top, 15)
        }

      } compactLeading: {
        // MARK: - Compact Leading (뱃지 스타일)
        Text("\(context.attributes.emoji) \(context.attributes.title)")
          .font(.system(size: 12, weight: .semibold))
          .lineLimit(1)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.pmpurple.n500.opacity(0.3))
          .clipShape(Capsule())

      } compactTrailing: {
        // MARK: - Compact Trailing (PM 시간)
        HStack(spacing: 2) {
          Text(context.attributes.scheduledTime.amPmText)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.6))
          Text(context.attributes.scheduledTime.timeOnlyText)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .monospacedDigit()
        }

      } minimal: {
        // MARK: - Minimal (약속 이모지)
        Text(context.attributes.emoji)
          .font(.system(size: 16))
      }
      .widgetURL(AppConstants.Deeplink.url(path: "live/\(context.attributes.promiseId)"))
    }
  }
}

// MARK: - Date Extension

private extension Date {
  var amPmText: String {
    Calendar.current.component(.hour, from: self) >= 12 ? "PM" : "AM"
  }

  var timeOnlyText: String {
    self.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
  }
}

// MARK: - Preview Attributes

private let previewAttributes = PromiseActivityAttributes(
  promiseId: "preview-123",
  currentUserId: "user-1",
  emoji: "🍜",
  title: "점심 모임",
  location: "강남역 11번 출구",
  latitude: 37.498095,
  longitude: 127.027610,
  scheduledTime: Date().addingTimeInterval(1080),
  trackingDurationMinutes: 30
)

/// 긴 제목 테스트용
private let previewAttributesLong = PromiseActivityAttributes(
  promiseId: "preview-long",
  currentUserId: "user-1",
  emoji: "🎂",
  title: "성원이 생일파티 with 친구들",
  location: "서울특별시 강남구 테헤란로 123번길",
  latitude: 37.501087,
  longitude: 127.026632,
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

#Preview("0. 긴 제목 (Lock Screen)", as: .content, using: previewAttributesLong) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("0. 긴 제목 (DI Expanded)", as: .dynamicIsland(.expanded), using: previewAttributesLong) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("0. 긴 제목 (DI Compact)", as: .dynamicIsland(.compact), using: previewAttributesLong) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

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
