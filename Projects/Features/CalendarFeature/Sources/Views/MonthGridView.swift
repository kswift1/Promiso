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

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.isCompactMode = isCompactMode
    vc.showAllIndicators = showAllIndicators
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
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
      onCollapseToWeek: onCollapseToWeek
    )
    return vc
  }

  func updateUIViewController(_ vc: PagerViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.parent = self

    // isCompactMode 변경 시 높이 업데이트
    if vc.isCompactMode != isCompactMode {
      vc.updateCompactMode(isCompactMode)
    }

    // showAllIndicators 변경 감지
    if vc.showAllIndicators != showAllIndicators {
      vc.showAllIndicators = showAllIndicators
    }

    if coordinator.needsRecenter {
      coordinator.needsRecenter = false
      vc.updatePages(
        prevMonth: prevMonth,
        currentMonth: currentMonth.startOfMonth,
        nextMonth: nextMonth,
        selectedDate: selectedDate,
        scheduleIndicatorsByDate: scheduleIndicatorsByDate,
        namespace: namespace,
        isCompactMode: isCompactMode,
        showAllIndicators: showAllIndicators,
        onDateSelected: onDateSelected,
        onCollapseToWeek: onCollapseToWeek
      )
      vc.recenterToCurrentPage(animated: false)
    } else {
      vc.updatePages(
        prevMonth: prevMonth,
        currentMonth: currentMonth.startOfMonth,
        nextMonth: nextMonth,
        selectedDate: selectedDate,
        scheduleIndicatorsByDate: scheduleIndicatorsByDate,
        namespace: namespace,
        isCompactMode: isCompactMode,
        showAllIndicators: showAllIndicators,
        onDateSelected: onDateSelected,
        onCollapseToWeek: onCollapseToWeek
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
      onCollapseToWeek: @escaping (Date) -> Void
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
          onCollapseToWeek: onCollapseToWeek
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

        if showAllIndicators {
          // 페이지가 가용 높이를 채우도록 — 내부 ScrollView가 오버플로 처리
          constraints.append(hostingVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor))
        } else {
          // 고정 높이
          let heightConstraint = hostingVC.view.heightAnchor.constraint(equalToConstant: fullGridHeight)
          heightConstraints.append(heightConstraint)
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
      onCollapseToWeek: @escaping (Date) -> Void
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
          onCollapseToWeek: onCollapseToWeek
        )
      }
    }

    func updateCompactMode(_ isCompactMode: Bool) {
      self.isCompactMode = isCompactMode
      let newHeight = fullGridHeight
      for constraint in heightConstraints {
        constraint.constant = newHeight
      }
      view.layoutIfNeeded()
    }

    func recenterToCurrentPage(animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: animated)
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

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

  var body: some View {
    if showAllIndicators {
      // Expanded: 페이지 내부 세로 스크롤 (HomeOverlay 패턴 — 고정 높이 페이저 + 내부 스크롤)
      ScrollView(.vertical, showsIndicators: false) {
        gridContent
      }
    } else {
      gridContent
    }
  }

  private var gridContent: some View {
    VStack(spacing: 8) {
      // 날짜 그리드
      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(calendarDates, id: \.self) { date in
          CalendarIndicatorDayCell(
            date: date,
            isSelected: isCurrentMonth(date) && monthGridCalendar.isDate(date, inSameDayAs: selectedDate),
            isToday: monthGridCalendar.isDateInToday(date),
            isCurrentMonth: isCurrentMonth(date),
            scheduleIndicators: getScheduleIndicators(for: date),
            namespace: namespace,
            selectionId: "monthSelection",
            isCompactMode: isCompactMode,
            showAllIndicators: showAllIndicators,
            onTap: { onDateSelected(date) }
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
