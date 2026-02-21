import Foundation
import PromisoShared

// MARK: - Overlay Calendar Models

enum OverlayCalendarModels {
  /// 오버레이 캘린더에서 표시할 날짜 셀 데이터
  struct DayItem: Identifiable, Equatable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let scheduleCount: Int

    init(
      date: Date,
      dayNumber: Int,
      isCurrentMonth: Bool = true,
      isSelected: Bool = false,
      isToday: Bool = false,
      scheduleCount: Int = 0
    ) {
      self.id = "\(dayNumber)-\(isCurrentMonth)"
      self.date = date
      self.dayNumber = dayNumber
      self.isCurrentMonth = isCurrentMonth
      self.isSelected = isSelected
      self.isToday = isToday
      self.scheduleCount = scheduleCount
    }
  }

  /// 현재 월의 날짜 배열을 생성
  static func generateMonthDays(
    for date: Date,
    selectedDate: Date,
    scheduleCountsByDate: [Date: Int]
  ) -> [DayItem] {
    let calendar = Calendar.current
    let today = Date()

    guard let monthInterval = calendar.dateInterval(of: .month, for: date),
          let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
    else { return [] }

    var days: [DayItem] = []

    // 월요일 시작 기준 오프셋 계산 (일=1, 월=2, ..., 토=7)
    // 월요일 시작이므로: 월=0, 화=1, ..., 일=6
    let offset = (firstWeekday - 2 + 7) % 7

    // 이전 월 placeholder
    if offset > 0 {
      for i in stride(from: offset, through: 1, by: -1) {
        if let prevDate = calendar.date(byAdding: .day, value: -i, to: monthInterval.start) {
          let dayNum = calendar.component(.day, from: prevDate)
          days.append(DayItem(
            date: prevDate,
            dayNumber: dayNum,
            isCurrentMonth: false
          ))
        }
      }
    }

    // 현재 월
    let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    for day in 1...daysInMonth {
      if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) {
        let dateKey = calendar.startOfDay(for: dayDate)
        let count = scheduleCountsByDate[dateKey] ?? 0
        days.append(DayItem(
          date: dayDate,
          dayNumber: day,
          isCurrentMonth: true,
          isSelected: calendar.isDate(dayDate, inSameDayAs: selectedDate),
          isToday: calendar.isDate(dayDate, inSameDayAs: today),
          scheduleCount: count
        ))
      }
    }

    return days
  }
}
