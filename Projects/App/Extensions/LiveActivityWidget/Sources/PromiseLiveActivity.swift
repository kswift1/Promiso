import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

struct PromiseLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PromiseActivityAttributes.self) { context in
      // MARK: - Lock Screen UI
      LockScreenBannerView(context: context)
        .background {
          GeometryReader { geo in
            Color.clear.onAppear { print("높이: \(geo.size.height)") }
          }
        }

    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Leading
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.title)
              .font(.subheadline.weight(.bold))
              .foregroundStyle(.white)
              .lineLimit(1)

            if let location = context.attributes.location {
              HStack(spacing: 2) {
                Text("📍")
                  .font(.caption2)
                Text(location)
                  .font(.caption2)
              }
              .foregroundStyle(.white.opacity(0.6))
            }
          }
        }

        // MARK: - Expanded Trailing
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 0) {
            Text(timerInterval: Date.now...context.attributes.scheduledTime, countsDown: true)
              .font(.title2.weight(.bold))
              .monospacedDigit()
              .foregroundStyle(context.attributes.scheduledTime.timeIntervalSinceNow < 600 ? .orange : .green)

            Text("남은 시간")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.6))
          }
        }

        // MARK: - Expanded Bottom
        DynamicIslandExpandedRegion(.bottom) {
          ExpandedRacingTrackView(context: context)
        }

      } compactLeading: {
        // MARK: - Compact Leading
        Image(systemName: "mappin.circle.fill")
          .foregroundStyle(.purple)

      } compactTrailing: {
        // MARK: - Compact Trailing
        Text(timerInterval: Date.now...context.attributes.scheduledTime, countsDown: true)
          .font(.caption2.weight(.semibold))
          .monospacedDigit()
          .foregroundStyle(context.attributes.scheduledTime.timeIntervalSinceNow < 600 ? .orange : .green)

      } minimal: {
        // MARK: - Minimal
        Image(systemName: "mappin.circle.fill")
          .foregroundStyle(.purple)
      }
    }
  }
}
