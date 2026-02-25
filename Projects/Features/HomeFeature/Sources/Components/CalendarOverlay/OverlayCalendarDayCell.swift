import SwiftUI
import ResourceKit

// MARK: - Overlay Calendar Day Cell

struct OverlayCalendarDayCell: View {
  let day: OverlayCalendarModels.DayItem
  var showSelectedHighlight: Bool = true

  private let maxVisibleIndicators = 2

  private var textColor: Color {
    if day.isSelected { return .white }
    if !day.isCurrentMonth { return Color.pmgray.n300 }
    if day.isToday { return Color.pmindigo.n500 }
    return .primary
  }

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        if showSelectedHighlight && day.isSelected {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 36, height: 36)
        } else if day.isToday && !day.isSelected {
          Circle()
            .stroke(Color.pmindigo.n500, lineWidth: 1.5)
            .frame(width: 36, height: 36)
        }

        Text("\(day.dayNumber)")
          .font(.system(size: 14, weight: day.isSelected || day.isToday ? .bold : .regular))
          .foregroundStyle(textColor)
          .contentTransition(.numericText())
      }
      .frame(width: 36, height: 36)

      // 일정 인디케이터 (컬러 바 + 축약 제목)
      if day.isCurrentMonth && !day.scheduleIndicators.isEmpty {
        VStack(spacing: 1) {
          ForEach(day.scheduleIndicators.prefix(maxVisibleIndicators)) { indicator in
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

          if day.scheduleIndicators.count > maxVisibleIndicators {
            Text("+\(day.scheduleIndicators.count - maxVisibleIndicators)")
              .font(.system(size: 7, weight: .medium))
              .foregroundStyle(Color.secondary)
              .padding(.leading, 4)
          }
        }
        .frame(width: 36, alignment: .leading)
      } else {
        Spacer()
          .frame(height: 12)
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
          .init(id: "2", color: .blue, title: "점심 약속"),
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
