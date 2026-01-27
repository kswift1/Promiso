import SwiftUI
import PromisoShared

// MARK: - Today Schedule Card

/// 오늘의 일정 카드 - 확정된 오늘 약속들을 타임라인으로 표시
struct TodayScheduleCard: View {
  let promises: [PromiseModel]
  let onPromiseTap: (PromiseModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      cardHeader
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)

      Divider()
        .padding(.horizontal, 16)

      // 콘텐츠
      if promises.isEmpty {
        TodayEmptyState()
          .padding(.vertical, 24)
      } else {
        timelineContent
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
      }
    }
    .adaptiveGlassCard(cornerRadius: 20)
  }

  // MARK: - Header

  private var cardHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("오늘의 일정")
          .font(.headline)
          .foregroundStyle(.primary)

        Text(todayDateString)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // 약속 개수 배지
      if !promises.isEmpty {
        Text("\(promises.count)개")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(Color.pmindigo.n500)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color.pmindigo.n500.opacity(0.1))
          .clipShape(Capsule())
      }
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
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 EEEE"
    return formatter.string(from: Date())
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
