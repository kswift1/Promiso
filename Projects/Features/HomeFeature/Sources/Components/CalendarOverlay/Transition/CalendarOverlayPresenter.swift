import SwiftUI
import UIKit
import PromisoShared

// MARK: - Calendar Overlay Presenter (SwiftUI ↔ UIKit Bridge)

struct CalendarOverlayPresenter: UIViewControllerRepresentable {
  let isPresented: Bool
  let currentMonth: Date
  let days: [OverlayCalendarModels.DayItem]
  let todayScheduleItems: [HomeModels.ScheduleItem]
  let selectedDate: Date
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIViewController(context: Context) -> UIViewController {
    UIViewController()
  }

  func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    let coordinator = context.coordinator

    if isPresented {
      // ViewModel 업데이트 (이미 presented인 경우)
      if let viewModel = coordinator.viewModel {
        viewModel.currentMonth = currentMonth
        viewModel.days = days
        viewModel.todayScheduleItems = todayScheduleItems
        viewModel.selectedDate = selectedDate
      }

      // 아직 present 안 된 경우
      if !coordinator.isPresenting {
        coordinator.isPresenting = true

        let viewModel = CalendarOverlayViewModel(
          currentMonth: currentMonth,
          days: days,
          todayScheduleItems: todayScheduleItems,
          selectedDate: selectedDate,
          onClose: onClose,
          onDateSelected: onDateSelected,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth
        )
        coordinator.viewModel = viewModel

        let calendarVC = CalendarOverlayHostingController(viewModel: viewModel)
        calendarVC.modalPresentationStyle = .custom
        calendarVC.transitioningDelegate = coordinator.transitionDelegate

        // 부모 VC 찾기
        let presentingVC = uiViewController.presentingParent ?? uiViewController
        presentingVC.present(calendarVC, animated: true)
      }
    } else {
      // dismiss
      if coordinator.isPresenting {
        let presentingVC = uiViewController.presentingParent ?? uiViewController
        if presentingVC.presentedViewController != nil {
          presentingVC.dismiss(animated: true) {
            coordinator.isPresenting = false
            coordinator.viewModel = nil
          }
        } else {
          // 제스처로 이미 dismiss 완료된 경우
          coordinator.isPresenting = false
          coordinator.viewModel = nil
        }
      }
    }
  }

  // MARK: - Coordinator

  final class Coordinator {
    let transitionDelegate = CalendarOverlayTransitionDelegate()
    var isPresenting = false
    var viewModel: CalendarOverlayViewModel?
  }
}

// MARK: - UIViewController Extension

private extension UIViewController {
  /// 실제 present 가능한 부모 VC 찾기
  var presentingParent: UIViewController? {
    var candidate: UIViewController? = self
    while let parent = candidate?.parent {
      candidate = parent
    }
    // 이미 present 중인 VC가 있으면 그걸 사용
    if candidate?.presentedViewController != nil {
      return nil // 이미 present 중
    }
    return candidate
  }
}
