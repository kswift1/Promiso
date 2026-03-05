// MARK: - MonthGridView.swift
// 월간 캘린더 그리드 뷰 - UIKit UIScrollView 기반 3페이지 페이저

import SwiftUI
import UIKit

// MARK: - Shared Calendar

private let monthGridCalendar = Calendar.current

/// 주간 모드에서 주 오프셋에 해당하는 월과 행 인덱스를 계산
private func weekPageInfo(for date: Date, weekOffset: Int) -> (month: Date, weekRow: Int) {
  let calendar = Calendar.current
  guard let targetDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: date) else {
    return (date.startOfMonth, 0)
  }
  let month = targetDate.startOfMonth
  let firstWeekday = month.firstWeekdayOfMonth
  let daysToSubtract = firstWeekday - 1
  guard let calendarStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: month) else {
    return (month, 0)
  }
  let daysBetween = calendar.dateComponents(
    [.day],
    from: calendar.startOfDay(for: calendarStart),
    to: calendar.startOfDay(for: targetDate)
  ).day ?? 0
  return (month, max(0, min(5, daysBetween / 7)))
}

// MARK: - Paging Month Grid View

/// UIScrollView 기반 3페이지 월간 캘린더 (prev / current / next month)
struct PagingMonthGridView: UIViewControllerRepresentable {
  @Binding var currentMonth: Date
  let selectedDate: Date
  let scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]]
  let namespace: Namespace.ID
  let isCompactMode: Bool
  var showAllIndicators: Bool = false
  var selectedWeekRow: Int? = nil
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void
  var onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil
  var onDayCreatePersonalEvent: ((Date) -> Void)? = nil
  var onDayCreatePromise: ((Date) -> Void)? = nil
  var onWeekPageChanged: ((Int) -> Void)? = nil  // -1 (이전 주) or +1 (다음 주)

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.isCompactMode = isCompactMode
    vc.showAllIndicators = showAllIndicators
    vc.selectedWeekRow = selectedWeekRow
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
    context.coordinator.lastKnownMonth = currentMonth.startOfMonth
    context.coordinator.lastKnownSelectedDate = selectedDate
    vc.setupPages(
      prevMonth: prevMonth,
      currentMonth: currentMonth.startOfMonth,
      nextMonth: nextMonth,
      selectedDate: selectedDate,
      scheduleIndicatorsByDate: scheduleIndicatorsByDate,
      namespace: namespace,
      isCompactMode: isCompactMode,
      showAllIndicators: showAllIndicators,
      selectedWeekRow: selectedWeekRow,
      onDateSelected: onDateSelected,
      onCollapseToWeek: onCollapseToWeek,
      onIndicatorTapped: onIndicatorTapped,
      onDayCreatePersonalEvent: onDayCreatePersonalEvent,
      onDayCreatePromise: onDayCreatePromise
    )
    return vc
  }

  func updateUIViewController(_ vc: PagerViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self

    // 모드 전환 시 6행 유지 상태로 높이/제약만 단계적으로 전환
    if vc.isCompactMode != isCompactMode || vc.showAllIndicators != showAllIndicators {
      vc.updateLayoutMode(
        isCompactMode: isCompactMode,
        showAllIndicators: showAllIndicators
      )
    }

    // 주간 행 모드 변경 감지
    if vc.selectedWeekRow != selectedWeekRow {
      vc.updateWeekRowMode(selectedWeekRow: selectedWeekRow)
    }

    let currentMonthStart = currentMonth.startOfMonth

    // 외부(화살표/오늘 버튼)에서 월 변경 감지 → 슬라이드 애니메이션
    var monthChanged = false
    if !coordinator.needsRecenter,
       let lastMonth = coordinator.lastKnownMonth,
       lastMonth != currentMonthStart {
      let direction: Coordinator.SlideDirection = currentMonthStart > lastMonth ? .right : .left
      coordinator.pendingSlideDirection = direction
      monthChanged = true
    }
    coordinator.lastKnownMonth = currentMonthStart

    // 주간 모드: 같은 달 내 주 변경 감지 → 슬라이드 애니메이션
    if selectedWeekRow != nil, !monthChanged, !coordinator.needsRecenter,
       let lastDate = coordinator.lastKnownSelectedDate {
      let lastWeek = lastDate.startOfWeek
      let currentWeek = selectedDate.startOfWeek
      if lastWeek != currentWeek {
        let direction: Coordinator.SlideDirection = selectedDate > lastDate ? .right : .left
        coordinator.pendingSlideDirection = direction
      }
    }
    coordinator.lastKnownSelectedDate = selectedDate

    if coordinator.needsRecenter {
      // 스와이프 완료 후 리센터 (애니메이션 없음 — 이미 사용자가 스와이프함)
      coordinator.needsRecenter = false
      coordinator.pendingSlideDirection = nil
      vc.updatePages(
        prevMonth: prevMonth,
        currentMonth: currentMonthStart,
        nextMonth: nextMonth,
        selectedDate: selectedDate,
        scheduleIndicatorsByDate: scheduleIndicatorsByDate,
        namespace: namespace,
        isCompactMode: isCompactMode,
        showAllIndicators: showAllIndicators,
        selectedWeekRow: selectedWeekRow,
        onDateSelected: onDateSelected,
        onCollapseToWeek: onCollapseToWeek,
        onIndicatorTapped: onIndicatorTapped,
        onDayCreatePersonalEvent: onDayCreatePersonalEvent,
        onDayCreatePromise: onDayCreatePromise
      )
      vc.recenterToCurrentPage(animated: false)
    } else if let direction = coordinator.pendingSlideDirection {
      // 화살표/오늘 버튼 → 슬라이드 애니메이션
      coordinator.pendingSlideDirection = nil
      let targetPage: Int = direction == .right ? 2 : 0
      vc.slideTo(page: targetPage) {
        vc.updatePages(
          prevMonth: self.prevMonth,
          currentMonth: currentMonthStart,
          nextMonth: self.nextMonth,
          selectedDate: self.selectedDate,
          scheduleIndicatorsByDate: self.scheduleIndicatorsByDate,
          namespace: self.namespace,
          isCompactMode: self.isCompactMode,
          showAllIndicators: self.showAllIndicators,
          selectedWeekRow: self.selectedWeekRow,
          onDateSelected: self.onDateSelected,
          onCollapseToWeek: self.onCollapseToWeek,
          onIndicatorTapped: self.onIndicatorTapped,
          onDayCreatePersonalEvent: self.onDayCreatePersonalEvent,
          onDayCreatePromise: self.onDayCreatePromise
        )
        vc.recenterToCurrentPage(animated: false)
      }
    } else {
      // 일반 데이터 업데이트 (선택 날짜 변경 등)
      vc.updatePages(
        prevMonth: prevMonth,
        currentMonth: currentMonthStart,
        nextMonth: nextMonth,
        selectedDate: selectedDate,
        scheduleIndicatorsByDate: scheduleIndicatorsByDate,
        namespace: namespace,
        isCompactMode: isCompactMode,
        showAllIndicators: showAllIndicators,
        selectedWeekRow: selectedWeekRow,
        onDateSelected: onDateSelected,
        onCollapseToWeek: onCollapseToWeek,
        onIndicatorTapped: onIndicatorTapped,
        onDayCreatePersonalEvent: onDayCreatePersonalEvent,
        onDayCreatePromise: onDayCreatePromise
      )
    }
  }

  // MARK: - Helpers

  private var prevMonth: Date {
    monthGridCalendar.date(byAdding: .month, value: -1, to: currentMonth.startOfMonth) ?? currentMonth.startOfMonth
  }

  private var nextMonth: Date {
    monthGridCalendar.date(byAdding: .month, value: 1, to: currentMonth.startOfMonth) ?? currentMonth.startOfMonth
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var parent: PagingMonthGridView
    weak var pagerVC: PagerViewController?
    var needsRecenter = false
    /// 외부(화살표/오늘 버튼)에서 월 변경 시 슬라이드 애니메이션 방향
    var pendingSlideDirection: SlideDirection?
    var lastKnownMonth: Date?
    var lastKnownSelectedDate: Date?

    enum SlideDirection { case left, right }

    init(parent: PagingMonthGridView) {
      self.parent = parent
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))

      if currentPage == 0 {
        needsRecenter = true
        if parent.selectedWeekRow != nil {
          // 주간 모드: 주 단위 탐색
          parent.onWeekPageChanged?(-1)
        } else {
          // 월간 모드: 월 단위 탐색
          let prev = monthGridCalendar.date(byAdding: .month, value: -1, to: parent.currentMonth.startOfMonth) ?? parent.currentMonth
          parent.currentMonth = prev.startOfMonth
        }
      } else if currentPage == 2 {
        needsRecenter = true
        if parent.selectedWeekRow != nil {
          parent.onWeekPageChanged?(1)
        } else {
          let next = monthGridCalendar.date(byAdding: .month, value: 1, to: parent.currentMonth.startOfMonth) ?? parent.currentMonth
          parent.currentMonth = next.startOfMonth
        }
      }
      // currentPage == 1 → 원래 위치, 아무것도 안 함
    }
  }

  // MARK: - PagerViewController

  final class PagerViewController: UIViewController {
    var coordinator: Coordinator?
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageHostingControllers: [UIHostingController<MonthGridContent>] = []
    private var heightConstraints: [NSLayoutConstraint] = []
    private var bottomConstraints: [NSLayoutConstraint] = []

    // Grid layout constants
    var isCompactMode: Bool = false
    var showAllIndicators: Bool = false
    var selectedWeekRow: Int? = nil
    private var isWeekMode: Bool { selectedWeekRow != nil }
    private var rowHeight: CGFloat { isCompactMode ? 46 : 62 }
    private let gridSpacing: CGFloat = 6
    private var fullGridHeight: CGFloat {
      if isWeekMode {
        return rowHeight
      }
      return 6 * rowHeight + 5 * gridSpacing
    }

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      view.clipsToBounds = true

      scrollView.isPagingEnabled = true
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.bounces = true
      scrollView.clipsToBounds = true
      scrollView.translatesAutoresizingMaskIntoConstraints = false

      contentView.translatesAutoresizingMaskIntoConstraints = false

      view.addSubview(scrollView)
      scrollView.addSubview(contentView)

      NSLayoutConstraint.activate([
        scrollView.topAnchor.constraint(equalTo: view.topAnchor),
        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

        contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
        contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
        contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
        contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, multiplier: 3),
      ])
    }

    func setupPages(
      prevMonth: Date,
      currentMonth: Date,
      nextMonth: Date,
      selectedDate: Date,
      scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]],
      namespace: Namespace.ID,
      isCompactMode: Bool,
      showAllIndicators: Bool = false,
      selectedWeekRow: Int? = nil,
      onDateSelected: @escaping (Date) -> Void,
      onCollapseToWeek: @escaping (Date) -> Void,
      onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil,
      onDayCreatePersonalEvent: ((Date) -> Void)? = nil,
      onDayCreatePromise: ((Date) -> Void)? = nil
    ) {
      scrollView.delegate = coordinator

      // 주간 모드: 각 페이지에 이전/현재/다음 주의 월+행 설정
      let pageMonths: [Date]
      let pageWeekRows: [Int?]
      if let weekRow = selectedWeekRow {
        let prevInfo = weekPageInfo(for: selectedDate, weekOffset: -1)
        let nextInfo = weekPageInfo(for: selectedDate, weekOffset: 1)
        pageMonths = [prevInfo.month, currentMonth, nextInfo.month]
        pageWeekRows = [prevInfo.weekRow, weekRow, nextInfo.weekRow]
      } else {
        pageMonths = [prevMonth, currentMonth, nextMonth]
        pageWeekRows = [nil, nil, nil]
      }
      let pageWidthMultiplier = 1.0 / 3.0

      for (index, month) in pageMonths.enumerated() {
        // 중앙 페이지(index 1)만 선택 표시 — matchedGeometryEffect 충돌 방지
        let pageSelectedDate = index == 1 ? selectedDate : .distantPast
        let gridView = MonthGridContent(
          currentMonth: month,
          selectedDate: pageSelectedDate,
          scheduleIndicatorsByDate: scheduleIndicatorsByDate,
          namespace: namespace,
          isCompactMode: isCompactMode,
          showAllIndicators: showAllIndicators,
          selectedWeekRow: pageWeekRows[index],
          onDateSelected: onDateSelected,
          onCollapseToWeek: onCollapseToWeek,
          onIndicatorTapped: onIndicatorTapped,
          onDayCreatePersonalEvent: onDayCreatePersonalEvent,
          onDayCreatePromise: onDayCreatePromise
        )
        let hostingVC = UIHostingController(rootView: gridView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        contentView.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        var constraints: [NSLayoutConstraint] = [
          hostingVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
          hostingVC.view.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: pageWidthMultiplier),
        ]

        let heightConstraint = hostingVC.view.heightAnchor.constraint(equalToConstant: fullGridHeight)
        let bottomConstraint = hostingVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        heightConstraints.append(heightConstraint)
        bottomConstraints.append(bottomConstraint)

        if showAllIndicators {
          // 페이지가 가용 높이를 채우도록 — 내부 ScrollView가 오버플로 처리
          constraints.append(bottomConstraint)
        } else {
          // 고정 높이
          constraints.append(heightConstraint)
        }

        NSLayoutConstraint.activate(constraints)

        if index == 0 {
          hostingVC.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        } else {
          hostingVC.view.leadingAnchor.constraint(
            equalTo: pageHostingControllers[index - 1].view.trailingAnchor
          ).isActive = true
        }

        pageHostingControllers.append(hostingVC)
      }
    }

    func updatePages(
      prevMonth: Date,
      currentMonth: Date,
      nextMonth: Date,
      selectedDate: Date,
      scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]],
      namespace: Namespace.ID,
      isCompactMode: Bool,
      showAllIndicators: Bool = false,
      selectedWeekRow: Int? = nil,
      onDateSelected: @escaping (Date) -> Void,
      onCollapseToWeek: @escaping (Date) -> Void,
      onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil,
      onDayCreatePersonalEvent: ((Date) -> Void)? = nil,
      onDayCreatePromise: ((Date) -> Void)? = nil
    ) {
      // 주간 모드: 각 페이지에 이전/현재/다음 주의 월+행 설정
      let pageMonths: [Date]
      let pageWeekRows: [Int?]
      if let weekRow = selectedWeekRow {
        let prevInfo = weekPageInfo(for: selectedDate, weekOffset: -1)
        let nextInfo = weekPageInfo(for: selectedDate, weekOffset: 1)
        pageMonths = [prevInfo.month, currentMonth, nextInfo.month]
        pageWeekRows = [prevInfo.weekRow, weekRow, nextInfo.weekRow]
      } else {
        pageMonths = [prevMonth, currentMonth, nextMonth]
        pageWeekRows = [nil, nil, nil]
      }
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < pageMonths.count else { break }
        // 중앙 페이지(index 1)만 선택 표시 — matchedGeometryEffect 충돌 방지
        let pageSelectedDate = index == 1 ? selectedDate : .distantPast
        vc.rootView = MonthGridContent(
          currentMonth: pageMonths[index],
          selectedDate: pageSelectedDate,
          scheduleIndicatorsByDate: scheduleIndicatorsByDate,
          namespace: namespace,
          isCompactMode: isCompactMode,
          showAllIndicators: showAllIndicators,
          selectedWeekRow: pageWeekRows[index],
          onDateSelected: onDateSelected,
          onCollapseToWeek: onCollapseToWeek,
          onIndicatorTapped: onIndicatorTapped,
          onDayCreatePersonalEvent: onDayCreatePersonalEvent,
          onDayCreatePromise: onDayCreatePromise
        )
      }
    }

    func updateWeekRowMode(selectedWeekRow: Int?) {
      let wasWeekMode = isWeekMode
      self.selectedWeekRow = selectedWeekRow

      // 주간 모드에서도 월 단위 페이징 유지 (주간 탐색은 헤더 화살표로)
      scrollView.isScrollEnabled = true

      updateHeightConstraintConstants()
      UIView.animate(
        withDuration: 0.28,
        delay: 0,
        options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
      ) {
        self.view.layoutIfNeeded()
      }
    }

    func updateLayoutMode(isCompactMode: Bool, showAllIndicators: Bool) {
      let wasExpanded = self.showAllIndicators
      let isExpanding = !wasExpanded && showAllIndicators
      let isCollapsing = wasExpanded && !showAllIndicators

      self.showAllIndicators = showAllIndicators

      if isExpanding {
        // 1) 고정 높이 상태에서 row 높이를 먼저 키워 아래로 내려가는 모션을 만든다.
        setExpandedConstraintMode(false)
        self.isCompactMode = isCompactMode
        updateHeightConstraintConstants()

        UIView.animate(
          withDuration: 0.28,
          delay: 0,
          options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
          self.view.layoutIfNeeded()
        } completion: { _ in
          // 2) 모션 후 expanded 제약으로 전환
          self.setExpandedConstraintMode(true)
          UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
          ) {
            self.view.layoutIfNeeded()
          }
        }
        return
      }

      if isCollapsing {
        // expanded -> fixed 높이로 되돌린 뒤 compact row로 축소
        self.isCompactMode = false
        updateHeightConstraintConstants()
        setExpandedConstraintMode(false)
        view.layoutIfNeeded()

        self.isCompactMode = isCompactMode
        updateHeightConstraintConstants()
        UIView.animate(
          withDuration: 0.28,
          delay: 0,
          options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
        ) {
          self.view.layoutIfNeeded()
        }
        return
      }

      self.isCompactMode = isCompactMode
      updateHeightConstraintConstants()
      UIView.animate(
        withDuration: 0.28,
        delay: 0,
        options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]
      ) {
        self.view.layoutIfNeeded()
      }
    }

    private func updateHeightConstraintConstants() {
      let newHeight = fullGridHeight
      for constraint in heightConstraints {
        constraint.constant = newHeight
      }
    }

    private func setExpandedConstraintMode(_ isExpanded: Bool) {
      for (heightConstraint, bottomConstraint) in zip(heightConstraints, bottomConstraints) {
        // 먼저 비활성화 후 활성화하여 동시 제약 충돌 방지
        if isExpanded {
          heightConstraint.isActive = false
          bottomConstraint.isActive = true
        } else {
          bottomConstraint.isActive = false
          heightConstraint.isActive = true
        }
      }
    }

    func recenterToCurrentPage(animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: animated)
    }

    /// 지정 페이지로 애니메이션 슬라이드 후 완료 콜백 실행
    func slideTo(page: Int, completion: @escaping () -> Void) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else {
        completion()
        return
      }
      let targetOffset = CGPoint(x: pageWidth * CGFloat(page), y: 0)
      UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
        self.scrollView.contentOffset = targetOffset
      } completion: { _ in
        completion()
      }
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      // 초기 레이아웃 후 center page(index 1)로 이동
      let pageWidth = scrollView.bounds.width
      if pageWidth > 0 && scrollView.contentOffset.x == 0 {
        scrollView.contentOffset = CGPoint(x: pageWidth, y: 0)
      }
    }
  }
}

// MARK: - Month Grid Content (단일 월 표시)

/// 단일 월의 캘린더 그리드
struct MonthGridContent: View {
  let currentMonth: Date
  let selectedDate: Date
  let scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]]
  let namespace: Namespace.ID
  let isCompactMode: Bool
  var showAllIndicators: Bool = false
  var selectedWeekRow: Int? = nil
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void
  var onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil
  var onDayCreatePersonalEvent: ((Date) -> Void)? = nil
  var onDayCreatePromise: ((Date) -> Void)? = nil

  // 애니메이션용 로컬 상태 — rootView 교체 시에도 보존됨 (root view의 @State)
  @State private var animCompact: Bool = true
  @State private var animShowAll: Bool = false
  @State private var animWeekRow: Int? = nil

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      gridContent
    }
    .scrollDisabled(!animShowAll)
    .onAppear {
      animCompact = isCompactMode && !showAllIndicators
      animShowAll = showAllIndicators
      animWeekRow = selectedWeekRow
    }
    .onChange(of: isCompactMode) { _, _ in
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        animCompact = isCompactMode && !showAllIndicators
        animShowAll = showAllIndicators
      }
    }
    .onChange(of: showAllIndicators) { _, _ in
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        animCompact = isCompactMode && !showAllIndicators
        animShowAll = showAllIndicators
      }
    }
    .onChange(of: selectedWeekRow) { oldValue, newValue in
      // 모드 전환 (nil ↔ non-nil): 행 collapse/expand 애니메이션
      if (oldValue == nil) != (newValue == nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          animWeekRow = newValue
        }
      } else {
        // 같은 모드 내 행 변경 (스와이프 후 리센터 등): 즉시 반영
        animWeekRow = newValue
      }
    }
  }

  private var gridContent: some View {
    let rowHeight: CGFloat = animCompact ? 46 : 62
    return VStack(spacing: shouldShowAllRows ? 6 : 0) {
      ForEach(0..<6, id: \.self) { rowIndex in
        HStack(spacing: 0) {
          ForEach(rowDates(for: rowIndex), id: \.self) { date in
            CalendarIndicatorDayCell(
              date: date,
              isSelected: isCurrentMonth(date) && monthGridCalendar.isDate(date, inSameDayAs: selectedDate),
              isToday: monthGridCalendar.isDateInToday(date),
              isCurrentMonth: isCurrentMonth(date),
              scheduleIndicators: getScheduleIndicators(for: date),
              namespace: namespace,
              selectionId: "monthSelection",
              isCompactMode: animCompact,
              showAllIndicators: animShowAll,
              onTap: { onDateSelected(date) },
              onIndicatorTapped: onIndicatorTapped,
              onDayCreatePersonalEvent: onDayCreatePersonalEvent,
              onDayCreatePromise: onDayCreatePromise
            )
            .frame(maxWidth: .infinity)
          }
        }
        .frame(height: shouldShowRow(rowIndex) ? (animShowAll ? nil : rowHeight) : 0)
        .opacity(shouldShowRow(rowIndex) ? 1 : 0)
        .clipped()
      }
    }
    .padding(.horizontal, 8)
  }

  // MARK: - Computed Properties

  /// 달력에 표시할 날짜들 (이전/다음 달 포함 6주)
  private var calendarDates: [Date] {
    let startOfMonth = currentMonth.startOfMonth
    let firstWeekday = currentMonth.firstWeekdayOfMonth

    // 시작 날짜 계산 (이전 달 날짜 포함)
    let daysToSubtract = firstWeekday - 1
    guard let calendarStart = monthGridCalendar.date(byAdding: .day, value: -daysToSubtract, to: startOfMonth) else {
      return []
    }

    // 6주 x 7일 = 42일
    return (0..<42).compactMap { dayOffset in
      monthGridCalendar.date(byAdding: .day, value: dayOffset, to: calendarStart)
    }
  }

  // MARK: - Helpers

  private var shouldShowAllRows: Bool {
    animWeekRow == nil
  }

  private func shouldShowRow(_ rowIndex: Int) -> Bool {
    guard let weekRow = animWeekRow else { return true }
    return rowIndex == weekRow
  }

  private func rowDates(for rowIndex: Int) -> [Date] {
    let allDates = calendarDates
    let start = rowIndex * 7
    let end = min(start + 7, allDates.count)
    guard start < allDates.count else { return [] }
    return Array(allDates[start..<end])
  }

  private func isCurrentMonth(_ date: Date) -> Bool {
    let dateMonth = monthGridCalendar.component(.month, from: date)
    let currentMonthValue = monthGridCalendar.component(.month, from: currentMonth)
    return dateMonth == currentMonthValue
  }

  private func getScheduleIndicators(for date: Date) -> [CalendarFeature.ScheduleIndicator] {
    let dateKey = monthGridCalendar.startOfDay(for: date)
    return scheduleIndicatorsByDate[dateKey] ?? []
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
      scheduleIndicatorsByDate: [:],
      namespace: namespace,
      isCompactMode: false,
      onDateSelected: { selectedDate = $0 },
      onCollapseToWeek: { _ in }
    )
    .frame(height: 420)
  }
}
