import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "PromisoShared",
  targets: [
    .target(
      name: "PromisoShared",
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
      name: "PromisoSharedTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: AppConfig.moduleBundleId("shared.tests"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/**"],
      dependencies: [
        .target(name: "PromisoShared")
      ],
      settings: .standard()
    )
  ]
)
