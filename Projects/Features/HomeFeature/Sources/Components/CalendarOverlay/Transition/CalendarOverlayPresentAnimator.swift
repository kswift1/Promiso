import UIKit

final class CalendarOverlayPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  nonisolated func transitionDuration(
    using transitionContext: (any UIViewControllerContextTransitioning)?
  ) -> TimeInterval {
    0.55
  }

  nonisolated func animateTransition(
    using transitionContext: any UIViewControllerContextTransitioning
  ) {
    MainActor.assumeIsolated {
      performAnimation(using: transitionContext)
    }
  }

  private func performAnimation(
    using transitionContext: any UIViewControllerContextTransitioning
  ) {
    guard
      let toVC = transitionContext.viewController(forKey: .to),
      let toView = transitionContext.view(forKey: .to)
    else {
      transitionContext.completeTransition(false)
      return
    }

    let containerView = transitionContext.containerView
    let finalFrame = transitionContext.finalFrame(for: toVC)

    // 화면 위에서 시작, 아래로 슬라이드
    toView.frame = finalFrame.offsetBy(dx: 0, dy: -finalFrame.height)
    containerView.addSubview(toView)

    let duration = transitionDuration(using: transitionContext)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: 1.0,
      initialSpringVelocity: 0,
      options: []
    ) {
      toView.frame = finalFrame
    } completion: { _ in
      let cancelled = transitionContext.transitionWasCancelled
      transitionContext.completeTransition(!cancelled)
    }
  }
}
