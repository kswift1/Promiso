import SwiftUI

import ComposableArchitecture
import RootTabFeatureImplement

@main
struct PromisoApp: App {
  var body: some Scene {
    WindowGroup {
      Factories
        .main()
        .makeView(.init())
    }
  }
}
