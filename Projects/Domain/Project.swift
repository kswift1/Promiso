import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Domain",
  targets: [
    // Domain Module - 순수 도메인 로직
    .target(
      name: "Domain",
      destinations: .iOS,
      product: .framework,
      bundleId: AppConfig.moduleBundleId("domain"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      settings: .standard()
    ),
    
    // Tests
    .target(
      name: "DomainTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: AppConfig.moduleBundleId("domain.tests"),
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/**"],
      dependencies: [
        .target(name: "Domain")
      ],
      settings: .standard()
    )
  ]
)
