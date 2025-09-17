import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "Shared",
  targets: [
    
    // DesignSystem Module - UI 컴포넌트, 테마
    .target(
      name: "SharedDesignSystem",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).shared.designsystem",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["DesignSystem/Sources/**"],
      resources: ["DesignSystem/Resources/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .project(target: "CoreInfrastructure", path: "../Core")
      ] + DefaultExternalDependency.interface
    ),
    
    // Services Module - 비즈니스 서비스들
    .target(
      name: "SharedServices",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).shared.services",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Services/Sources/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .project(target: "CoreNetworking", path: "../Core"),
        .project(target: "CoreInfrastructure", path: "../Core")
      ] + DefaultExternalDependency.interface
    ),
    
    // Extensions Module - 비즈니스 로직이 포함된 확장들
    .target(
      name: "SharedExtensions",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).shared.extensions",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Extensions/Sources/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .project(target: "CoreInfrastructure", path: "../Core")
      ] + DefaultExternalDependency.interface
    ),
    
    // Constants Module - 앱별 상수, 설정
    .target(
      name: "SharedConstants",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).shared.constants",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Constants/Sources/**"],
      dependencies: DefaultExternalDependency.interface
    ),
    
    // Resources Module - 공통 리소스
    .target(
      name: "SharedResources",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).shared.resources",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Resources/Sources/**"],
      resources: ["Resources/Resources/**"],
      dependencies: DefaultExternalDependency.interface
    ),
    
    // Tests
    .target(
      name: "SharedTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).shared.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/**"],
      dependencies: [
        .project(target: "Domain", path: "../Domain"),
        .target(name: "SharedDesignSystem"),
        .target(name: "SharedServices"),
        .target(name: "SharedExtensions"),
        .target(name: "SharedConstants"),
        .target(name: "SharedResources")
      ] + DefaultExternalDependency.tests
    )
  ]
)
