import Foundation

import ExternalDependency
import Clients

enum LiveDependencies {
  static func install(into dependencies: inout DependencyValues) {
    dependencies.authClient = .liveValue
    dependencies.userProfileClient = .liveValue
    dependencies.promiseClient = .liveValue
    dependencies.groupClient = .liveValue
  }
}
