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
  
  static func loupe() -> Package.Dependency {
    .package(
      url: "https://github.com/Aeastr/Loupe.git",
      .upToNextMajor(from: "2.1.0")
    )
  }
  
  static func kakao() -> Package.Dependency {
    .package(
      url: "https://github.com/kakao/kakao-ios-sdk",
      .upToNextMajor(from: "2.26.0")
    )
  }
  
  // MARK: - All Dependencies
  static var all: [Package.Dependency] { [
    tca(),
    firebase(),
    loupe(),
    kakao(),
  ]}
}

let package = Package(
  name: "Promiso",
  dependencies: Dependencies.all
)
