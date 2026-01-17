import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

struct PromiseLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PromiseActivityAttributes.self) { context in
      // MARK: - Lock Screen UI
      LockScreenView(
        attributes: context.attributes,
        state: context.state
      )
    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Leading
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 4) {
            Text(context.attributes.emoji)
              .font(.title2)
            Text(context.attributes.title)
              .font(.headline)
              .lineLimit(1)
          }
        }

        // MARK: - Expanded Trailing
        DynamicIslandExpandedRegion(.trailing) {
          ArrivalCountBadge(
            arrived: context.state.arrivedCount,
            total: context.attributes.totalParticipants
          )
        }

        // MARK: - Expanded Bottom
        DynamicIslandExpandedRegion(.bottom) {
          MemberStatusRow(members: context.state.memberStatuses)
        }

        // MARK: - Expanded Center (optional)
        DynamicIslandExpandedRegion(.center) {
          if let location = context.attributes.locationName {
            Label(location, systemImage: "mappin")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

      } compactLeading: {
        // MARK: - Compact Leading
        Text(context.attributes.emoji)
          .font(.body)
      } compactTrailing: {
        // MARK: - Compact Trailing
        Text("\(context.state.arrivedCount)/\(context.attributes.totalParticipants)")
          .font(.caption.monospacedDigit().bold())
          .foregroundStyle(
            context.state.arrivedCount == context.attributes.totalParticipants
              ? .green
              : .primary
          )
      } minimal: {
        // MARK: - Minimal (when sharing space with other activities)
        Text(context.attributes.emoji)
          .font(.caption)
      }
    }
  }
}

// MARK: - Preview

#Preview("Live Activity", as: .content, using: PromiseActivityAttributes(
  promiseId: "preview-123",
  title: "점심 약속",
  emoji: "🍽️",
  startAt: Date().addingTimeInterval(1800),
  locationName: "강남역 2번 출구",
  groupId: "group-123",
  totalParticipants: 4
)) {
  PromiseLiveActivity()
} contentStates: {
  PromiseActivityAttributes.ContentState(
    memberStatuses: [
      MemberArrivalStatus(memberId: "1", memberName: "김철수", hasArrived: true, arrivedAt: Date()),
      MemberArrivalStatus(memberId: "2", memberName: "이영희", hasArrived: true, arrivedAt: Date()),
      MemberArrivalStatus(memberId: "3", memberName: "박민수", hasArrived: false),
      MemberArrivalStatus(memberId: "4", memberName: "최지원", hasArrived: false)
    ],
    lastUpdatedAt: Date(),
    isEnded: false
  )
}
