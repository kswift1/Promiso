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

  func makeCoordinator() -> Coordinator {
    Coordinator(pager: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
    vc.setupPages(
      prevDayScheduleItems: prevDayScheduleItems,
      currentDayScheduleItems: currentDayScheduleItems,
      nextDayScheduleItems: nextDayScheduleItems,
      onScheduleItemTapped: onScheduleItemTapped
    )
    return vc
  }

  func updateUIViewController(_ vc: PagerViewController, context: Context) {
    let coordinator = context.coordinator
    coordinator.pager = self

    // 페이지 전환 직후 리센터 요청이 있으면 콘텐츠 업데이트 + 리센터
    if coordinator.needsRecenter {
      coordinator.needsRecenter = false
      vc.updatePages(
        prevDayScheduleItems: prevDayScheduleItems,
        currentDayScheduleItems: currentDayScheduleItems,
        nextDayScheduleItems: nextDayScheduleItems,
        onScheduleItemTapped: onScheduleItemTapped
      )
      vc.recenterToCurrentPage(animated: false)

      // 센터(page 1): 도착 페이지의 오프셋을 동기적으로 즉시 복원
      vc.applyCenterOffset(coordinator.arrivedPageOffset)

      // 인접 페이지(page 0, 2): 캐시 오프셋으로 async 프리셋
      let calendar = Calendar.promiseDisplay
      let selectedDay = calendar.startOfDay(for: coordinator.pager.selectedDate)
      let prevDay = calendar.date(byAdding: .day, value: -1, to: selectedDay)
      let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay)
      let prevOffset = prevDay.flatMap { coordinator.savedOffsets[$0] }
      let nextOffset = nextDay.flatMap { coordinator.savedOffsets[$0] }
      vc.presetAdjacentOffsets(prevOffset: prevOffset, nextOffset: nextOffset)
    } else {
      // 일반 업데이트 (선택 날짜 변경 등)
      vc.updatePages(
        prevDayScheduleItems: prevDayScheduleItems,
        currentDayScheduleItems: currentDayScheduleItems,
        nextDayScheduleItems: nextDayScheduleItems,
        onScheduleItemTapped: onScheduleItemTapped
      )
    }
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var pager: DayTimelinePager
    weak var pagerVC: PagerViewController?
    var needsRecenter = false
    var savedOffsets: [Date: CGFloat] = [:]
    var arrivedPageOffset: CGFloat = 0

    init(pager: DayTimelinePager) {
      self.pager = pager
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
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageHostingControllers: [UIHostingController<DayTimelineView>] = []

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
      onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void
    ) {
      scrollView.delegate = coordinator

      let pageWidthMultiplier = 1.0 / 3.0
      let itemsArrays = [prevDayScheduleItems, currentDayScheduleItems, nextDayScheduleItems]

      for (index, items) in itemsArrays.enumerated() {
        let dayTimelineView = DayTimelineView(
          scheduleItems: items,
          onScheduleItemTapped: onScheduleItemTapped
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
      onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void
    ) {
      let itemsArrays = [prevDayScheduleItems, currentDayScheduleItems, nextDayScheduleItems]
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < itemsArrays.count else { break }
        vc.rootView = DayTimelineView(
          scheduleItems: itemsArrays[index],
          onScheduleItemTapped: onScheduleItemTapped
        )
      }
    }

    func recenterToCurrentPage(animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: animated)
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

    /// 센터 페이지 오프셋을 동기적으로 복원 (화면에 보이므로 즉시 적용)
    func applyCenterOffset(_ offset: CGFloat) {
      // SwiftUI rootView 변경 후 레이아웃을 강제 실행
      for vc in pageHostingControllers {
        vc.view.setNeedsLayout()
      }
      view.layoutIfNeeded()

      // 동기적으로 센터 페이지 inner scroll의 offset 설정
      if let innerScrollView = findInnerScrollView(at: 1) {
        innerScrollView.contentOffset.y = offset
      }
    }

    /// 인접 페이지(오프스크린) 오프셋 프리셋 — async OK
    func presetAdjacentOffsets(prevOffset: CGFloat?, nextOffset: CGFloat?) {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        // page 0 (이전일)
        if let innerSV = self.findInnerScrollView(at: 0) {
          if let offset = prevOffset {
            innerSV.contentOffset.y = offset
          } else {
            self.scrollToCurrentTime(scrollView: innerSV)
          }
        }
        // page 2 (다음일)
        if let innerSV = self.findInnerScrollView(at: 2) {
          if let offset = nextOffset {
            innerSV.contentOffset.y = offset
          } else {
            self.scrollToCurrentTime(scrollView: innerSV)
          }
        }
      }
    }

    private func scrollToCurrentTime(scrollView: UIScrollView) {
      let hourHeight: CGFloat = 52
      let hour = max(0, Calendar.promiseDisplay.component(.hour, from: Date()) - 1)
      let targetY = CGFloat(hour) * hourHeight
      let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
      scrollView.contentOffset.y = min(targetY, maxY)
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      // 초기 레이아웃 후 center page로 이동
      let pageWidth = scrollView.bounds.width
      if pageWidth > 0 && scrollView.contentOffset.x == 0 {
        scrollView.contentOffset = CGPoint(x: pageWidth, y: 0)
      }
    }
  }
}
