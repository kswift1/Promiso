import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Shared",
  targets: [
    .target(
      name: "Shared",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("shared"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: [
        .project(target: "ResourceKit", path: "../ResourceKit"),
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ],
      settings: .standard()
    ),
    .target(
      name: "SharedTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: AppConfig.moduleBundleId("shared.tests"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/**"],
      dependencies: [
        .target(name: "Shared")
      ],
      settings: .standard()
    )
  ]
)
