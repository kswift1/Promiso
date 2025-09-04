import ProjectDescription

let project = Project(
  name: "StopLateApp",
  targets: [
    .target(
      name: "StopLateApp",
      destinations: .iOS,
      product: .app,
      bundleId: "com.example.StopLate",
      deploymentTargets: .iOS("16.4"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      dependencies: [
        // 나중에 Feature/Client 구현 모듈을 여기에 추가
      ]
    )
  ]
)
