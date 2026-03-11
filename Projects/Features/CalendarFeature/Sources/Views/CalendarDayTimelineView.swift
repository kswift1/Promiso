import SwiftUI
import UIKit
import PromisoShared
import Clients
import ResourceKit

// MARK: - Calendar Day Timeline View

/// CalendarFeature용 24시간 타임라인 뷰
/// HomeFeature DayTimelineView를 기반으로 CalendarEvent 케이스 렌더링 추가
struct CalendarDayTimelineView: View {
  let scheduleItems: [CalendarFeature.ScheduleItem]
  let displayDate: Date
  let onScheduleItemTapped: (CalendarFeature.ScheduleItem) -> Void
  let onEditScheduleItem: ((CalendarFeature.ScheduleItem) -> Void)?
  let onCreatePersonalEvent: (Date, Date) -> Void
  let onCreatePromise: (Date, Date) -> Void
  let onDeleteScheduleItem: ((CalendarFeature.ScheduleItem) -> Void)?
  let onShareScheduleItem: ((CalendarFeature.ScheduleItem) -> Void)?
  let onPastTimeBlocked: (() -> Void)?
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]
  var zoomState: TimelineZoomState

  // MARK: - State

  @State private var creationStartSlot: Int? = nil  // 상단 (0-143), nil = 비활성
  @State private var creationEndSlot: Int = 0        // 하단 (1-144)
  @State private var dragAnchorStart: Int = 0        // 드래그 시작 시점 start
  @State private var dragAnchorEnd: Int = 0          // 드래그 시작 시점 end
  @State private var showCreationDialog = false
  @State private var creationTargetDate: Date?

  // 이미지 미리보기
  @State private var previewImageUrls: [String]? = nil

  // 드래그 햅틱
  @State private var selectionFeedback = UISelectionFeedbackGenerator()

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

  /// 현재 줌 레벨에 따른 시간당 높이
  private var hourHeight: CGFloat {
    baseHourHeight * zoomState.scale
  }

  /// 블록 최소 높이 (줌 레벨 반영)
  private var blockMinHeight: CGFloat {
    max(36, 48 * zoomState.scale)
  }

  private var totalHeight: CGFloat {
    CGFloat(totalHours) * hourHeight
  }

  /// 1분당 픽셀 수 (겹침 엔진용)
  private var pixelsPerMinute: CGFloat {
    hourHeight / 60.0
  }

  // MARK: - Body

  var body: some View {
    timelineContent
      .fullScreenCover(isPresented: Binding(
        get: { previewImageUrls != nil },
        set: { if !$0 { previewImageUrls = nil } }
      )) {
        if let urls = previewImageUrls {
          PhotoGalleryViewer(
            imageUrls: urls,
            initialIndex: 0,
            onDismiss: { previewImageUrls = nil }
          )
        }
      }
  }

  private var creationDialogBinding: Binding<Bool> {
    Binding(
      get: { showCreationDialog },
      set: { isPresented in
        showCreationDialog = isPresented
        if !isPresented {
          creationTargetDate = nil
          creationStartSlot = nil
        }
      }
    )
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

        // Layer 3.5: 현재 시간 인디케이터 (오늘만)
        if isToday {
          currentTimeIndicator
        }

        // Layer 4: 생성 블록 오버레이 (creationSlot != nil일 때만)
        creationBlockOverlay
      }
      .frame(width: nil, height: totalHeight)
      .coordinateSpace(name: "timeline")
      .padding(.top, 16)
      .padding(.bottom, 20)
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
    .onAppear {
      if isToday {
        let initialScrollOffset: CGFloat = 60
        let components = Calendar.promiseDisplay.dateComponents([.hour, .minute], from: Date())
        let hour = CGFloat(components.hour ?? 0)
        let minute = CGFloat(components.minute ?? 0)
        let targetY = max(0, (hour + minute / 60.0) * hourHeight - initialScrollOffset)
        scrollPosition.scrollTo(y: targetY)
      }
    }
    .onChange(of: displayDate) {
      creationStartSlot = nil
      // 날짜 변경 시 첫 번째 일정 위치 또는 현재 시간으로 스크롤
      let targetY: CGFloat
      if let firstItem = scheduleItems.first {
        targetY = max(0, yOffset(for: clampedStartAt(for: firstItem)) - 20)
      } else {
        let hour = Calendar.promiseDisplay.component(.hour, from: Date())
        targetY = max(0, CGFloat(hour) * hourHeight - 20)
      }
      scrollPosition.scrollTo(y: targetY)
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

  /// 겹침 레이아웃 계산
  private func computeOverlapLayout() -> [TimelineOverlapLayout.LayoutResult] {
    let dayStartDate = dayStart

    let starts: [CGFloat] = scheduleItems.map { item in
      let start = clampedStartAt(for: item)
      return CGFloat(start.timeIntervalSince(dayStartDate)) / 60.0
    }

    let durations: [CGFloat] = scheduleItems.map { item in
      // 콘텐츠 인식 블록 높이를 분 단위로 변환하여 겹침 감지 정확도 향상
      return CGFloat(blockHeight(for: item)) / pixelsPerMinute
    }

    return TimelineOverlapLayout.computeLayout(
      startMinutes: starts,
      durationMinutes: durations,
      pixelsPerMinute: pixelsPerMinute
    )
  }

  /// +N 오버플로우 뱃지
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
      ForEach(0..<144, id: \.self) { slot in
        Color.clear
          .frame(height: hourHeight / 6)
          .contentShape(Rectangle())
          .onTapGesture(count: 2) {
            let slotDate = dateForSlot(slot)
            if slotDate > Date() {
              let impactMedium = UIImpactFeedbackGenerator(style: .medium)
              impactMedium.impactOccurred()
              creationStartSlot = slot
              creationEndSlot = min(144, slot + 6)
              dragAnchorStart = slot
              dragAnchorEnd = min(144, slot + 6)
            } else {
              onPastTimeBlocked?()
            }
          }
          .onLongPressGesture(minimumDuration: 0.5) {
            let impactMedium = UIImpactFeedbackGenerator(style: .medium)
            impactMedium.impactOccurred()
            creationStartSlot = slot
            creationEndSlot = min(144, slot + 6)
            dragAnchorStart = slot
            dragAnchorEnd = min(144, slot + 6)
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
      let blockHeight = CGFloat(endSlot - startSlot) * (hourHeight / 6)
      let blockY = CGFloat(startSlot) * (hourHeight / 6)
      let startHour = startSlot / 6
      let startMinute = (startSlot % 6) * 10
      let endHour = endSlot / 6
      let endMinute = (endSlot % 6) * 10

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
            let slot = Int(round(value.location.y / (hourHeight / 6)))
            let newStart = max(0, min(creationEndSlot - 6, slot))
            if newStart != creationStartSlot {
              selectionFeedback.selectionChanged()
              creationStartSlot = newStart
            }
          }
          .onEnded { value in
            let slot = Int(round(value.location.y / (hourHeight / 6)))
            dragAnchorStart = max(0, min(creationEndSlot - 6, slot))
          }
      )

      // 중간 영역: 이동 드래그 + 일정 추가 버튼
      Button {
        guard let startSlot = creationStartSlot else { return }
        let startDate = dateForSlot(startSlot)
        if startDate <= Date() {
          creationStartSlot = nil
          onPastTimeBlocked?()
          return
        }
        creationTargetDate = dateForSlot(startSlot)
        showCreationDialog = true
      } label: {
        Label(LocalizedStrings.Calendar.addSchedule, systemImage: "plus.circle.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)
      }
      .confirmationDialog(
        LocalizedStrings.Calendar.addSchedule,
        isPresented: creationDialogBinding,
        titleVisibility: .hidden,
        actions: {
          Button(LocalizedStrings.Calendar.personalSchedule) {
            guard let startSlot = creationStartSlot else { return }
            let startDate = dateForSlot(startSlot)
            let endDate = dateForSlot(creationEndSlot)
            onCreatePersonalEvent(startDate, endDate)
          }
          Button(LocalizedStrings.Calendar.groupSchedule) {
            guard let startSlot = creationStartSlot else { return }
            let startDate = dateForSlot(startSlot)
            let endDate = dateForSlot(creationEndSlot)
            onCreatePromise(startDate, endDate)
          }
          Button(LocalizedStrings.Common.cancel, role: .cancel) {}
        }
      )
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 5, coordinateSpace: .named("timeline"))
          .onChanged { value in
            let duration = dragAnchorEnd - dragAnchorStart
            let delta = Int(round((value.location.y - value.startLocation.y) / (hourHeight / 6)))
            let newStart = max(0, min(144 - duration, dragAnchorStart + delta))
            if newStart != creationStartSlot {
              selectionFeedback.selectionChanged()
              creationStartSlot = newStart
              creationEndSlot = newStart + duration
            }
          }
          .onEnded { value in
            let duration = dragAnchorEnd - dragAnchorStart
            let delta = Int(round((value.location.y - value.startLocation.y) / (hourHeight / 6)))
            let newStart = max(0, min(144 - duration, dragAnchorStart + delta))
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
            let slot = Int(round(value.location.y / (hourHeight / 6)))
            let newEnd = max((creationStartSlot ?? 0) + 6, min(144, slot))
            if newEnd != creationEndSlot {
              selectionFeedback.selectionChanged()
              creationEndSlot = newEnd
            }
          }
          .onEnded { value in
            let slot = Int(round(value.location.y / (hourHeight / 6)))
            dragAnchorEnd = max((creationStartSlot ?? 0) + 6, min(144, slot))
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

  // MARK: - Current Time Indicator

  private var isToday: Bool {
    Calendar.promiseDisplay.isDateInToday(displayDate)
  }

  private var currentTimeIndicator: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let y = yOffset(for: context.date)

      HStack(spacing: 0) {
        Color.clear
          .frame(width: timeLabelWidth - 4, height: 8)

        Circle()
          .fill(Color.pmerror.n500)
          .frame(width: 8, height: 8)

        Rectangle()
          .fill(Color.pmerror.n500)
          .frame(height: 1)
      }
      .offset(y: y - 4)
    }
    .frame(height: totalHeight, alignment: .top)
  }

  // MARK: - Context Menu Preview

  private func contextMenuPreview(for item: CalendarFeature.ScheduleItem) -> some View {
    let color = barColor(for: item)
    let cardShape = RoundedRectangle(cornerRadius: 10)

    return HStack(alignment: .top, spacing: 8) {
      // 시간 레이블
      VStack(spacing: 0) {
        Text(timeString(for: item.startAt))
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(color)
        Spacer(minLength: 0)
        if let endAt = item.endAt {
          Text(timeString(for: endAt))
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(color.opacity(0.6))
        }
      }
      .frame(width: 36)

      // 카드
      HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 5) {
            if !item.displayEmoji.isEmpty {
              Text(item.displayEmoji)
                .font(.system(size: 16))
            }
            Text(item.title)
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
          }

          if let name = groupName(for: item) {
            Text(name)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          if let location = itemLocation(for: item), !location.isEmpty {
            HStack(spacing: 3) {
              Image(systemName: "location.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.pmgray.n400)
              Text(location)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }

          if let desc = itemDescription(for: item), !desc.isEmpty {
            Text(desc)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }

          let imageUrls = itemImageUrls(for: item)
          if !imageUrls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(imageUrls.prefix(4), id: \.self) { urlString in
                  if let url = URL(string: urlString) {
                    ScheduleItemThumbnail(url: url, size: 56)
                  }
                }
                if imageUrls.count > 4 {
                  Text("+\(imageUrls.count - 4)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        Spacer(minLength: 0)
      }
      .background(.ultraThinMaterial, in: cardShape)
      .overlay(alignment: .leading) {
        RoundedRectangle(cornerRadius: 10)
          .fill(color)
          .frame(width: 4)
          .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 10, bottomLeadingRadius: 10,
            bottomTrailingRadius: 0, topTrailingRadius: 0
          ))
      }
      .clipShape(cardShape)
    }
    .padding(12)
    .frame(width: 280, alignment: .leading)
  }

  // MARK: - Slot Helpers

  /// 일정 아이템의 시작 시간을 10분 슬롯으로 변환
  private func slotForItem(_ item: CalendarFeature.ScheduleItem) -> Int {
    let start = clampedStartAt(for: item)
    let cal = Calendar.promiseDisplay
    let hour = cal.component(.hour, from: start)
    let minute = cal.component(.minute, from: start)
    return hour * 6 + minute / 10
  }

  private func dateForSlot(_ slot: Int) -> Date {
    let hour = slot / 6
    let minute = (slot % 6) * 10
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
              .fill(Color(.separator).opacity(0.7))
              .frame(height: 1)
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
    _ item: CalendarFeature.ScheduleItem,
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

    // 높이 기반 표시 단계: compact(<64) → normal(64~) → detail(100~) → rich(140~)
    let showDetails = blockHeight >= 100
    let showRich = blockHeight >= 140

    return Button {
      onScheduleItemTapped(item)
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 0) {
          VStack(alignment: .leading, spacing: 2) {
            // Row 1: 이모지 + 제목
            HStack(spacing: 5) {
              if !item.displayEmoji.isEmpty {
                Text(item.displayEmoji)
                  .font(.system(size: isCompact ? 14 : 16))
              }

              Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            }

            if !isCompact {
              // Row 2: 그룹명 + 응답 상태
              HStack(spacing: 5) {
                if let name = groupName(for: item) {
                  Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                if case .promise(let p) = item,
                   p.responseStatus(currentUserId: currentUserId) == .needResponse {
                  Text("응답 필요")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.pmwarning.n500)
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

              // Row 4: 상세설명 (detail 이상에서 표시)
              if showDetails, let desc = itemDescription(for: item), !desc.isEmpty {
                Text(desc)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                  .lineLimit(showRich ? 3 : 1)
              }
            }
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 6)

          Spacer(minLength: 0)
        }

        // 이미지 썸네일 (detail 이상, 하단에 배치)
        if showDetails {
          let imageUrls = itemImageUrls(for: item)
          if !imageUrls.isEmpty {
            let thumbSize: CGFloat = showRich ? 72 : 48
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(imageUrls.prefix(4), id: \.self) { urlString in
                  if let url = URL(string: urlString) {
                    ScheduleItemThumbnail(url: url, size: thumbSize)
                      .onTapGesture {
                        previewImageUrls = imageUrls
                      }
                  }
                }
                if imageUrls.count > 4 {
                  Text("+\(imageUrls.count - 4)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: thumbSize, height: thumbSize)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
              }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
          }
        }

        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
    .contextMenu {
      switch item {
      case .promise(let promise):
        // Host인 경우 수정/삭제 옵션 (PromiseCard 패턴)
        if promise.isHost(userId: currentUserId) {
          Button {
            onEditScheduleItem?(item)
          } label: {
            Label(LocalizedStrings.PromiseCard.editPromise, systemImage: "pencil")
          }

          Button(role: .destructive) {
            onDeleteScheduleItem?(item)
          } label: {
            Label(LocalizedStrings.PromiseCard.deletePromise, systemImage: "trash")
          }
        }

        // 항상 표시
        Button {
          onScheduleItemTapped(item)
        } label: {
          Label(LocalizedStrings.PromiseCard.viewDetail, systemImage: "info.circle")
        }

        Button {
          onShareScheduleItem?(item)
        } label: {
          Label(LocalizedStrings.PromiseCard.share, systemImage: "square.and.arrow.up")
        }

      case .personalEvent:
        Button {
          onScheduleItemTapped(item)
        } label: {
          Label(LocalizedStrings.Personal.viewDetail, systemImage: "info.circle")
        }

        Button {
          onEditScheduleItem?(item)
        } label: {
          Label("수정", systemImage: "pencil")
        }

        Button(role: .destructive) {
          onDeleteScheduleItem?(item)
        } label: {
          Label(LocalizedStrings.Shared.deleteEvent, systemImage: "trash")
        }

      case .calendarEvent:
        Button {
          onScheduleItemTapped(item)
        } label: {
          Label(LocalizedStrings.PromiseCard.viewDetail, systemImage: "info.circle")
        }

      case .recurringPersonalEvent:
        Button {
          onScheduleItemTapped(item)
        } label: {
          Label(LocalizedStrings.Personal.viewDetail, systemImage: "info.circle")
        }
      }
    } preview: {
      contextMenuPreview(for: item)
    }
  }

  // MARK: - Event Time Label

  private func eventTimeLabel(_ item: CalendarFeature.ScheduleItem) -> some View {
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
      .stroke(Color(.separator).opacity(0.6), style: StrokeStyle(lineWidth: 0.75, dash: [4, 3]))
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
  private func clampedStartAt(for item: CalendarFeature.ScheduleItem) -> Date {
    max(item.startAt, dayStart)
  }

  /// multi-day 일정의 종료 시간을 해당 날짜로 클램핑
  private func clampedEndAt(for item: CalendarFeature.ScheduleItem) -> Date {
    min(item.effectiveEndAt, dayEnd)
  }

  /// 이전 날짜에서 이어지는 일정인지
  private func continuesFromPreviousDay(_ item: CalendarFeature.ScheduleItem) -> Bool {
    item.startAt < dayStart
  }

  /// 다음 날짜로 이어지는 일정인지
  private func continuesToNextDay(_ item: CalendarFeature.ScheduleItem) -> Bool {
    item.effectiveEndAt > dayEnd
  }

  // MARK: - Block Height Constants

  private enum BlockHeight {
    static let detailThreshold: CGFloat = 100
    static let richThreshold: CGFloat = 140
    static let baseContent: CGFloat = 52       // emoji + title + group + padding
    static let locationRow: CGFloat = 18
    static let richDescriptionRow: CGFloat = 44
    static let compactDescriptionRow: CGFloat = 18
    static let richImageSize: CGFloat = 72
    static let compactImageSize: CGFloat = 48
    static let imageSpacing: CGFloat = 8
  }

  /// 일정 블록 높이 (duration 기반 + 콘텐츠 인식, 최소 blockMinHeight)
  private func blockHeight(for item: CalendarFeature.ScheduleItem) -> CGFloat {
    let start = clampedStartAt(for: item)
    let end = clampedEndAt(for: item)
    let duration = end.timeIntervalSince(start)
    let hours = duration / 3600.0
    let calculatedHeight = CGFloat(hours) * hourHeight
    let timeBasedHeight = max(blockMinHeight, calculatedHeight)

    // 콘텐츠 인식: detail 표시 시 콘텐츠가 잘리지 않도록 최소 높이 보장
    guard timeBasedHeight >= BlockHeight.detailThreshold else { return timeBasedHeight }

    let hasDesc = (itemDescription(for: item) ?? "").isEmpty == false
    let hasImage = itemFirstImageUrl(for: item) != nil
    let isRich = timeBasedHeight >= BlockHeight.richThreshold

    var contentMinHeight: CGFloat = BlockHeight.baseContent
    if let loc = itemLocation(for: item), !loc.isEmpty {
      contentMinHeight += BlockHeight.locationRow
    }
    if hasDesc {
      contentMinHeight += isRich ? BlockHeight.richDescriptionRow : BlockHeight.compactDescriptionRow
    }
    if hasImage {
      contentMinHeight += (isRich ? BlockHeight.richImageSize : BlockHeight.compactImageSize) + BlockHeight.imageSpacing
    }

    return max(timeBasedHeight, contentMinHeight)
  }

  private func barColor(for item: CalendarFeature.ScheduleItem) -> Color {
    switch item {
    case .promise(let p):
      return groupColorMap[p.groupId] ?? Color.pmindigo.n500
    case .personalEvent:
      return Color.pminfo.n500
    case .calendarEvent(let e):
      return e.calendarColor
    case .recurringPersonalEvent:
      return Color.pminfo.n500
    }
  }

  private func groupName(for item: CalendarFeature.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.group?.name
    case .personalEvent:
      return nil
    case .calendarEvent(let e):
      return e.calendarName
    case .recurringPersonalEvent:
      return nil
    }
  }

  @ViewBuilder
  private func weatherBadge(for item: CalendarFeature.ScheduleItem) -> some View {
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
    case .calendarEvent:
      // CalendarEvent는 날씨 캐시 미지원
      EmptyView()
    case .recurringPersonalEvent:
      // 반복 일정은 날씨 캐시 미지원
      EmptyView()
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
    case .expired:      return Color.pmgray.n400
    case .responded:    return Color.pmwarning.n600
    case .confirmed:    return Color.pmsuccess.n500
    case .failed:       return Color.pmgray.n400
    }
  }

  private func statusText(for status: PromiseResponseStatus) -> String {
    switch status {
    case .needResponse: return "응답 필요"
    case .expired:      return "마감됨"
    case .responded:    return "투표 완료"
    case .confirmed:    return "확정"
    case .failed:       return "미확정"
    }
  }

  private func itemLocation(for item: CalendarFeature.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.location?.name
    case .personalEvent(let e):
      return e.location?.name
    case .calendarEvent(let e):
      return e.location
    case .recurringPersonalEvent(let e):
      return e.location?.name
    }
  }

  private func itemDescription(for item: CalendarFeature.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.description
    case .personalEvent(let e):
      return e.description
    case .calendarEvent:
      return nil
    case .recurringPersonalEvent:
      return nil
    }
  }

  private func itemImageUrls(for item: CalendarFeature.ScheduleItem) -> [String] {
    switch item {
    case .promise(let p):
      return p.imageUrls
    case .personalEvent(let e):
      return e.imageUrls
    case .calendarEvent:
      return []
    case .recurringPersonalEvent:
      return []
    }
  }

  private func itemFirstImageUrl(for item: CalendarFeature.ScheduleItem) -> URL? {
    switch item {
    case .promise(let p):
      return p.imageUrls.first.flatMap { URL(string: $0) }
    case .personalEvent(let e):
      return e.imageUrls.first.flatMap { URL(string: $0) }
    case .calendarEvent:
      return nil
    case .recurringPersonalEvent:
      return nil
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

// MARK: - Schedule Item Thumbnail

/// 일정 이미지 썸네일 (CalendarFeature 공통, Nuke ImageLoader 사용)
struct ScheduleItemThumbnail: View {
  let url: URL
  let size: CGFloat
  var placeholder: Color = .clear

  @State private var loadedImage: UIImage?

  var body: some View {
    Group {
      if let image = loadedImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        placeholder
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .task(id: url) {
      loadedImage = await ImageLoader.loadImage(from: url, retryCount: 1)
    }
  }
}

// MARK: - Preview

#Preview("일정 있음") {
  let calendar = Calendar.promiseDisplay
  let today = Date()

  let items: [CalendarFeature.ScheduleItem] = [
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
    .calendarEvent(CalendarEvent(
      id: "3",
      title: "팀 회의",
      startDate: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today)!,
      endDate: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: today)!,
      location: "회의실 A",
      isAllDay: false,
      calendarName: "업무",
      calendarColorHex: "#007AFF"
    )),
  ]

  CalendarDayTimelineView(
    scheduleItems: items,
    displayDate: today,
    onScheduleItemTapped: { _ in },
    onEditScheduleItem: nil,
    onCreatePersonalEvent: { _, _ in },
    onCreatePromise: { _, _ in },
    onDeleteScheduleItem: nil,
    onShareScheduleItem: nil,
    onPastTimeBlocked: nil,
    currentUserId: "host1",
    weatherCache: [:],
    groupColorMap: ["g1": Color.pmindigo.n500],
    zoomState: TimelineZoomState()
  )
  .auroraBackground()
}

#Preview("일정 없음") {
  CalendarDayTimelineView(
    scheduleItems: [],
    displayDate: Date(),
    onScheduleItemTapped: { _ in },
    onEditScheduleItem: nil,
    onCreatePersonalEvent: { _, _ in },
    onCreatePromise: { _, _ in },
    onDeleteScheduleItem: nil,
    onShareScheduleItem: nil,
    onPastTimeBlocked: nil,
    currentUserId: "preview",
    weatherCache: [:],
    groupColorMap: [:],
    zoomState: TimelineZoomState()
  )
  .auroraBackground()
}
