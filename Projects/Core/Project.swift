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
      bundleId: "\(AppConfig.name).core.networking",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/Networking/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ]
    ),
    
    // Infrastructure Module - 통합 인프라 서비스
    .target(
      name: "CoreInfrastructure",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.infrastructure",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/Infrastructure/**"],
      dependencies: [
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ]
    )
  ]
)
