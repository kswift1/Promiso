import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

struct PromiseLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PromiseActivityAttributes.self) { context in
      // MARK: - Lock Screen UI
      LockScreenBannerView(context: context)

    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Leading
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.attributes.title)
              .font(.subheadline.weight(.bold))
              .foregroundStyle(.white)
              .lineLimit(1)

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
          .padding(.leading, 5)
        }

        // MARK: - Expanded Trailing
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text("약속")
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
          .padding(.trailing, 5)
        }

        // MARK: - Expanded Bottom
        DynamicIslandExpandedRegion(.bottom) {
          RacingTrackView(
            participants: context.state.participants,
            trackingDurationMinutes: context.state.trackingDurationMinutes,
            currentUserId: context.attributes.currentUserId
          )
          .frame(height: 44)
          .padding(.horizontal, 5)
          .padding(.top, 12)
        }

      } compactLeading: {
        // MARK: - Compact Leading
        Text(context.attributes.title.prefix(2))
          .font(.system(size: 14, weight: .bold))

      } compactTrailing: {
        // MARK: - Compact Trailing
        Text(timerInterval: Date.now...context.attributes.scheduledTime, countsDown: true)
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .monospacedDigit()
          .foregroundStyle(context.attributes.scheduledTime.timeIntervalSinceNow < 600 ? .orange : .white)

      } minimal: {
        // MARK: - Minimal
        Text(context.attributes.title.prefix(1))
          .font(.system(size: 12, weight: .bold))
      }
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
