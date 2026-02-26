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
  let onTap: () -> Void

  private let maxVisibleIndicators = 2

  // 캐싱된 날짜 숫자
  private var dayNumber: String {
    String(sharedCalendarForIndicator.component(.day, from: date))
  }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 2) {
        // 날짜 원형 배경 + 숫자
        ZStack {
          if isSelected {
            Circle()
              .fill(Color.pmindigo.n500)
              .matchedGeometryEffect(id: selectionId, in: namespace)
          } else if isToday {
            Circle()
              .stroke(Color.pmindigo.n500, lineWidth: 2)
          }

          Text(dayNumber)
            .font(.system(size: 14, weight: isSelected || isToday ? .bold : .regular))
            .foregroundColor(textColor)
            .contentTransition(.numericText())
        }
        .frame(width: 36, height: 36)

        // 인디케이터 분기
        if isCompactMode {
          compactIndicatorArea
            .frame(height: 8)
        } else if showAllIndicators {
          expandedIndicatorArea
        } else {
          indicatorArea
            .frame(height: 22)
            .clipped()
        }
      }
      .frame(height: showAllIndicators ? nil : (isCompactMode ? 46 : 62))
      .frame(minHeight: showAllIndicators ? 46 : nil, alignment: .top)
      .frame(maxHeight: showAllIndicators ? .infinity : nil, alignment: .top)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .top)
    .opacity(isCurrentMonth ? 1 : 0.3)
  }

  // MARK: - Indicator Views

  @ViewBuilder
  private var compactIndicatorArea: some View {
    if isCurrentMonth && !scheduleIndicators.isEmpty {
      HStack(spacing: 3) {
        ForEach(uniqueColorIndicators.prefix(3)) { indicator in
          Circle()
            .fill(indicator.color)
            .frame(width: 5, height: 5)
        }
      }
    } else {
      Color.clear
    }
  }

  /// 고유 색상별 인디케이터 (중복 색상 제거 — description으로 판별)
  private var uniqueColorIndicators: [CalendarFeature.ScheduleIndicator] {
    var seenDescriptions = Set<String>()
    return scheduleIndicators.filter { indicator in
      let key = indicator.color.description
      if seenDescriptions.contains(key) { return false }
      seenDescriptions.insert(key)
      return true
    }
  }

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

  @ViewBuilder
  private var expandedIndicatorArea: some View {
    if isCurrentMonth && !scheduleIndicators.isEmpty {
      VStack(spacing: 3) {
        ForEach(scheduleIndicators) { indicator in
          HStack(alignment: .top, spacing: 2) {
            RoundedRectangle(cornerRadius: 1)
              .fill(indicator.color)
              .frame(width: 2, height: 10)

            Text(indicator.title)
              .font(.system(size: 7, weight: .medium))
              .foregroundStyle(Color.secondary)
              .lineLimit(2)
              .truncationMode(.tail)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.horizontal, 3)
          .padding(.vertical, 2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .adaptiveGlassBackground(cornerRadius: 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      Color.clear.frame(height: 0)
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
