import SwiftUI
import UIKit
import PromisoShared

// MARK: - Day Timeline Pager

/// detail mode 상단 3페이지 일간 수평 페이저
struct DayTimelinePager: UIViewControllerRepresentable {
  let selectedDate: Date
  let prevDayScheduleItems: [HomeModels.ScheduleItem]
  let currentDayScheduleItems: [HomeModels.ScheduleItem]
  let nextDayScheduleItems: [HomeModels.ScheduleItem]
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void
  let onPreviousDay: () -> Void
  let onNextDay: () -> Void
  let onCreatePersonalEvent: (Date) -> Void
  let onCreatePromise: () -> Void
  let onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let calendarMode: CalendarMode
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]
  let zoomState: TimelineZoomState

  func makeCoordinator() -> Coordinator {
    Coordinator(pager: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.coordinator = context.coordinator
    vc.calendarMode = calendarMode
    vc.zoomState = zoomState
    context.coordinator.pagerVC = vc
    vc.setupPages(
      prevDayScheduleItems: prevDayScheduleItems,
      currentDayScheduleItems: currentDayScheduleItems,
      nextDayScheduleItems: nextDayScheduleItems,
      selectedDate: selectedDate,
      onScheduleItemTapped: onScheduleItemTapped,
      onCreatePersonalEvent: onCreatePersonalEvent,
      onCreatePromise: onCreatePromise,
      onDeleteScheduleItem: onDeleteScheduleItem,
      onShareScheduleItem: onShareScheduleItem,
      currentUserId: currentUserId,
      weatherCache: weatherCache,
      groupColorMap: groupColorMap
    )
    return vc
  }

  func updateUIViewController(_ vc: PagerViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.pager = self
    vc.calendarMode = calendarMode
    let calendar = Calendar.promiseDisplay
    let selectedDay = calendar.startOfDay(for: selectedDate)

    // 날짜 탭 슬라이드 애니메이션 중에는 업데이트 스킵
    if coordinator.isAnimatingDateTap {
      return
    }

    if coordinator.needsRecenter {
      coordinator.needsRecenter = false

      vc.updatePages(
        prevDayScheduleItems: prevDayScheduleItems,
        currentDayScheduleItems: currentDayScheduleItems,
        nextDayScheduleItems: nextDayScheduleItems,
        selectedDate: selectedDate,
        onScheduleItemTapped: onScheduleItemTapped,
        onCreatePersonalEvent: coordinator.pager.onCreatePersonalEvent,
        onCreatePromise: coordinator.pager.onCreatePromise,
        onDeleteScheduleItem: coordinator.pager.onDeleteScheduleItem,
        onShareScheduleItem: coordinator.pager.onShareScheduleItem,
        currentUserId: coordinator.pager.currentUserId,
        weatherCache: coordinator.pager.weatherCache,
        groupColorMap: coordinator.pager.groupColorMap
      )
      vc.recenterToCurrentPage(animated: false)

      // 모든 오프셋을 동기적으로 설정
      vc.forceLayout()

      // 센터(page 1): 도착 페이지의 오프셋 즉시 복원
      vc.applyOffset(at: 1, offset: coordinator.arrivedPageOffset)

      // 인접 페이지: 캐시 오프셋 또는 현재 시간
      let prevDay = calendar.date(byAdding: .day, value: -1, to: selectedDay)
      let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay)
      let fallbackOffset = vc.currentTimeOffset()
      let prevOffset = prevDay.flatMap { coordinator.savedOffsets[$0] } ?? fallbackOffset
      let nextOffset = nextDay.flatMap { coordinator.savedOffsets[$0] } ?? fallbackOffset
      vc.applyOffset(at: 0, offset: prevOffset)
      vc.applyOffset(at: 2, offset: nextOffset)
      coordinator.lastSelectedDay = selectedDay
    } else {
      let previousDay = coordinator.lastSelectedDay
      let isDateChanged = previousDay != selectedDay

      if isDateChanged {
        // 날짜 탭 전환: 떠나는 날짜(center page)의 현재 오프셋을 날짜 키로 저장
        if let centerSV = vc.findInnerScrollView(at: 1) {
          coordinator.savedOffsets[previousDay] = centerSV.contentOffset.y
        }

        // 슬라이드 방향 결정
        let goingForward = selectedDay > previousDay
        let targetPage = goingForward ? 2 : 0

        // 타겟 페이지에 새 날짜 데이터 로드
        vc.updateSinglePage(
          at: targetPage,
          scheduleItems: currentDayScheduleItems,
          displayDate: selectedDay,
          onScheduleItemTapped: onScheduleItemTapped,
          onCreatePersonalEvent: onCreatePersonalEvent,
          onCreatePromise: onCreatePromise,
          onDeleteScheduleItem: onDeleteScheduleItem,
          onShareScheduleItem: onShareScheduleItem,
          currentUserId: currentUserId,
          weatherCache: weatherCache,
          groupColorMap: groupColorMap
        )
        vc.forceLayout()

        // 타겟 페이지 오프셋 적용
        let targetOffset = coordinator.savedOffsets[selectedDay] ?? vc.currentTimeOffset()
        vc.applyOffset(at: targetPage, offset: targetOffset)

        // 슬라이드 애니메이션
        coordinator.isAnimatingDateTap = true
        coordinator.lastSelectedDay = selectedDay
        vc.scrollToPage(targetPage, animated: true)
      } else {
        // 일반 업데이트 — 오프셋 보존
        let savedOffsets = vc.saveAllOffsets()
        vc.updatePages(
          prevDayScheduleItems: prevDayScheduleItems,
          currentDayScheduleItems: currentDayScheduleItems,
          nextDayScheduleItems: nextDayScheduleItems,
          selectedDate: selectedDate,
          onScheduleItemTapped: onScheduleItemTapped,
          onCreatePersonalEvent: coordinator.pager.onCreatePersonalEvent,
          onCreatePromise: coordinator.pager.onCreatePromise,
          onDeleteScheduleItem: coordinator.pager.onDeleteScheduleItem,
          onShareScheduleItem: coordinator.pager.onShareScheduleItem,
          currentUserId: coordinator.pager.currentUserId,
          weatherCache: coordinator.pager.weatherCache,
          groupColorMap: coordinator.pager.groupColorMap
        )
        if !savedOffsets.isEmpty {
          vc.restoreOffsets(savedOffsets)
        }
      }
      coordinator.lastSelectedDay = selectedDay
    }
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var pager: DayTimelinePager
    weak var pagerVC: PagerViewController?
    var needsRecenter = false
    var savedOffsets: [Date: CGFloat] = [:]
    var arrivedPageOffset: CGFloat = 0
    var lastSelectedDay: Date
    var isAnimatingDateTap = false

    init(pager: DayTimelinePager) {
      self.pager = pager
      self.lastSelectedDay = Calendar.promiseDisplay.startOfDay(for: pager.selectedDate)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
      guard isAnimatingDateTap else { return }
      isAnimatingDateTap = false

      guard let vc = pagerVC else { return }

      // 애니메이션 완료 후 전체 페이지를 올바른 데이터로 교체 + 리센터
      vc.updatePages(
        prevDayScheduleItems: pager.prevDayScheduleItems,
        currentDayScheduleItems: pager.currentDayScheduleItems,
        nextDayScheduleItems: pager.nextDayScheduleItems,
        selectedDate: pager.selectedDate,
        onScheduleItemTapped: pager.onScheduleItemTapped,
        onCreatePersonalEvent: pager.onCreatePersonalEvent,
        onCreatePromise: pager.onCreatePromise,
        onDeleteScheduleItem: pager.onDeleteScheduleItem,
        onShareScheduleItem: pager.onShareScheduleItem,
        currentUserId: pager.currentUserId,
        weatherCache: pager.weatherCache,
        groupColorMap: pager.groupColorMap
      )
      vc.recenterToCurrentPage(animated: false)
      vc.forceLayout()

      let calendar = Calendar.promiseDisplay
      let selectedDay = calendar.startOfDay(for: pager.selectedDate)
      let prevDay = calendar.date(byAdding: .day, value: -1, to: selectedDay)
      let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay)
      let fallbackOffset = vc.currentTimeOffset()

      let centerOffset = savedOffsets[selectedDay] ?? fallbackOffset
      let prevOffset = prevDay.flatMap { savedOffsets[$0] } ?? fallbackOffset
      let nextOffset = nextDay.flatMap { savedOffsets[$0] } ?? fallbackOffset

      vc.applyOffset(at: 1, offset: centerOffset)
      vc.applyOffset(at: 0, offset: prevOffset)
      vc.applyOffset(at: 2, offset: nextOffset)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))

      if currentPage == 0 {
        let calendar = Calendar.promiseDisplay
        let dateKey = calendar.startOfDay(for: pager.selectedDate)
        // 떠나는 페이지(page 1)의 오프셋 캐시
        if let innerSV = pagerVC?.findInnerScrollView(at: 1) {
          savedOffsets[dateKey] = innerSV.contentOffset.y
        }
        // 도착한 페이지(page 0)의 현재 오프셋 보존
        if let innerSV = pagerVC?.findInnerScrollView(at: 0) {
          arrivedPageOffset = innerSV.contentOffset.y
        } else {
          arrivedPageOffset = pagerVC?.currentTimeOffset() ?? 0
        }
        needsRecenter = true
        pager.onPreviousDay()
      } else if currentPage == 2 {
        let calendar = Calendar.promiseDisplay
        let dateKey = calendar.startOfDay(for: pager.selectedDate)
        // 떠나는 페이지(page 1)의 오프셋 캐시
        if let innerSV = pagerVC?.findInnerScrollView(at: 1) {
          savedOffsets[dateKey] = innerSV.contentOffset.y
        }
        // 도착한 페이지(page 2)의 현재 오프셋 보존
        if let innerSV = pagerVC?.findInnerScrollView(at: 2) {
          arrivedPageOffset = innerSV.contentOffset.y
        } else {
          arrivedPageOffset = pagerVC?.currentTimeOffset() ?? 0
        }
        needsRecenter = true
        pager.onNextDay()
      }
      // currentPage == 1 → 아무것도 안 함
    }
  }

  // MARK: - PagerViewController

  final class PagerViewController: UIViewController {
    var coordinator: Coordinator?
    var calendarMode: CalendarMode = .weekly
    var zoomState = TimelineZoomState()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageHostingControllers: [UIHostingController<DayTimelineView>] = []
    private var didApplyInitialOffsets = false

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear
      view.clipsToBounds = true

      scrollView.isPagingEnabled = true
      scrollView.showsHorizontalScrollIndicator = false
      scrollView.showsVerticalScrollIndicator = false
      scrollView.alwaysBounceVertical = false
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
      prevDayScheduleItems: [HomeModels.ScheduleItem],
      currentDayScheduleItems: [HomeModels.ScheduleItem],
      nextDayScheduleItems: [HomeModels.ScheduleItem],
      selectedDate: Date,
      onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void,
      onCreatePersonalEvent: @escaping (Date) -> Void,
      onCreatePromise: @escaping () -> Void,
      onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      currentUserId: String,
      weatherCache: [String: WeatherInfo],
      groupColorMap: [String: Color]
    ) {
      scrollView.delegate = coordinator

      let pageWidthMultiplier = 1.0 / 3.0
      let calendar = Calendar.promiseDisplay
      let currentDay = calendar.startOfDay(for: selectedDate)
      let prevDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
      let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
      let displayDates = [prevDay, currentDay, nextDay]
      let itemsArrays = [prevDayScheduleItems, currentDayScheduleItems, nextDayScheduleItems]

      for (index, items) in itemsArrays.enumerated() {
        let dayTimelineView = DayTimelineView(
          scheduleItems: items,
          displayDate: displayDates[index],
          onScheduleItemTapped: onScheduleItemTapped,
          onCreatePersonalEvent: onCreatePersonalEvent,
          onCreatePromise: onCreatePromise,
          onDeleteScheduleItem: onDeleteScheduleItem,
          onShareScheduleItem: onShareScheduleItem,
          calendarMode: calendarMode,
          currentUserId: currentUserId,
          weatherCache: weatherCache,
          groupColorMap: groupColorMap,
          zoomState: zoomState
        )
        let hostingVC = UIHostingController(rootView: dayTimelineView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        contentView.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
          hostingVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
          hostingVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
          hostingVC.view.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: pageWidthMultiplier),
        ])

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
      prevDayScheduleItems: [HomeModels.ScheduleItem],
      currentDayScheduleItems: [HomeModels.ScheduleItem],
      nextDayScheduleItems: [HomeModels.ScheduleItem],
      selectedDate: Date,
      onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void,
      onCreatePersonalEvent: @escaping (Date) -> Void,
      onCreatePromise: @escaping () -> Void,
      onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      currentUserId: String,
      weatherCache: [String: WeatherInfo],
      groupColorMap: [String: Color]
    ) {
      let calendar = Calendar.promiseDisplay
      let currentDay = calendar.startOfDay(for: selectedDate)
      let prevDay = calendar.date(byAdding: .day, value: -1, to: currentDay) ?? currentDay
      let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay
      let displayDates = [prevDay, currentDay, nextDay]
      let itemsArrays = [prevDayScheduleItems, currentDayScheduleItems, nextDayScheduleItems]
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < itemsArrays.count else { break }
        vc.rootView = DayTimelineView(
          scheduleItems: itemsArrays[index],
          displayDate: displayDates[index],
          onScheduleItemTapped: onScheduleItemTapped,
          onCreatePersonalEvent: onCreatePersonalEvent,
          onCreatePromise: onCreatePromise,
          onDeleteScheduleItem: onDeleteScheduleItem,
          onShareScheduleItem: onShareScheduleItem,
          calendarMode: calendarMode,
          currentUserId: currentUserId,
          weatherCache: weatherCache,
          groupColorMap: groupColorMap,
          zoomState: zoomState
        )
      }
    }

    func recenterToCurrentPage(animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: animated)
    }

    /// 단일 페이지 데이터 업데이트
    func updateSinglePage(
      at index: Int,
      scheduleItems: [HomeModels.ScheduleItem],
      displayDate: Date,
      onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void,
      onCreatePersonalEvent: @escaping (Date) -> Void,
      onCreatePromise: @escaping () -> Void,
      onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
      currentUserId: String,
      weatherCache: [String: WeatherInfo],
      groupColorMap: [String: Color]
    ) {
      guard index < pageHostingControllers.count else { return }
      pageHostingControllers[index].rootView = DayTimelineView(
        scheduleItems: scheduleItems,
        displayDate: displayDate,
        onScheduleItemTapped: onScheduleItemTapped,
        onCreatePersonalEvent: onCreatePersonalEvent,
        onCreatePromise: onCreatePromise,
        onDeleteScheduleItem: onDeleteScheduleItem,
        onShareScheduleItem: onShareScheduleItem,
        calendarMode: calendarMode,
        currentUserId: currentUserId,
        weatherCache: weatherCache,
        groupColorMap: groupColorMap,
        zoomState: zoomState
      )
    }

    /// 지정 페이지로 스크롤
    func scrollToPage(_ page: Int, animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: CGFloat(page) * pageWidth, y: 0), animated: animated)
    }

    fileprivate func findInnerScrollView(at pageIndex: Int) -> UIScrollView? {
      guard pageIndex < pageHostingControllers.count else { return nil }
      return findScrollView(in: pageHostingControllers[pageIndex].view)
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
      for subview in view.subviews {
        if let sv = subview as? UIScrollView {
          return sv
        }
        if let found = findScrollView(in: subview) {
          return found
        }
      }
      return nil
    }

    /// 모든 호스팅 컨트롤러의 레이아웃을 강제 실행하여 inner scroll view가 존재하도록 보장
    func forceLayout() {
      for vc in pageHostingControllers {
        vc.view.setNeedsLayout()
      }
      view.layoutIfNeeded()
    }

    /// 지정된 페이지의 inner scroll view에 오프셋을 동기적으로 적용
    func applyOffset(at pageIndex: Int, offset: CGFloat) {
      guard let innerSV = findInnerScrollView(at: pageIndex) else { return }
      innerSV.contentOffset.y = offset
    }

    /// 현재 시간 기준 오프셋 계산 (hour - 1) * 52, 19시 이후는 16시 영역으로 cap
    func currentTimeOffset() -> CGFloat {
      let hourHeight: CGFloat = 52
      let hour = Calendar.promiseDisplay.component(.hour, from: Date())
      let capped = max(0, min(hour, 16) - 1)
      return CGFloat(capped) * hourHeight
    }

    /// 모든 페이지의 현재 inner scroll offset 저장
    func saveAllOffsets() -> [Int: CGFloat] {
      var offsets: [Int: CGFloat] = [:]
      for i in 0..<pageHostingControllers.count {
        if let innerSV = findInnerScrollView(at: i) {
          offsets[i] = innerSV.contentOffset.y
        }
      }
      return offsets
    }

    /// 저장된 오프셋을 동기적으로 복원
    func restoreOffsets(_ offsets: [Int: CGFloat]) {
      forceLayout()
      for (index, offset) in offsets {
        applyOffset(at: index, offset: offset)
      }
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      // 초기 레이아웃 후 center page로 이동
      let pageWidth = scrollView.bounds.width
      if pageWidth > 0 && scrollView.contentOffset.x == 0 {
        scrollView.contentOffset = CGPoint(x: pageWidth, y: 0)
      }
      applyInitialCurrentTimeOffsetsIfNeeded()
    }

    /// 최초 1회: 3페이지 모두 현재 시간 기준으로 동기 오프셋 적용
    private func applyInitialCurrentTimeOffsetsIfNeeded() {
      guard !didApplyInitialOffsets else { return }
      guard !pageHostingControllers.isEmpty else { return }

      forceLayout()

      let offset = currentTimeOffset()
      applyOffset(at: 0, offset: offset)
      applyOffset(at: 1, offset: offset)
      applyOffset(at: 2, offset: offset)
      didApplyInitialOffsets = true
    }
  }
}
