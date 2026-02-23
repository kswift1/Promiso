import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Calendar Month Grid View

/// 단일 월의 요일 헤더 + 날짜 그리드
struct CalendarMonthGridView: View {
  let days: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
  private let weekdays = [
    LocalizedStrings.Calendar.weekdayMon,
    LocalizedStrings.Calendar.weekdayTue,
    LocalizedStrings.Calendar.weekdayWed,
    LocalizedStrings.Calendar.weekdayThu,
    LocalizedStrings.Calendar.weekdayFri,
    LocalizedStrings.Calendar.weekdaySat,
    LocalizedStrings.Calendar.weekdaySun,
  ]

  var body: some View {
    VStack(spacing: 6) {
      // Weekday header
      LazyVGrid(columns: columns, spacing: 0) {
        ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
          Text(day)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.pmgray.n400)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
        }
      }

      // Day grid
      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(days) { day in
          Button {
            if day.isCurrentMonth {
              onDateSelected(day.date)
            }
          } label: {
            OverlayCalendarDayCell(day: day)
          }
          .buttonStyle(.plain)
          .disabled(!day.isCurrentMonth)
        }
      }
    }
  }
}
