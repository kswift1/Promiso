import SwiftUI
import WidgetKit

@main
struct PromiseWidgetBundle: WidgetBundle {
  var body: some Widget {
    PromiseSystemSmallWidget()
    PromiseSystemMediumWidget()
    PromiseSystemLargeWidget()
    PromiseAccessoryCircularWidget()
    PromiseAccessoryRectangularWidget()
  }
}
