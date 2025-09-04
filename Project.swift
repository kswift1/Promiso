import ProjectDescription

let project = Project(
    name: "StopLate",
    targets: [
        .target(
            name: "StopLate",
            destinations: .iOS,
            product: .app,
            bundleId: "dev.tuist.StopLate",
            infoPlist: .extendingDefault(
                with: [
                    "UILaunchScreen": [
                        "UIColorName": "",
                        "UIImageName": "",
                    ],
                ]
            ),
            buildableFolders: [
                "StopLate/Sources",
                "StopLate/Resources",
            ],
            dependencies: []
        ),
        .target(
            name: "StopLateTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "dev.tuist.StopLateTests",
            infoPlist: .default,
            buildableFolders: [
                "StopLate/Tests"
            ],
            dependencies: [.target(name: "StopLate")]
        ),
    ]
)
