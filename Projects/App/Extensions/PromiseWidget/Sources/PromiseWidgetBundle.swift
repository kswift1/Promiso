import SwiftUI
import WidgetKit

@main
struct PromiseWidgetBundle: WidgetBundle {
  var body: some Widget {
    SmallPromiseWidget()
    MediumPromiseWidget()
    LargePromiseWidget()
    CircularPromiseWidget()
    RectangularPromiseWidget()
  }
}
