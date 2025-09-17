import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Core",
  targets: [
    // Dependencies Module
    .target(
      name: "CoreDependencies",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.dependencies",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Dependencies/Sources/**"],
      dependencies: DefaultExternalDependency.interface
    ),
    
    // Networking Module
    .target(
      name: "CoreNetworking",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.networking",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Networking/Sources/**"],
      dependencies: [
        .target(name: "CoreDependencies"),
        .target(name: "CoreUtilities")
      ] + DefaultExternalDependency.interface
    ),
    
    // Storage Module
    .target(
      name: "CoreStorage",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.storage",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Storage/Sources/**"],
      dependencies: [
        .target(name: "CoreDependencies"),
        .target(name: "CoreUtilities")
      ] + DefaultExternalDependency.interface
    ),
    
    // Utilities Module
    .target(
      name: "CoreUtilities",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.utilities",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Utilities/Sources/**"],
      dependencies: DefaultExternalDependency.interface
    ),
    
    // Logger Module
    .target(
      name: "CoreLogger",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.logger",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Logger/Sources/**"],
      dependencies: [
        .target(name: "CoreDependencies"),
        .target(name: "CoreUtilities")
      ] + DefaultExternalDependency.interface
    ),
    
    // Analytics Module
    .target(
      name: "CoreAnalytics",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).core.analytics",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Analytics/Sources/**"],
      dependencies: [
        .target(name: "CoreDependencies"),
        .target(name: "CoreLogger"),
        .target(name: "CoreUtilities")
      ] + DefaultExternalDependency.interface
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
        .target(name: "CoreDependencies"),
        .target(name: "CoreNetworking"),
        .target(name: "CoreStorage"),
        .target(name: "CoreUtilities"),
        .target(name: "CoreLogger"),
        .target(name: "CoreAnalytics")
      ] + DefaultExternalDependency.tests
    )
  ]
)
