import SwiftUI

@main
struct StopLateApp: App {
  var body: some Scene {
    WindowGroup {
      Factories
        .main()
        .makeView(.init())
    }
  }
}
