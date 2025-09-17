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
      sources: ["Networking/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .target(name: "CoreInfrastructure")
      ] + DefaultExternalDependency.interface + DefaultExternalDependency.firebase(.firestore)
    ),
    
    // Infrastructure Module - 통합 인프라 서비스
        .target(
          name: "CoreInfrastructure",
          destinations: .iOS,
          product: .framework,
          bundleId: "\(AppConfig.name).core.infrastructure",
          deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
          sources: ["Infrastructure/**"],
          dependencies: [
            ExternalDependency.tca
          ]
        ),
    
    // Tests
    .target(
      name: "CoreTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).core.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/**"],
      dependencies: [
        .target(name: "CoreNetworking"),
        .target(name: "CoreInfrastructure")
      ] + DefaultExternalDependency.tests
    )
  ]
)
