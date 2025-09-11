import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .rootTab

// Pre-computed dependency arrays to avoid compiler timeout
private let interfaceDependencies = SharedDependencies.interface + DefaultExternalDependency.interface

private let implementDependencies = [
  FeatureDependency.interface(feature),
  FeatureDependency.interface(.home, isExternal: true),
  FeatureDependency.interface(.promise, isExternal: true)
] + SharedDependencies.implement + DefaultExternalDependency.implement

private let testingDependencies = [
  FeatureDependency.interface(feature)
] + SharedDependencies.testing + DefaultExternalDependency.testing

private let testsDependencies = FeatureDependency.all(feature) + DefaultExternalDependency.tests

private let exampleDependencies = FeatureDependency.all(feature) + DefaultExternalDependency.example

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
      dependencies: interfaceDependencies
    ),

    // Implement
    .target(
      name: "\(feature.fullName)Implement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: implementDependencies
    ),

    // Testing
    .target(
      name: "\(feature.fullName)Testing",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: testingDependencies
    ),

    // Unit Tests
    .target(
      name: "\(feature.fullName)Tests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: testsDependencies
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
      dependencies: exampleDependencies,
      settings: .withTeamId()
    )
  ]
)
