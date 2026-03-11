import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Upcoming Section

/// 다가오는 일정 섹션 - 확정된 미래 일정과 개인 일정
struct UpcomingSection: View {
  let items: [HomeModels.ScheduleItem]
  let weatherCache: [String: WeatherInfo]
  let recurringSummaries: [HomeModels.RecurringEventSummary]
  let onItemTap: (HomeModels.ScheduleItem) -> Void
  let onSeeAllTap: () -> Void

  @State private var isRecurringExpanded = false

  /// 표시할 최대 개수
  private let maxDisplayCount = 5

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (날짜별 그룹)
      if items.isEmpty && recurringSummaries.isEmpty {
        emptyState
      } else {
        VStack(spacing: 10) {
          ForEach(groupedByDate, id: \.date) { group in
            UpcomingDateCard(
              date: group.date,
              items: group.items,
              weatherCache: weatherCache,
              onItemTap: onItemTap
            )
          }

          // 반복 일정 요약
          if !recurringSummaries.isEmpty {
            recurringEventsBadge
          }
        }
      }
    }
  }

  // MARK: - Header

  private var sectionHeader: some View {
    HStack {
      Text(LocalizedStrings.Home.upcomingSchedule)
        .font(.pmHeadline)
        .foregroundStyle(.primary)

      Spacer()

      // "전체 >" 버튼 (5개 이상일 때만)
      if items.count > maxDisplayCount {
        Button(action: onSeeAllTap) {
          HStack(spacing: 2) {
            Text(LocalizedStrings.Common.all)
              .font(.pmSubheadline)

            Image(systemName: "chevron.right")
              .font(.pmCaption)
          }
          .foregroundStyle(Color.pmindigo.n500)
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Recurring Events Badge

  private var recurringEventsBadge: some View {
    VStack(spacing: 0) {
      // 헤더 (탭하면 펼침/접힘)
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isRecurringExpanded.toggle()
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.trianglehead.2.counterclockwise")
            .font(.pmCaption)
            .foregroundStyle(Color.pmindigo.n500)

          Text("반복 일정 \(recurringSummaries.count)개")
            .font(.pmCaption)
            .foregroundStyle(.secondary)

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(isRecurringExpanded ? 90 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // 펼침 시 종류별 목록
      if isRecurringExpanded {
        VStack(spacing: 0) {
          Divider()
            .padding(.horizontal, 14)

          ForEach(Array(recurringSummaries.enumerated()), id: \.element.id) { index, summary in
            HStack(spacing: 8) {
              Text(summary.emoji)
                .font(.pmCaption)

              Text(summary.title)
                .font(.pmCaption)
                .foregroundStyle(.primary)
                .lineLimit(1)

              Text("·")
                .font(.pmCaption)
                .foregroundStyle(.tertiary)

              Text(summary.recurrenceText)
                .font(.pmCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

              Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if index < recurringSummaries.count - 1 {
              Divider()
                .padding(.horizontal, 14)
            }
          }
        }
      }
    }
    .background(Color.pmindigo.n500.opacity(0.03))
    .adaptiveGlassCard(cornerRadius: 10)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(Color.pmindigo.n500.opacity(0.1))
          .frame(width: 48, height: 48)

        Image(systemName: "calendar.badge.clock")
          .font(.pmTitle3)
          .foregroundStyle(Color.pmindigo.n500)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(LocalizedStrings.Home.noUpcomingTitle)
          .font(.pmSubheadlineSemibold)
          .foregroundStyle(.primary)

        Text(LocalizedStrings.Home.noUpcomingSubtitle)
          .font(.pmCaption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(14)
    .adaptiveGlassCard(cornerRadius: 14)
  }

  // MARK: - Computed Properties

  private var displayedItems: [HomeModels.ScheduleItem] {
    Array(items.prefix(maxDisplayCount))
  }

  /// 날짜별로 그룹화된 일정
  private var groupedByDate: [DateGroup] {
    let calendar = Calendar.scheduleDisplay
    var groups: [Date: [HomeModels.ScheduleItem]] = [:]

    for item in displayedItems {
      let dayStart = calendar.startOfDay(for: item.startAt)
      groups[dayStart, default: []].append(item)
    }

    return groups
      .sorted { $0.key < $1.key }
      .map { DateGroup(date: $0.key, items: $0.value) }
  }
}

// MARK: - Date Group

private struct DateGroup {
  let date: Date
  let items: [HomeModels.ScheduleItem]
}

// MARK: - Preview

#Preview("일정 + 반복") {
  UpcomingSection(
    items: [
      .schedule(ScheduleModel.mock(id: "1", title: "팀 미팅", startAt: Date().addingTimeInterval(86400))),
      .personalEvent(PersonalEventModel.mock(
        id: "pe-1",
        title: "치과 예약",
        emoji: "🦷",
        startAt: Date().addingTimeInterval(90000)
      )),
    ],
    weatherCache: [:],
    recurringSummaries: [
      .init(recurringEventId: "r1", title: "출근", emoji: "🏢", recurrenceText: "매주 월, 화, 수, 목, 금", nextInstanceDate: Date().addingTimeInterval(86400)),
      .init(recurringEventId: "r2", title: "헬스장", emoji: "💪", recurrenceText: "매주 월, 수, 금", nextInstanceDate: Date().addingTimeInterval(172800)),
    ],
    onItemTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}

#Preview("일정 없음") {
  UpcomingSection(
    items: [],
    weatherCache: [:],
    recurringSummaries: [],
    onItemTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}

#Preview("반복 일정만") {
  UpcomingSection(
    items: [],
    weatherCache: [:],
    recurringSummaries: [
      .init(recurringEventId: "r1", title: "출근", emoji: "🏢", recurrenceText: "매주 월, 화, 수, 목, 금", nextInstanceDate: Date().addingTimeInterval(86400)),
      .init(recurringEventId: "r2", title: "헬스장", emoji: "💪", recurrenceText: "매주 월, 수, 금", nextInstanceDate: Date().addingTimeInterval(172800)),
      .init(recurringEventId: "r3", title: "영어 수업", emoji: "📚", recurrenceText: "매주 화, 목", nextInstanceDate: Date().addingTimeInterval(259200)),
    ],
    onItemTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}
