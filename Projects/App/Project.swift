import ProjectDescription
import ProjectDescriptionHelpers

// Helper for infoPlist with DisplayName
func infoPlistWithDisplayName(_ displayName: String, environment: String = "prod") -> [String: Plist.Value] {
  var plist = AppConfig.infoPlist(for: environment)
  plist["CFBundleDisplayName"] = .string(displayName)
  return plist
}

// MARK: - Main App Targets

let promisoDev = Target.target(
  name: "PromisoDev",
  destinations: .iOS,
  product: .app,
  bundleId: "com.promiso.dev",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: infoPlistWithDisplayName("Promiso [DEV]", environment: "dev")),
  sources: ["Sources/**"],
  resources: ["Resources-Dev/**"],
  entitlements: .file(path: "PromisoDev.entitlements"),
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension-Dev"),
    .target(name: "PromiseWidgetExtension-Dev")
  ],
  settings: .settings(
    base: [
      "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": .string("AccentColor"),
      "PRODUCT_BUNDLE_IDENTIFIER": .string("com.promiso.dev"),
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Automatic"),
      "DEEPLINK_SCHEME": .string("promiso-dev"),
      "DEEPLINK_WEB_HOST": .string("dev.promiso.app")
    ],
    configurations: [
      .debug(name: "Debug", xcconfig: .relativeToRoot("Config/Dev.xcconfig")),
      .release(name: "Release", xcconfig: .relativeToRoot("Config/Dev.xcconfig"))
    ]
  )
)

let promisoStage = Target.target(
  name: "PromisoStage",
  destinations: .iOS,
  product: .app,
  bundleId: "com.promiso.stage",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: infoPlistWithDisplayName("Promiso [STAGE]", environment: "stage")),
  sources: ["Sources/**"],
  resources: ["Resources-Stage/**"],
  entitlements: .file(path: "PromisoStage.entitlements"),
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension-Stage"),
    .target(name: "PromiseWidgetExtension-Stage")
  ],
  settings: .settings(
    base: [
      "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": .string("AccentColor"),
      "PRODUCT_BUNDLE_IDENTIFIER": .string("com.promiso.stage"),
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual"),
      "DEEPLINK_SCHEME": .string("promiso-stage"),
      "DEEPLINK_WEB_HOST": .string("stage.promiso.app")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.stage"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ], xcconfig: .relativeToRoot("Config/Stage.xcconfig")),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.stage"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ], xcconfig: .relativeToRoot("Config/Stage.xcconfig"))
    ]
  )
)

let promisoProd = Target.target(
  name: AppConfig.name,
  destinations: .iOS,
  product: .app,
  bundleId: AppConfig.bundleId,
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: infoPlistWithDisplayName("Promiso", environment: "prod")),
  sources: ["Sources/**"],
  resources: ["Resources-Prod/**"],
  entitlements: .file(path: "Promiso.entitlements"),
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension"),
    .target(name: "PromiseWidgetExtension")
  ],
  settings: .settings(
    base: [
      "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": .string("AccentColor"),
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual"),
      "DEEPLINK_SCHEME": .string("promiso"),
      "DEEPLINK_WEB_HOST": .string("promiso.app")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ], xcconfig: .relativeToRoot("Config/Prod.xcconfig")),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ], xcconfig: .relativeToRoot("Config/Prod.xcconfig"))
    ]
  )
)

// MARK: - Widget Extension Targets

let liveActivityDev = Target.target(
  name: "LiveActivityWidgetExtension-Dev",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.dev.liveactivity",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Live Activity [DEV]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "dev")),
    "DEEPLINK_SCHEME": "promiso-dev",
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
  settings: .standard(base: [
    "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
    "CODE_SIGN_STYLE": .string("Automatic")
  ])
)

let liveActivityStage = Target.target(
  name: "LiveActivityWidgetExtension-Stage",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.stage.liveactivity",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Live Activity [STAGE]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "stage")),
    "DEEPLINK_SCHEME": "promiso-stage",
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
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.stage.liveactivity"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.stage.liveactivity"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

let liveActivityProd = Target.target(
  name: "LiveActivityWidgetExtension",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "\(AppConfig.bundleId).liveactivity",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Live Activity",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "prod")),
    "DEEPLINK_SCHEME": "promiso",
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
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.liveactivity"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.liveactivity"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

let promiseWidgetDev = Target.target(
  name: "PromiseWidgetExtension-Dev",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.dev.promisewidget",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso [DEV]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "dev")),
    "DEEPLINK_SCHEME": "promiso-dev",
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
  settings: .standard(base: [
    "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
    "CODE_SIGN_STYLE": .string("Automatic")
  ])
)

let promiseWidgetStage = Target.target(
  name: "PromiseWidgetExtension-Stage",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.stage.promisewidget",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso [STAGE]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "stage")),
    "DEEPLINK_SCHEME": "promiso-stage",
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
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.stage.promisewidget"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.stage.promisewidget"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

let promiseWidgetProd = Target.target(
  name: "PromiseWidgetExtension",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "\(AppConfig.bundleId).promisewidget",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "prod")),
    "DEEPLINK_SCHEME": "promiso",
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
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.promisewidget"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.promisewidget"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

// MARK: - Environment-based Target Filtering

/// 환경변수 TUIST_ENV에 따라 생성할 타겟 결정
/// - dev (기본값): PromisoDev + 관련 Widget만 생성
/// - stage: PromisoStage + 관련 Widget만 생성
/// - prod: Promiso + 관련 Widget만 생성
let environment: String = {
  if case let .string(env) = Environment.env {
    return env
  }
  return "dev"
}()

let targets: [Target] = {
  switch environment {
  case "dev":
    return [promisoDev, liveActivityDev, promiseWidgetDev]
  case "stage":
    return [promisoStage, liveActivityStage, promiseWidgetStage]
  case "prod":
    return [promisoProd, liveActivityProd, promiseWidgetProd]
  default:
    // 잘못된 값이 들어오면 dev로 fallback
    return [promisoDev, liveActivityDev, promiseWidgetDev]
  }
}()

// MARK: - Schemes (StoreKit Configuration 포함)

let schemes: [Scheme] = {
  switch environment {
  case "dev":
    return [
      Scheme.scheme(
        name: "PromisoDev",
        shared: true,
        buildAction: .buildAction(targets: [.target("PromisoDev")]),
        runAction: .runAction(
          configuration: .debug,
          options: .options(
            storeKitConfigurationPath: .relativeToRoot("Projects/App/ProPlan.storekit")
          )
        )
      )
    ]
  case "stage":
    return [
      Scheme.scheme(
        name: "PromisoStage",
        shared: true,
        buildAction: .buildAction(targets: [.target("PromisoStage")]),
        runAction: .runAction(
          configuration: .debug,
          options: .options(
            storeKitConfigurationPath: .relativeToRoot("Projects/App/ProPlan.storekit")
          )
        )
      )
    ]
  case "prod":
    return [
      Scheme.scheme(
        name: AppConfig.name,
        shared: true,
        buildAction: .buildAction(targets: [.target(AppConfig.name)]),
        runAction: .runAction(
          configuration: .debug,
          options: .options(
            storeKitConfigurationPath: .relativeToRoot("Projects/App/ProPlan.storekit")
          )
        )
      )
    ]
  default:
    return []
  }
}()

// MARK: - Project

let project = Project(
  name: AppConfig.name,
  options: .options(developmentRegion: "ko"),
  settings: .settings(
    configurations: [
      .debug(name: "Debug"),
      .release(name: "Release")
    ]
  ),
  targets: targets,
  schemes: schemes
)
