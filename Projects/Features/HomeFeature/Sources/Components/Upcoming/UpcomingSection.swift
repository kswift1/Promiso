import SwiftUI
import PromisoShared

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

      // 카드들
      if promises.isEmpty {
        emptyState
      } else {
        VStack(spacing: 10) {
          ForEach(displayedPromises) { promise in
            UpcomingCard(
              promise: promise,
              onTap: { onPromiseTap(promise) }
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
        .font(.headline)
        .foregroundStyle(.primary)

      Spacer()

      // "전체 >" 버튼 (5개 이상일 때만)
      if promises.count > maxDisplayCount {
        Button(action: onSeeAllTap) {
          HStack(spacing: 2) {
            Text("전체")
              .font(.subheadline)

            Image(systemName: "chevron.right")
              .font(.caption)
          }
          .foregroundStyle(Color.pmindigo.n500)
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "calendar.badge.plus")
        .font(.title2)
        .foregroundStyle(.secondary)

      Text("확정된 약속이 없어요")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 24)
  }

  // MARK: - Computed Properties

  private var displayedPromises: [PromiseModel] {
    Array(promises.prefix(maxDisplayCount))
  }
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
