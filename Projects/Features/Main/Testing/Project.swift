import ProjectDescription

let project = Project(
  name: "MainFeatureTesting",
  targets: [
    .target(
      name: "MainFeatureTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.testing",
      deploymentTargets: .iOS("16.4"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "MainFeatureInterface", path: "../Interface")
      ]
    )
  ]
)