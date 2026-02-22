import Observation
import SwiftUI
import UIKit
import PromisoShared
import ResourceKit

// MARK: - Calendar Overlay ViewModel

@Observable
final class CalendarOverlayViewModel {
  var currentMonth: Date
  var days: [OverlayCalendarModels.DayItem]
  var todayScheduleItems: [HomeModels.ScheduleItem]
  var selectedDate: Date
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

  init(
    currentMonth: Date,
    days: [OverlayCalendarModels.DayItem],
    todayScheduleItems: [HomeModels.ScheduleItem],
    selectedDate: Date,
    onClose: @escaping () -> Void,
    onDateSelected: @escaping (Date) -> Void,
    onPreviousMonth: @escaping () -> Void,
    onNextMonth: @escaping () -> Void
  ) {
    self.currentMonth = currentMonth
    self.days = days
    self.todayScheduleItems = todayScheduleItems
    self.selectedDate = selectedDate
    self.onClose = onClose
    self.onDateSelected = onDateSelected
    self.onPreviousMonth = onPreviousMonth
    self.onNextMonth = onNextMonth
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
    view.backgroundColor = .systemBackground
    view.layer.cornerRadius = 32
    view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    view.clipsToBounds = true

    let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
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

// MARK: - Content View

private struct CalendarOverlayContentView: View {
  var viewModel: CalendarOverlayViewModel

  var body: some View {
    CalendarOverlayView(
      currentMonth: viewModel.currentMonth,
      days: viewModel.days,
      todayScheduleItems: viewModel.todayScheduleItems,
      selectedDate: viewModel.selectedDate,
      onClose: viewModel.onClose,
      onDateSelected: viewModel.onDateSelected,
      onPreviousMonth: viewModel.onPreviousMonth,
      onNextMonth: viewModel.onNextMonth
    )
    .padding(.top, SafeArea.topInset + 16)
    .padding(.horizontal, 4)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, alignment: .top)
  }
}
