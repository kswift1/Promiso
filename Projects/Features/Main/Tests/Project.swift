import ProjectDescription

let project = Project(
  name: "MainFeatureTests",
  targets: [
    .target(
      name: "MainFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.example.features.main.tests",
      deploymentTargets: .iOS("16.4"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "MainFeatureImplement", path: "../Implement")
      ]
    )
  ]
)