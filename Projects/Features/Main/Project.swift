import ProjectDescription

let project = Project(
  name: "MainFeature",
  targets: [

    // Interface
    .target(
      name: "MainFeatureInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.interface",
      deploymentTargets: .iOS("16.4"),
      sources: ["Interface/Sources/**"],
      dependencies: []
    ),

    // Implement
    .target(
      name: "MainFeatureImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.implement",
      deploymentTargets: .iOS("16.4"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        .project(target: "MainFeatureInterface", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Testing
    .target(
      name: "MainFeatureTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.testing",
      deploymentTargets: .iOS("16.4"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        .project(target: "MainFeatureInterface", path: ".")
      ]
    ),

    // Unit Tests
    .target(
      name: "MainFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.example.features.main.tests",
      deploymentTargets: .iOS("16.4"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .project(target: "MainFeatureImplement", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Example App (Demo)
    .target(
      name: "MainFeatureExample",
      destinations: .iOS,
      product: .app,
      bundleId: "com.example.features.main.example",
      deploymentTargets: .iOS("16.4"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .project(target: "MainFeatureImplement", path: ".")
      ]
    )
  ]
)