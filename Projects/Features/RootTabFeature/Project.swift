import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "RootTabFeature",
  targets: [

    // Interface
    .target(
      name: "RootTabInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.roottab.interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: []
    ),

    // Implement
    .target(
      name: "RootTabImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.roottab.implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        .project(target: "RootTabInterface", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Testing
    .target(
      name: "RootTabTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.roottab.testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        .project(target: "RootTabInterface", path: ".")
      ]
    ),

    // Unit Tests
    .target(
      name: "RootTabTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).features.roottab.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .project(target: "RootTabImplement", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Example App (Demo)
    .target(
      name: "RootTabExample",
      destinations: .iOS,
      product: .app,
      bundleId: "\(AppConfig.name).features.roottab.example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .project(target: "RootTabImplement", path: ".")
      ]
    )
  ]
)