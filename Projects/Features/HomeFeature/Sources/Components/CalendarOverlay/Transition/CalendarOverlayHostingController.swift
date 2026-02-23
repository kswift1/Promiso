import Observation
import SwiftUI
import UIKit
import PromisoShared
import ResourceKit

// MARK: - Calendar Overlay ViewModel

@Observable
final class CalendarOverlayViewModel {
  var currentMonth: Date
  var selectedDate: Date
  var prevMonthDays: [OverlayCalendarModels.DayItem]
  var days: [OverlayCalendarModels.DayItem]
  var nextMonthDays: [OverlayCalendarModels.DayItem]
  var weatherState: OverlayWeatherState
  var detailMode: Bool
  var scheduleItems: [HomeModels.ScheduleItem]
  var weekDays: [OverlayCalendarModels.DayItem]
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void
  let onWeatherCardTapped: () -> Void
  let onBackToMonth: () -> Void
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void

  init(
    currentMonth: Date,
    selectedDate: Date,
    prevMonthDays: [OverlayCalendarModels.DayItem],
    days: [OverlayCalendarModels.DayItem],
    nextMonthDays: [OverlayCalendarModels.DayItem],
    weatherState: OverlayWeatherState,
    detailMode: Bool,
    scheduleItems: [HomeModels.ScheduleItem],
    weekDays: [OverlayCalendarModels.DayItem],
    onClose: @escaping () -> Void,
    onDateSelected: @escaping (Date) -> Void,
    onPreviousMonth: @escaping () -> Void,
    onNextMonth: @escaping () -> Void,
    onWeatherCardTapped: @escaping () -> Void,
    onBackToMonth: @escaping () -> Void,
    onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void
  ) {
    self.currentMonth = currentMonth
    self.selectedDate = selectedDate
    self.prevMonthDays = prevMonthDays
    self.days = days
    self.nextMonthDays = nextMonthDays
    self.weatherState = weatherState
    self.detailMode = detailMode
    self.scheduleItems = scheduleItems
    self.weekDays = weekDays
    self.onClose = onClose
    self.onDateSelected = onDateSelected
    self.onPreviousMonth = onPreviousMonth
    self.onNextMonth = onNextMonth
    self.onWeatherCardTapped = onWeatherCardTapped
    self.onBackToMonth = onBackToMonth
    self.onScheduleItemTapped = onScheduleItemTapped
  }
}

// MARK: - Calendar Overlay Hosting Controller

final class CalendarOverlayHostingController: UIHostingController<AnyView> {
  let viewModel: CalendarOverlayViewModel
  private var initialFrame: CGRect = .zero

  init(viewModel: CalendarOverlayViewModel) {
    self.viewModel = viewModel
    let content = CalendarOverlayContentView(viewModel: viewModel)
    super.init(rootView: AnyView(content))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    safeAreaRegions = []
    view.backgroundColor = .secondarySystemBackground
    view.layer.cornerRadius = 32
    view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    view.clipsToBounds = true

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    pan.delegate = self
    view.addGestureRecognizer(pan)
  }

  // MARK: - Pan Gesture

  @objc nonisolated private func handlePan(_ gesture: UIPanGestureRecognizer) {
    MainActor.assumeIsolated {
      performHandlePan(gesture)
    }
  }

  private func performHandlePan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: view)
    let velocity = gesture.velocity(in: view)
    let pc = presentationController as? CalendarOverlayPresentationController

    switch gesture.state {
    case .began:
      initialFrame = view.frame

    case .changed:
      // 위로만 이동 허용
      let offsetY = min(0, translation.y)
      view.frame = initialFrame.offsetBy(dx: 0, dy: offsetY)

      let totalDistance = initialFrame.height + 200
      let progress = min(max(-offsetY / totalDistance, 0), 1)
      pc?.updateForDismissProgress(progress)

    case .ended, .cancelled:
      let offsetY = min(0, translation.y)
      let totalDistance = initialFrame.height + 200
      let progress = min(max(-offsetY / totalDistance, 0), 1)

      if progress > 0.3 || velocity.y < -800 {
        // dismiss: 위로 날리기
        UIView.animate(
          withDuration: 0.35,
          delay: 0,
          usingSpringWithDamping: 1.0,
          initialSpringVelocity: 0
        ) {
          self.view.frame = self.initialFrame.offsetBy(
            dx: 0, dy: -(self.initialFrame.height + 200)
          )
          pc?.updateForDismissProgress(1.0)
        } completion: { _ in
          self.dismiss(animated: false) {
            self.viewModel.onClose()
          }
        }
      } else {
        // spring back
        UIView.animate(
          withDuration: 0.35,
          delay: 0,
          usingSpringWithDamping: 0.9,
          initialSpringVelocity: 0
        ) {
          self.view.frame = self.initialFrame
          pc?.updateForDismissProgress(0)
        }
      }

    default:
      break
    }
  }
}

// MARK: - UIGestureRecognizerDelegate

extension CalendarOverlayHostingController: UIGestureRecognizerDelegate {
  nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    MainActor.assumeIsolated {
      guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
      let velocity = pan.velocity(in: view)
      // 수직 방향일 때만 dismiss pan 시작 (수평 드래그는 SwiftUI에 위임)
      return abs(velocity.y) > abs(velocity.x)
    }
  }
}

// MARK: - Content View

private struct CalendarOverlayContentView: View {
  var viewModel: CalendarOverlayViewModel
  @State private var isCollapsed = false

  var body: some View {
    GeometryReader { proxy in
      let topPad = SafeArea.topInset + 16
      let bottomPad: CGFloat = 16
      let availableHeight = proxy.size.height - topPad - bottomPad

      CalendarOverlayView(
        availableHeight: availableHeight,
        currentMonth: viewModel.currentMonth,
        selectedDate: viewModel.selectedDate,
        prevMonthDays: viewModel.prevMonthDays,
        days: viewModel.days,
        nextMonthDays: viewModel.nextMonthDays,
        weatherState: viewModel.weatherState,
        detailMode: isCollapsed,
        scheduleItems: viewModel.scheduleItems,
        weekDays: viewModel.weekDays,
        onClose: viewModel.onClose,
        onDateSelected: viewModel.onDateSelected,
        onPreviousMonth: viewModel.onPreviousMonth,
        onNextMonth: viewModel.onNextMonth,
        onWeatherCardTapped: viewModel.onWeatherCardTapped,
        onBackToMonth: viewModel.onBackToMonth,
        onScheduleItemTapped: viewModel.onScheduleItemTapped
      )
      .padding(.top, topPad)
      .padding(.bottom, bottomPad)
    }
    .background(alignment: .top) {
      Color(.systemBackground)
        .frame(height: SafeArea.topInset + 16)
    }
    .onChange(of: viewModel.detailMode) { _, newValue in
      withAnimation(.spring(duration: 0.45, bounce: 0.05)) {
        isCollapsed = newValue
      }
    }
  }
}
