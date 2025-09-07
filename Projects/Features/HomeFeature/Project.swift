import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "HomeFeature",
  targets: [

    // Interface
    .target(
      name: "HomeInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.home.interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: []
    ),

    // Implement
    .target(
      name: "HomeImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.home.implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        .project(target: "HomeInterface", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Testing
    .target(
      name: "HomeTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.home.testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        .project(target: "HomeInterface", path: ".")
      ]
    ),

    // Unit Tests
    .target(
      name: "HomeTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).features.home.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .project(target: "HomeImplement", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Example App (Demo)
    .target(
      name: "HomeExample",
      destinations: .iOS,
      product: .app,
      bundleId: "\(AppConfig.name).features.home.example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .project(target: "HomeImplement", path: ".")
      ]
    )
  ]
)