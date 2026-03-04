// MARK: - MonthGridView.swift
// 월간 캘린더 그리드 뷰 - UIKit UIScrollView 기반 3페이지 페이저

import SwiftUI
import UIKit

// MARK: - Shared Calendar

private let monthGridCalendar = Calendar.current

// MARK: - Paging Month Grid View

/// UIScrollView 기반 3페이지 월간 캘린더 (prev / current / next month)
struct PagingMonthGridView: UIViewControllerRepresentable {
  @Binding var currentMonth: Date
  let selectedDate: Date
  let scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]]
  let namespace: Namespace.ID
  let isCompactMode: Bool
  var showAllIndicators: Bool = false
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void
  var onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil
  var onDayCreatePersonalEvent: ((Date) -> Void)? = nil
  var onDayCreatePromise: ((Date) -> Void)? = nil

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.isCompactMode = isCompactMode
    vc.showAllIndicators = showAllIndicators
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
    context.coordinator.lastKnownMonth = currentMonth.startOfMonth
    vc.setupPages(
      prevMonth: prevMonth,
      currentMonth: currentMonth.startOfMonth,
      nextMonth: nextMonth,
      selectedDate: selectedDate,
      scheduleIndicatorsByDate: scheduleIndicatorsByDate,
      namespace: namespace,
      isCompactMode: isCompactMode,
      showAllIndicators: showAllIndicators,
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

    let currentMonthStart = currentMonth.startOfMonth

    // 외부(화살표/오늘 버튼)에서 월 변경 감지 → 슬라이드 애니메이션
    if !coordinator.needsRecenter,
       let lastMonth = coordinator.lastKnownMonth,
       lastMonth != currentMonthStart {
      let direction: Coordinator.SlideDirection = currentMonthStart > lastMonth ? .right : .left
      coordinator.pendingSlideDirection = direction
    }
    coordinator.lastKnownMonth = currentMonthStart

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

    enum SlideDirection { case left, right }

    init(parent: PagingMonthGridView) {
      self.parent = parent
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))

      if currentPage == 0 {
        // 이전 월로 이동
        needsRecenter = true
        let prev = monthGridCalendar.date(byAdding: .month, value: -1, to: parent.currentMonth.startOfMonth) ?? parent.currentMonth
        parent.currentMonth = prev.startOfMonth
      } else if currentPage == 2 {
        // 다음 월로 이동
        needsRecenter = true
        let next = monthGridCalendar.date(byAdding: .month, value: 1, to: parent.currentMonth.startOfMonth) ?? parent.currentMonth
        parent.currentMonth = next.startOfMonth
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
    private var rowHeight: CGFloat { isCompactMode ? 46 : 62 }
    private let gridSpacing: CGFloat = 6
    private var fullGridHeight: CGFloat { 6 * rowHeight + 5 * gridSpacing }

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
      onDateSelected: @escaping (Date) -> Void,
      onCollapseToWeek: @escaping (Date) -> Void,
      onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil,
      onDayCreatePersonalEvent: ((Date) -> Void)? = nil,
      onDayCreatePromise: ((Date) -> Void)? = nil
    ) {
      scrollView.delegate = coordinator

      let months = [prevMonth, currentMonth, nextMonth]
      let pageWidthMultiplier = 1.0 / 3.0

      for (index, month) in months.enumerated() {
        let gridView = MonthGridContent(
          currentMonth: month,
          selectedDate: selectedDate,
          scheduleIndicatorsByDate: scheduleIndicatorsByDate,
          namespace: namespace,
          isCompactMode: isCompactMode,
          showAllIndicators: showAllIndicators,
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
      onDateSelected: @escaping (Date) -> Void,
      onCollapseToWeek: @escaping (Date) -> Void,
      onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil,
      onDayCreatePersonalEvent: ((Date) -> Void)? = nil,
      onDayCreatePromise: ((Date) -> Void)? = nil
    ) {
      let months = [prevMonth, currentMonth, nextMonth]
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < months.count else { break }
        vc.rootView = MonthGridContent(
          currentMonth: months[index],
          selectedDate: selectedDate,
          scheduleIndicatorsByDate: scheduleIndicatorsByDate,
          namespace: namespace,
          isCompactMode: isCompactMode,
          showAllIndicators: showAllIndicators,
          onDateSelected: onDateSelected,
          onCollapseToWeek: onCollapseToWeek,
          onIndicatorTapped: onIndicatorTapped,
          onDayCreatePersonalEvent: onDayCreatePersonalEvent,
          onDayCreatePromise: onDayCreatePromise
        )
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
  let onDateSelected: (Date) -> Void
  let onCollapseToWeek: (Date) -> Void
  var onIndicatorTapped: ((CalendarFeature.ScheduleIndicator) -> Void)? = nil
  var onDayCreatePersonalEvent: ((Date) -> Void)? = nil
  var onDayCreatePromise: ((Date) -> Void)? = nil

  // 애니메이션용 로컬 상태 — rootView 교체 시에도 보존됨 (root view의 @State)
  @State private var animCompact: Bool = true
  @State private var animShowAll: Bool = false

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

  var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      gridContent
    }
    .scrollDisabled(!animShowAll)
    .onAppear {
      animCompact = isCompactMode && !showAllIndicators
      animShowAll = showAllIndicators
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
  }

  private var gridContent: some View {
    VStack(spacing: 8) {
      // 날짜 그리드
      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(Array(calendarDates.enumerated()), id: \.offset) { _, date in
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
        }
      }
    }
    .padding(.horizontal, 8)
    .padding(.top, 4)
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
