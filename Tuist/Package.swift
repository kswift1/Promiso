// swift-tools-version: 6.0
@preconcurrency import PackageDescription

#if TUIST
    import struct ProjectDescription.PackageSettings
    
    let packageSettings = PackageSettings(
        productTypes: [
            "ComposableArchitecture": .framework
        ]
    )
#endif

// MARK: - Package Dependencies

enum Dependencies {
    // MARK: - Architecture
    nonisolated(unsafe) static let tca = Package.Dependency.package(
        url: "https://github.com/pointfreeco/swift-composable-architecture",
        .upToNextMajor(from: "1.22.2")
    )
    
    // MARK: - Networking
    // nonisolated(unsafe) static let alamofire = Package.Dependency.package(
    //     url: "https://github.com/Alamofire/Alamofire",
    //     .upToNextMajor(from: "5.0.0")
    // )
    
    // MARK: - All Dependencies
    nonisolated(unsafe) static let all: [Package.Dependency] = [
        tca,
        // alamofire,
    ]
}

let package = Package(
    name: "StopLate",
    dependencies: Dependencies.all
)
