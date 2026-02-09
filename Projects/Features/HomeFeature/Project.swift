import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .home

let project = Project(
  name: feature.fullName,
  targets: [

    // Main Feature (TCA)
    .target(
      name: "HomeFeature",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix)",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "Clients", path: "../../Clients"),
        .project(target: "PromisoShared", path: "../../Shared"),
        .project(target: "ExternalDependency", path: "../../ExternalDependency"),
        .project(target: "ResourceKit", path: "../../ResourceKit"),
        .project(target: "SharedFeature", path: "../SharedFeature"),
        .project(target: "NotificationCenterFeature", path: "../NotificationCenterFeature")
      ],
      settings: .standard()
    ),

    // Unit Tests
    .target(
      name: "HomeFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .target(name: "HomeFeature")
      ],
      settings: .standard()
    ),

    // Example App (Demo)
    .target(
      name: "HomeFeatureExample",
      destinations: .iOS,
      product: .app,
      bundleId: "\(feature.defaultBundleIdPrefix).example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .target(name: "HomeFeature")
      ],
      settings: .standard()
    )
  ]
)
