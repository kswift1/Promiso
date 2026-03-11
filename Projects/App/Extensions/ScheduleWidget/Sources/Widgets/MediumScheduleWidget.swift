import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 홈 화면 중간 크기 위젯 (systemMedium) - 오늘 일정 2-3개 표시
struct ScheduleSystemMediumWidget: Widget {
  let kind: String = WidgetKind.systemMedium

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleTimelineProvider()) { entry in
      ScheduleSystemMediumWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName(LocalizedStrings.Widget.configTodaySchedules)
    .description(LocalizedStrings.Widget.configTodaySchedulesDescription)
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

struct ScheduleSystemMediumWidgetView: View {
  let entry: WidgetScheduleEntry

  var body: some View {
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: LocalizedStrings.Widget.emptyNoTodaySchedules,
          hint: LocalizedStrings.Widget.emptyCreateNewHint
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
          message: LocalizedStrings.Widget.emptyNoSchedulesMessage,
          hint: LocalizedStrings.Widget.emptyCreateNewHint
        )
      } else {
        upcomingView(upcomingItems)
      }
    } else {
      todayView(todayItems)
    }
  }

  @ViewBuilder
  private func todayView(_ items: [WidgetScheduleData]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      sectionHeader(title: LocalizedStrings.Widget.today, icon: "sun.max.fill")

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
    .padding(0)
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date, showLabel: true)
        .padding(.bottom, -10)
        .padding(.trailing, -6)
    }
  }

  @ViewBuilder
  private func upcomingView(_ items: [WidgetScheduleData]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      sectionHeader(title: LocalizedStrings.Widget.upcomingSchedule, icon: "calendar")

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
    .padding(0)
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date, showLabel: true)
        .padding(.bottom, -10)
        .padding(.trailing, -6)
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
  private func todayRow(_ item: WidgetScheduleData) -> some View {
    HStack(spacing: 6) {
      // 이모지
      Text(item.emoji)
        .font(.system(size: 18))
        .frame(width: 22)

      // 제목 + 메타 정보
      VStack(alignment: .leading, spacing: 0) {
        Text(item.title)
          .font(.caption.weight(.medium))
          .lineLimit(1)
          .foregroundStyle(.primary)

        if item.isPersonalEvent {
          HStack(spacing: 2) {
            Image(systemName: "person.fill")
              .font(.system(size: 7))
            Text(LocalizedStrings.Widget.personal)
              .lineLimit(1)
          }
          .font(.caption2)
          .foregroundStyle(Color.pmaurora.purple)
        } else {
          HStack(spacing: 3) {
            if let location = item.location {
              HStack(spacing: 2) {
                Image(systemName: "location.fill")
                  .font(.system(size: 7))
                Text(location)
                  .lineLimit(1)
              }
              .foregroundStyle(.secondary)
            }

            if item.location != nil && item.groupName != nil {
              Text("·")
                .foregroundStyle(.secondary)
            }

            if let groupName = item.groupName {
              Text(groupName)
                .lineLimit(1)
                .foregroundStyle(Color.pmindigo.n500)
            }
          }
          .font(.caption2)
        }
      }

      Spacer(minLength: 2)

      // 시간 (강조)
      Text(formatTime(item.startAt))
        .font(.caption.weight(.bold))
        .foregroundStyle(item.isPersonalEvent ? Color.pmaurora.purple : Color.pmindigo.n500)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: item, isToday: true))
  }

  @ViewBuilder
  private func upcomingRow(_ item: WidgetScheduleData) -> some View {
    HStack(spacing: 10) {
      // 이모지
      Text(item.emoji)
        .font(.system(size: 20))
        .frame(width: 24)

      // 제목 + 그룹명
      HStack(spacing: 4) {
        Text(item.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .foregroundStyle(.primary)

        if let groupName = item.groupName {
          Text(groupName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.pmindigo.n500)
        }
      }

      if item.isPersonalEvent {
        Text(LocalizedStrings.Widget.personal)
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
        Text(LocalizedStrings.Widget.tomorrow)
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

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "a h:mm"
    return formatter
  }()

  private static let shortDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "M/d"
    return formatter
  }()

  private func formatTime(_ date: Date) -> String {
    Self.timeFormatter.string(from: date)
  }

  private func formatShortDate(_ date: Date) -> String {
    Self.shortDateFormatter.string(from: date)
  }

  // MARK: - Accessibility

  private func accessibilityLabel(for item: WidgetScheduleData, isToday: Bool) -> String {
    let calendar = Calendar.current
    var components: [String] = []

    if item.isPersonalEvent {
      components.append(LocalizedStrings.Widget.personalEvent)
    }

    // 날짜
    if isToday {
      components.append(LocalizedStrings.Widget.today)
    } else if calendar.isDateInTomorrow(item.startAt) {
      components.append(LocalizedStrings.Widget.tomorrow)
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
#Preview("오늘 일정", as: .systemMedium) {
  ScheduleSystemMediumWidget()
} timeline: {
  WidgetScheduleEntry.previewToday
}

#Preview("다가오는 일정", as: .systemMedium) {
  ScheduleSystemMediumWidget()
} timeline: {
  WidgetScheduleEntry.previewUpcoming
}

#Preview("일정 없음", as: .systemMedium) {
  ScheduleSystemMediumWidget()
} timeline: {
  WidgetScheduleEntry(date: Date(), schedules: [], state: .empty)
}

#Preview("로그인 필요", as: .systemMedium) {
  ScheduleSystemMediumWidget()
} timeline: {
  WidgetScheduleEntry(date: Date(), schedules: [], state: .notLoggedIn)
}

#Preview("긴 텍스트", as: .systemMedium) {
  ScheduleSystemMediumWidget()
} timeline: {
  WidgetScheduleEntry(
    date: Date(),
    schedules: {
      let calendar = Calendar.current
      let now = Date()
      let today1 = calendar.date(bySettingHour: 11, minute: 30, second: 0, of: now) ?? now
      let today2 = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now
      let today3 = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
      return [
        WidgetScheduleData(
          id: "long1",
          title: "대학교 졸업 10주년 기념 동창회 모임",
          emoji: "🎓",
          startAt: today1,
          endAt: nil,
          location: "서울특별시 강남구 역삼동 스타벅스 리저브점",
          groupId: "g1",
          groupName: "서울대학교 컴퓨터공학과 2015학번",
          participantCount: 12
        ),
        WidgetScheduleData(
          id: "long2",
          title: "프로미소 앱 디자인 리뷰 회의",
          emoji: "💻",
          startAt: today2,
          endAt: nil,
          location: "판교 테크노밸리 네이버 그린팩토리 3층",
          groupId: "g2",
          groupName: "프로미소 개발팀 디자인파트",
          participantCount: 6
        ),
        WidgetScheduleData(
          id: "long3",
          title: "크리스마스 파티 겸 연말 송년회",
          emoji: "🎄",
          startAt: today3,
          endAt: nil,
          location: "이태원 해밀턴 호텔 루프탑 바",
          groupId: "g3",
          groupName: "직장동료 번개모임 친목회",
          participantCount: 15
        ),
      ]
    }(),
    state: .loaded
  )
}
#endif
