import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .createSchedule

let project = Project(
  name: feature.fullName,
  options: .options(developmentRegion: "ko"),
  targets: [

    // Main Feature (TCA)
    .target(
      name: "CreateScheduleFeature",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix)",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "Clients", path: "../../Clients"),
        .project(target: "PromisoShared", path: "../../Shared"),
        .project(target: "SharedFeature", path: "../SharedFeature"),
        .project(target: "CreateGroupFeature", path: "../CreateGroupFeature"),
        .project(target: "ExternalDependency", path: "../../ExternalDependency")
      ],
      settings: .standard()
    ),

    // Unit Tests
    .target(
      name: "CreateScheduleFeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .target(name: "CreateScheduleFeature")
      ],
      settings: .standard()
    )
  ]
)
