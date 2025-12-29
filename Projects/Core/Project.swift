import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Core",
  targets: [
    
    // Networking Module
    .target(
      name: "CoreNetworking",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("core.networking"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/Networking/**"],
      dependencies: [],
      settings: .standard()
    ),
    
    // Infrastructure Module - 통합 인프라 서비스
    .target(
      name: "CoreInfrastructure",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("core.infrastructure"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/Infrastructure/**"],
      dependencies: [],
      settings: .standard()
    )
  ]
)
