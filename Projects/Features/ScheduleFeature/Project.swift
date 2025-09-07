import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "ScheduleFeature",
  targets: [

    // Interface
    .target(
      name: "ScheduleInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.schedule.interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: []
    ),

    // Implement
    .target(
      name: "ScheduleImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.schedule.implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        .project(target: "ScheduleInterface", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Testing
    .target(
      name: "ScheduleTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.schedule.testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        .project(target: "ScheduleInterface", path: ".")
      ]
    ),

    // Unit Tests
    .target(
      name: "ScheduleTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).features.schedule.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .project(target: "ScheduleImplement", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Example App (Demo)
    .target(
      name: "ScheduleExample",
      destinations: .iOS,
      product: .app,
      bundleId: "\(AppConfig.name).features.schedule.example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .project(target: "ScheduleImplement", path: ".")
      ]
    )
  ]
)