import SwiftUI
import UIKit
import PromisoShared
import ResourceKit

// MARK: - Day Timeline View

/// 00~24시 전체 시간을 수직 축으로 표시하는 타임라인 뷰
struct DayTimelineView: View {
  let scheduleItems: [HomeModels.ScheduleItem]
  let displayDate: Date
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void
  let onCreatePersonalEvent: (Date) -> Void
  let onCreatePromise: () -> Void
  let calendarMode: CalendarMode
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]

  // MARK: - State

  @State private var creationStartSlot: Int? = nil  // 상단 (0-47), nil = 비활성
  @State private var creationEndSlot: Int = 0        // 하단 (1-48)
  @State private var dragAnchorStart: Int = 0        // 드래그 시작 시점 start
  @State private var dragAnchorEnd: Int = 0          // 드래그 시작 시점 end

  var zoomState: TimelineZoomState

  // 줌 앵커링용 스크롤 추적
  @State private var scrollOffset: CGFloat = 0
  @State private var viewportHeight: CGFloat = 0
  @State private var scrollPosition = ScrollPosition(edge: .top)
  @State private var zoomScrollY: CGFloat? = nil

  // MARK: - Constants

  private let baseHourHeight: CGFloat = 52
  private let minZoomScale: CGFloat = 0.5
  private let maxZoomScale: CGFloat = 3.0
  private let timeLabelWidth: CGFloat = 44
  private let eventTimeLabelWidth: CGFloat = 40
  private let colorBarWidth: CGFloat = 4
  private let totalHours: Int = 24

  private var hourHeight: CGFloat {
    baseHourHeight * zoomState.scale
  }

  private var blockMinHeight: CGFloat {
    max(36, 48 * zoomState.scale)
  }

  private var totalHeight: CGFloat {
    CGFloat(totalHours) * hourHeight
  }

  private var pixelsPerMinute: CGFloat {
    hourHeight / 60.0
  }

  // MARK: - Body

  var body: some View {
    timelineContent
  }

  // MARK: - Timeline Content

  private var timelineContent: some View {
    ScrollView(.vertical, showsIndicators: false) {
      ZStack(alignment: .topLeading) {
        // Layer 1: 시간 눈금 + 구분선
        timeGrid

        // Layer 1.5: 상호작용 슬롯 (Long Press → 생성 블록)
        interactionSlots

        // Layer 2 + 3: 겹침 레이아웃 엔진 기반 렌더링
        overlapAwareScheduleBlocks

        // Layer 4: 생성 블록 오버레이 (creationSlot != nil일 때만)
        creationBlockOverlay
      }
      .frame(width: nil, height: totalHeight)
      .coordinateSpace(name: "timeline")
      .padding(.top, 10)
      .padding(.bottom, 10)
      .padding(.leading, 8)
      .padding(.trailing, 20)
    }
    .scrollPosition($scrollPosition)
    .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, newValue in
      scrollOffset = newValue
    }
    .onScrollGeometryChange(for: CGFloat.self, of: { $0.containerSize.height }) { _, newValue in
      viewportHeight = newValue
    }
    .simultaneousGesture(
      MagnifyGesture()
        .onChanged { value in
          let oldScale = zoomState.scale
          let newScale = min(maxZoomScale, max(minZoomScale, zoomState.gestureScale * value.magnification))
          guard oldScale != newScale else { return }

          // 화면 중앙 기준 앵커 줌
          let currentY = zoomScrollY ?? scrollOffset
          let centerY = currentY + viewportHeight / 2
          let newCenterY = centerY * (newScale / oldScale)
          let newY = max(0, newCenterY - viewportHeight / 2)

          zoomState.scale = newScale
          zoomScrollY = newY
          scrollPosition.scrollTo(y: newY)
        }
        .onEnded { _ in
          zoomState.gestureScale = zoomState.scale
          zoomScrollY = nil
        }
    )
    .onChange(of: displayDate) {
      creationStartSlot = nil
    }
    .onChange(of: calendarMode) {
      creationStartSlot = nil
    }
  }

  // MARK: - Overlap-Aware Schedule Blocks (Layer 2 + 3)

  @ViewBuilder
  private var overlapAwareScheduleBlocks: some View {
    let layoutResults = computeOverlapLayout()

    GeometryReader { geo in
      let blockAreaWidth = geo.size.width - timeLabelWidth - eventTimeLabelWidth - 8 - 4

      ForEach(Array(zip(scheduleItems.indices, scheduleItems)), id: \.1.id) { index, item in
        if let layout = layoutResults[safe: index], layout.columnIndex >= 0 {
          let yPos = yOffset(for: clampedStartAt(for: item))

          switch layout.severity {
          case .none, .layerable:
            eventTimeLabel(item)
              .offset(y: yPos)
              .zIndex(Double(layout.zIndex))

            scheduleBlock(item, layout: layout)
              .frame(width: blockAreaWidth, alignment: .leading)
              .padding(.leading, timeLabelWidth + eventTimeLabelWidth + 8)
              .offset(y: yPos)
              .zIndex(Double(layout.zIndex))

          case .colliding:
            eventTimeLabel(item)
              .offset(y: yPos)

            let colWidth = (blockAreaWidth - TimelineOverlapLayout.columnGap * CGFloat(layout.columnCount - 1)) / CGFloat(layout.columnCount)
            let colX = CGFloat(layout.columnIndex) * (colWidth + TimelineOverlapLayout.columnGap)

            scheduleBlock(item, layout: layout)
              .frame(width: colWidth, alignment: .leading)
              .offset(x: timeLabelWidth + eventTimeLabelWidth + 8 + colX, y: yPos)
              .zIndex(Double(layout.zIndex))
              .overlay(alignment: .topTrailing) {
                if layout.overflowCount > 0 {
                  overflowBadge(count: layout.overflowCount)
                    .offset(x: timeLabelWidth + eventTimeLabelWidth + 8 + colX + colWidth - 8, y: yPos + 4)
                }
              }
          }
        }
      }
    }
    .frame(height: totalHeight)
  }

  private func computeOverlapLayout() -> [TimelineOverlapLayout.LayoutResult] {
    let dayStartDate = dayStart

    let starts: [CGFloat] = scheduleItems.map { item in
      let start = clampedStartAt(for: item)
      return CGFloat(start.timeIntervalSince(dayStartDate)) / 60.0
    }

    let durations: [CGFloat] = scheduleItems.map { item in
      let start = clampedStartAt(for: item)
      let end = clampedEndAt(for: item)
      let dur = CGFloat(end.timeIntervalSince(start)) / 60.0
      return max(dur, CGFloat(blockMinHeight) / pixelsPerMinute)
    }

    return TimelineOverlapLayout.computeLayout(
      startMinutes: starts,
      durationMinutes: durations,
      pixelsPerMinute: pixelsPerMinute
    )
  }

  private func overflowBadge(count: Int) -> some View {
    Text("+\(count)")
      .font(.system(size: 10, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.pmgray.n500, in: Capsule())
  }

  // MARK: - Interaction Slots (Layer 1.5)

  private var interactionSlots: some View {
    VStack(spacing: 0) {
      ForEach(0..<48, id: \.self) { slot in
        Color.clear
          .frame(height: hourHeight / 2)
          .contentShape(Rectangle())
          .onLongPressGesture(minimumDuration: 0.5) {
            let impactMedium = UIImpactFeedbackGenerator(style: .medium)
            impactMedium.impactOccurred()
            creationStartSlot = slot
            creationEndSlot = min(48, slot + 2)
            dragAnchorStart = slot
            dragAnchorEnd = min(48, slot + 2)
          }
      }
    }
    .frame(height: totalHeight)
  }

  // MARK: - Creation Block Overlay (Layer 4)

  @ViewBuilder
  private var creationBlockOverlay: some View {
    if let startSlot = creationStartSlot {
      let endSlot = creationEndSlot
      let blockHeight = CGFloat(endSlot - startSlot) * (hourHeight / 2)
      let blockY = CGFloat(startSlot) * (hourHeight / 2)
      let startHour = startSlot / 2
      let startMinute = (startSlot % 2) * 30
      let endHour = endSlot / 2
      let endMinute = (endSlot % 2) * 30

      // Layer 4a: dismiss 배경
      Color.clear
        .frame(height: totalHeight)
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation(.easeOut(duration: 0.2)) {
            creationStartSlot = nil
          }
        }

      // Layer 4b: 시간 레이블
      VStack(spacing: 0) {
        Text(String(format: "%02d:%02d", startHour, startMinute))
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(Color.pmindigo.n500)
        Spacer(minLength: 0)
        Text(String(format: "%02d:%02d", endHour, endMinute))
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(Color.pmindigo.n500.opacity(0.6))
      }
      .frame(width: eventTimeLabelWidth, height: blockHeight, alignment: .leading)
      .padding(.leading, timeLabelWidth)
      .offset(y: blockY)

      // Layer 4c: 생성 블록 + 리사이즈 핸들
      creationBlockWithHandles(
        startSlot: startSlot,
        endSlot: endSlot,
        blockHeight: blockHeight
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, timeLabelWidth + eventTimeLabelWidth + 8)
      .padding(.trailing, 4)
      .offset(y: blockY)
    }
  }

  // MARK: - Creation Block with Resize Handles

  private let handleZoneHeight: CGFloat = 16

  private func creationBlockWithHandles(startSlot: Int, endSlot: Int, blockHeight: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: 10)

    // VStack으로 상단/중간/하단 영역을 명확히 분리 → 제스처 충돌 방지
    return VStack(spacing: 0) {
      // 상단 리사이즈 핸들 영역
      HStack {
        Spacer()
        Capsule()
          .fill(Color.pmindigo.n500.opacity(0.5))
          .frame(width: 32, height: 4)
        Spacer()
      }
      .frame(height: handleZoneHeight)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
          .onChanged { value in
            let slot = Int(round(value.location.y / (hourHeight / 2)))
            creationStartSlot = max(0, min(creationEndSlot - 2, slot))
          }
          .onEnded { value in
            let slot = Int(round(value.location.y / (hourHeight / 2)))
            dragAnchorStart = max(0, min(creationEndSlot - 2, slot))
          }
      )

      // 중간 영역: 이동 드래그 + 액션 버튼
      HStack(spacing: 12) {
        Button {
          onCreatePersonalEvent(dateForSlot(startSlot))
          creationStartSlot = nil
        } label: {
          Label(LocalizedStrings.Calendar.addPersonalEvent, systemImage: "plus.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.pminfo.n500)
        }
        .buttonStyle(.plain)

        Button {
          onCreatePromise()
          creationStartSlot = nil
        } label: {
          Label(LocalizedStrings.Calendar.createPromise, systemImage: "person.2.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
        }
        .buttonStyle(.plain)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 5, coordinateSpace: .named("timeline"))
          .onChanged { value in
            let duration = dragAnchorEnd - dragAnchorStart
            let delta = Int(round((value.location.y - value.startLocation.y) / (hourHeight / 2)))
            let newStart = max(0, min(48 - duration, dragAnchorStart + delta))
            creationStartSlot = newStart
            creationEndSlot = newStart + duration
          }
          .onEnded { value in
            let duration = dragAnchorEnd - dragAnchorStart
            let delta = Int(round((value.location.y - value.startLocation.y) / (hourHeight / 2)))
            let newStart = max(0, min(48 - duration, dragAnchorStart + delta))
            dragAnchorStart = newStart
            dragAnchorEnd = newStart + duration
          }
      )

      // 하단 리사이즈 핸들 영역
      HStack {
        Spacer()
        Capsule()
          .fill(Color.pmindigo.n500.opacity(0.5))
          .frame(width: 32, height: 4)
        Spacer()
      }
      .frame(height: handleZoneHeight)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 3, coordinateSpace: .named("timeline"))
          .onChanged { value in
            let slot = Int(round(value.location.y / (hourHeight / 2)))
            creationEndSlot = max((creationStartSlot ?? 0) + 2, min(48, slot))
          }
          .onEnded { value in
            let slot = Int(round(value.location.y / (hourHeight / 2)))
            dragAnchorEnd = max((creationStartSlot ?? 0) + 2, min(48, slot))
          }
      )
    }
    .frame(height: blockHeight)
    .background(.ultraThinMaterial, in: shape)
    .overlay(
      shape.strokeBorder(
        Color.pmindigo.n500.opacity(0.5),
        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
      )
    )
    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
  }

  // MARK: - Slot Helpers

  /// 일정 아이템의 시작 시간을 30분 슬롯으로 변환
  private func slotForItem(_ item: HomeModels.ScheduleItem) -> Int {
    let start = clampedStartAt(for: item)
    let cal = Calendar.promiseDisplay
    let hour = cal.component(.hour, from: start)
    let minute = cal.component(.minute, from: start)
    return hour * 2 + (minute >= 30 ? 1 : 0)
  }

  private func dateForSlot(_ slot: Int) -> Date {
    let hour = slot / 2
    let minute = (slot % 2) * 30
    return Calendar.promiseDisplay.date(bySettingHour: hour, minute: minute, second: 0, of: displayDate) ?? displayDate
  }

  // MARK: - Time Grid

  private var timeGrid: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(0..<totalHours, id: \.self) { hour in
        ZStack(alignment: .topLeading) {
          // 정각 행
          HStack(spacing: 8) {
            Text(String(format: "%02d:00", hour))
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(.tertiary)
              .frame(width: timeLabelWidth, alignment: .leading)

            // 정각 실선
            Rectangle()
              .fill(Color(.separator).opacity(0.5))
              .frame(height: 0.5)
          }
          .frame(height: 14, alignment: .center)
          .offset(y: -7)

          // 30분 점선
          HStack(alignment: .top, spacing: 8) {
            Color.clear
              .frame(width: timeLabelWidth)

            VStack(spacing: 0) {
              Spacer()
                .frame(height: hourHeight / 2)
              dashedLine
              Spacer()
            }
          }
        }
        .frame(height: hourHeight)
      }
    }
    .frame(height: totalHeight)
  }

  // MARK: - Schedule Block

  private func scheduleBlock(
    _ item: HomeModels.ScheduleItem,
    layout: TimelineOverlapLayout.LayoutResult? = nil
  ) -> some View {
    let blockHeight = blockHeight(for: item)
    let isCompact = blockHeight < 64
    let fromPrev = continuesFromPreviousDay(item)
    let toNext = continuesToNextDay(item)
    let topRadius: CGFloat = fromPrev ? 0 : 10
    let bottomRadius: CGFloat = toNext ? 0 : 10
    let cardShape = UnevenRoundedRectangle(
      topLeadingRadius: topRadius,
      bottomLeadingRadius: bottomRadius,
      bottomTrailingRadius: bottomRadius,
      topTrailingRadius: topRadius
    )

    let isLayerableBack = layout?.severity == .layerable && layout?.zIndex == 0
    let barOpacity: Double = isLayerableBack ? 0.4 : 1.0
    let cardShadow: Double = (layout?.severity == .layerable && (layout?.zIndex ?? 0) > 0)
      ? 0.15 : 0.08

    return Button {
      onScheduleItemTapped(item)
    } label: {
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 2) {
          // Row 1: 이모지 + 제목 + 상태
          HStack(spacing: 5) {
            Text(item.displayEmoji)
              .font(.system(size: isCompact ? 14 : 16))

            Text(item.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)

            if case .promise(let p) = item {
              let status = promiseResponseStatus(p)
              Text(statusText(for: status))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor(for: status))
            }
          }

          if !isCompact {
            // Row 2: 그룹명 + 참여자수
            HStack(spacing: 5) {
              if let name = groupName(for: item) {
                Text(name)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }

              if case .promise(let p) = item {
                Text("·")
                  .font(.system(size: 10))
                  .foregroundStyle(.tertiary)
                Text("👤 \(p.votes.acceptedCount)/\(p.minimumParticipants)")
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
            }

            // Row 3: 장소 (있을 때만)
            if let location = itemLocation(for: item), !location.isEmpty {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.system(size: 9))
                  .foregroundStyle(Color.pmgray.n400)
                Text(location)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        Spacer(minLength: 0)
      }
      .frame(height: blockHeight, alignment: .top)
      .background(.ultraThinMaterial, in: cardShape)
      .overlay(cardShape.strokeBorder(.white.opacity(0.2), lineWidth: 1))
      .shadow(color: .black.opacity(cardShadow), radius: 8, x: 0, y: 4)
      .overlay(alignment: .topTrailing) {
        if layout?.severity != .colliding {
          weatherBadge(for: item)
            .padding(.top, 4)
            .padding(.trailing, 4)
        }
      }
      .overlay(alignment: .leading) {
        UnevenRoundedRectangle(
          topLeadingRadius: topRadius,
          bottomLeadingRadius: bottomRadius,
          bottomTrailingRadius: 0,
          topTrailingRadius: 0
        )
        .fill(barColor(for: item).opacity(barOpacity))
        .frame(width: colorBarWidth)
      }
      .clipShape(cardShape)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      LongPressGesture(minimumDuration: 0.5)
        .onEnded { _ in
          UIImpactFeedbackGenerator(style: .medium).impactOccurred()
          let s = slotForItem(item)
          creationStartSlot = s
          creationEndSlot = min(48, s + 2)
          dragAnchorStart = s
          dragAnchorEnd = min(48, s + 2)
        }
    )
  }

  // MARK: - Event Time Label

  private func eventTimeLabel(_ item: HomeModels.ScheduleItem) -> some View {
    let blockHeight = blockHeight(for: item)
    let color = barColor(for: item)
    let clampedStart = clampedStartAt(for: item)
    let clampedEnd = clampedEndAt(for: item)
    let fromPrev = continuesFromPreviousDay(item)
    let toNext = continuesToNextDay(item)

    return VStack(spacing: 0) {
      if fromPrev {
        Text(dateTimeString(for: item.startAt))
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(color)
      } else {
        Text(timeString(for: clampedStart))
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(color)
      }

      Spacer(minLength: 0)

      if toNext {
        if let endAt = item.endAt {
          Text(dateTimeString(for: endAt))
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(color.opacity(0.6))
        }
      } else if item.endAt != nil {
        Text(timeString(for: clampedEnd))
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(color.opacity(0.6))
      }
    }
    .frame(width: eventTimeLabelWidth, height: blockHeight, alignment: .leading)
    .padding(.leading, timeLabelWidth)
  }

  // MARK: - Dashed Line

  private var dashedLine: some View {
    GeometryReader { geo in
      Path { path in
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
      }
      .stroke(Color(.separator).opacity(0.45), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
    }
    .frame(height: 0.5)
  }

  // MARK: - Helpers

  /// 시간 기반 y 좌표 계산
  private func yOffset(for date: Date) -> CGFloat {
    let calendar = Calendar.promiseDisplay
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return (CGFloat(hour) + CGFloat(minute) / 60.0) * hourHeight
  }

  /// 해당 날짜의 시작/종료 시각
  private var dayStart: Date {
    Calendar.promiseDisplay.startOfDay(for: displayDate)
  }

  private var dayEnd: Date {
    Calendar.promiseDisplay.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
  }

  /// multi-day 일정의 시작 시간을 해당 날짜로 클램핑
  private func clampedStartAt(for item: HomeModels.ScheduleItem) -> Date {
    max(item.startAt, dayStart)
  }

  /// multi-day 일정의 종료 시간을 해당 날짜로 클램핑
  private func clampedEndAt(for item: HomeModels.ScheduleItem) -> Date {
    min(item.effectiveEndAt, dayEnd)
  }

  /// 이전 날짜에서 이어지는 일정인지
  private func continuesFromPreviousDay(_ item: HomeModels.ScheduleItem) -> Bool {
    item.startAt < dayStart
  }

  /// 다음 날짜로 이어지는 일정인지
  private func continuesToNextDay(_ item: HomeModels.ScheduleItem) -> Bool {
    item.effectiveEndAt > dayEnd
  }

  /// 일정 블록 높이 (duration 기반, 최소 blockMinHeight)
  private func blockHeight(for item: HomeModels.ScheduleItem) -> CGFloat {
    let start = clampedStartAt(for: item)
    let end = clampedEndAt(for: item)
    let duration = end.timeIntervalSince(start)
    let hours = duration / 3600.0
    let calculatedHeight = CGFloat(hours) * hourHeight
    return max(blockMinHeight, calculatedHeight)
  }

  /// 블록 배경색 (그룹 컬러 기반 연한 배경)
  private func blockBackground(for item: HomeModels.ScheduleItem) -> Color {
    barColor(for: item).opacity(0.08)
  }

  private func barColor(for item: HomeModels.ScheduleItem) -> Color {
    switch item {
    case .promise(let p):
      return groupColorMap[p.groupId] ?? Color.pmindigo.n500
    case .personalEvent:
      return Color.pminfo.n500
    }
  }

  private func groupName(for item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.group?.name
    case .personalEvent:
      return nil
    }
  }

  @ViewBuilder
  private func weatherBadge(for item: HomeModels.ScheduleItem) -> some View {
    switch item {
    case .promise(let p):
      if let weatherInfo = weatherCache[p.id],
         let forecast = weatherInfo.forecast(for: p.startAt) {
        WeatherBadge(
          forecast: forecast,
          rangeForecasts: weatherInfo.forecasts(from: p.startAt, to: p.endAt),
          referenceTimeText: p.startAt.formattedMonthDayTime,
          forecastSource: weatherInfo.forecastSource(for: p.startAt)
        )
      }
    case .personalEvent(let e):
      if let weatherInfo = weatherCache[e.id],
         let forecast = weatherInfo.forecast(for: e.startAt) {
        WeatherBadge(
          forecast: forecast,
          rangeForecasts: weatherInfo.forecasts(from: e.startAt, to: e.endAt),
          referenceTimeText: e.startAt.formattedMonthDayTime,
          forecastSource: weatherInfo.forecastSource(for: e.startAt)
        )
      }
    }
  }

  private func timeString(for date: Date) -> String {
    Formatters.time.string(from: date)
  }

  private func dateTimeString(for date: Date) -> String {
    Formatters.dateTime.string(from: date)
  }

  private func promiseResponseStatus(_ promise: PromiseModel) -> PromiseResponseStatus {
    let memberCount = promise.group?.memberIds.count
    let totalMembers = (memberCount ?? 0) > 0 ? memberCount : nil
    return promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: totalMembers)
  }

  private func statusColor(for status: PromiseResponseStatus) -> Color {
    switch status {
    case .needResponse: return Color.pmwarning.n500
    case .responded:    return Color.pmwarning.n600
    case .confirmed:    return Color.pmsuccess.n500
    case .failed:       return Color.pmgray.n400
    }
  }

  private func statusText(for status: PromiseResponseStatus) -> String {
    switch status {
    case .needResponse: return "응답 필요"
    case .responded:    return "투표 완료"
    case .confirmed:    return "확정"
    case .failed:       return "미확정"
    }
  }

  private func itemLocation(for item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.location?.name
    case .personalEvent(let e):
      return e.location?.name
    }
  }

  // MARK: - Formatters

  private enum Formatters {
    static let displayTimeZone = Calendar.promiseDisplay.timeZone
    static let time: DateFormatter = {
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = displayTimeZone
      f.dateFormat = "HH:mm"
      return f
    }()

    static let dateTime: DateFormatter = {
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = displayTimeZone
      f.dateFormat = "M/d HH:mm"
      return f
    }()
  }
}

// MARK: - Preview

#Preview("일정 있음") {
  let calendar = Calendar.promiseDisplay
  let today = Date()

  let items: [HomeModels.ScheduleItem] = [
    .promise(PromiseModel.mock(
      id: "1",
      title: "팀 미팅",
      emoji: "🤝",
      hostId: "host1",
      groupId: "g1",
      group: GroupModel(
        id: "g1",
        name: "개발팀",
        maxMembers: 10,
        inviteCode: "code1",
        createdBy: "host1"
      ),
      startAt: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!,
      endAt: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)
    )),
    .personalEvent(PersonalEventModel.mock(
      id: "2",
      title: "독서",
      emoji: "📚",
      startAt: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!,
      endAt: calendar.date(bySettingHour: 11, minute: 30, second: 0, of: today)
    )),
    .promise(PromiseModel.mock(
      id: "3",
      title: "점심 약속",
      emoji: "🍽️",
      hostId: "host1",
      groupId: "g2",
      group: GroupModel(
        id: "g2",
        name: "친구들",
        maxMembers: 5,
        inviteCode: "code2",
        createdBy: "host1"
      ),
      startAt: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!,
      endAt: nil
    )),
  ]

  DayTimelineView(
    scheduleItems: items,
    displayDate: today,
    onScheduleItemTapped: { _ in },
    onCreatePersonalEvent: { _ in },
    onCreatePromise: {},
    calendarMode: .weekly,
    currentUserId: "host1",
    weatherCache: [:],
    groupColorMap: ["g1": Color.pmindigo.n500, "g2": .orange],
    zoomState: TimelineZoomState()
  )
  .auroraBackground()
}

#Preview("일정 없음") {
  DayTimelineView(
    scheduleItems: [],
    displayDate: Date(),
    onScheduleItemTapped: { _ in },
    onCreatePersonalEvent: { _ in },
    onCreatePromise: {},
    calendarMode: .weekly,
    currentUserId: "preview",
    weatherCache: [:],
    groupColorMap: [:],
    zoomState: TimelineZoomState()
  )
  .auroraBackground()
}
