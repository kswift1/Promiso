import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .appEntry

let project = Project(
  name: feature.fullName,
  options: .options(developmentRegion: "ko"),
  targets: [

    // Main Feature (TCA)
    .target(
      name: "AppEntryFeature",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix)",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "Clients", path: "../../Clients"),
        .project(target: "PromisoShared", path: "../../Shared"),
        .project(target: "ResourceKit", path: "../../ResourceKit"),
        .project(target: "AuthFeature", path: "../AuthFeature"),
        .project(target: "RootTabFeature", path: "../RootTabFeature"),
        .project(target: "ExternalDependency", path: "../../ExternalDependency")
      ],
      settings: .standard()
    ),

    // Unit Tests
    .target(
      name: "AppEntryFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .target(name: "AppEntryFeature"),
      ],
      settings: .standard()
    ),

    // Example App (Demo)
    .target(
      name: "AppEntryFeatureExample",
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
        .target(name: "AppEntryFeature")
      ],
      settings: .standard()
    )
  ]
)
