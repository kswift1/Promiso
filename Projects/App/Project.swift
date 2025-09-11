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
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies:
        AppFeatureDeps.allFeaturesDeps() + [
          ExternalDependency.tca
        ],
      settings: .withTeamId()
    )
  ]
)
