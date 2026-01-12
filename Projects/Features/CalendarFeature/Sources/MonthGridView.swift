// MARK: - MonthGridView.swift
// 월간 캘린더 그리드 뷰 - TabView 기반 페이징

import SwiftUI

// MARK: - Height Preference Key

private struct MonthContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

// MARK: - Paging Month Grid View

/// TabView 기반 월간 캘린더 (네이티브 페이징)
struct PagingMonthGridView: View {
  @Binding var currentMonth: Date
  let selectedDate: Date
  let promisesByDate: [Date: [MockPromise]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void

  // 로컬 상태로 TabView selection 관리 (스와이프 중 깜빡임 방지)
  @State private var localSelection: Date
  @State private var contentHeight: CGFloat = 320

  private let calendar = Calendar.current

  // 충분히 큰 범위의 페이지를 미리 생성 (재생성 안함)
  private var monthPages: [Date] {
    let range = -24...24  // 전후 2년
    let today = Date()
    return range.compactMap { offset in
      guard let date = calendar.date(byAdding: .month, value: offset, to: today) else {
        return nil
      }
      return date.startOfMonth
    }
  }

  init(
    currentMonth: Binding<Date>,
    selectedDate: Date,
    promisesByDate: [Date: [MockPromise]],
    namespace: Namespace.ID,
    onDateSelected: @escaping (Date) -> Void,
    onCollapseToWeek: @escaping (Date) -> Void
  ) {
    self._currentMonth = currentMonth
    self.selectedDate = selectedDate
    self.promisesByDate = promisesByDate
    self.namespace = namespace
    self.onDateSelected = onDateSelected
    self.onCollapseToWeek = onCollapseToWeek
    self._localSelection = State(initialValue: currentMonth.wrappedValue.startOfMonth)
  }

  var body: some View {
    TabView(selection: $localSelection) {
      ForEach(monthPages, id: \.self) { month in
        MonthGridContent(
          currentMonth: month,
          selectedDate: selectedDate,
          promisesByDate: promisesByDate,
          namespace: namespace,
          onDateSelected: onDateSelected,
          onCollapseToWeek: onCollapseToWeek
        )
        .tag(month)
      }
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .frame(height: contentHeight)
    .onPreferenceChange(MonthContentHeightKey.self) { height in
      if height > 0 {
        contentHeight = height
      }
    }
    .onChange(of: currentMonth) { _, newValue in
      // 외부에서 변경된 경우 (오늘 버튼 등)
      let normalized = newValue.startOfMonth
      if !calendar.isDate(localSelection, inSameDayAs: normalized) {
        localSelection = normalized
      }
    }
    .onChange(of: localSelection) { oldValue, newValue in
      // 스와이프로 페이지가 변경 완료된 경우에만 외부 알림
      if !calendar.isDate(oldValue, inSameDayAs: newValue) {
        currentMonth = newValue
      }
    }
  }
}

// MARK: - Month Grid Content (단일 월 표시)

/// 단일 월의 캘린더 그리드
struct MonthGridContent: View {
  let currentMonth: Date
  let selectedDate: Date
  let promisesByDate: [Date: [MockPromise]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void

  private let calendar = Calendar.current
  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

  var body: some View {
    VStack(spacing: 8) {
      // 날짜 그리드
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(calendarDates, id: \.self) { date in
          DayCell(
            date: date,
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isToday: calendar.isDateInToday(date),
            isCurrentMonth: isCurrentMonth(date),
            promiseStatuses: getPromiseStatuses(for: date),
            namespace: namespace,
            onTap: {
              onDateSelected(date)
              // 날짜 탭 시 주간 뷰로 전환
              onCollapseToWeek(date)
            }
          )
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.top, 4)
    .background(
      GeometryReader { geometry in
        Color.clear.preference(
          key: MonthContentHeightKey.self,
          value: geometry.size.height
        )
      }
    )
  }

  // MARK: - Computed Properties

  /// 달력에 표시할 날짜들 (이전/다음 달 포함 6주)
  private var calendarDates: [Date] {
    let startOfMonth = currentMonth.startOfMonth
    let firstWeekday = currentMonth.firstWeekdayOfMonth

    // 시작 날짜 계산 (이전 달 날짜 포함)
    let daysToSubtract = firstWeekday - 1
    guard let calendarStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth) else {
      return []
    }

    // 6주 x 7일 = 42일
    return (0..<42).compactMap { dayOffset in
      calendar.date(byAdding: .day, value: dayOffset, to: calendarStart)
    }
  }

  // MARK: - Helpers

  private func isCurrentMonth(_ date: Date) -> Bool {
    let dateMonth = calendar.component(.month, from: date)
    let currentMonthValue = calendar.component(.month, from: currentMonth)
    return dateMonth == currentMonthValue
  }

  private func getPromiseStatuses(for date: Date) -> [MockPromiseStatus] {
    let dateKey = calendar.startOfDay(for: date)
    guard let promises = promisesByDate[dateKey] else { return [] }
    return promises.map { $0.status }
  }
}

// MARK: - Preview

#Preview("Paging Month Grid") {
  @Previewable @Namespace var namespace
  @Previewable @State var currentMonth = Date().startOfMonth
  @Previewable @State var selectedDate = Date()

  VStack {
    Text("현재 월: \(currentMonth.formatted(date: .abbreviated, time: .omitted))")
      .font(.caption)
      .foregroundColor(.secondary)

    PagingMonthGridView(
      currentMonth: $currentMonth,
      selectedDate: selectedDate,
      promisesByDate: [:],
      namespace: namespace,
      onDateSelected: { selectedDate = $0 },
      onCollapseToWeek: { _ in }
    )
    .frame(height: 320)
  }
}
