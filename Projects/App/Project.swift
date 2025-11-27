import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: AppConfig.name,
  targets: [
    .target(
      name: AppConfig.name,
      destinations: .iOS,
      product: .app,
      bundleId: AppConfig.bundleId,
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      entitlements: .file(path: "Promiso.entitlements"),
      dependencies: AppFeatureDeps.allDeps,
      settings: .standard()
    )
  ]
)
