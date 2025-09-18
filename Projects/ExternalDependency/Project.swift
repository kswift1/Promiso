import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "ExternalDependency",
  targets: [
    .target(
      name: "ExternalDependency",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("externaldependency"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      dependencies: ExternalDeps.allExternalDeps(),
      settings: .standard()
    )
  ]
)
