import UIKit

final class CalendarOverlayDismissAnimator: NSObject, UIViewControllerAnimatedTransitioning {
  nonisolated func transitionDuration(
    using transitionContext: (any UIViewControllerContextTransitioning)?
  ) -> TimeInterval {
    0.5
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
    guard let fromView = transitionContext.view(forKey: .from) else {
      transitionContext.completeTransition(false)
      return
    }

    let duration = transitionDuration(using: transitionContext)

    UIView.animate(
      withDuration: duration,
      delay: 0,
      usingSpringWithDamping: 1.0,
      initialSpringVelocity: 0,
      options: []
    ) {
      fromView.frame.origin.y = -(fromView.frame.height + 200)
    } completion: { _ in
      let cancelled = transitionContext.transitionWasCancelled
      if cancelled {
        fromView.frame.origin.y = 0
      }
      transitionContext.completeTransition(!cancelled)
    }
  }
}
