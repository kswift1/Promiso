import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Day Detail View

/// 캘린더 오버레이에서 날짜 탭 시 표시되는 일간 상세 뷰
struct DayDetailView: View {
  let selectedDate: Date
  let scheduleItems: [HomeModels.ScheduleItem]
  let weekDays: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void
  let onBackToMonth: () -> Void
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void

  var body: some View {
    VStack(spacing: 0) {
      // Header: 요일 + 날짜
      dayHeader
        .padding(.horizontal, 20)
        .padding(.bottom, 12)

      // 일정 리스트 (스크롤)
      ScrollView {
        VStack(spacing: 12) {
          let grouped = groupedByTimePeriod
          ForEach(OverlayCalendarModels.TimePeriod.allCases, id: \.self) { period in
            if let items = grouped[period], !items.isEmpty {
              timePeriodSection(period: period, items: items)
            }
          }

          if scheduleItems.isEmpty {
            emptyStateView
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
      }

      Divider()
        .foregroundStyle(Color(.separator).opacity(0.3))

      // 하단 주간 스트립
      WeekStripView(
        weekDays: weekDays,
        onDateSelected: onDateSelected
      )
      .padding(.horizontal, 16)
    }
  }

  // MARK: - Day Header

  private var dayHeader: some View {
    HStack(alignment: .top) {
      Button(action: onBackToMonth) {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }

      VStack(alignment: .leading, spacing: 0) {
        Text(weekdayString)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)

        Text(dateString)
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
  }

  // MARK: - Time Period Section

  private func timePeriodSection(
    period: OverlayCalendarModels.TimePeriod,
    items: [HomeModels.ScheduleItem]
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      // 시간대 타이틀
      Text(period.displayTitle)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(periodTitleColor(period))
        .padding(.leading, 4)

      // 일정 카드들
      VStack(spacing: 8) {
        ForEach(items) { item in
          Button {
            onScheduleItemTapped(item)
          } label: {
            scheduleItemRow(item)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(14)
      .background(periodBackgroundColor(period))
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }

  // MARK: - Schedule Item Row

  private func scheduleItemRow(_ item: HomeModels.ScheduleItem) -> some View {
    HStack(spacing: 12) {
      Text(item.displayEmoji)
        .font(.system(size: 24))
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.title)
          .font(.system(size: 15, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        HStack(spacing: 6) {
          Text(timeString(for: item.startAt))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

          if let groupName = groupName(for: item) {
            Text("·")
              .font(.system(size: 12))
              .foregroundStyle(.tertiary)

            Text(groupName)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
  }

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "calendar.badge.clock")
        .font(.system(size: 36))
        .foregroundStyle(.tertiary)

      Text(LocalizedStrings.Calendar.noSchedules)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  // MARK: - Helpers

  private var groupedByTimePeriod: [OverlayCalendarModels.TimePeriod: [HomeModels.ScheduleItem]] {
    Dictionary(grouping: scheduleItems) { item in
      let hour = Calendar.current.component(.hour, from: item.startAt)
      return OverlayCalendarModels.TimePeriod.from(hour: hour)
    }
  }

  private var weekdayString: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "EEEE"
    return formatter.string(from: selectedDate)
  }

  private var dateString: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: selectedDate)
  }

  private func timeString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func groupName(for item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.group?.name
    case .personalEvent:
      return nil
    }
  }

  private func periodTitleColor(_ period: OverlayCalendarModels.TimePeriod) -> Color {
    switch period {
    case .morning: return Color(.systemGreen)
    case .afternoon: return Color(.systemBlue)
    case .night: return Color(.systemIndigo)
    }
  }

  private func periodBackgroundColor(_ period: OverlayCalendarModels.TimePeriod) -> Color {
    switch period {
    case .morning: return Color(.systemGreen).opacity(0.08)
    case .afternoon: return Color(.systemBlue).opacity(0.08)
    case .night: return Color(.systemIndigo).opacity(0.08)
    }
  }
}

// MARK: - Preview

#Preview("일정 있음") {
  DayDetailView(
    selectedDate: Date(),
    scheduleItems: [
      .promise(PromiseModel(
        id: "1",
        title: "팀 미팅",
        emoji: "🤝",
        hostId: "host",
        groupId: "g1",
        group: GroupModel(id: "g1", name: "개발팀", maxMembers: 10, inviteCode: "", createdBy: ""),
        minimumParticipants: 2,
        votes: .init(),
        startAt: Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date(),
        createdAt: Date(),
        updatedAt: Date()
      )),
      .promise(PromiseModel(
        id: "2",
        title: "점심 약속",
        emoji: "🍽️",
        hostId: "host",
        groupId: "g2",
        group: GroupModel(id: "g2", name: "친구들", maxMembers: 10, inviteCode: "", createdBy: ""),
        minimumParticipants: 2,
        votes: .init(),
        startAt: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date()) ?? Date(),
        createdAt: Date(),
        updatedAt: Date()
      )),
      .promise(PromiseModel(
        id: "3",
        title: "저녁 회식",
        emoji: "🍻",
        hostId: "host",
        groupId: "g1",
        group: GroupModel(id: "g1", name: "개발팀", maxMembers: 10, inviteCode: "", createdBy: ""),
        minimumParticipants: 3,
        votes: .init(),
        startAt: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date(),
        createdAt: Date(),
        updatedAt: Date()
      )),
    ],
    weekDays: (0..<7).map { i in
      OverlayCalendarModels.DayItem(
        date: Calendar.current.date(byAdding: .day, value: i - 3, to: Date()) ?? Date(),
        dayNumber: 10 + i,
        isSelected: i == 3,
        isToday: i == 3,
        scheduleCount: i % 2 == 0 ? 2 : 0
      )
    },
    onDateSelected: { _ in },
    onBackToMonth: {},
    onScheduleItemTapped: { _ in }
  )
}

#Preview("일정 없음") {
  DayDetailView(
    selectedDate: Date(),
    scheduleItems: [],
    weekDays: (0..<7).map { i in
      OverlayCalendarModels.DayItem(
        date: Calendar.current.date(byAdding: .day, value: i - 3, to: Date()) ?? Date(),
        dayNumber: 10 + i,
        isSelected: i == 3,
        isToday: i == 3,
        scheduleCount: 0
      )
    },
    onDateSelected: { _ in },
    onBackToMonth: {},
    onScheduleItemTapped: { _ in }
  )
}
