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
      resources: ["Resources/**"],
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ExternalDependency", path: "../ExternalDependency"),
        // Clarity는 ExternalDependency에 포함되어 있지만,
        // @_exported import 시 다른 타입과 충돌하므로
        // ClarityClient에서만 직접 import해서 사용
        .external(name: "Clarity")
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
      ],
      settings: .settings(
        base: ["CODE_SIGNING_ALLOWED": "NO"]
      )
    )
  ]
)
