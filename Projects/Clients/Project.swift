import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Clients",
  targets: [
    .target(
      name: "Clients",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.sungwon.promiso.clients",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .default,
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "Shared", path: "../Shared"),
        .project(target: "ExternalDependency", path: "../ExternalDependency")
      ]
    ),
    .target(
      name: "ClientsTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "com.sungwon.promiso.clients.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .default,
      sources: ["Tests/**"],
      dependencies: [
        .target(name: "Clients")
      ]
    )
  ]
)
