import SwiftUI
import ResourceKit

// MARK: - Overlay Calendar Day Cell

struct OverlayCalendarDayCell: View {
  let day: OverlayCalendarModels.DayItem
  var showSelectedHighlight: Bool = true

  private let maxVisibleDots = 3

  private var textColor: Color {
    if day.isSelected { return .white }
    if !day.isCurrentMonth { return Color.pmgray.n300 }
    if day.isToday { return Color.pmindigo.n500 }
    if day.isHoliday { return .red.opacity(0.8) }
    return .primary
  }

  /// 중복 색상 제거한 인디케이터
  private var uniqueColorIndicators: [OverlayCalendarModels.ScheduleIndicator] {
    var seen = Set<String>()
    return day.scheduleIndicators.filter { indicator in
      let key = indicator.color.description
      if seen.contains(key) { return false }
      seen.insert(key)
      return true
    }
  }

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        if showSelectedHighlight && day.isSelected {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 32, height: 32)
        } else if day.isToday && !day.isSelected {
          Circle()
            .stroke(Color.pmindigo.n500, lineWidth: 1.5)
            .frame(width: 32, height: 32)
        }

        Text("\(day.dayNumber)")
          .font(.system(size: 13, weight: day.isSelected || day.isToday ? .bold : .regular))
          .foregroundStyle(textColor)
          .contentTransition(.numericText())
      }
      .frame(width: 32, height: 32)

      // 일정 인디케이터 (컬러 dot)
      if day.isCurrentMonth && !day.scheduleIndicators.isEmpty {
        HStack(spacing: 3) {
          ForEach(uniqueColorIndicators.prefix(maxVisibleDots)) { indicator in
            Circle()
              .fill(indicator.color)
              .frame(width: 5, height: 5)
          }
        }
        .frame(height: 8)
      } else {
        Spacer()
          .frame(height: 8)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  HStack(spacing: 8) {
    OverlayCalendarDayCell(
      day: .init(
        date: Date(), dayNumber: 6, isSelected: true, scheduleCount: 3,
        scheduleIndicators: [
          .init(id: "1", color: .red, title: "팀 미팅"),
          .init(id: "2", color: .blue, title: "점심 일정"),
          .init(id: "3", color: .green, title: "저녁"),
        ]
      )
    )
    OverlayCalendarDayCell(
      day: .init(
        date: Date(), dayNumber: 7, isToday: true, scheduleCount: 1,
        scheduleIndicators: [
          .init(id: "1", color: .orange, title: "회의")
        ]
      )
    )
    OverlayCalendarDayCell(
      day: .init(date: Date(), dayNumber: 8, scheduleCount: 0)
    )
    OverlayCalendarDayCell(
      day: .init(date: Date(), dayNumber: 31, isCurrentMonth: false)
    )
  }
  .padding()
}
