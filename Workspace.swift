import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
  name: AppConfig.name,
  projects: [
    "Projects/App",   // 앱
    "Projects/**"     // Features/Clients/Shared/Extensions 전체
  ],
  generationOptions: .options(
    lastXcodeUpgradeCheck: Version(26, 2, 0)
  )
)
