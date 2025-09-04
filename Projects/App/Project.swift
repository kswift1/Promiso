import ProjectDescription

let project = Project(
  name: "StopLateApp",
  targets: [
    .target(
      name: "StopLateApp",
      destinations: .iOS,
      product: .app,
      bundleId: "com.example.StopLate",
      deploymentTargets: .iOS("16.4"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: [
        .project(target: "MainFeatureInterface", path: "../Features/Main"),
          .project(target: "MainFeatureImplement", path: "../Features/Main"),
      ]
    )
  ]
)
