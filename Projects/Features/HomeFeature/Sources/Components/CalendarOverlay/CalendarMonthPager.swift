import SwiftUI
import UIKit
import PromisoShared

// MARK: - Calendar Month Pager

/// UIScrollView 기반 3페이지 수평 페이저 (prev / current / next month)
struct CalendarMonthPager: UIViewControllerRepresentable {
  let prevDays: [OverlayCalendarModels.DayItem]
  let currentDays: [OverlayCalendarModels.DayItem]
  let nextDays: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(pager: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
    vc.setupPages(
      prevDays: prevDays,
      currentDays: currentDays,
      nextDays: nextDays,
      onDateSelected: onDateSelected
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
        prevDays: prevDays,
        currentDays: currentDays,
        nextDays: nextDays,
        onDateSelected: onDateSelected
      )
      vc.recenterToCurrentPage(animated: false)
    } else {
      // 일반 업데이트 (선택 날짜 변경 등)
      vc.updatePages(
        prevDays: prevDays,
        currentDays: currentDays,
        nextDays: nextDays,
        onDateSelected: onDateSelected
      )
    }
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var pager: CalendarMonthPager
    weak var pagerVC: PagerViewController?
    var needsRecenter = false

    init(pager: CalendarMonthPager) {
      self.pager = pager
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))

      if currentPage == 0 {
        // 이전 월로 이동
        needsRecenter = true
        pager.onPreviousMonth()
      } else if currentPage == 2 {
        // 다음 월로 이동
        needsRecenter = true
        pager.onNextMonth()
      }
      // currentPage == 1 → 원래 위치, 아무것도 안 함
    }
  }

  // MARK: - PagerViewController

  final class PagerViewController: UIViewController {
    var coordinator: Coordinator?
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageHostingControllers: [UIHostingController<CalendarMonthGridView>] = []

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .clear

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
      prevDays: [OverlayCalendarModels.DayItem],
      currentDays: [OverlayCalendarModels.DayItem],
      nextDays: [OverlayCalendarModels.DayItem],
      onDateSelected: @escaping (Date) -> Void
    ) {
      scrollView.delegate = coordinator

      let daysArrays = [prevDays, currentDays, nextDays]
      for (index, days) in daysArrays.enumerated() {
        let gridView = CalendarMonthGridView(days: days, onDateSelected: onDateSelected)
        let hostingVC = UIHostingController(rootView: gridView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        contentView.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        let pageWidth = 1.0 / 3.0

        NSLayoutConstraint.activate([
          hostingVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
          hostingVC.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
          hostingVC.view.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: pageWidth),
          hostingVC.view.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: 0
          ),
        ])

        // 각 페이지 위치 설정 (leading constraint 대신 multiplier 활용)
        if index > 0 {
          hostingVC.view.leadingAnchor.constraint(
            equalTo: pageHostingControllers[index - 1].view.trailingAnchor
          ).isActive = true
          // 위에서 잡은 leading to contentView 제거를 위해 별도 처리
        }

        pageHostingControllers.append(hostingVC)
      }

      // Leading constraints 재설정
      setupPageConstraints()
    }

    private func setupPageConstraints() {
      guard pageHostingControllers.count == 3 else { return }

      // 기존 constraints를 제거하고 재설정
      for vc in pageHostingControllers {
        vc.view.removeFromSuperview()
      }

      for (index, vc) in pageHostingControllers.enumerated() {
        contentView.addSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false

        let pageWidth = 1.0 / 3.0

        NSLayoutConstraint.activate([
          vc.view.topAnchor.constraint(equalTo: contentView.topAnchor),
          vc.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
          vc.view.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: pageWidth),
        ])

        if index == 0 {
          vc.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        } else {
          vc.view.leadingAnchor.constraint(
            equalTo: pageHostingControllers[index - 1].view.trailingAnchor
          ).isActive = true
        }
      }
    }

    func updatePages(
      prevDays: [OverlayCalendarModels.DayItem],
      currentDays: [OverlayCalendarModels.DayItem],
      nextDays: [OverlayCalendarModels.DayItem],
      onDateSelected: @escaping (Date) -> Void
    ) {
      let daysArrays = [prevDays, currentDays, nextDays]
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < daysArrays.count else { break }
        vc.rootView = CalendarMonthGridView(days: daysArrays[index], onDateSelected: onDateSelected)
      }
    }

    func recenterToCurrentPage(animated: Bool) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      scrollView.setContentOffset(CGPoint(x: pageWidth, y: 0), animated: animated)
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
