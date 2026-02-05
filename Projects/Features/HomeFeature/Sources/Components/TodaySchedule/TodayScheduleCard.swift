import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Today Schedule Card

/// 오늘의 일정 카드 - 확정된 오늘 약속들을 타임라인으로 표시
struct TodayScheduleCard: View {
  let promises: [PromiseModel]
  let onPromiseTap: (PromiseModel) -> Void

  @State private var isExpanded: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더 (탭 가능)
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          isExpanded.toggle()
        }
      } label: {
        cardHeader
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 12)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // 콘텐츠 (expanded일 때만)
      if isExpanded {
        Divider()
          .padding(.horizontal, 16)

        if promises.isEmpty {
          TodayEmptyState()
            .padding(.vertical, 24)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
          timelineContent
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
    }
    .adaptiveGlassCard(cornerRadius: 20)
  }

  // MARK: - Header

  private var cardHeader: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text("오늘의 일정")
          .font(.pmHeadline)
          .foregroundStyle(.primary)

        Text(todayDateString)
          .font(.pmCaption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // 약속 개수 (배경 없음)
      if !promises.isEmpty {
        Text("\(promises.count)개")
          .font(.pmSubheadlineMedium)
          .foregroundStyle(Color.pmindigo.n500)
      }

      // Chevron (회전 애니메이션)
      Image(systemName: "chevron.right")
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(Color.pmgray.n400)
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }
  }

  // MARK: - Timeline Content

  private var timelineContent: some View {
    VStack(spacing: 0) {
      ForEach(Array(promises.enumerated()), id: \.element.id) { index, promise in
        TimelineItemView(
          promise: promise,
          isFirst: index == 0,
          isLast: index == promises.count - 1,
          onTap: { onPromiseTap(promise) }
        )
      }
    }
  }

  // MARK: - Computed Properties

  private var todayDateString: String {
    KoreanDateFormatters.monthDayWeekday.string(from: Date())
  }
}

// MARK: - Preview

#Preview("약속 있음") {
  TodayScheduleCard(
    promises: [
      PromiseModel.mock(
        id: "1",
        title: "점심 모임",
        startAt: Date().addingTimeInterval(3600)
      ),
      PromiseModel.mock(
        id: "2",
        title: "카페 미팅",
        startAt: Date().addingTimeInterval(7200)
      )
    ],
    onPromiseTap: { _ in }
  )
  .padding()
  .auroraBackground()
}

#Preview("약속 없음") {
  TodayScheduleCard(
    promises: [],
    onPromiseTap: { _ in }
  )
  .padding()
  .auroraBackground()
}
