import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: AppConfig.name,
  targets: [
    // MARK: - Main App Target
    .target(
      name: AppConfig.name,
      destinations: .iOS,
      product: .app,
      bundleId: AppConfig.bundleId,
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      entitlements: .file(path: "Promiso.entitlements"),
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension"),
        .target(name: "PromiseWidgetExtension")
      ],
      settings: .standard()
    ),
    // MARK: - Live Activity Widget Extension
    .target(
      name: "LiveActivityWidgetExtension",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "\(AppConfig.bundleId).liveactivity",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso Live Activity",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/LiveActivityWidget/Sources/**"],
      entitlements: .file(path: "Extensions/LiveActivityWidget/LiveActivityWidget.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    ),
    // MARK: - Promise Widget Extension (Home Screen)
    .target(
      name: "PromiseWidgetExtension",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "\(AppConfig.bundleId).promisewidget",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/PromiseWidget/Sources/**"],
      entitlements: .file(path: "Extensions/PromiseWidget/PromiseWidget.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    )
  ]
)
