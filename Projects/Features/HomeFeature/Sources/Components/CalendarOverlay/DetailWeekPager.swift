import SwiftUI
import UIKit
import PromisoShared

// MARK: - Detail Week Pager

/// detail mode 하단 3페이지 주간 수평 페이저
struct DetailWeekPager: UIViewControllerRepresentable {
  let prevWeekDays: [OverlayCalendarModels.DayItem]
  let currentWeekDays: [OverlayCalendarModels.DayItem]
  let nextWeekDays: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void
  let onPreviousWeek: () -> Void
  let onNextWeek: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(pager: self)
  }

  func makeUIViewController(context: Context) -> PagerViewController {
    let vc = PagerViewController()
    vc.coordinator = context.coordinator
    context.coordinator.pagerVC = vc
    vc.setupPages(
      prevWeekDays: prevWeekDays,
      currentWeekDays: currentWeekDays,
      nextWeekDays: nextWeekDays,
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
        prevWeekDays: prevWeekDays,
        currentWeekDays: currentWeekDays,
        nextWeekDays: nextWeekDays,
        onDateSelected: onDateSelected
      )
      vc.recenterToCurrentPage(animated: false)
    } else {
      // 일반 업데이트 (선택 날짜 변경 등)
      vc.updatePages(
        prevWeekDays: prevWeekDays,
        currentWeekDays: currentWeekDays,
        nextWeekDays: nextWeekDays,
        onDateSelected: onDateSelected
      )
    }
  }

  // MARK: - Coordinator

  final class Coordinator: NSObject, UIScrollViewDelegate {
    var pager: DetailWeekPager
    weak var pagerVC: PagerViewController?
    var needsRecenter = false

    init(pager: DetailWeekPager) {
      self.pager = pager
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
      let pageWidth = scrollView.bounds.width
      guard pageWidth > 0 else { return }
      let currentPage = Int(round(scrollView.contentOffset.x / pageWidth))

      if currentPage == 0 {
        // 이전 주로 이동
        needsRecenter = true
        pager.onPreviousWeek()
      } else if currentPage == 2 {
        // 다음 주로 이동
        needsRecenter = true
        pager.onNextWeek()
      }
      // currentPage == 1 → 원래 위치, 아무것도 안 함
    }
  }

  // MARK: - PagerViewController

  final class PagerViewController: UIViewController {
    var coordinator: Coordinator?
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private var pageHostingControllers: [UIHostingController<WeekRowView>] = []

    private let rowHeight: CGFloat = 48

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
      prevWeekDays: [OverlayCalendarModels.DayItem],
      currentWeekDays: [OverlayCalendarModels.DayItem],
      nextWeekDays: [OverlayCalendarModels.DayItem],
      onDateSelected: @escaping (Date) -> Void
    ) {
      scrollView.delegate = coordinator

      let pageWidthMultiplier = 1.0 / 3.0
      let daysArrays = [prevWeekDays, currentWeekDays, nextWeekDays]

      for (index, days) in daysArrays.enumerated() {
        let weekRowView = WeekRowView(days: days, onDateSelected: onDateSelected)
        let hostingVC = UIHostingController(rootView: weekRowView)
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingVC)
        contentView.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
          hostingVC.view.topAnchor.constraint(equalTo: contentView.topAnchor),
          hostingVC.view.heightAnchor.constraint(equalToConstant: rowHeight),
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
      prevWeekDays: [OverlayCalendarModels.DayItem],
      currentWeekDays: [OverlayCalendarModels.DayItem],
      nextWeekDays: [OverlayCalendarModels.DayItem],
      onDateSelected: @escaping (Date) -> Void
    ) {
      let daysArrays = [prevWeekDays, currentWeekDays, nextWeekDays]
      for (index, vc) in pageHostingControllers.enumerated() {
        guard index < daysArrays.count else { break }
        vc.rootView = WeekRowView(days: daysArrays[index], onDateSelected: onDateSelected)
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

// MARK: - Week Row View

/// 페이저 내 단일 주 행 뷰
private struct WeekRowView: View {
  let days: [OverlayCalendarModels.DayItem]
  let onDateSelected: (Date) -> Void

  private var selectedIndex: Int? {
    days.firstIndex(where: { $0.isSelected })
  }

  var body: some View {
    ZStack {
      // Layer 1: 슬라이딩 하이라이트 원
      GeometryReader { geo in
        let cellWidth = geo.size.width / max(CGFloat(days.count), 1)

        if let idx = selectedIndex {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 36, height: 36)
            .position(
              x: cellWidth * CGFloat(idx) + cellWidth / 2,
              y: geo.size.height / 2 - 4
            )
        }
      }
      .animation(.spring(duration: 0.3), value: selectedIndex)

      // Layer 2: 날짜 셀 (하이라이트 원 제외)
      HStack(spacing: 0) {
        ForEach(days) { day in
          Button {
            onDateSelected(day.date)
          } label: {
            OverlayCalendarDayCell(day: day, showSelectedHighlight: false)
          }
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity)
          .contentShape(Rectangle())
        }
      }
    }
  }
}
