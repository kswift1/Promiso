import UIKit

final class CalendarOverlayTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
  nonisolated func presentationController(
    forPresented presented: UIViewController,
    presenting: UIViewController?,
    source: UIViewController
  ) -> UIPresentationController? {
    MainActor.assumeIsolated {
      CalendarOverlayPresentationController(
        presentedViewController: presented,
        presenting: presenting
      )
    }
  }

  nonisolated func animationController(
    forPresented presented: UIViewController,
    presenting: UIViewController,
    source: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    MainActor.assumeIsolated {
      CalendarOverlayPresentAnimator()
    }
  }

  nonisolated func animationController(
    forDismissed dismissed: UIViewController
  ) -> (any UIViewControllerAnimatedTransitioning)? {
    MainActor.assumeIsolated {
      CalendarOverlayDismissAnimator()
    }
  }
}
