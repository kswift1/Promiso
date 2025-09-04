import ProjectDescription

let project = Project(
  name: "MainFeatureImplement",
  packages: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.17.0"))
  ],
  targets: [
    .target(
      name: "MainFeatureImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "com.example.features.main.implement",
      deploymentTargets: .iOS("16.4"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "MainFeatureInterface", path: "../Interface"),
        .project(target: "SharedModels", path: "../../../Shared/SharedModels"),
        .project(target: "DesignSystem", path: "../../../Shared/DesignSystem"),
        .package(product: "ComposableArchitecture")
      ]
    )
  ]
)