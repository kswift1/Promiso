import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 홈 화면 중간 크기 위젯 (systemMedium) - 오늘 약속 2-3개 표시
struct PromiseSystemMediumWidget: Widget {
  let kind: String = WidgetKind.systemMedium

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      PromiseSystemMediumWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName("오늘의 약속")
    .description("오늘 예정된 약속을 확인하세요")
    .supportedFamilies([.systemMedium])
  }

  @ViewBuilder
  private var widgetBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear.glassEffect(.regular)
    } else {
      Color(.systemBackground).opacity(0.9)
    }
  }
}

struct PromiseSystemMediumWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "오늘 예정된 약속이 없어요",
          hint: "새 약속을 만들어보세요"
        )
      case .error:
        ErrorWidgetView()
      case .loaded:
        contentView
      }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    let todayItems = Array(entry.todayItems.prefix(3))

    if todayItems.isEmpty {
      let upcomingItems = Array(entry.upcomingItems.prefix(3))
      if upcomingItems.isEmpty {
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "예정된 약속이 없어요",
          hint: "새 약속을 만들어보세요"
        )
      } else {
        upcomingView(upcomingItems)
      }
    } else {
      todayView(todayItems)
    }
  }

  @ViewBuilder
  private func todayView(_ items: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      sectionHeader(title: "오늘", icon: "sun.max.fill")

      ForEach(items, id: \.id) { item in
        if let url = item.deeplinkURL {
          Link(destination: url) {
            todayRow(item)
          }
        } else {
          todayRow(item)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date)
    }
  }

  @ViewBuilder
  private func upcomingView(_ items: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      sectionHeader(title: "다가오는 일정", icon: "calendar")

      ForEach(items, id: \.id) { item in
        if let url = item.deeplinkURL {
          Link(destination: url) {
            upcomingRow(item)
          }
        } else {
          upcomingRow(item)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date)
    }
  }

  // MARK: - Section Header

  @ViewBuilder
  private func sectionHeader(title: String, icon: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.pmindigo.n500)

      Text(title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.primary)

      Spacer()
    }
    .padding(.bottom, 4)
  }

  // MARK: - Row Views

  @ViewBuilder
  private func todayRow(_ item: WidgetPromiseData) -> some View {
    HStack(spacing: 10) {
      // 이모지
      Text(item.emoji)
        .font(.system(size: 22))
        .frame(width: 26)

      // 제목 + 장소/개인 라벨
      VStack(alignment: .leading, spacing: 1) {
        Text(item.title)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
          .foregroundStyle(.primary)

        if item.isPersonalEvent {
          HStack(spacing: 2) {
            Image(systemName: "person.fill")
              .font(.system(size: 8))
            Text("개인")
              .lineLimit(1)
          }
          .font(.caption2)
          .foregroundStyle(Color.pmaurora.purple)
        } else if let location = item.location {
          HStack(spacing: 2) {
            Image(systemName: "location.fill")
              .font(.system(size: 8))
            Text(location)
              .lineLimit(1)
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 4)

      // 시간 (강조)
      Text(formatTime(item.startAt))
        .font(.subheadline.weight(.bold))
        .foregroundStyle(item.isPersonalEvent ? Color.pmaurora.purple : Color.pmindigo.n500)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: item, isToday: true))
  }

  @ViewBuilder
  private func upcomingRow(_ item: WidgetPromiseData) -> some View {
    HStack(spacing: 10) {
      // 이모지
      Text(item.emoji)
        .font(.system(size: 20))
        .frame(width: 24)

      // 제목 + 그룹명
      HStack(spacing: 4) {
        Text(item.title)
          .font(.subheadline)
          .lineLimit(1)
          .foregroundStyle(.primary)

        if let groupName = item.groupName {
          Text(groupName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.pmindigo.n500)
        }
      }

      if item.isPersonalEvent {
        Text("개인")
          .font(.caption2.weight(.medium))
          .foregroundStyle(Color.pmaurora.purple)
      }

      Spacer(minLength: 4)

      // 날짜 배지
      dateBadge(item.startAt)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: item, isToday: false))
  }

  // MARK: - Date Badge

  @ViewBuilder
  private func dateBadge(_ date: Date) -> some View {
    let calendar = Calendar.current

    HStack(spacing: 3) {
      if calendar.isDateInTomorrow(date) {
        Text("내일")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.pmindigo.n500)
      } else {
        Text(formatShortDate(date))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(formatTime(date))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Date Formatting

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M/d"
    return formatter.string(from: date)
  }

  // MARK: - Accessibility

  private func accessibilityLabel(for item: WidgetPromiseData, isToday: Bool) -> String {
    let calendar = Calendar.current
    var components: [String] = []

    if item.isPersonalEvent {
      components.append("개인 일정")
    }

    // 날짜
    if isToday {
      components.append("오늘")
    } else if calendar.isDateInTomorrow(item.startAt) {
      components.append("내일")
    } else {
      components.append(formatShortDate(item.startAt))
    }

    // 시간
    components.append(formatTime(item.startAt))

    // 제목
    components.append(item.title)

    // 장소
    if let location = item.location {
      components.append(location)
    }

    return components.joined(separator: ", ")
  }
}

#if DEBUG
#Preview("오늘 약속", as: .systemMedium) {
  PromiseSystemMediumWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("다가오는 약속", as: .systemMedium) {
  PromiseSystemMediumWidget()
} timeline: {
  WidgetPromiseEntry.previewUpcoming
}

#Preview("약속 없음", as: .systemMedium) {
  PromiseSystemMediumWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("로그인 필요", as: .systemMedium) {
  PromiseSystemMediumWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .notLoggedIn)
}
#endif
