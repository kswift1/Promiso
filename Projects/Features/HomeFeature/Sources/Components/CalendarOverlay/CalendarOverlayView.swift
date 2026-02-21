import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Calendar Overlay View

/// Home 화면 위에 표시되는 캘린더 오버레이
struct CalendarOverlayView: View {
  let currentMonth: Date
  let days: [OverlayCalendarModels.DayItem]
  let todayScheduleItems: [HomeModels.ScheduleItem]
  let selectedDate: Date
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

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
    VStack(spacing: 16) {
      // Header
      calendarHeader

      // Weekday labels
      weekdayHeader

      // Day grid
      dayGrid

      // Selected date summary
      selectedDateSummary
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 20)
  }

  // MARK: - Calendar Header

  private var calendarHeader: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 0) {
        Text(yearString)
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(.primary)

        Text(monthString)
          .font(.system(size: 34, weight: .bold))
          .foregroundStyle(.primary)
      }

      Spacer()

      HStack(spacing: 12) {
        Button(action: onPreviousMonth) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }

        Button(action: onNextMonth) {
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .adaptiveGlassBackground(cornerRadius: 16)
        }
      }
    }
  }

  // MARK: - Weekday Header

  private var weekdayHeader: some View {
    LazyVGrid(columns: columns, spacing: 0) {
      ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
        Text(day)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(Color.pmgray.n400)
          .frame(maxWidth: .infinity)
          .frame(height: 24)
      }
    }
  }

  // MARK: - Day Grid

  private var dayGrid: some View {
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

  // MARK: - Selected Date Summary

  @ViewBuilder
  private var selectedDateSummary: some View {
    let selectedDayItems = todayScheduleItems.filter { item in
      Calendar.current.isDate(item.startAt, inSameDayAs: selectedDate)
    }

    VStack(alignment: .leading, spacing: 8) {
      Text(selectedDateString)
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(.primary)

      if selectedDayItems.isEmpty {
        Text(LocalizedStrings.Calendar.noPromises)
          .font(.pmCaption)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      } else {
        ForEach(selectedDayItems.prefix(3)) { item in
          HStack(spacing: 8) {
            Circle()
              .fill(Color.pmindigo.n400)
              .frame(width: 6, height: 6)

            Text(item.title)
              .font(.pmBody)
              .foregroundStyle(.primary)
              .lineLimit(1)

            Spacer()

            Text(timeString(from: item.startAt))
              .font(.pmCaption)
              .foregroundStyle(.secondary)
          }
        }

        if selectedDayItems.count > 3 {
          Text(LocalizedStrings.Calendar.additionalItems(selectedDayItems.count - 3))
            .font(.pmCaption)
            .foregroundStyle(Color.pmindigo.n500)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .adaptiveGlassCard(cornerRadius: 16)
  }

  // MARK: - Computed

  private var yearString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy"
    return formatter.string(from: currentMonth)
  }

  private var monthString: String {
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.dateFormat = "MMMM"
    return formatter.string(from: currentMonth)
  }

  private var selectedDateString: String {
    LocalizedDateFormatters.monthDayWeekday.string(from: selectedDate)
  }

  private func timeString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }
}

// MARK: - Preview

#Preview {
  CalendarOverlayView(
    currentMonth: Date(),
    days: OverlayCalendarModels.generateMonthDays(
      for: Date(),
      selectedDate: Date(),
      scheduleCountsByDate: [:]
    ),
    todayScheduleItems: [],
    selectedDate: Date(),
    onClose: {},
    onDateSelected: { _ in },
    onPreviousMonth: {},
    onNextMonth: {}
  )
  .auroraBackground()
}
