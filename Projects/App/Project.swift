import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: AppConfig.name,
  settings: .settings(
    configurations: [
      .debug(name: "Debug"),
      .release(name: "Release")
    ]
  ),
  targets: [
    // MARK: - PromisoDev (Development Environment)
    .target(
      name: "PromisoDev",
      destinations: .iOS,
      product: .app,
      bundleId: "com.promiso.dev",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist.merging([
        "CFBundleDisplayName": "Promiso [DEV]"
      ]) { _, new in new }),
      sources: ["Sources/**"],
      resources: ["Resources/**", "Resources-Dev/**"],
      entitlements: .file(path: "PromisoDev.entitlements"),
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension-Dev"),
        .target(name: "PromiseWidgetExtension-Dev")
      ],
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
          "PRODUCT_BUNDLE_IDENTIFIER": "com.promiso.dev"
        ],
        configurations: [
          .debug(name: "Debug", xcconfig: .relativeToRoot("Config/Dev.xcconfig")),
          .release(name: "Release", xcconfig: .relativeToRoot("Config/Dev.xcconfig"))
        ]
      )
    ),

    // MARK: - PromisoStage (Staging Environment)
    .target(
      name: "PromisoStage",
      destinations: .iOS,
      product: .app,
      bundleId: "com.promiso.stage",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist.merging([
        "CFBundleDisplayName": "Promiso [STAGE]"
      ]) { _, new in new }),
      sources: ["Sources/**"],
      resources: ["Resources/**", "Resources-Stage/**"],
      entitlements: .file(path: "PromisoStage.entitlements"),
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension-Stage"),
        .target(name: "PromiseWidgetExtension-Stage")
      ],
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
          "PRODUCT_BUNDLE_IDENTIFIER": "com.promiso.stage"
        ],
        configurations: [
          .debug(name: "Debug", xcconfig: .relativeToRoot("Config/Stage.xcconfig")),
          .release(name: "Release", xcconfig: .relativeToRoot("Config/Stage.xcconfig"))
        ]
      )
    ),

    // MARK: - Promiso (Production Environment)
    .target(
      name: AppConfig.name,
      destinations: .iOS,
      product: .app,
      bundleId: AppConfig.bundleId,
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist),
      sources: ["Sources/**"],
      resources: ["Resources/**", "Resources-Prod/**"],
      entitlements: .file(path: "Promiso.entitlements"),
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension"),
        .target(name: "PromiseWidgetExtension")
      ],
      settings: .settings(
        base: [
          "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor"
        ],
        configurations: [
          .debug(name: "Debug", xcconfig: .relativeToRoot("Config/Prod.xcconfig")),
          .release(name: "Release", xcconfig: .relativeToRoot("Config/Prod.xcconfig"))
        ]
      )
    ),

    // MARK: - LiveActivityWidgetExtension-Dev
    .target(
      name: "LiveActivityWidgetExtension-Dev",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "com.promiso.dev.liveactivity",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso Live Activity [DEV]",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/LiveActivityWidget/Sources/**"],
      entitlements: .file(path: "Extensions/LiveActivityWidget/LiveActivityWidget-Dev.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    ),

    // MARK: - LiveActivityWidgetExtension-Stage
    .target(
      name: "LiveActivityWidgetExtension-Stage",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "com.promiso.stage.liveactivity",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso Live Activity [STAGE]",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/LiveActivityWidget/Sources/**"],
      entitlements: .file(path: "Extensions/LiveActivityWidget/LiveActivityWidget-Stage.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    ),

    // MARK: - LiveActivityWidgetExtension (Production)
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

    // MARK: - PromiseWidgetExtension-Dev
    .target(
      name: "PromiseWidgetExtension-Dev",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "com.promiso.dev.promisewidget",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso [DEV]",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/PromiseWidget/Sources/**"],
      entitlements: .file(path: "Extensions/PromiseWidget/PromiseWidget-Dev.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    ),

    // MARK: - PromiseWidgetExtension-Stage
    .target(
      name: "PromiseWidgetExtension-Stage",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "com.promiso.stage.promisewidget",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso [STAGE]",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/PromiseWidget/Sources/**"],
      entitlements: .file(path: "Extensions/PromiseWidget/PromiseWidget-Stage.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    ),

    // MARK: - PromiseWidgetExtension (Production)
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
