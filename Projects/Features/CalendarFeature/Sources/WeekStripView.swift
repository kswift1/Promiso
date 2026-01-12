// MARK: - WeekStripView.swift
// 주간 캘린더 스트립 뷰 - TabView 기반 페이징

import SwiftUI

// MARK: - Height Preference Key

private struct WeekContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

// MARK: - Paging Week Strip View

/// TabView 기반 주간 날짜 스트립 (네이티브 페이징)
struct PagingWeekStripView: View {
  @Binding var currentWeekStart: Date
  let selectedDate: Date
  let promisesByDate: [Date: [MockPromise]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void

  // 로컬 상태로 TabView selection 관리 (스와이프 중 깜빡임 방지)
  @State private var localSelection: Date
  @State private var contentHeight: CGFloat = 60

  private let calendar = Calendar.current

  // 충분히 큰 범위의 페이지를 미리 생성 (재생성 안함)
  private var weekPages: [Date] {
    let range = -52...52  // 전후 1년
    return range.compactMap { offset in
      // 기준점을 오늘로 고정
      let today = calendar.startOfDay(for: Date())
      guard let weekStart = calendar.date(byAdding: .day, value: -calendar.component(.weekday, from: today) + 1, to: today),
            let targetWeek = calendar.date(byAdding: .weekOfYear, value: offset, to: weekStart) else {
        return nil
      }
      return targetWeek.startOfWeek
    }
  }

  init(
    currentWeekStart: Binding<Date>,
    selectedDate: Date,
    promisesByDate: [Date: [MockPromise]],
    namespace: Namespace.ID,
    onDateSelected: @escaping (Date) -> Void
  ) {
    self._currentWeekStart = currentWeekStart
    self.selectedDate = selectedDate
    self.promisesByDate = promisesByDate
    self.namespace = namespace
    self.onDateSelected = onDateSelected
    self._localSelection = State(initialValue: currentWeekStart.wrappedValue.startOfWeek)
  }

  var body: some View {
    TabView(selection: $localSelection) {
      ForEach(weekPages, id: \.self) { weekStart in
        WeekStripContent(
          weekDates: getWeekDates(for: weekStart),
          selectedDate: selectedDate,
          promisesByDate: promisesByDate,
          namespace: namespace,
          onDateSelected: onDateSelected
        )
        .tag(weekStart)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .frame(height: contentHeight)
    .onPreferenceChange(WeekContentHeightKey.self) { height in
      if height > 0 {
        contentHeight = height
      }
    }
    .onChange(of: currentWeekStart) { _, newValue in
      // 외부에서 변경된 경우 (오늘 버튼 등)
      let normalized = newValue.startOfWeek
      if !calendar.isDate(localSelection, inSameDayAs: normalized) {
        localSelection = normalized
      }
    }
    .onChange(of: localSelection) { oldValue, newValue in
      // 스와이프로 페이지가 변경 완료된 경우에만 외부 알림
      if !calendar.isDate(oldValue, inSameDayAs: newValue) {
        currentWeekStart = newValue
      }
    }
  }

  // MARK: - Helper

  private func getWeekDates(for weekStart: Date) -> [Date] {
    (0..<7).compactMap { dayOffset in
      calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
    }
  }
}

// MARK: - Week Strip Content (단일 주 표시)

/// 단일 주의 날짜 셀들
struct WeekStripContent: View {
  let weekDates: [Date]
  let selectedDate: Date
  let promisesByDate: [Date: [MockPromise]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void

  private let calendar = Calendar.current

  var body: some View {
    HStack(spacing: 0) {
      ForEach(weekDates, id: \.self) { date in
        DayCell(
          date: date,
          isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
          isToday: calendar.isDateInToday(date),
          isCurrentMonth: true,
          promiseStatuses: getPromiseStatuses(for: date),
          namespace: namespace,
          onTap: { onDateSelected(date) }
        )
      }
    }
    .padding(.horizontal, 8)
    .padding(.top, 4)
    .background(
      GeometryReader { geometry in
        Color.clear.preference(
          key: WeekContentHeightKey.self,
          value: geometry.size.height
        )
      }
    )
  }

  // MARK: - Helper

  private func getPromiseStatuses(for date: Date) -> [MockPromiseStatus] {
    let dateKey = calendar.startOfDay(for: date)
    guard let promises = promisesByDate[dateKey] else { return [] }
    return promises.map { $0.status }
  }
}

// MARK: - Preview

#Preview("Paging Week Strip") {
  @Previewable @Namespace var namespace
  @Previewable @State var currentWeekStart = Date().startOfWeek
  @Previewable @State var selectedDate = Date()

  VStack {
    Text("현재 주: \(currentWeekStart.formatted(date: .abbreviated, time: .omitted))")
      .font(.caption)
      .foregroundColor(.secondary)

    PagingWeekStripView(
      currentWeekStart: $currentWeekStart,
      selectedDate: selectedDate,
      promisesByDate: [:],
      namespace: namespace,
      onDateSelected: { selectedDate = $0 }
    )
    .background(Color(.systemBackground))
  }
}
