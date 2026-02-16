import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Circular Widget (원형 잠금화면 위젯)

/// 잠금 화면 원형 위젯 (accessoryCircular) - D-Day 표시
struct PromiseAccessoryCircularWidget: Widget {
  let kind: String = WidgetKind.accessoryCircular

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      PromiseAccessoryCircularWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName(LocalizedStrings.Widget.configNextPromise)
    .description(LocalizedStrings.Widget.configDaysRemaining)
    .supportedFamilies([.accessoryCircular])
  }
}

struct PromiseAccessoryCircularWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn, .empty, .error:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "calendar")
          .font(.title2)
      }
      .accessibilityLabel(LocalizedStrings.Widget.noPromises)
    case .loaded:
      if let item = entry.nextItem {
        ZStack {
          AccessoryWidgetBackground()
          VStack(spacing: 0) {
            Text(item.emoji)
              .font(.system(size: 16))
            Text(dDayText(item.startAt))
              .font(.system(size: 12, weight: .bold))
              .minimumScaleFactor(0.8)
          }
        }
        .accessibilityLabel(circularAccessibilityLabel(for: item))
      } else {
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "calendar")
            .font(.title2)
        }
        .accessibilityLabel(LocalizedStrings.Widget.noPromises)
      }
    }
  }

  private func dDayText(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return LocalizedStrings.Widget.today
    } else if calendar.isDateInTomorrow(date) {
      return LocalizedStrings.Widget.tomorrow
    } else {
      let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
      ).day ?? 0
      return "D-\(days)"
    }
  }

  private func circularAccessibilityLabel(for item: WidgetPromiseData) -> String {
    let prefix = item.isPersonalEvent ? "\(LocalizedStrings.Widget.personalEvent), " : ""
    return "\(prefix)\(dDayText(item.startAt)), \(item.title)"
  }
}

// MARK: - Rectangular Widget (직사각형 잠금화면 위젯)

/// 잠금 화면 직사각형 위젯 (accessoryRectangular) - 다음 약속 정보
struct PromiseAccessoryRectangularWidget: Widget {
  let kind: String = WidgetKind.accessoryRectangular

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      PromiseAccessoryRectangularWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName(LocalizedStrings.Widget.configNextPromise)
    .description(LocalizedStrings.Widget.configPromiseInfo)
    .supportedFamilies([.accessoryRectangular])
  }
}

struct PromiseAccessoryRectangularWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      emptyView(message: LocalizedStrings.Widget.loginRequired)
    case .empty:
      emptyView(message: LocalizedStrings.Widget.noScheduledPromises)
    case .error:
      emptyView(message: LocalizedStrings.Widget.dataLoadFailed)
    case .loaded:
      if let item = entry.nextItem {
        scheduleItemView(item)
      } else {
        emptyView(message: LocalizedStrings.Widget.noScheduledPromises)
      }
    }
  }

  @ViewBuilder
  private func emptyView(message: String) -> some View {
    HStack {
      Image(systemName: "calendar")
        .font(.title3)
      Text(message)
        .font(.headline)
    }
    .accessibilityLabel(message)
  }

  @ViewBuilder
  private func scheduleItemView(_ item: WidgetPromiseData) -> some View {
    HStack(alignment: .center, spacing: 8) {
      // 이모지 + D-Day
      VStack(spacing: 2) {
        Text(item.emoji)
          .font(.system(size: 20))
        if item.isPersonalEvent {
          Text(LocalizedStrings.Widget.personal)
            .font(.system(size: 9, weight: .bold))
        } else {
          Text(dDayText(item.startAt))
            .font(.system(size: 10, weight: .bold))
        }
      }
      .frame(width: 36)

      // 제목 + 시간
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.headline)
          .lineLimit(1)

        Text(formatTime(item.startAt))
          .font(.subheadline)
      }

      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(rectangularAccessibilityLabel(for: item))
  }

  private func dDayText(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return LocalizedStrings.Widget.today
    } else if calendar.isDateInTomorrow(date) {
      return LocalizedStrings.Widget.tomorrow
    } else {
      let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
      ).day ?? 0
      return "D-\(days)"
    }
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func rectangularAccessibilityLabel(for item: WidgetPromiseData) -> String {
    var components: [String] = []
    if item.isPersonalEvent {
      components.append(LocalizedStrings.Widget.personalEvent)
    }
    components.append(contentsOf: [dDayText(item.startAt), formatTime(item.startAt), item.title])
    if let location = item.location {
      components.append(location)
    }
    return components.joined(separator: ", ")
  }
}

// MARK: - Previews

#if DEBUG
#Preview("Circular - 약속 있음", as: .accessoryCircular) {
  PromiseAccessoryCircularWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("Circular - 약속 없음", as: .accessoryCircular) {
  PromiseAccessoryCircularWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("Rectangular - 약속 있음", as: .accessoryRectangular) {
  PromiseAccessoryRectangularWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("Rectangular - 약속 없음", as: .accessoryRectangular) {
  PromiseAccessoryRectangularWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}
#endif
