import UIKit

final class CalendarOverlayPresentationController: UIPresentationController {
  private let dimmingView = UIView()

  override var shouldRemovePresentersView: Bool { false }

  override var frameOfPresentedViewInContainerView: CGRect {
    guard let containerView else { return .zero }
    if let calendarVC = presentedViewController as? CalendarOverlayHostingController {
      let height = calendarVC.sizeThatFits(
        in: CGSize(width: containerView.bounds.width, height: .greatestFiniteMagnitude)
      ).height
      return CGRect(x: 0, y: 0, width: containerView.bounds.width, height: height)
    }
    return containerView.bounds
  }

  override func presentationTransitionWillBegin() {
    guard let containerView else { return }

    dimmingView.backgroundColor = .black
    dimmingView.alpha = 0
    dimmingView.frame = containerView.bounds
    containerView.insertSubview(dimmingView, at: 0)

    let tap = UITapGestureRecognizer(target: self, action: #selector(dimmingViewTapped))
    dimmingView.addGestureRecognizer(tap)

    let presentingView = presentingViewController.view!
    presentingView.layer.masksToBounds = true

    presentedViewController.transitionCoordinator?.animate(
      alongsideTransition: { _ in
        presentingView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        presentingView.alpha = 0.4
        presentingView.layer.cornerRadius = 30
        self.dimmingView.alpha = 0.3
      }
    )
  }

  override func dismissalTransitionWillBegin() {
    let presentingView = presentingViewController.view!

    presentedViewController.transitionCoordinator?.animate(
      alongsideTransition: { _ in
        presentingView.transform = .identity
        presentingView.alpha = 1.0
        presentingView.layer.cornerRadius = 0
        self.dimmingView.alpha = 0
      }
    )
  }

  // MARK: - Dimming View Tap

  @objc nonisolated private func dimmingViewTapped() {
    MainActor.assumeIsolated {
      if let calendarVC = presentedViewController as? CalendarOverlayHostingController {
        calendarVC.viewModel.onClose()
      }
    }
  }

  // MARK: - Interactive Dismiss Progress

  /// 수동 pan gesture에서 호출 - 손가락 위치에 1:1 대응
  func updateForDismissProgress(_ progress: CGFloat) {
    let presentingView = presentingViewController.view!
    let scale = 0.88 + (1.0 - 0.88) * progress
    let alpha = 0.4 + (1.0 - 0.4) * progress
    let cornerRadius = 30.0 * (1.0 - progress)
    let dimmingAlpha = 0.3 * (1.0 - progress)

    presentingView.transform = CGAffineTransform(scaleX: scale, y: scale)
    presentingView.alpha = alpha
    presentingView.layer.cornerRadius = cornerRadius
    dimmingView.alpha = dimmingAlpha
  }

  override func dismissalTransitionDidEnd(_ completed: Bool) {
    if completed {
      dimmingView.removeFromSuperview()
      let presentingView = presentingViewController.view!
      presentingView.layer.masksToBounds = false
      presentingView.layer.cornerRadius = 0
      presentingView.transform = .identity
      presentingView.alpha = 1.0
    }
  }
}
