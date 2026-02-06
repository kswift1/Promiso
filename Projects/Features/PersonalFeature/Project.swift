import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .personal

let project = Project(
  name: feature.fullName,
  targets: [

    // Main Feature (TCA)
    .target(
      name: "PersonalFeature",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix)",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "Clients", path: "../../Clients"),
        .project(target: "PromisoShared", path: "../../Shared"),
        .project(target: "SharedFeature", path: "../SharedFeature"),
        .project(target: "ResourceKit", path: "../../ResourceKit"),
        .project(target: "ExternalDependency", path: "../../ExternalDependency")
      ],
      settings: .standard()
    ),

    // Unit Tests
    .target(
      name: "PersonalFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .target(name: "PersonalFeature")
      ],
      settings: .standard()
    ),

    // Example App (Demo)
    .target(
      name: "PersonalFeatureExample",
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
        .target(name: "PersonalFeature")
      ],
      settings: .standard()
    )
  ]
)