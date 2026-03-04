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
  var weatherLocationText: String?
  var weatherInfo: WeatherInfo?
  var calendarMode: CalendarMode
  var scheduleItems: [HomeModels.ScheduleItem]
  var prevDayScheduleItems: [HomeModels.ScheduleItem]
  var nextDayScheduleItems: [HomeModels.ScheduleItem]
  var weekDays: [OverlayCalendarModels.DayItem]
  var currentUserId: String
  var weatherCache: [String: WeatherInfo]
  var groupColorMap: [String: Color]
  let onClose: () -> Void
  let onDateSelected: (Date) -> Void
  let onPreviousMonth: () -> Void
  let onNextMonth: () -> Void
  let onWeatherCardTapped: () -> Void
  let onBackToMonth: () -> Void
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void
  let onEditScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let onCreatePersonalEvent: (Date) -> Void
  let onCreatePromise: () -> Void
  let onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  let onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  /// promiseDetail/promiseCreate 모드에서 표시할 Feature 뷰
  var overlayFeatureContent: AnyView?
  /// promiseDetail/promiseCreate 모드에서 뒤로가기 클로저
  var onFeatureBack: (() -> Void)?

  init(
    currentMonth: Date,
    selectedDate: Date,
    prevMonthDays: [OverlayCalendarModels.DayItem],
    days: [OverlayCalendarModels.DayItem],
    nextMonthDays: [OverlayCalendarModels.DayItem],
    weatherState: OverlayWeatherState,
    weatherLocationText: String?,
    weatherInfo: WeatherInfo?,
    calendarMode: CalendarMode,
    scheduleItems: [HomeModels.ScheduleItem],
    prevDayScheduleItems: [HomeModels.ScheduleItem],
    nextDayScheduleItems: [HomeModels.ScheduleItem],
    weekDays: [OverlayCalendarModels.DayItem],
    currentUserId: String,
    weatherCache: [String: WeatherInfo],
    groupColorMap: [String: Color],
    onClose: @escaping () -> Void,
    onDateSelected: @escaping (Date) -> Void,
    onPreviousMonth: @escaping () -> Void,
    onNextMonth: @escaping () -> Void,
    onWeatherCardTapped: @escaping () -> Void,
    onBackToMonth: @escaping () -> Void,
    onScheduleItemTapped: @escaping (HomeModels.ScheduleItem) -> Void,
    onEditScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
    onCreatePersonalEvent: @escaping (Date) -> Void,
    onCreatePromise: @escaping () -> Void,
    onDeleteScheduleItem: ((HomeModels.ScheduleItem) -> Void)?,
    onShareScheduleItem: ((HomeModels.ScheduleItem) -> Void)?
  ) {
    self.currentMonth = currentMonth
    self.selectedDate = selectedDate
    self.prevMonthDays = prevMonthDays
    self.days = days
    self.nextMonthDays = nextMonthDays
    self.weatherState = weatherState
    self.weatherLocationText = weatherLocationText
    self.weatherInfo = weatherInfo
    self.calendarMode = calendarMode
    self.scheduleItems = scheduleItems
    self.prevDayScheduleItems = prevDayScheduleItems
    self.nextDayScheduleItems = nextDayScheduleItems
    self.weekDays = weekDays
    self.currentUserId = currentUserId
    self.weatherCache = weatherCache
    self.groupColorMap = groupColorMap
    self.onClose = onClose
    self.onDateSelected = onDateSelected
    self.onPreviousMonth = onPreviousMonth
    self.onNextMonth = onNextMonth
    self.onWeatherCardTapped = onWeatherCardTapped
    self.onBackToMonth = onBackToMonth
    self.onScheduleItemTapped = onScheduleItemTapped
    self.onEditScheduleItem = onEditScheduleItem
    self.onCreatePersonalEvent = onCreatePersonalEvent
    self.onCreatePromise = onCreatePromise
    self.onDeleteScheduleItem = onDeleteScheduleItem
    self.onShareScheduleItem = onShareScheduleItem
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
      // Feature 모드(약속 상세/생성)에서는 dismiss pan 비활성화
      let mode = viewModel.calendarMode
      if mode == .promiseDetail || mode == .promiseCreate {
        return false
      }
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
  @State private var animatedMode: CalendarMode = .monthly

  private var isFeatureMode: Bool {
    animatedMode == .promiseDetail || animatedMode == .promiseCreate
  }

  var body: some View {
    GeometryReader { proxy in
      let topPad = SafeArea.topInset + 16
      let bottomPad: CGFloat = 16
      let availableHeight = proxy.size.height - topPad - bottomPad

      ZStack {
        if isFeatureMode {
          overlayFeatureView
            .transition(.asymmetric(
              insertion: .move(edge: .top).combined(with: .opacity),
              removal: .move(edge: .top).combined(with: .opacity)
            ))
        } else {
          CalendarOverlayView(
            availableHeight: availableHeight,
            currentMonth: viewModel.currentMonth,
            selectedDate: viewModel.selectedDate,
            prevMonthDays: viewModel.prevMonthDays,
            days: viewModel.days,
            nextMonthDays: viewModel.nextMonthDays,
            weatherState: viewModel.weatherState,
            weatherLocationText: viewModel.weatherLocationText,
            weatherInfo: viewModel.weatherInfo,
            calendarMode: animatedMode,
            scheduleItems: viewModel.scheduleItems,
            prevDayScheduleItems: viewModel.prevDayScheduleItems,
            nextDayScheduleItems: viewModel.nextDayScheduleItems,
            weekDays: viewModel.weekDays,
            onClose: viewModel.onClose,
            onDateSelected: viewModel.onDateSelected,
            onPreviousMonth: viewModel.onPreviousMonth,
            onNextMonth: viewModel.onNextMonth,
            onWeatherCardTapped: viewModel.onWeatherCardTapped,
            onBackToMonth: viewModel.onBackToMonth,
            onScheduleItemTapped: viewModel.onScheduleItemTapped,
            onEditScheduleItem: viewModel.onEditScheduleItem,
            onCreatePersonalEvent: viewModel.onCreatePersonalEvent,
            onCreatePromise: viewModel.onCreatePromise,
            onDeleteScheduleItem: viewModel.onDeleteScheduleItem,
            onShareScheduleItem: viewModel.onShareScheduleItem,
            currentUserId: viewModel.currentUserId,
            weatherCache: viewModel.weatherCache,
            groupColorMap: viewModel.groupColorMap
          )
          .transition(.opacity)
        }
      }
      .padding(.top, topPad)
      .padding(.bottom, bottomPad)
    }
    .background(alignment: .top) {
      Color(isFeatureMode || animatedMode == .weatherDetail ? .secondarySystemBackground : .systemBackground)
        .frame(height: SafeArea.topInset + 16)
    }
    .background(Color(.secondarySystemBackground))
    .onChange(of: viewModel.calendarMode) { _, newValue in
      withAnimation(.spring(duration: 0.45, bounce: 0.05)) {
        animatedMode = newValue
      }
    }
  }

  // MARK: - Feature View (약속 상세/생성)

  private var overlayFeatureView: some View {
    VStack(spacing: 0) {
      // Feature 콘텐츠
      if let content = viewModel.overlayFeatureContent {
        content
      }
    }
    .background(Color(.secondarySystemBackground))
  }
}
