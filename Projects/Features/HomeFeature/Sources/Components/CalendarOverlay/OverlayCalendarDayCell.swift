import SwiftUI
import ResourceKit

// MARK: - Overlay Calendar Day Cell

struct OverlayCalendarDayCell: View {
  let day: OverlayCalendarModels.DayItem

  private var textColor: Color {
    if day.isSelected { return .white }
    if !day.isCurrentMonth { return Color.pmgray.n300 }
    if day.isToday { return Color.pmindigo.n500 }
    return .primary
  }

  var body: some View {
    VStack(spacing: 4) {
      ZStack {
        if day.isSelected {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 36, height: 36)
        } else if day.isToday {
          Circle()
            .stroke(Color.pmindigo.n500, lineWidth: 1.5)
            .frame(width: 36, height: 36)
        }

        Text("\(day.dayNumber)")
          .font(.system(size: 14, weight: day.isSelected || day.isToday ? .bold : .regular))
          .foregroundStyle(textColor)
      }
      .frame(width: 36, height: 36)

      // 일정 인디케이터 (최대 3개 점)
      if day.isCurrentMonth && day.scheduleCount > 0 {
        HStack(spacing: 3) {
          ForEach(0..<min(day.scheduleCount, 3), id: \.self) { _ in
            Circle()
              .fill(day.isSelected ? .white.opacity(0.8) : Color.pmindigo.n400)
              .frame(width: 4, height: 4)
          }
        }
        .frame(height: 4)
      } else {
        Spacer()
          .frame(height: 4)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  HStack(spacing: 8) {
    OverlayCalendarDayCell(
      day: .init(date: Date(), dayNumber: 6, isSelected: true, scheduleCount: 2)
    )
    OverlayCalendarDayCell(
      day: .init(date: Date(), dayNumber: 7, isToday: true, scheduleCount: 1)
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
