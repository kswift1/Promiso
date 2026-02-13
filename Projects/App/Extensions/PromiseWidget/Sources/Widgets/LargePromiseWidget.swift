import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 홈 화면 큰 크기 위젯 (systemLarge) - 오늘 + 다가오는 약속 표시
struct PromiseSystemLargeWidget: Widget {
  let kind: String = WidgetKind.systemLarge

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      PromiseSystemLargeWidgetView(entry: entry)
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

struct PromiseSystemLargeWidgetView: View {
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
    let todayItems = Array(entry.todayItems.prefix(5))
    let maxUpcoming = todayItems.isEmpty ? 9 : max(8 - todayItems.count, 3)
    let upcomingItems = Array(entry.upcomingItems.prefix(maxUpcoming))

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
      .padding(0)
      .overlay(alignment: .bottomTrailing) {
        WidgetFooterView(updatedAt: entry.date, showLabel: true)
          .padding(.bottom, -10)
          .padding(.trailing, -6)
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
    VStack(alignment: .leading, spacing: 6) {
      sectionHeader(
        title: "다가오는 일정",
        icon: "calendar",
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
    isHighlighted: Bool
  ) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(isHighlighted ? Color.pmindigo.n500 : .secondary)

      Text(title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.primary)

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
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry.previewFull
}

#Preview("오늘만", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("다가오는 약속만", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry.previewUpcoming
}

#Preview("약속 없음", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("오늘 7개", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      let emojis = ["🍽️", "💻", "☕", "🧘", "📞", "🎮", "🍕"]
      let titles = ["점심 모임", "디자인 리뷰", "커피챗", "요가 수업", "전화 미팅", "게임 모임", "저녁 식사"]
      let locations = ["강남역", "판교", "합정 카페", "홍대", nil, nil, "이태원"]
      let groups = ["직장 동료", "개발팀", "프로젝트팀", nil, "마케팅팀", "친구들", "동기모임"]
      return (0..<7).map { i in
        WidgetPromiseData(
          type: i == 3 ? .personal : .promise,
          id: "t\(i)", title: titles[i], emoji: emojis[i],
          startAt: cal.date(bySettingHour: 9 + i * 2, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: locations[i],
          groupId: groups[i] != nil ? "g\(i)" : "", groupName: groups[i],
          participantCount: i == 3 ? 0 : i + 3
        )
      }
    }(),
    state: .loaded
  )
}

#Preview("오늘 6개", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      let emojis = ["🍽️", "💻", "☕", "🧘", "📞", "🎮"]
      let titles = ["점심 모임", "디자인 리뷰", "커피챗", "요가 수업", "전화 미팅", "게임 모임"]
      let locations = ["강남역", "판교", "합정 카페", "홍대", nil, nil]
      let groups = ["직장 동료", "개발팀", "프로젝트팀", nil, "마케팅팀", "친구들"]
      return (0..<6).map { i in
        WidgetPromiseData(
          type: i == 3 ? .personal : .promise,
          id: "t\(i)", title: titles[i], emoji: emojis[i],
          startAt: cal.date(bySettingHour: 9 + i * 2, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: locations[i],
          groupId: groups[i] != nil ? "g\(i)" : "", groupName: groups[i],
          participantCount: i == 3 ? 0 : i + 3
        )
      }
    }(),
    state: .loaded
  )
}

#Preview("다가오는 9개", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      let emojis = ["☕", "🎂", "🎬", "🏃", "📚", "🎵", "🍕", "🎯", "🏖️"]
      let titles = ["카페 미팅", "생일 파티", "영화 관람", "러닝 모임", "독서 모임", "공연 관람", "피자 파티", "볼링 대회", "여행 계획"]
      let groups = ["프로젝트팀", "친구들", "동호회", nil, "북클럽", "문화팀", "직장 동료", "친구들", "가족"]
      let locations = ["합정", "이태원", "CGV", nil, "교보문고", "예술의전당", "이태원", "코엑스", nil]
      return (0..<9).map { i in
        let date = cal.date(byAdding: .day, value: i + 1, to:
          cal.date(bySettingHour: 12 + (i % 3) * 3, minute: 0, second: 0, of: now) ?? now
        ) ?? now
        return WidgetPromiseData(
          type: i == 3 ? .personal : .promise,
          id: "u\(i)", title: titles[i], emoji: emojis[i],
          startAt: date, endAt: nil, location: locations[i],
          groupId: groups[i] != nil ? "g\(i)" : "", groupName: groups[i],
          participantCount: i == 3 ? 0 : i + 2
        )
      }
    }(),
    state: .loaded
  )
}

#Preview("오늘 1 + 다가오는 7", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      var items: [WidgetPromiseData] = []
      // 오늘 1개
      items.append(WidgetPromiseData(
        id: "t0", title: "점심 모임", emoji: "🍽️",
        startAt: cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now,
        endAt: nil, location: "강남역", groupId: "g0", groupName: "직장 동료", participantCount: 4
      ))
      // 다가오는 7개
      let emojis = ["☕", "🎂", "🎬", "🏃", "📚", "🎵", "🍕"]
      let titles = ["카페 미팅", "생일 파티", "영화 관람", "러닝", "독서 모임", "공연", "피자 파티"]
      for i in 0..<7 {
        let date = cal.date(byAdding: .day, value: i + 1, to:
          cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now) ?? now
        items.append(WidgetPromiseData(
          id: "u\(i)", title: titles[i], emoji: emojis[i],
          startAt: date, endAt: nil, location: nil,
          groupId: "g\(i+1)", groupName: nil, participantCount: i + 2
        ))
      }
      return items
    }(),
    state: .loaded
  )
}

#Preview("오늘 3 + 다가오는 5", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      var items: [WidgetPromiseData] = []
      // 오늘 3개
      let tEmojis = ["🍽️", "💻", "🧘"]
      let tTitles = ["점심 모임", "디자인 리뷰", "저녁 요가"]
      for i in 0..<3 {
        items.append(WidgetPromiseData(
          type: i == 2 ? .personal : .promise,
          id: "t\(i)", title: tTitles[i], emoji: tEmojis[i],
          startAt: cal.date(bySettingHour: 12 + i * 3, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: i == 0 ? "강남역" : nil,
          groupId: i < 2 ? "g\(i)" : "", groupName: i < 2 ? "팀\(i+1)" : nil,
          participantCount: i == 2 ? 0 : i + 3
        ))
      }
      // 다가오는 5개
      let uEmojis = ["☕", "🎂", "🎬", "📚", "🍕"]
      let uTitles = ["카페 미팅", "생일 파티", "영화 관람", "독서 모임", "피자 파티"]
      for i in 0..<5 {
        let date = cal.date(byAdding: .day, value: i + 1, to:
          cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now) ?? now
        items.append(WidgetPromiseData(
          id: "u\(i)", title: uTitles[i], emoji: uEmojis[i],
          startAt: date, endAt: nil, location: nil,
          groupId: "g\(i+10)", groupName: nil, participantCount: i + 2
        ))
      }
      return items
    }(),
    state: .loaded
  )
}

#Preview("오늘 5 + 다가오는 3", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      var items: [WidgetPromiseData] = []
      // 오늘 5개
      let tEmojis = ["🍽️", "💻", "☕", "🧘", "🎮"]
      let tTitles = ["점심 모임", "디자인 리뷰", "커피챗", "요가", "게임 모임"]
      for i in 0..<5 {
        items.append(WidgetPromiseData(
          type: i == 3 ? .personal : .promise,
          id: "t\(i)", title: tTitles[i], emoji: tEmojis[i],
          startAt: cal.date(bySettingHour: 9 + i * 2, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: i == 0 ? "강남역" : nil,
          groupId: i != 3 ? "g\(i)" : "", groupName: i != 3 ? "팀\(i+1)" : nil,
          participantCount: i == 3 ? 0 : i + 3
        ))
      }
      // 다가오는 3개
      let uEmojis = ["🎂", "🎬", "🍕"]
      let uTitles = ["생일 파티", "영화 관람", "피자 파티"]
      for i in 0..<3 {
        let date = cal.date(byAdding: .day, value: i + 1, to:
          cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now) ?? now
        items.append(WidgetPromiseData(
          id: "u\(i)", title: uTitles[i], emoji: uEmojis[i],
          startAt: date, endAt: nil, location: nil,
          groupId: "g\(i+10)", groupName: nil, participantCount: i + 2
        ))
      }
      return items
    }(),
    state: .loaded
  )
}

#Preview("오늘 꽉참 (3개)", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      return [
        WidgetPromiseData(
          id: "t1", title: "점심 모임", emoji: "🍽️",
          startAt: cal.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: "강남역 맛집", groupId: "g1", groupName: "직장 동료", participantCount: 4
        ),
        WidgetPromiseData(
          id: "t2", title: "디자인 리뷰 회의", emoji: "💻",
          startAt: cal.date(bySettingHour: 14, minute: 30, second: 0, of: now) ?? now,
          endAt: nil, location: "판교 오피스", groupId: "g2", groupName: "개발팀", participantCount: 6
        ),
        WidgetPromiseData(
          type: .personal, id: "t3", title: "저녁 요가", emoji: "🧘",
          startAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now,
          endAt: nil, location: "홍대 요가스튜디오", groupId: "", groupName: nil, participantCount: 0
        ),
      ]
    }(),
    state: .loaded
  )
}

#Preview("다가오는 꽉참 (7개)", as: .systemLarge) {
  PromiseSystemLargeWidget()
} timeline: {
  WidgetPromiseEntry(
    date: Date(),
    promises: {
      let cal = Calendar.current
      let now = Date()
      return (1...7).map { day in
        let date = cal.date(byAdding: .day, value: day, to:
          cal.date(bySettingHour: 12 + (day % 3) * 3, minute: 0, second: 0, of: now) ?? now
        ) ?? now
        let emojis = ["☕", "🎂", "🎬", "🏃", "📚", "🎵", "🍕"]
        let titles = ["카페 미팅", "생일 파티", "영화 관람", "러닝 모임", "독서 모임", "공연 관람", "피자 파티"]
        let groups = ["프로젝트팀", "친구들", "동호회", nil, "북클럽", "문화팀", "직장 동료"]
        let locations = ["합정 카페", "이태원", "CGV 용산", nil, "교보문고", "예술의전당", "이태원 피자집"]
        return WidgetPromiseData(
          type: day == 4 ? .personal : .promise,
          id: "u\(day)", title: titles[day - 1], emoji: emojis[day - 1],
          startAt: date, endAt: nil, location: locations[day - 1],
          groupId: groups[day - 1] != nil ? "g\(day)" : "", groupName: groups[day - 1],
          participantCount: day == 4 ? 0 : day + 2
        )
      }
    }(),
    state: .loaded
  )
}
#endif
