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
      let sortedPromises = promises.sorted { $0.startAt < $1.startAt }
      let currentTimePosition = findCurrentTimePosition(in: sortedPromises)

      ForEach(Array(sortedPromises.enumerated()), id: \.element.id) { index, promise in
        // 현재 시간 마커 삽입 (이 약속 전에 표시해야 하는 경우)
        if currentTimePosition == .beforeIndex(index) {
          CurrentTimeMarkerView(nextPromiseStartAt: promise.startAt)
        }

        TimelineItemView(
          promise: promise,
          isFirst: index == 0 && currentTimePosition != .beforeIndex(0),
          isLast: index == sortedPromises.count - 1 && currentTimePosition != .afterAll,
          onTap: { onPromiseTap(promise) }
        )

        // 마지막 약속 후 현재 시간 마커 (모든 일정 종료 후)
        if index == sortedPromises.count - 1 && currentTimePosition == .afterAll {
          CurrentTimeMarkerView(nextPromiseStartAt: nil)
        }
      }
    }
  }

  // MARK: - Current Time Position

  /// 현재 시간이 타임라인에서 어디에 위치하는지
  private enum CurrentTimePosition: Equatable {
    case insidePromise       // 어떤 약속 진행 중
    case beforeIndex(Int)    // 특정 인덱스 약속 전 (빈 시간)
    case afterAll            // 모든 약속 종료 후
  }

  /// 정렬된 약속 배열에서 현재 시간 위치 찾기
  private func findCurrentTimePosition(in sortedPromises: [PromiseModel]) -> CurrentTimePosition {
    let now = Date()

    for (index, promise) in sortedPromises.enumerated() {
      let start = promise.startAt
      let end = promise.endAt ?? promise.startAt.addingTimeInterval(7200)

      // 현재 진행 중인 약속이 있으면 마커 표시 안함
      if now >= start && now <= end {
        return .insidePromise
      }

      // 이 약속 시작 전인데, 이전 약속은 끝났거나 없는 경우
      if now < start {
        if index == 0 {
          // 첫 약속 전이면 마커 표시 안함 (아직 일정 시작 전)
          return .insidePromise
        }

        // 이전 약속 종료 시간 확인
        let previousPromise = sortedPromises[index - 1]
        let previousEnd = previousPromise.endAt ?? previousPromise.startAt.addingTimeInterval(7200)

        if now > previousEnd {
          // 이전 약속 끝났고, 다음 약속 시작 전 = 빈 시간
          return .beforeIndex(index)
        }
      }
    }

    // 마지막 약속 종료 후인지 확인
    if let lastPromise = sortedPromises.last {
      let lastEnd = lastPromise.endAt ?? lastPromise.startAt.addingTimeInterval(7200)
      if now > lastEnd {
        return .afterAll
      }
    }

    return .insidePromise
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
