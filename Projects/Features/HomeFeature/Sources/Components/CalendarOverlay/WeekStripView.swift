import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Week Strip View

/// 일간 상세 모드 하단에 표시되는 주간 날짜 스트립 (1행 7일)
struct WeekStripView: View {
  let weekDays: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void

  private let weekdayLabels = [
    LocalizedStrings.Calendar.weekdayMon,
    LocalizedStrings.Calendar.weekdayTue,
    LocalizedStrings.Calendar.weekdayWed,
    LocalizedStrings.Calendar.weekdayThu,
    LocalizedStrings.Calendar.weekdayFri,
    LocalizedStrings.Calendar.weekdaySat,
    LocalizedStrings.Calendar.weekdaySun,
  ]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(weekDays.enumerated()), id: \.element.id) { index, day in
        Button {
          onDateSelected(day.date)
        } label: {
          VStack(spacing: 6) {
            Text(index < weekdayLabels.count ? weekdayLabels[index] : "")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmgray.n400)

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
                .foregroundStyle(dayTextColor(day))
            }
            .frame(width: 36, height: 36)

            // 일정 인디케이터
            if day.scheduleCount > 0 {
              HStack(spacing: 3) {
                ForEach(0..<min(day.scheduleCount, 3), id: \.self) { _ in
                  Circle()
                    .fill(day.isSelected ? Color.pmindigo.n500 : Color.pmindigo.n400)
                    .frame(width: 4, height: 4)
                }
              }
              .frame(height: 4)
            } else {
              Spacer()
                .frame(height: 4)
            }
          }
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 8)
  }

  private func dayTextColor(_ day: OverlayCalendarModels.DayItem) -> Color {
    if day.isSelected { return .white }
    if !day.isCurrentMonth { return Color.pmgray.n300 }
    if day.isToday { return Color.pmindigo.n500 }
    return .primary
  }
}

// MARK: - Preview

#Preview {
  WeekStripView(
    weekDays: (0..<7).map { i in
      OverlayCalendarModels.DayItem(
        date: Calendar.promiseDisplay.date(byAdding: .day, value: i, to: Date()) ?? Date(),
        dayNumber: 10 + i,
        isSelected: i == 3,
        isToday: i == 0,
        scheduleCount: i % 2 == 0 ? 2 : 0
      )
    },
    onDateSelected: { _ in }
  )
  .padding()
}
