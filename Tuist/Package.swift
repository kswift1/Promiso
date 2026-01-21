// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings

let packageSettings = PackageSettings()
#endif

// MARK: - Package Dependencies

enum Dependencies {
  // MARK: - Architecture
  static func tca() -> Package.Dependency {
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture",
      .upToNextMajor(from: "1.22.2")
    )
  }
  
  static func firebase() -> Package.Dependency {
    .package(
      url: "https://github.com/firebase/firebase-ios-sdk.git",
      .upToNextMajor(from: "12.3.0")
    )
  }
  
  static func google() -> Package.Dependency {
    .package(
      url: "https://github.com/google/GoogleSignIn-iOS",
      .upToNextMajor(from: "9.0.0")
    )
  }
  
  static func loupe() -> Package.Dependency {
    .package(
      url: "https://github.com/Aeastr/Loupe.git",
      .upToNextMajor(from: "2.1.0")
    )
  }

  static func nuke() -> Package.Dependency {
    .package(
      url: "https://github.com/kean/Nuke.git",
      .upToNextMajor(from: "12.8.0")
    )
  }

  static func clarity() -> Package.Dependency {
    .package(
      url: "https://github.com/microsoft/clarity-apps",
      .upToNextMajor(from: "3.4.0")
    )
  }

  static func lottie() -> Package.Dependency {
    .package(
      url: "https://github.com/airbnb/lottie-spm",
      .upToNextMajor(from: "4.5.1")
    )
  }

  // MARK: - All Dependencies
  static var all: [Package.Dependency] { [
    tca(),
    firebase(),
    loupe(),
    google(),
    nuke(),
    clarity(),
    lottie(),
  ]}
}

let package = Package(
  name: "Promiso",
  dependencies: Dependencies.all
)
