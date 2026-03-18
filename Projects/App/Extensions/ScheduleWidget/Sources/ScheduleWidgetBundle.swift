import SwiftUI
import WidgetKit

@main
struct ScheduleWidgetBundle: WidgetBundle {
  var body: some Widget {
    ScheduleSystemSmallWidget()
    ScheduleSystemMediumWidget()
    ScheduleSystemLargeWidget()
    ScheduleAccessoryCircularWidget()
    ScheduleAccessoryRectangularWidget()
  }
}
