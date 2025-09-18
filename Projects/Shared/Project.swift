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
        .project(target: "CoreInfrastructure", path: "../Core"),
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ],
      settings: .standard()
    )
  ]
)
