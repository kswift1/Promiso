import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "ResourceKit",
  targets: [
    .target(
      name: "ResourceKit",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("resourcekit"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: [],
      settings: .standard()
    )
  ]
)
