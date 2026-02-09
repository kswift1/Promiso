import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Upcoming Section

/// 다가오는 약속 섹션 - 확정된 미래 약속들
struct UpcomingSection: View {
  let promises: [PromiseModel]
  let onPromiseTap: (PromiseModel) -> Void
  let onSeeAllTap: () -> Void

  /// 표시할 최대 개수
  private let maxDisplayCount = 5

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (날짜별 그룹)
      if promises.isEmpty {
        emptyState
      } else {
        VStack(spacing: 10) {
          ForEach(groupedByDate, id: \.date) { group in
            UpcomingDateCard(
              date: group.date,
              promises: group.promises,
              onPromiseTap: onPromiseTap
            )
          }
        }
      }
    }
  }

  // MARK: - Header

  private var sectionHeader: some View {
    HStack {
      Text("다가오는 약속")
        .font(.pmHeadline)
        .foregroundStyle(.primary)

      Spacer()

      // "전체 >" 버튼 (5개 이상일 때만)
      if promises.count > maxDisplayCount {
        Button(action: onSeeAllTap) {
          HStack(spacing: 2) {
            Text("전체")
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
        Text("예정된 약속이 없어요")
          .font(.pmSubheadlineSemibold)
          .foregroundStyle(.primary)

        Text("친구들과 새로운 약속을 만들어보세요")
          .font(.pmCaption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(14)
    .adaptiveGlassCard(cornerRadius: 14)
  }

  // MARK: - Computed Properties

  private var displayedPromises: [PromiseModel] {
    Array(promises.prefix(maxDisplayCount))
  }

  /// 날짜별로 그룹화된 약속
  private var groupedByDate: [DateGroup] {
    let calendar = Calendar.current
    var groups: [Date: [PromiseModel]] = [:]

    for promise in displayedPromises {
      let dayStart = calendar.startOfDay(for: promise.startAt)
      groups[dayStart, default: []].append(promise)
    }

    return groups
      .sorted { $0.key < $1.key }
      .map { DateGroup(date: $0.key, promises: $0.value) }
  }
}

// MARK: - Date Group

private struct DateGroup {
  let date: Date
  let promises: [PromiseModel]
}

// MARK: - Preview

#Preview("약속 있음") {
  UpcomingSection(
    promises: [
      PromiseModel.mock(id: "1", title: "팀 미팅", startAt: Date().addingTimeInterval(86400)),
      PromiseModel.mock(id: "2", title: "저녁 식사", startAt: Date().addingTimeInterval(172800)),
      PromiseModel.mock(id: "3", title: "영화 관람", startAt: Date().addingTimeInterval(259200))
    ],
    onPromiseTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}

#Preview("약속 없음") {
  UpcomingSection(
    promises: [],
    onPromiseTap: { _ in },
    onSeeAllTap: {}
  )
  .padding()
  .auroraBackground()
}
