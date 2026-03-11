import SwiftUI
import UIKit
import PromisoShared

// MARK: - Calendar Overlay Presenter (SwiftUI ↔ UIKit Bridge)

struct CalendarOverlayPresenter: UIViewControllerRepresentable {
  let isPresented: Bool
  let currentMonth: Date
  let selectedDate: Date
  let prevMonthDays: [OverlayCalendarModels.DayItem]
  let days: [OverlayCalendarModels.DayItem]
  let nextMonthDays: [OverlayCalendarModels.DayItem]
  let weatherState: OverlayWeatherState
  let weatherLocationText: String?
  let weatherInfo: WeatherInfo?
  let calendarMode: CalendarMode
  let scheduleItems: [HomeModels.ScheduleItem]
  let prevDayScheduleItems: [HomeModels.ScheduleItem]
  let nextDayScheduleItems: [HomeModels.ScheduleItem]
  let weekDays: [OverlayCalendarModels.DayItem]
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]
  var holidayDates: Set<Date> = []
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void
  let onWeatherCardTapped: () -> Void
  let onBackToMonth: () -> Void
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void
  let onEditScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let onCreatePersonalEvent: (Date) -> Void
  let onCreateSchedule: () -> Void
  let onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  /// scheduleDetail/scheduleCreate 모드에서 표시할 뷰
  let overlayFeatureContent: AnyView?
  /// scheduleDetail/scheduleCreate 뒤로가기 클로저
  let onFeatureBack: (() -> Void)?

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
        viewModel.selectedDate = selectedDate
        viewModel.prevMonthDays = prevMonthDays
        viewModel.days = days
        viewModel.nextMonthDays = nextMonthDays
        viewModel.weatherState = weatherState
        viewModel.weatherLocationText = weatherLocationText
        viewModel.weatherInfo = weatherInfo
        viewModel.calendarMode = calendarMode
        viewModel.scheduleItems = scheduleItems
        viewModel.prevDayScheduleItems = prevDayScheduleItems
        viewModel.nextDayScheduleItems = nextDayScheduleItems
        viewModel.weekDays = weekDays
        viewModel.currentUserId = currentUserId
        viewModel.weatherCache = weatherCache
        viewModel.groupColorMap = groupColorMap
        viewModel.holidayDates = holidayDates
        viewModel.overlayFeatureContent = overlayFeatureContent
        viewModel.onFeatureBack = onFeatureBack
      }

      // dismiss/transition 중에는 중복 present 방지
      if coordinator.isTransitioning {
        return
      }

      // 혹시 참조가 남아 있으면 정리
      if coordinator.overlayViewController == nil, coordinator.viewModel != nil {
        coordinator.viewModel = nil
      }

      // 아직 present 안 된 경우
      if coordinator.overlayViewController == nil {
        guard let presentingVC = uiViewController.modalPresentationHost else { return }
        // 다른 모달이 떠 있는 동안에는 오버레이를 새로 띄우지 않음
        guard presentingVC.presentedViewController == nil else { return }

        let viewModel = CalendarOverlayViewModel(
          currentMonth: currentMonth,
          selectedDate: selectedDate,
          prevMonthDays: prevMonthDays,
          days: days,
          nextMonthDays: nextMonthDays,
          weatherState: weatherState,
          weatherLocationText: weatherLocationText,
          weatherInfo: weatherInfo,
          calendarMode: calendarMode,
          scheduleItems: scheduleItems,
          prevDayScheduleItems: prevDayScheduleItems,
          nextDayScheduleItems: nextDayScheduleItems,
          weekDays: weekDays,
          currentUserId: currentUserId,
          weatherCache: weatherCache,
          groupColorMap: groupColorMap,
          holidayDates: holidayDates,
          onClose: onClose,
          onDateSelected: onDateSelected,
          onPreviousMonth: onPreviousMonth,
          onNextMonth: onNextMonth,
          onWeatherCardTapped: onWeatherCardTapped,
          onBackToMonth: onBackToMonth,
          onScheduleItemTapped: onScheduleItemTapped,
          onEditScheduleItem: onEditScheduleItem,
          onCreatePersonalEvent: onCreatePersonalEvent,
          onCreateSchedule: onCreateSchedule,
          onDeleteScheduleItem: onDeleteScheduleItem,
          onShareScheduleItem: onShareScheduleItem
        )
        viewModel.overlayFeatureContent = overlayFeatureContent
        viewModel.onFeatureBack = onFeatureBack
        coordinator.viewModel = viewModel

        let calendarVC = CalendarOverlayHostingController(viewModel: viewModel)
        calendarVC.modalPresentationStyle = .custom
        calendarVC.transitioningDelegate = coordinator.transitionDelegate
        coordinator.overlayViewController = calendarVC
        coordinator.isTransitioning = true

        presentingVC.present(calendarVC, animated: true) {
          coordinator.isTransitioning = false
          if calendarVC.presentingViewController == nil {
            coordinator.overlayViewController = nil
            coordinator.viewModel = nil
          }
        }
      }
    } else {
      // dismiss는 오버레이 자신만 대상으로 수행
      if coordinator.isTransitioning {
        return
      }

      guard let overlayVC = coordinator.overlayViewController else {
        coordinator.viewModel = nil
        return
      }

      if overlayVC.presentingViewController != nil || overlayVC.isBeingPresented {
        coordinator.isTransitioning = true
        overlayVC.dismiss(animated: true) {
          coordinator.isTransitioning = false
          coordinator.overlayViewController = nil
          coordinator.viewModel = nil
        }
      } else {
        coordinator.overlayViewController = nil
        coordinator.viewModel = nil
      }
    }
  }

  // MARK: - Coordinator

  final class Coordinator {
    let transitionDelegate = CalendarOverlayTransitionDelegate()
    var isTransitioning = false
    var viewModel: CalendarOverlayViewModel?
    weak var overlayViewController: CalendarOverlayHostingController?
  }
}

// MARK: - UIViewController Extension

private extension UIViewController {
  /// representable 기준 루트 컨테이너 VC
  var modalPresentationHost: UIViewController? {
    var candidate: UIViewController? = self
    while let parent = candidate?.parent {
      candidate = parent
    }
    return candidate
  }
}
