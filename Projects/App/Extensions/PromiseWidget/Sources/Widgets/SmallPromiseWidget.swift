import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 홈 화면 작은 크기 위젯 (systemSmall) - 다음 약속 1개 표시
struct PromiseSystemSmallWidget: Widget {
  let kind: String = WidgetKind.systemSmall

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      PromiseSystemSmallWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName(LocalizedStrings.Widget.configNextPromise)
    .description(LocalizedStrings.Widget.configNextPromiseDescription)
    .supportedFamilies([.systemSmall])
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

struct PromiseSystemSmallWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: LocalizedStrings.Widget.emptyNoPromisesMessage,
          hint: LocalizedStrings.Widget.emptyCreateNewHint
        )
      case .error:
        ErrorWidgetView()
      case .loaded:
        if let item = entry.nextItem {
          scheduleItemView(item)
            .widgetURL(item.deeplinkURL)
        } else {
          EmptyWidgetView(
            icon: "calendar.badge.clock",
            message: LocalizedStrings.Widget.emptyNoPromisesMessage,
            hint: LocalizedStrings.Widget.emptyCreateNewHint
          )
        }
      }
    }
  }

  @ViewBuilder
  private func scheduleItemView(_ item: WidgetPromiseData) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더: 이모지 + 배지
      HStack(alignment: .top) {
        Text(item.emoji)
          .font(.system(size: 36))

        Spacer()

        dDayBadge(item.startAt)
      }

      Spacer(minLength: 2)

      // 제목
      Text(item.title)
        .font(.subheadline.weight(.semibold))
        .lineLimit(2)
        .foregroundStyle(.primary)

      Spacer().frame(height: 1)

      // 시간 (강조)
      Text(formatTime(item.startAt))
        .font(.subheadline.weight(.bold))
        .foregroundStyle(item.isPersonalEvent ? personalColor : accentColor)

      // 장소
      if let location = item.location {
        HStack(spacing: 2) {
          Image(systemName: "location.fill")
            .font(.system(size: 8))
          Text(location)
            .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 1)
      }

      Spacer(minLength: 0)
    }
    .padding(0)
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date, showLabel: false)
        .padding(.bottom, -10)
        .padding(.trailing, -6)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: item))
  }

  // MARK: - Personal Badge

  private var personalBadge: some View {
    Text(LocalizedStrings.Widget.personal)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(personalColor, in: Capsule())
  }

  // MARK: - Accessibility

  private func accessibilityLabel(for item: WidgetPromiseData) -> String {
    let calendar = Calendar.current
    var components: [String] = []

    if item.isPersonalEvent {
      components.append(LocalizedStrings.Widget.personalEvent)
    }

    // D-Day
    if calendar.isDateInToday(item.startAt) {
      components.append(LocalizedStrings.Widget.today)
    } else if calendar.isDateInTomorrow(item.startAt) {
      components.append(LocalizedStrings.Widget.tomorrow)
    } else {
      let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: item.startAt)
      ).day ?? 0
      components.append(String(format: LocalizedStrings.Widget.daysLater, days))
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

  // MARK: - D-Day Badge

  @ViewBuilder
  private func dDayBadge(_ date: Date) -> some View {
    let calendar = Calendar.current

    Group {
      if calendar.isDateInToday(date) {
        Text(LocalizedStrings.Widget.today)
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(accentColor, in: Capsule())
      } else if calendar.isDateInTomorrow(date) {
        Text(LocalizedStrings.Widget.tomorrow)
          .font(.caption.weight(.medium))
          .foregroundStyle(accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(accentColor.opacity(0.15), in: Capsule())
      } else {
        let days = calendar.dateComponents(
          [.day],
          from: calendar.startOfDay(for: Date()),
          to: calendar.startOfDay(for: date)
        ).day ?? 0
        Text("D-\(days)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.15), in: Capsule())
      }
    }
  }

  // MARK: - Helpers

  private var accentColor: Color {
    Color.pmindigo.n500
  }

  private var personalColor: Color {
    Color.pmaurora.purple
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.dateFormat = "a h:mm"
    return formatter
  }()

  private func formatTime(_ date: Date) -> String {
    Self.timeFormatter.string(from: date)
  }
}


#if DEBUG
#Preview("다음 약속", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("약속 없음", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("로그인 필요", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .notLoggedIn)
}

#Preview("오늘 약속", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        id: "today1",
        title: "점심 모임",
        emoji: "🍽️",
        startAt: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date()) ?? Date(),
        endAt: nil,
        location: "강남역 맛집",
        groupId: "g1",
        groupName: "직장 동료",
        participantCount: 4
      )
    ],
    state: .loaded
  )
}

#Preview("내일 약속", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        id: "tomorrow1",
        title: "카페 미팅",
        emoji: "☕",
        startAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date(),
        endAt: nil,
        location: "합정 카페",
        groupId: "g2",
        groupName: "프로젝트팀",
        participantCount: 3
      )
    ],
    state: .loaded
  )
}

#Preview("D-5 약속", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        id: "d5",
        title: "생일 파티",
        emoji: "🎂",
        startAt: Calendar.current.date(byAdding: .day, value: 5, to: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()) ?? Date(),
        endAt: nil,
        location: "이태원 레스토랑",
        groupId: "g3",
        groupName: "친구들",
        participantCount: 8
      )
    ],
    state: .loaded
  )
}

#Preview("오늘 개인 일정", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        type: .personal,
        id: "pe1",
        title: "아침 운동",
        emoji: "🏃",
        startAt: Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date(),
        endAt: nil,
        location: nil,
        groupId: "",
        groupName: nil,
        participantCount: 0
      )
    ],
    state: .loaded
  )
}

#Preview("내일 개인 일정", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        type: .personal,
        id: "pe2",
        title: "병원 예약",
        emoji: "🏥",
        startAt: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.date(bySettingHour: 10, minute: 30, second: 0, of: Date()) ?? Date()) ?? Date(),
        endAt: nil,
        location: "서울대병원",
        groupId: "",
        groupName: nil,
        participantCount: 0
      )
    ],
    state: .loaded
  )
}

#Preview("긴 제목 (그룹)", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        id: "long1",
        title: "대학교 졸업 10주년 기념 동창회 모임",
        emoji: "🎓",
        startAt: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date(),
        endAt: nil,
        location: "서울특별시 강남구 역삼동 스타벅스 리저브점",
        groupId: "g1",
        groupName: "서울대 컴공 15학번",
        participantCount: 12
      )
    ],
    state: .loaded
  )
}

#Preview("긴 제목 (개인)", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        type: .personal,
        id: "pe-long1",
        title: "아침 요가 수업 & 명상 프로그램",
        emoji: "🧘",
        startAt: Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date(),
        endAt: nil,
        location: "홍대입구역 3번출구 요가스튜디오",
        groupId: "",
        groupName: nil,
        participantCount: 0
      )
    ],
    state: .loaded
  )
}

#Preview("장소 없음", as: .systemSmall) {
  PromiseSystemSmallWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: [
      WidgetPromiseData(
        id: "noloc",
        title: "온라인 회의",
        emoji: "💻",
        startAt: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date(),
        endAt: nil,
        location: nil,
        groupId: "g4",
        groupName: "개발팀",
        participantCount: 5
      )
    ],
    state: .loaded
  )
}
#endif
