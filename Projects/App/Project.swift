import ProjectDescription
import ProjectDescriptionHelpers

// Helper for infoPlist with DisplayName
func infoPlistWithDisplayName(_ displayName: String, environment: String = "prod") -> [String: Plist.Value] {
  var plist = AppConfig.infoPlist(for: environment)
  plist["CFBundleDisplayName"] = .string(displayName)
  return plist
}

// MARK: - Crashlytics Run Script

let crashlyticsScript = TargetScript.post(
  script: """
  # Skip for Debug builds and Simulator
  if [ "${CONFIGURATION}" = "Debug" ]; then
    echo "Skipping Crashlytics dSYM upload for Debug build"
    exit 0
  fi

  # Find the correct GoogleService-Info.plist in the built app bundle
  GSP_PATH="${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/GoogleService-Info.plist"

  # Execute the upload-symbols script with the correct path
  "${SRCROOT}/../../Tuist/.build/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" -gsp "$GSP_PATH" -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
  """,
  name: "Firebase Crashlytics",
  inputPaths: [
    "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}",
    "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${PRODUCT_NAME}",
    "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Info.plist",
    "$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)"
  ],
  basedOnDependencyAnalysis: false
)

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
  scripts: [crashlyticsScript],
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension-Dev"),
    .target(name: "ScheduleWidgetExtension-Dev"),
    .target(name: "ShareExtension-Dev"),
    .target(name: "NotificationServiceExtension-Dev")
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
  scripts: [crashlyticsScript],
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension-Stage"),
    .target(name: "ScheduleWidgetExtension-Stage"),
    .target(name: "ShareExtension-Stage"),
    .target(name: "NotificationServiceExtension-Stage")
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
  scripts: [crashlyticsScript],
  dependencies: AppFeatureDeps.allDeps + [
    .target(name: "LiveActivityWidgetExtension"),
    .target(name: "ScheduleWidgetExtension"),
    .target(name: "ShareExtension"),
    .target(name: "NotificationServiceExtension")
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

let scheduleWidgetDev = Target.target(
  name: "ScheduleWidgetExtension-Dev",
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
  sources: ["Extensions/ScheduleWidget/Sources/**"],
  entitlements: .file(path: "Extensions/ScheduleWidget/ScheduleWidget-Dev.entitlements"),
  dependencies: [
    .project(target: "PromisoShared", path: "../Shared"),
    .project(target: "ResourceKit", path: "../ResourceKit")
  ],
  settings: .standard(base: [
    "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
    "CODE_SIGN_STYLE": .string("Automatic")
  ])
)

let scheduleWidgetStage = Target.target(
  name: "ScheduleWidgetExtension-Stage",
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
  sources: ["Extensions/ScheduleWidget/Sources/**"],
  entitlements: .file(path: "Extensions/ScheduleWidget/ScheduleWidget-Stage.entitlements"),
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

let scheduleWidgetProd = Target.target(
  name: "ScheduleWidgetExtension",
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
  sources: ["Extensions/ScheduleWidget/Sources/**"],
  entitlements: .file(path: "Extensions/ScheduleWidget/ScheduleWidget.entitlements"),
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

// MARK: - Share Extension Targets

let shareExtensionDev = Target.target(
  name: "ShareExtension-Dev",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.dev.shareextension",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Share [DEV]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "dev")),
    "DEEPLINK_SCHEME": "promiso-dev",
    "APP_GROUP_ID": "group.com.promiso.dev.shared",
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.share-services",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ShareViewController",
      "NSExtensionAttributes": [
        "NSExtensionActivationRule": [
          "NSExtensionActivationSupportsText": .boolean(true),
          "NSExtensionActivationSupportsImageWithMaxCount": .integer(1)
        ]
      ]
    ]
  ]),
  sources: ["Extensions/ShareExtension/Sources/**"],
  entitlements: .file(path: "Extensions/ShareExtension/ShareExtension-Dev.entitlements"),
  dependencies: [
    .project(target: "PromisoShared", path: "../Shared"),
    .project(target: "ResourceKit", path: "../ResourceKit")
  ],
  settings: .standard(base: [
    "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
    "CODE_SIGN_STYLE": .string("Automatic"),
    "SWIFT_OBJC_BRIDGING_HEADER": .string("$(SRCROOT)/Extensions/ShareExtension/Sources/ShareExtension-Bridging-Header.h")
  ])
)

let shareExtensionStage = Target.target(
  name: "ShareExtension-Stage",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.stage.shareextension",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Share [STAGE]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "stage")),
    "DEEPLINK_SCHEME": "promiso-stage",
    "APP_GROUP_ID": "group.com.promiso.stage.shared",
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.share-services",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ShareViewController",
      "NSExtensionAttributes": [
        "NSExtensionActivationRule": [
          "NSExtensionActivationSupportsText": .boolean(true),
          "NSExtensionActivationSupportsImageWithMaxCount": .integer(1)
        ]
      ]
    ]
  ]),
  sources: ["Extensions/ShareExtension/Sources/**"],
  entitlements: .file(path: "Extensions/ShareExtension/ShareExtension-Stage.entitlements"),
  dependencies: [
    .project(target: "PromisoShared", path: "../Shared"),
    .project(target: "ResourceKit", path: "../ResourceKit")
  ],
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual"),
      "SWIFT_OBJC_BRIDGING_HEADER": .string("$(SRCROOT)/Extensions/ShareExtension/Sources/ShareExtension-Bridging-Header.h")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.stage.shareextension"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.stage.shareextension"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

let shareExtensionProd = Target.target(
  name: "ShareExtension",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "\(AppConfig.bundleId).shareextension",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Share",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "prod")),
    "DEEPLINK_SCHEME": "promiso",
    "APP_GROUP_ID": "group.com.promiso.shared",
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.share-services",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ShareViewController",
      "NSExtensionAttributes": [
        "NSExtensionActivationRule": [
          "NSExtensionActivationSupportsText": .boolean(true),
          "NSExtensionActivationSupportsImageWithMaxCount": .integer(1)
        ]
      ]
    ]
  ]),
  sources: ["Extensions/ShareExtension/Sources/**"],
  entitlements: .file(path: "Extensions/ShareExtension/ShareExtension.entitlements"),
  dependencies: [
    .project(target: "PromisoShared", path: "../Shared"),
    .project(target: "ResourceKit", path: "../ResourceKit")
  ],
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual"),
      "SWIFT_OBJC_BRIDGING_HEADER": .string("$(SRCROOT)/Extensions/ShareExtension/Sources/ShareExtension-Bridging-Header.h")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.shareextension"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.shareextension"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

// MARK: - Notification Service Extension Targets

let notificationServiceDev = Target.target(
  name: "NotificationServiceExtension-Dev",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.dev.notificationservice",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Notifications [DEV]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "dev")),
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.usernotifications.service",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).NotificationService"
    ]
  ]),
  sources: ["Extensions/NotificationServiceExtension/Sources/**"],
  entitlements: .file(path: "Extensions/NotificationServiceExtension/NotificationServiceExtension-Dev.entitlements"),
  dependencies: [],
  settings: .standard(base: [
    "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
    "CODE_SIGN_STYLE": .string("Automatic")
  ])
)

let notificationServiceStage = Target.target(
  name: "NotificationServiceExtension-Stage",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "com.promiso.stage.notificationservice",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Notifications [STAGE]",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "stage")),
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.usernotifications.service",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).NotificationService"
    ]
  ]),
  sources: ["Extensions/NotificationServiceExtension/Sources/**"],
  entitlements: .file(path: "Extensions/NotificationServiceExtension/NotificationServiceExtension-Stage.entitlements"),
  dependencies: [],
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.stage.notificationservice"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.stage.notificationservice"),
        "CODE_SIGN_IDENTITY": .string("Apple Distribution")
      ])
    ]
  )
)

let notificationServiceProd = Target.target(
  name: "NotificationServiceExtension",
  destinations: .iOS,
  product: .appExtension,
  bundleId: "\(AppConfig.bundleId).notificationservice",
  deploymentTargets: .iOS(AppConfig.deploymentTargets),
  infoPlist: .extendingDefault(with: [
    "CFBundleDisplayName": "Promiso Notifications",
    "CFBundleShortVersionString": .string(AppConfig.marketingNumber),
    "CFBundleVersion": .string(AppConfig.buildVersion(for: "prod")),
    "NSExtension": [
      "NSExtensionPointIdentifier": "com.apple.usernotifications.service",
      "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).NotificationService"
    ]
  ]),
  sources: ["Extensions/NotificationServiceExtension/Sources/**"],
  entitlements: .file(path: "Extensions/NotificationServiceExtension/NotificationServiceExtension.entitlements"),
  dependencies: [],
  settings: .settings(
    base: [
      "DEVELOPMENT_TEAM": .string(AppConfig.teamId),
      "CODE_SIGN_STYLE": .string("Manual")
    ],
    configurations: [
      .debug(name: "Debug", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match Development com.promiso.notificationservice"),
        "CODE_SIGN_IDENTITY": .string("Apple Development")
      ]),
      .release(name: "Release", settings: [
        "PROVISIONING_PROFILE_SPECIFIER": .string("match AppStore com.promiso.notificationservice"),
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
    return [promisoDev, liveActivityDev, scheduleWidgetDev, shareExtensionDev, notificationServiceDev]
  case "stage":
    return [promisoStage, liveActivityStage, scheduleWidgetStage, shareExtensionStage, notificationServiceStage]
  case "prod":
    return [promisoProd, liveActivityProd, scheduleWidgetProd, shareExtensionProd, notificationServiceProd]
  default:
    // 잘못된 값이 들어오면 dev로 fallback
    return [promisoDev, liveActivityDev, scheduleWidgetDev, shareExtensionDev, notificationServiceDev]
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
            storeKitConfigurationPath: .relativeToRoot("Projects/App/ProPlan-Dev.storekit")
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
          configuration: .debug
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
          configuration: .debug
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
