import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Upcoming Section

/// 다가오는 일정 섹션 - 확정된 미래 약속과 개인 일정
struct UpcomingSection: View {
  let items: [HomeModels.ScheduleItem]
  let weatherCache: [String: WeatherInfo]
  let onItemTap: (HomeModels.ScheduleItem) -> Void
  let onSeeAllTap: () -> Void

  /// 표시할 최대 개수
  private let maxDisplayCount = 5

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (날짜별 그룹)
      if items.isEmpty {
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

  // MARK: - Empty State

  private var emptyState: some View {
    HStack(spacing: 14) {
      // 캘린더 아이콘
      ZStack {
        Circle()
          .fill(Color.pmindigo.n500.opacity(0.1))
          .frame(width: 48, height: 48)

        Image(systemName: "calendar.badge.clock")
          .font(.pmTitle3)
          .foregroundStyle(Color.pmindigo.n500)
      }

      // 텍스트
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
    let calendar = Calendar.promiseDisplay
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

#Preview("일정 있음") {
  UpcomingSection(
    items: [
      .promise(PromiseModel.mock(id: "1", title: "팀 미팅", startAt: Date().addingTimeInterval(86400))),
      .personalEvent(PersonalEventModel.mock(
        id: "pe-1",
        title: "치과 예약",
        emoji: "🦷",
        startAt: Date().addingTimeInterval(90000)
      )),
      .promise(PromiseModel.mock(id: "2", title: "저녁 식사", startAt: Date().addingTimeInterval(172800))),
      .promise(PromiseModel.mock(id: "3", title: "영화 관람", startAt: Date().addingTimeInterval(259200)))
    ],
    weatherCache: [:],
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
    onItemTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}
