import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Today Schedule Card

/// 오늘의 일정 카드 - 확정된 오늘 약속과 개인 일정을 타임라인으로 표시
struct TodayScheduleCard: View {
  let items: [HomeModels.ScheduleItem]
  let weatherCache: [String: WeatherInfo]
  let departureAlerts: [String: HomeModels.DepartureAlertInfo]
  let isPro: Bool
  let onItemTap: (HomeModels.ScheduleItem) -> Void
  let onDepartureAlertTap: (HomeModels.ScheduleItem) -> Void
  let onDepartureAlertCancel: (String) -> Void

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

        if items.isEmpty {
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
      Text(LocalizedStrings.Home.todaySchedule)
        .font(.pmHeadline)
        .foregroundStyle(.primary)

      Spacer()

      // 일정 개수 (배경 없음)
      if !items.isEmpty {
        Text(LocalizedStrings.Home.itemCount(items.count))
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
      let sortedItems = items.sorted { $0.startAt < $1.startAt }
      let currentTimePosition = findCurrentTimePosition(in: sortedItems)

      ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
        // 현재 시간 마커 삽입 (이 일정 전에 표시해야 하는 경우)
        if currentTimePosition == .beforeIndex(index) {
          CurrentTimeMarkerView(nextPromiseStartAt: item.startAt)
        }

        let weather: WeatherInfo? = {
          if case .promise(let p) = item { return weatherCache[p.id] }
          return nil
        }()

        TimelineItemView(
          item: item,
          isFirst: index == 0 && currentTimePosition != .beforeIndex(0),
          isLast: index == sortedItems.count - 1 && currentTimePosition != .afterAll,
          weather: weather,
          departureAlert: departureAlerts[item.id],
          isPro: isPro,
          onTap: { onItemTap(item) },
          onDepartureAlertTap: { onDepartureAlertTap(item) },
          onDepartureAlertCancel: { onDepartureAlertCancel(item.id) }
        )

        // 모든 일정 종료 후 완료 메시지
        if index == sortedItems.count - 1 && currentTimePosition == .afterAll {
          TodayScheduleCompleteView()
        }
      }
    }
  }

  // MARK: - Current Time Position

  /// 현재 시간이 타임라인에서 어디에 위치하는지
  private enum CurrentTimePosition: Equatable {
    case insideItem          // 어떤 일정 진행 중
    case beforeIndex(Int)    // 특정 인덱스 일정 전 (빈 시간)
    case afterAll            // 모든 일정 종료 후
  }

  /// 정렬된 일정 배열에서 현재 시간 위치 찾기
  private func findCurrentTimePosition(in sortedItems: [HomeModels.ScheduleItem]) -> CurrentTimePosition {
    let now = Date()

    for (index, item) in sortedItems.enumerated() {
      // 현재 진행 중인 일정이 있으면 마커 표시 안함
      if now >= item.startAt && now <= item.effectiveEndAt {
        return .insideItem
      }

      // 이 일정 시작 전인데, 이전 일정은 끝났거나 없는 경우
      if now < item.startAt {
        if index == 0 {
          // 첫 일정 전에도 현재 시간 마커 표시
          return .beforeIndex(0)
        }

        // 이전 일정 종료 시간 확인
        let previousItem = sortedItems[index - 1]
        if now > previousItem.effectiveEndAt {
          // 이전 일정 끝났고, 다음 일정 시작 전 = 빈 시간
          return .beforeIndex(index)
        }
      }
    }

    // 마지막 일정 종료 후인지 확인
    if let lastItem = sortedItems.last {
      if now > lastItem.effectiveEndAt {
        return .afterAll
      }
    }

    return .insideItem
  }

}

// MARK: - Preview

#Preview("일정 있음") {
  TodayScheduleCard(
    items: [
      .promise(PromiseModel.mock(
        id: "1",
        title: "점심 모임",
        startAt: Date().addingTimeInterval(3600)
      )),
      .personalEvent(PersonalEventModel.mock(
        id: "pe-1",
        title: "아침 운동",
        emoji: "🏃",
        startAt: Date().addingTimeInterval(1800),
        endAt: Date().addingTimeInterval(5400)
      )),
      .promise(PromiseModel.mock(
        id: "2",
        title: "카페 미팅",
        startAt: Date().addingTimeInterval(7200)
      ))
    ],
    weatherCache: [:],
    departureAlerts: [:],
    isPro: false,
    onItemTap: { _ in },
    onDepartureAlertTap: { _ in },
    onDepartureAlertCancel: { _ in }
  )
  .padding()
  .auroraBackground()
}

#Preview("일정 없음") {
  TodayScheduleCard(
    items: [],
    weatherCache: [:],
    departureAlerts: [:],
    isPro: false,
    onItemTap: { _ in },
    onDepartureAlertTap: { _ in },
    onDepartureAlertCancel: { _ in }
  )
  .padding()
  .auroraBackground()
}
