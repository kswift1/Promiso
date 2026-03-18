import UIKit

final class CalendarOverlayPresentationController: UIPresentationController {

  // MARK: - Constants

  private enum Layout {
    static let presentedHeightRatio: CGFloat = 0.85
    static let presentingScale: CGFloat = 0.88
    static let presentingAlpha: CGFloat = 0.4
    static let presentingCornerRadius: CGFloat = 30
    static let dimmingAlpha: CGFloat = 0.3
  }

  private let dimmingView = UIView()

  override var shouldRemovePresentersView: Bool { false }

  override var frameOfPresentedViewInContainerView: CGRect {
    guard let containerView else { return .zero }
    let height = containerView.bounds.height * Layout.presentedHeightRatio
    return CGRect(x: 0, y: 0, width: containerView.bounds.width, height: height)
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
        presentingView.transform = CGAffineTransform(scaleX: Layout.presentingScale, y: Layout.presentingScale)
        presentingView.alpha = Layout.presentingAlpha
        presentingView.layer.cornerRadius = Layout.presentingCornerRadius
        self.dimmingView.alpha = Layout.dimmingAlpha
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
    let scale = Layout.presentingScale + (1.0 - Layout.presentingScale) * progress
    let alpha = Layout.presentingAlpha + (1.0 - Layout.presentingAlpha) * progress
    let cornerRadius = Layout.presentingCornerRadius * (1.0 - progress)
    let dimmingAlpha = Layout.dimmingAlpha * (1.0 - progress)

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
