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
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen"),
        "UIDesignRequiresCompatibility": .boolean(false)
      ]),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: AppFeatureDeps.allDeps,
      settings: .standard()
    )
  ]
)
