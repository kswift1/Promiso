import ProjectDescription

let project = Project(
  name: "MainFeatureInterface",
  targets: [
    .target(
      name: "MainFeatureInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.interface",
      deploymentTargets: .iOS("16.4"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "SharedModels", path: "../../../Shared/SharedModels")
      ]
    )
  ]
)