// MARK: - CalendarIndicatorDayCell.swift
// 인디케이터 바를 포함한 CalendarFeature용 날짜 셀 컴포넌트

import SwiftUI
import ResourceKit
import PromisoShared

// MARK: - Shared Calendar Instance

private let sharedCalendarForIndicator = Calendar.current

// MARK: - Calendar Indicator Day Cell

/// 인디케이터 바(색상 바 + 축약 제목)를 표시하는 CalendarFeature 전용 날짜 셀
struct CalendarIndicatorDayCell: View {
  let date: Date
  let isSelected: Bool
  let isToday: Bool
  let isCurrentMonth: Bool
  let scheduleIndicators: [CalendarFeature.ScheduleIndicator]
  let namespace: Namespace.ID
  let selectionId: String
  var isCompactMode: Bool = false
  var showAllIndicators: Bool = false  // true면 모든 인디케이터 표시 (expanded 전용)
  var holidayName: String? = nil
  let onTap: () -> Void
  var onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil
  var onDayCreatePersonalEvent: ((Date) -> Void)? = nil
  var onDayCreatePromise: ((Date) -> Void)? = nil

  private let maxVisibleIndicators = 2

  // 캐싱된 날짜 숫자
  private var dayNumber: String {
    String(sharedCalendarForIndicator.component(.day, from: date))
  }

  var body: some View {
    if isCompactMode || showAllIndicators {
      // 월간 모드: compact ↔ expanded morphing
      morphingBody
    } else {
      // 주간 모드: 기존 normal bar (변경 없음)
      normalBarBody
    }
  }

  // MARK: - Normal Bar Body (주간 모드)

  private var normalBarBody: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        ZStack {
          if isSelected {
            Circle()
              .fill(Color.pmindigo.n500)
              .matchedGeometryEffect(id: selectionId, in: namespace)
          } else if isToday {
            Circle()
              .strokeBorder(Color.pmindigo.n500, lineWidth: 2)
          }
          Text(dayNumber)
            .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
            .foregroundColor(textColor)
            .contentTransition(.numericText())
        }
        .frame(width: 36, height: 36)

        indicatorArea
          .frame(height: 22)
          .clipped()
      }
      .frame(height: 62)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .top)
    .opacity(isCurrentMonth ? 1 : 0.3)
  }

  // MARK: - Morphing Body (월간 모드)

  private var morphingBody: some View {
    let isCompact = isCompactMode && !showAllIndicators

    return VStack(spacing: 2) {
      // 날짜 원형 — 항상 동일
      ZStack {
        if isSelected {
          Circle()
            .fill(Color.pmindigo.n500)
            .matchedGeometryEffect(id: selectionId, in: namespace)
        } else if isToday {
          Circle()
            .strokeBorder(Color.pmindigo.n500, lineWidth: 2)
        }
        Text(dayNumber)
          .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
          .foregroundColor(textColor)
          .contentTransition(.numericText())
      }
      .frame(width: 36, height: 36)
      .contentShape(Circle())
      .onTapGesture { onTap() }
      .contextMenu {
        Button {
          onDayCreatePersonalEvent?(date)
        } label: {
          Label(LocalizedStrings.Calendar.addPersonalEvent, systemImage: "plus.circle")
        }
        Button {
          onDayCreatePromise?(date)
        } label: {
          Label(LocalizedStrings.Calendar.createPromise, systemImage: "person.2.circle")
        }
      } preview: {
        ExpandedDayPreviewView(date: date, indicators: scheduleIndicators)
      }

      // 공휴일 이름 (expanded 모드에서만)
      if showAllIndicators, let name = holidayName, isCurrentMonth {
        Text(name)
          .font(.system(size: 7, weight: .semibold))
          .foregroundStyle(.red.opacity(0.8))
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(maxWidth: .infinity)
      }

      // Morphing 인디케이터 영역
      morphingIndicatorSection(isCompact: isCompact)

      // Expanded 하단 스페이서 + 컨텍스트 메뉴
      if showAllIndicators {
        Spacer(minLength: 0)
          .contentShape(Rectangle())
          .onTapGesture { onTap() }
          .contextMenu {
            Button {
              onDayCreatePersonalEvent?(date)
            } label: {
              Label(LocalizedStrings.Calendar.addPersonalEvent, systemImage: "plus.circle")
            }
            Button {
              onDayCreatePromise?(date)
            } label: {
              Label(LocalizedStrings.Calendar.createPromise, systemImage: "person.2.circle")
            }
          } preview: {
            ExpandedDayPreviewView(date: date, indicators: scheduleIndicators)
          }
      }
    }
    .frame(height: showAllIndicators ? nil : (isCompact ? 46 : 62))
    .frame(minHeight: showAllIndicators ? 46 : nil, alignment: .top)
    .frame(maxHeight: showAllIndicators ? .infinity : nil, alignment: .top)
    .frame(maxWidth: .infinity, alignment: .top)
    .opacity(isCurrentMonth ? 1 : 0.3)
    .contentShape(Rectangle())
    .onTapGesture { onTap() }
  }

  @ViewBuilder
  private func morphingIndicatorSection(isCompact: Bool) -> some View {
    if isCurrentMonth && !scheduleIndicators.isEmpty {
      let displayCount = scheduleIndicators.count
      let layout = isCompact
        ? AnyLayout(HStackLayout(spacing: 3))
        : AnyLayout(VStackLayout(spacing: 3))

      layout {
        ForEach(Array(scheduleIndicators.prefix(displayCount))) { indicator in
          morphingIndicatorItem(indicator, isCompact: isCompact)
        }
      }
      .frame(height: isCompact ? 8 : nil)
      .frame(maxWidth: isCompact ? nil : .infinity, alignment: isCompact ? .center : .leading)
    } else {
      Color.clear.frame(height: isCompact ? 8 : 0)
    }
  }

  private func morphingIndicatorItem(
    _ indicator: CalendarFeature.ScheduleIndicator,
    isCompact: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: isCompact ? 0 : 2) {
      // 색상 도형: Circle(5×5) ↔ RoundedRect(2×10)
      RoundedRectangle(cornerRadius: isCompact ? 2.5 : 1)
        .fill(indicator.color)
        .frame(width: isCompact ? 5 : 2, height: isCompact ? 5 : 10)

      // 제목: compact에서 0 width + 0 opacity
      Text(indicator.title)
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(Color.secondary)
        .lineLimit(showAllIndicators ? 2 : 1)
        .truncationMode(.tail)
        .fixedSize(horizontal: false, vertical: !isCompact)
        .opacity(isCompact ? 0 : 1)
        .frame(maxWidth: isCompact ? 0 : .infinity, alignment: .leading)
        .clipped()
    }
    .padding(.horizontal, showAllIndicators ? 3 : 0)
    .padding(.vertical, showAllIndicators ? 2 : 0)
    .frame(maxWidth: isCompact ? nil : .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 4)
        .fill(.ultraThinMaterial)
        .opacity(showAllIndicators ? 1 : 0)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      onIndicatorTapped?(indicator)
    }
    .contextMenu {
      Button {
        onIndicatorTapped?(indicator)
      } label: {
        Label(LocalizedStrings.PromiseCard.viewDetail, systemImage: "info.circle")
      }
    } preview: {
      IndicatorPreviewView(indicator: indicator)
    }
  }

  // MARK: - Indicator Views

  @ViewBuilder
  private var indicatorArea: some View {
    if isCurrentMonth && !scheduleIndicators.isEmpty {
      VStack(spacing: 1) {
        ForEach(scheduleIndicators.prefix(maxVisibleIndicators)) { indicator in
          HStack(alignment: .center, spacing: 2) {
            RoundedRectangle(cornerRadius: 1)
              .fill(indicator.color)
              .frame(width: 2)

            Text(indicator.title)
              .font(.system(size: 7, weight: .medium))
              .foregroundStyle(Color.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .frame(height: 10)
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        if scheduleIndicators.count > maxVisibleIndicators {
          Text("+\(scheduleIndicators.count - maxVisibleIndicators)")
            .font(.system(size: 7, weight: .medium))
            .foregroundStyle(Color.secondary)
            .padding(.leading, 4)
        }
      }
      .frame(width: 36, alignment: .leading)
    } else {
      Color.clear
    }
  }

  // MARK: - Computed Properties

  private var textColor: Color {
    if isSelected {
      return .white
    }
    if isToday {
      return Color.pmindigo.n500
    }
    if !isCurrentMonth {
      return .secondary.opacity(0.5)
    }

    // 공휴일이면 빨간색 (일요일과 같은 색)
    if holidayName != nil {
      return .red.opacity(0.8)
    }

    // 주말 색상
    let weekday = sharedCalendarForIndicator.component(.weekday, from: date)
    if weekday == 1 { // 일요일
      return .red.opacity(0.8)
    }
    if weekday == 7 { // 토요일
      return .blue.opacity(0.8)
    }

    return .primary
  }
}

// MARK: - Indicator Preview View

private struct IndicatorPreviewView: View {
  let indicator: CalendarFeature.ScheduleIndicator

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 상단: 이모지 + 제목 + 우측 그룹/개인
      HStack(alignment: .top, spacing: 8) {
        if let emoji = indicator.emoji {
          Text(emoji)
            .font(.system(size: 28))
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(indicator.title)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(2)
        }

        Spacer(minLength: 0)

        indicatorSourceLabel
      }

      // 시간
      Label(timeRangeString, systemImage: "clock")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)

      // 장소
      if let locationName = indicator.locationName {
        Label(locationName, systemImage: "mappin.and.ellipse")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      // 설명
      if let description = indicator.description, !description.isEmpty {
        Text(description)
          .font(.system(size: 13))
          .foregroundStyle(.tertiary)
          .lineLimit(3)
      }

      // 이미지 썸네일
      if !indicator.imageUrls.isEmpty {
        HStack(spacing: 6) {
          ForEach(indicator.imageUrls.prefix(3), id: \.self) { urlString in
            AsyncImage(url: URL(string: urlString)) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            } placeholder: {
              Color(.systemGray5)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }
        .padding(.top, 2)
      }
    }
    .padding(16)
    .frame(width: 280, alignment: .leading)
    .background(Color(.systemBackground))
  }

  // MARK: - Source Label

  @ViewBuilder
  private var indicatorSourceLabel: some View {
    switch indicator.sourceType {
    case .promise:
      if let groupName = indicator.groupName {
        HStack(spacing: 3) {
          if let imageUrl = indicator.groupImageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
              image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
              Image(systemName: "person.2.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            }
            .frame(width: 14, height: 14)
            .clipShape(Circle())
          } else {
            Image(systemName: "person.2.fill")
              .font(.system(size: 8))
              .foregroundStyle(Color.pmindigo.n500)
          }
          Text(groupName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.pmindigo.n500)
            .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.pmindigo.n500.opacity(0.08), in: Capsule())
      } else {
        EmptyView()
      }

    case .personalEvent:
      HStack(spacing: 3) {
        Image(systemName: "person.fill")
          .font(.system(size: 8))
          .foregroundStyle(Color.pminfo.n500)
        Text(LocalizedStrings.Calendar.indicatorPersonal)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.pminfo.n500)
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.pminfo.n500.opacity(0.08), in: Capsule())

    case .calendarEvent:
      HStack(spacing: 3) {
        Image(systemName: "calendar")
          .font(.system(size: 8))
          .foregroundStyle(.gray)
        Text(LocalizedStrings.Calendar.indicatorCalendar)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.gray)
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.gray.opacity(0.08), in: Capsule())

    case .unknown:
      EmptyView()
    }
  }

  private var timeRangeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    let start = formatter.string(from: indicator.startAt)
    if let endAt = indicator.endAt {
      let endFormatter = DateFormatter()
      endFormatter.dateFormat = "HH:mm"
      return "\(start) ~ \(endFormatter.string(from: endAt))"
    }
    return start
  }
}

// MARK: - Expanded Day Preview View

private struct ExpandedDayPreviewView: View {
  let date: Date
  let indicators: [CalendarFeature.ScheduleIndicator]

  private var calendar: Calendar { Calendar.current }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더: 날짜 + 요일 + 일정 수
      HStack(alignment: .firstTextBaseline) {
        Text(dateHeaderString)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.primary)

        if calendar.isDateInToday(date) {
          Text(LocalizedStrings.Common.today)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.pmindigo.n500, in: Capsule())
        }

        Spacer()

        if !indicators.isEmpty {
          Text(LocalizedStrings.Calendar.indicatorEventCount(indicators.count))
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }

      if indicators.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "calendar.badge.checkmark")
            .font(.system(size: 28, weight: .light))
            .foregroundStyle(.secondary.opacity(0.6))
          Text(LocalizedStrings.Calendar.noPromises)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 16)
      } else {
        VStack(spacing: 8) {
          ForEach(indicators) { indicator in
            dayPreviewCard(indicator)
          }
        }
      }
    }
    .padding(16)
    .frame(width: 300, alignment: .leading)
    .background(Color(.systemBackground))
  }

  // MARK: - Card

  private func dayPreviewCard(_ indicator: CalendarFeature.ScheduleIndicator) -> some View {
    HStack(alignment: .top, spacing: 8) {
      // 컬러 바
      RoundedRectangle(cornerRadius: 2)
        .fill(indicator.color)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 4) {
        // 상단: 이모지 + 제목 + 우측 그룹/개인 라벨
        HStack(alignment: .top, spacing: 6) {
          if let emoji = indicator.emoji {
            Text(emoji)
              .font(.system(size: 16))
          }

          Text(indicator.title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

          Spacer(minLength: 0)

          sourceLabel(for: indicator)
        }

        // 시간
        Label(timeString(for: indicator), systemImage: "clock")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

        // 장소
        if let locationName = indicator.locationName {
          Label(locationName, systemImage: "mappin.and.ellipse")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        // 설명
        if let description = indicator.description, !description.isEmpty {
          Text(description)
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .lineLimit(2)
        }

        // 이미지 썸네일
        if !indicator.imageUrls.isEmpty {
          HStack(spacing: 4) {
            ForEach(indicator.imageUrls.prefix(3), id: \.self) { urlString in
              AsyncImage(url: URL(string: urlString)) { image in
                image
                  .resizable()
                  .aspectRatio(contentMode: .fill)
              } placeholder: {
                Color(.systemGray5)
              }
              .frame(width: 40, height: 40)
              .clipShape(RoundedRectangle(cornerRadius: 6))
            }
          }
          .padding(.top, 2)
        }
      }
    }
    .padding(8)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Source Label (우측 상단)

  @ViewBuilder
  private func sourceLabel(for indicator: CalendarFeature.ScheduleIndicator) -> some View {
    switch indicator.sourceType {
    case .promise:
      if let groupName = indicator.groupName {
        HStack(spacing: 3) {
          if let imageUrl = indicator.groupImageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
              image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
              Image(systemName: "person.2.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            }
            .frame(width: 14, height: 14)
            .clipShape(Circle())
          } else {
            Image(systemName: "person.2.fill")
              .font(.system(size: 8))
              .foregroundStyle(Color.pmindigo.n500)
          }
          Text(groupName)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.pmindigo.n500)
            .lineLimit(1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.pmindigo.n500.opacity(0.08), in: Capsule())
      } else {
        EmptyView()
      }

    case .personalEvent:
      HStack(spacing: 3) {
        Image(systemName: "person.fill")
          .font(.system(size: 8))
          .foregroundStyle(Color.pminfo.n500)
        Text(LocalizedStrings.Calendar.indicatorPersonal)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.pminfo.n500)
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.pminfo.n500.opacity(0.08), in: Capsule())

    case .calendarEvent:
      HStack(spacing: 3) {
        Image(systemName: "calendar")
          .font(.system(size: 8))
          .foregroundStyle(.gray)
        Text(LocalizedStrings.Calendar.indicatorCalendar)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.gray)
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(Color.gray.opacity(0.08), in: Capsule())

    case .unknown:
      EmptyView()
    }
  }

  // MARK: - Helpers

  private var dateHeaderString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M월 d일 EEEE"
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: date)
  }

  private func timeString(for indicator: CalendarFeature.ScheduleIndicator) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let start = formatter.string(from: indicator.startAt)
    if let endAt = indicator.endAt {
      return "\(start) ~ \(formatter.string(from: endAt))"
    }
    return start
  }
}

// MARK: - Preview

#Preview("CalendarIndicatorDayCell States") {
  @Previewable @Namespace var namespace

  let today = Date()
  let calendar = Calendar.current
  let outOfMonth = calendar.date(byAdding: .day, value: -5, to: today) ?? today

  ScrollView {
    VStack(spacing: 20) {
      // 풀 인디케이터 (expanded) 모드
      Text("Expanded 모드 (풀 바 인디케이터)")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 0) {
        // 선택됨 + 인디케이터 2개
        CalendarIndicatorDayCell(
          date: today,
          isSelected: true,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "1", color: .red, title: "팀 미팅"),
            .init(id: "2", color: .blue, title: "점심 약속")
          ],
          namespace: namespace,
          selectionId: "selected",
          onTap: {}
        )

        // 오늘 + 인디케이터 1개
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: true,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "3", color: .orange, title: "회의")
          ],
          namespace: namespace,
          selectionId: "today",
          onTap: {}
        )

        // 일반 + 인디케이터 3개 (오버플로우)
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "4", color: .green, title: "운동"),
            .init(id: "5", color: .purple, title: "스터디"),
            .init(id: "6", color: .pink, title: "저녁")
          ],
          namespace: namespace,
          selectionId: "overflow",
          onTap: {}
        )

        // 빈 날짜
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [],
          namespace: namespace,
          selectionId: "empty",
          onTap: {}
        )

        // 월 밖 날짜
        CalendarIndicatorDayCell(
          date: outOfMonth,
          isSelected: false,
          isToday: false,
          isCurrentMonth: false,
          scheduleIndicators: [
            .init(id: "7", color: .teal, title: "약속")
          ],
          namespace: namespace,
          selectionId: "out",
          onTap: {}
        )
      }
      .padding(.horizontal)

      Divider()

      // 컴팩트 dot (collapsed) 모드
      Text("Compact 모드 (dot 인디케이터)")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 0) {
        // 선택됨 + dots 3개
        CalendarIndicatorDayCell(
          date: today,
          isSelected: true,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "c1", color: .red, title: "팀 미팅"),
            .init(id: "c2", color: .blue, title: "점심 약속"),
            .init(id: "c3", color: .green, title: "저녁")
          ],
          namespace: namespace,
          selectionId: "compact-selected",
          isCompactMode: true,
          onTap: {}
        )

        // 오늘 + dot 1개
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: true,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "c4", color: .orange, title: "회의")
          ],
          namespace: namespace,
          selectionId: "compact-today",
          isCompactMode: true,
          onTap: {}
        )

        // 중복 색상 → 고유 dot만 표시
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [
            .init(id: "c5", color: .purple, title: "스터디1"),
            .init(id: "c6", color: .purple, title: "스터디2"),
            .init(id: "c7", color: .pink, title: "저녁")
          ],
          namespace: namespace,
          selectionId: "compact-dedup",
          isCompactMode: true,
          onTap: {}
        )

        // 빈 날짜
        CalendarIndicatorDayCell(
          date: today,
          isSelected: false,
          isToday: false,
          isCurrentMonth: true,
          scheduleIndicators: [],
          namespace: namespace,
          selectionId: "compact-empty",
          isCompactMode: true,
          onTap: {}
        )

        // 월 밖 날짜
        CalendarIndicatorDayCell(
          date: outOfMonth,
          isSelected: false,
          isToday: false,
          isCurrentMonth: false,
          scheduleIndicators: [
            .init(id: "c8", color: .teal, title: "약속")
          ],
          namespace: namespace,
          selectionId: "compact-out",
          isCompactMode: true,
          onTap: {}
        )
      }
      .padding(.horizontal)
    }
    .padding(.vertical)
  }
}
