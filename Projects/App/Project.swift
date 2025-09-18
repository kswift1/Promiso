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
        "UIDesignRequiresCompatibility": .boolean(true)
      ]),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: AppFeatureDeps.allFeaturesDeps() + [
        .project(target: "Shared", path: "../Shared"),
        .project(target: "CoreInfrastructure", path: "../Core"),
        .project(target: "CoreNetworking", path: "../Core"),
        .project(target: "Domain", path: "../Domain"),
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ]
      ,
      settings: .withTeamId()
    )
  ]
)
