import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .rootTab

let project = Project(
  name: feature.fullName,
  targets: [

    // Interface
    .target(
      name: "\(feature.fullName)Interface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: DefaultExternalDependency.interface
    ),

    // Implement
    .target(
      name: "\(feature.fullName)Implement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        FeatureDependency.interface(feature),
        FeatureDependency.interface(.schedule, isExternal: true)
      ] + DefaultExternalDependency.implement
    ),

    // Testing
    .target(
      name: "\(feature.fullName)Testing",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        FeatureDependency.interface(feature)
      ] + DefaultExternalDependency.testing
    ),

    // Unit Tests
    .target(
      name: "\(feature.fullName)Tests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: FeatureDependency.all(feature) + DefaultExternalDependency.tests
    ),

    // Example App (Demo)
    .target(
      name: "\(feature.fullName)Example",
      destinations: .iOS,
      product: .app,
      bundleId: "\(feature.defaultBundleIdPrefix).example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: FeatureDependency.all(feature) + DefaultExternalDependency.example
    )
  ]
)
