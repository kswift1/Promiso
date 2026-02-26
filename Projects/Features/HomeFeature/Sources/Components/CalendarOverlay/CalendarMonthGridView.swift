import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Calendar Month Grid View

/// 단일 월 날짜 그리드 (요일 헤더는 상위 뷰에서 별도 표시)
struct CalendarMonthGridView: View {
  let days: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

  var body: some View {
    LazyVGrid(columns: columns, spacing: 6) {
      ForEach(days) { day in
        if day.isCurrentMonth {
          Button {
            onDateSelected(day.date)
          } label: {
            OverlayCalendarDayCell(day: day)
              .frame(maxHeight: .infinity, alignment: .top)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .contextMenu {
            Button {
              onDateSelected(day.date)
            } label: {
              Label("일정 보기", systemImage: "calendar")
            }
          } preview: {
            DaySchedulePreviewView(day: day)
          }
        } else {
          OverlayCalendarDayCell(day: day)
            .frame(maxHeight: .infinity, alignment: .top)
        }
      }
    }
  }
}
