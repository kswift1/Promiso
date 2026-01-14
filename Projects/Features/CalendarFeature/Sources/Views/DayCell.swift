// MARK: - DayCell.swift
// 캘린더 날짜 셀 컴포넌트

import SwiftUI
import Clients
import ResourceKit

// MARK: - Shared Calendar Instance

private let sharedCalendar = Calendar.current

// MARK: - Day Cell View

/// 캘린더 날짜 셀
struct DayCell: View {
  let date: Date
  let isSelected: Bool
  let isToday: Bool
  let isCurrentMonth: Bool
  let promiseStatuses: [PromiseResponseStatus]
  let systemEventCount: Int  // 시스템 캘린더 이벤트 개수
  let namespace: Namespace.ID
  let selectionId: String  // 주간/월간 구분용 ID
  let onTap: () -> Void

  init(
    date: Date,
    isSelected: Bool,
    isToday: Bool,
    isCurrentMonth: Bool,
    promiseStatuses: [PromiseResponseStatus],
    systemEventCount: Int = 0,
    namespace: Namespace.ID,
    selectionId: String,
    onTap: @escaping () -> Void
  ) {
    self.date = date
    self.isSelected = isSelected
    self.isToday = isToday
    self.isCurrentMonth = isCurrentMonth
    self.promiseStatuses = promiseStatuses
    self.systemEventCount = systemEventCount
    self.namespace = namespace
    self.selectionId = selectionId
    self.onTap = onTap
  }

  // 캐싱된 날짜 숫자 (Calendar.component 사용으로 DateFormatter 제거)
  private var dayNumber: String {
    String(sharedCalendar.component(.day, from: date))
  }

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 4) {
        // 날짜 숫자
        ZStack {
          // 선택 상태 배경
          if isSelected {
            Circle()
              .fill(Color.pmindigo.n500)
              .matchedGeometryEffect(id: selectionId, in: namespace)
          } else if isToday {
            Circle()
              .stroke(Color.pmindigo.n500, lineWidth: 2)
          }

          Text(dayNumber)
            .font(.system(size: 16, weight: fontWeight))
            .foregroundColor(textColor)
        }
        .frame(width: 36, height: 36)

        // 약속 상태 도트 + 시스템 이벤트 도트 (최대 3개)
        HStack(spacing: 3) {
          // 약속 도트 (최대 2개)
          ForEach(Array(promiseStatuses.prefix(2).enumerated()), id: \.offset) { _, status in
            Circle()
              .fill(isSelected ? Color.white.opacity(0.8) : status.color)
              .frame(width: 5, height: 5)
          }

          // 시스템 이벤트 도트 (회색, 1개) - 선택 상태와 무관하게 회색 유지
          if systemEventCount > 0 {
            Circle()
              .fill(Color.gray)
              .frame(width: 5, height: 5)
          }
        }
        .frame(height: 5)
        .opacity(promiseStatuses.isEmpty && systemEventCount == 0 ? 0 : 1)
      }
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity)
    .opacity(isCurrentMonth ? 1 : 0.3)
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
    let weekday = sharedCalendar.component(.weekday, from: date)
    if weekday == 1 { // 일요일
      return .red.opacity(0.8)
    }
    if weekday == 7 { // 토요일
      return .blue.opacity(0.8)
    }

    return .primary
  }

  private var fontWeight: Font.Weight {
    if isSelected || isToday {
      return .bold
    }
    return .regular
  }
}

// MARK: - Preview

#Preview("Day Cell States") {
  @Previewable @Namespace var namespace

  VStack(spacing: 20) {
    HStack(spacing: 16) {
      DayCell(
        date: Date(),
        isSelected: false,
        isToday: true,
        isCurrentMonth: true,
        promiseStatuses: [.confirmed, .responded],
        namespace: namespace,
        selectionId: "preview",
        onTap: {}
      )

      DayCell(
        date: Date(),
        isSelected: true,
        isToday: false,
        isCurrentMonth: true,
        promiseStatuses: [.needResponse],
        namespace: namespace,
        selectionId: "preview",
        onTap: {}
      )

      DayCell(
        date: Date(),
        isSelected: false,
        isToday: false,
        isCurrentMonth: true,
        promiseStatuses: [],
        namespace: namespace,
        selectionId: "preview",
        onTap: {}
      )

      DayCell(
        date: Date(),
        isSelected: false,
        isToday: false,
        isCurrentMonth: false,
        promiseStatuses: [.confirmed],
        namespace: namespace,
        selectionId: "preview",
        onTap: {}
      )
    }
    .padding()
  }
}
