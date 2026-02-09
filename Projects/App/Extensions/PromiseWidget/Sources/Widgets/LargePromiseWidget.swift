import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 큰 크기 위젯 (4x4) - 오늘 + 다가오는 약속 표시
struct LargePromiseWidget: Widget {
  let kind: String = "LargePromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      LargePromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName("약속 일정")
    .description("오늘과 다가오는 약속을 한눈에 확인하세요")
    .supportedFamilies([.systemLarge])
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

struct LargePromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "예정된 약속이 없어요",
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
    let upcomingItems = Array(entry.upcomingItems.prefix(4))

    if todayItems.isEmpty && upcomingItems.isEmpty {
      EmptyWidgetView(
        icon: "calendar.badge.clock",
        message: "예정된 약속이 없어요",
        hint: "새 약속을 만들어보세요"
      )
    } else {
      VStack(alignment: .leading, spacing: 0) {
        if !todayItems.isEmpty {
          todaySection(todayItems)
        }

        if !upcomingItems.isEmpty {
          if !todayItems.isEmpty {
            sectionDivider
          }
          upcomingSection(upcomingItems)
        }

        Spacer(minLength: 0)
      }
      .padding()
      .overlay(alignment: .bottomTrailing) {
        WidgetFooterView(updatedAt: entry.date)
      }
    }
  }

  // MARK: - Today Section

  @ViewBuilder
  private func todaySection(_ items: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(
        title: "오늘",
        icon: "sun.max.fill",
        count: items.count,
        isHighlighted: true
      )

      ForEach(items, id: \.id) { item in
        if let url = item.deeplinkURL {
          Link(destination: url) {
            todayRow(item)
          }
        } else {
          todayRow(item)
        }
      }
    }
  }

  // MARK: - Upcoming Section

  @ViewBuilder
  private func upcomingSection(_ items: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      sectionHeader(
        title: "다가오는 일정",
        icon: "calendar",
        count: items.count,
        isHighlighted: false
      )

      ForEach(items, id: \.id) { item in
        if let url = item.deeplinkURL {
          Link(destination: url) {
            upcomingRow(item)
          }
        } else {
          upcomingRow(item)
        }
      }
    }
  }

  // MARK: - Section Header

  @ViewBuilder
  private func sectionHeader(
    title: String,
    icon: String,
    count: Int,
    isHighlighted: Bool
  ) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(isHighlighted ? Color.pmindigo.n500 : .secondary)

      Text(title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.primary)

      Text("\(count)")
        .font(.caption2.weight(.bold))
        .foregroundStyle(isHighlighted ? .white : .secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
          isHighlighted ? Color.pmindigo.n500 : Color.secondary.opacity(0.2),
          in: Capsule()
        )

      Spacer()
    }
  }

  @ViewBuilder
  private var sectionDivider: some View {
    Rectangle()
      .fill(Color.secondary.opacity(0.15))
      .frame(height: 1)
      .padding(.vertical, 10)
  }

  // MARK: - Row Views

  @ViewBuilder
  private func todayRow(_ item: WidgetPromiseData) -> some View {
    HStack(alignment: .top, spacing: 10) {
      // 이모지
      Text(item.emoji)
        .font(.system(size: 24))
        .frame(width: 28)

      // 제목 + 메타 정보
      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .foregroundStyle(.primary)

        // 메타 정보
        HStack(spacing: 4) {
          if item.isPersonalEvent {
            HStack(spacing: 2) {
              Image(systemName: "person.fill")
                .font(.system(size: 8))
              Text("개인")
            }
            .foregroundStyle(Color.pmaurora.purple)
          } else {
            if let location = item.location {
              HStack(spacing: 2) {
                Image(systemName: "location.fill")
                  .font(.system(size: 8))
                Text(location)
                  .lineLimit(1)
              }
            }

            if item.location != nil && item.participantCount > 0 {
              Text("·")
            }

            if item.participantCount > 0 {
              HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                  .font(.system(size: 8))
                Text("\(item.participantCount)명")
              }
            }
          }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
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

      // 제목
      Text(item.title)
        .font(.subheadline)
        .lineLimit(1)
        .foregroundStyle(.primary)

      if item.isPersonalEvent {
        Text("개인")
          .font(.caption2.weight(.medium))
          .foregroundStyle(Color.pmaurora.purple)
      }

      Spacer(minLength: 4)

      // 날짜 + 시간
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

    HStack(spacing: 4) {
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

    // 참여자 (약속만)
    if !item.isPersonalEvent && item.participantCount > 0 {
      components.append("\(item.participantCount)명 참여")
    }

    return components.joined(separator: ", ")
  }
}

#if DEBUG
#Preview("전체 약속", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewFull
}

#Preview("오늘만", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("다가오는 약속만", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewUpcoming
}

#Preview("약속 없음", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}
#endif
