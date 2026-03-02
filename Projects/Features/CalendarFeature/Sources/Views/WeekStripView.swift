// MARK: - WeekStripView.swift
// 주간 캘린더 스트립 뷰 - TabView 기반 페이징 + 동적 로딩

import SwiftUI

// MARK: - Height Preference Key

private struct WeekContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

// MARK: - Shared Calendar

private let weekStripCalendar = Calendar.current

// MARK: - Constants

private enum WeekPagesConfig {
  static let pageRange = 12        // 전후 12주 (약 3개월)
  static let reloadThreshold = 4   // 경계에서 4주 이내면 재생성
}

// MARK: - Paging Week Strip View

/// TabView 기반 주간 날짜 스트립 (동적 페이지 로딩)
struct PagingWeekStripView: View {
  @Binding var currentWeekStart: Date
  let selectedDate: Date
  let scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void

  // 로컬 상태
  @State private var localSelection: Date
  @State private var contentHeight: CGFloat = 60
  @State private var weekPages: [Date] = []
  @State private var centerWeek: Date

  init(
    currentWeekStart: Binding<Date>,
    selectedDate: Date,
    scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]],
    namespace: Namespace.ID,
    onDateSelected: @escaping (Date) -> Void
  ) {
    self._currentWeekStart = currentWeekStart
    self.selectedDate = selectedDate
    self.scheduleIndicatorsByDate = scheduleIndicatorsByDate
    self.namespace = namespace
    self.onDateSelected = onDateSelected

    let initialWeek = currentWeekStart.wrappedValue.startOfWeek
    self._localSelection = State(initialValue: initialWeek)
    self._centerWeek = State(initialValue: initialWeek)
    self._weekPages = State(initialValue: Self.generatePages(around: initialWeek))
  }

  var body: some View {
    TabView(selection: $localSelection) {
      ForEach(weekPages, id: \.self) { weekStart in
        WeekStripContent(
          weekDates: getWeekDates(for: weekStart),
          selectedDate: selectedDate,
          scheduleIndicatorsByDate: scheduleIndicatorsByDate,
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
      // 외부에서 변경된 경우 (화살표 버튼, 오늘 버튼 등)
      let normalized = newValue.startOfWeek
      if !weekStripCalendar.isDate(localSelection, inSameDayAs: normalized) {
        // 페이지 범위 밖이면 재생성
        if !weekPages.contains(where: { weekStripCalendar.isDate($0, inSameDayAs: normalized) }) {
          reloadPages(around: normalized)
        }
        // 슬라이드 애니메이션 적용 (스프링)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
          localSelection = normalized
        }
      }
    }
    .onChange(of: localSelection) { oldValue, newValue in
      // 스와이프로 페이지가 변경 완료된 경우
      if !weekStripCalendar.isDate(oldValue, inSameDayAs: newValue) {
        currentWeekStart = newValue

        // 경계 근처면 페이지 재생성
        checkAndReloadIfNeeded(currentPage: newValue)
      }
    }
  }

  // MARK: - Page Management

  private static func generatePages(around centerWeek: Date) -> [Date] {
    let range = -WeekPagesConfig.pageRange...WeekPagesConfig.pageRange
    return range.compactMap { offset in
      weekStripCalendar.date(byAdding: .weekOfYear, value: offset, to: centerWeek)?.startOfWeek
    }
  }

  private func reloadPages(around newCenter: Date) {
    centerWeek = newCenter
    weekPages = Self.generatePages(around: newCenter)
  }

  private func checkAndReloadIfNeeded(currentPage: Date) {
    guard let currentIndex = weekPages.firstIndex(where: {
      weekStripCalendar.isDate($0, inSameDayAs: currentPage)
    }) else { return }

    let distanceFromStart = currentIndex
    let distanceFromEnd = weekPages.count - 1 - currentIndex

    // 경계에서 threshold 이내면 재생성
    if distanceFromStart <= WeekPagesConfig.reloadThreshold ||
       distanceFromEnd <= WeekPagesConfig.reloadThreshold {
      reloadPages(around: currentPage)
    }
  }

  // MARK: - Helper

  private func getWeekDates(for weekStart: Date) -> [Date] {
    (0..<7).compactMap { dayOffset in
      weekStripCalendar.date(byAdding: .day, value: dayOffset, to: weekStart)
    }
  }
}

// MARK: - Week Strip Content (단일 주 표시)

/// 단일 주의 날짜 셀들
struct WeekStripContent: View {
  let weekDates: [Date]
  let selectedDate: Date
  let scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]]
  let namespace: Namespace.ID
  let onDateSelected: (Date) -> Void

  var body: some View {
    HStack(spacing: 0) {
      ForEach(weekDates, id: \.self) { date in
        CalendarIndicatorDayCell(
          date: date,
          isSelected: weekStripCalendar.isDate(date, inSameDayAs: selectedDate),
          isToday: weekStripCalendar.isDateInToday(date),
          isCurrentMonth: true,
          scheduleIndicators: getScheduleIndicators(for: date),
          namespace: namespace,
          selectionId: "weekSelection",
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

  private func getScheduleIndicators(for date: Date) -> [CalendarFeature.ScheduleIndicator] {
    let dateKey = weekStripCalendar.startOfDay(for: date)
    return scheduleIndicatorsByDate[dateKey] ?? []
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
      scheduleIndicatorsByDate: [:],
      namespace: namespace,
      onDateSelected: { selectedDate = $0 }
    )
    .background(Color(.systemBackground))
  }
}
