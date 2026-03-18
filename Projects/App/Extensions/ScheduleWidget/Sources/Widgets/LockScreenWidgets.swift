import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Circular Widget (원형 잠금화면 위젯)

/// 잠금 화면 원형 위젯 (accessoryCircular) - D-Day 표시
struct ScheduleAccessoryCircularWidget: Widget {
  let kind: String = WidgetKind.accessoryCircular

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
      ScheduleAccessoryCircularWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName(LocalizedStrings.Widget.configNextSchedule)
    .description(LocalizedStrings.Widget.configDaysRemaining)
    .supportedFamilies([.accessoryCircular])
  }
}

struct ScheduleAccessoryCircularWidgetView: View {
  let entry: WidgetScheduleEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn, .empty, .error:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "calendar")
          .font(.title2)
      }
      .accessibilityLabel(LocalizedStrings.Widget.noSchedules)
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
        .accessibilityLabel(LocalizedStrings.Widget.noSchedules)
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

  private func circularAccessibilityLabel(for item: WidgetScheduleData) -> String {
    let prefix = item.isPersonalEvent ? "\(LocalizedStrings.Widget.personalEvent), " : ""
    return "\(prefix)\(dDayText(item.startAt)), \(item.title)"
  }
}

// MARK: - Rectangular Widget (직사각형 잠금화면 위젯)

/// 잠금 화면 직사각형 위젯 (accessoryRectangular) - 다음 일정 정보
struct ScheduleAccessoryRectangularWidget: Widget {
  let kind: String = WidgetKind.accessoryRectangular

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
      ScheduleAccessoryRectangularWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName(LocalizedStrings.Widget.configNextSchedule)
    .description(LocalizedStrings.Widget.configScheduleInfo)
    .supportedFamilies([.accessoryRectangular])
  }
}

struct ScheduleAccessoryRectangularWidgetView: View {
  let entry: WidgetScheduleEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      emptyView(message: LocalizedStrings.Widget.loginRequired)
    case .empty:
      emptyView(message: LocalizedStrings.Widget.noScheduledSchedules)
    case .error:
      emptyView(message: LocalizedStrings.Widget.dataLoadFailed)
    case .loaded:
      if let item = entry.nextItem {
        scheduleItemView(item)
      } else {
        emptyView(message: LocalizedStrings.Widget.noScheduledSchedules)
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
  private func scheduleItemView(_ item: WidgetScheduleData) -> some View {
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
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func rectangularAccessibilityLabel(for item: WidgetScheduleData) -> String {
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
#Preview("Circular - 일정 있음", as: .accessoryCircular) {
  ScheduleAccessoryCircularWidget()
} timeline: {
  WidgetScheduleEntry.previewToday
}

#Preview("Circular - 일정 없음", as: .accessoryCircular) {
  ScheduleAccessoryCircularWidget()
} timeline: {
  WidgetScheduleEntry(date: Date(), schedules: [], state: .empty)
}

#Preview("Rectangular - 일정 있음", as: .accessoryRectangular) {
  ScheduleAccessoryRectangularWidget()
} timeline: {
  WidgetScheduleEntry.previewToday
}

#Preview("Rectangular - 일정 없음", as: .accessoryRectangular) {
  ScheduleAccessoryRectangularWidget()
} timeline: {
  WidgetScheduleEntry(date: Date(), schedules: [], state: .empty)
}
#endif
