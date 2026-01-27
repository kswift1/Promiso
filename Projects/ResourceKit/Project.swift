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
      dependencies: [
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ],
      settings: .standard()
    )
  ],
  resourceSynthesizers: [
    .assets(),
    .custom(name: "Lottie", parser: .json, extensions: ["json"])
  ]
)
