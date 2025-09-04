// Tuist/Templates/feature/feature.swift
import ProjectDescription

let name: Template.Attribute = .required("name") // --name MyFeature
let org  = "com.example"                         // 필요시 수정
let ios  = "16.4"

let template = Template(
  description: "TMA 스타일 Feature 모듈(Interface/Implement/Testing/Tests)",
  attributes: [name],
  items: [

    // Interface
    .string(
      path: "Projects/Features/{{ name }}/Interface/Project.swift",
      contents:
"""
import ProjectDescription

let project = Project(
  name: "{{ name }}FeatureInterface",
  targets: [
    .target(
      name: "{{ name }}FeatureInterface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(org).features.{{ name | lowercase }}.interface",
      deploymentTargets: .iOS("\(ios)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "SharedModels", path: "../../../Shared/SharedModels")
      ]
    )
  ]
)
"""
    ),
    .string(
      path: "Projects/Features/{{ name }}/Interface/Sources/{{ name }}Entry.swift",
      contents:
"""
import SwiftUI
import SharedModels

public struct {{ name }}Entry {
  public var makeView: (_ config: Config) -> AnyView
  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
}

public struct Config: Sendable {
  public let groupID: GroupID
  public init(groupID: GroupID) { self.groupID = groupID }
}

public enum {{ name }}Route: Hashable {
  case root
}
"""
    ),

    // Implement
    .string(
      path: "Projects/Features/{{ name }}/Implement/Project.swift",
      contents:
"""
import ProjectDescription

let project = Project(
  name: "{{ name }}FeatureImplement",
  packages: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.17.0"))
  ],
  targets: [
    .target(
      name: "{{ name }}FeatureImplement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(org).features.{{ name | lowercase }}.implement",
      deploymentTargets: .iOS("\(ios)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "{{ name }}FeatureInterface", path: "../Interface"),
        .project(target: "SharedModels", path: "../../../Shared/SharedModels"),
        .project(target: "DesignSystem", path: "../../../Shared/DesignSystem"),
        .package(product: "ComposableArchitecture")
      ]
    )
  ]
)
"""
    ),
    .string(
      path: "Projects/Features/{{ name }}/Implement/Sources/{{ name }}Feature.swift",
      contents:
"""
import SwiftUI
import ComposableArchitecture
import {{ name }}FeatureInterface
import DesignSystem

public enum {{ name }} {}

extension {{ name }} {
  @Reducer
  public struct Feature {
    public init() {}
    public struct State: Equatable { public init() {} }
    public enum Action: Equatable { case didTap }
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        .none
      }
    }
  }

  public struct RootView: View {
    let store: StoreOf<Feature>
    public init(store: StoreOf<Feature>) { self.store = store }
    public var body: some View {
      VStack(spacing: DS.Spacing.l) {
        Text("{{ name }} Feature")
        Button("Tap") { store.send(.didTap) }
      }
      .padding()
      .background(DS.Color.bg)
    }
  }
}

public extension {{ name }}Entry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: {{ name }}.Feature.State()) { {{ name }}.Feature() }
      return AnyView({{ name }}.RootView(store: store))
    }
  }
}
"""
    ),

    // Testing (Mocks/Previews)
    .string(
      path: "Projects/Features/{{ name }}/Testing/Project.swift",
      contents:
"""
import ProjectDescription

let project = Project(
  name: "{{ name }}FeatureTesting",
  targets: [
    .target(
      name: "{{ name }}FeatureTesting",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(org).features.{{ name | lowercase }}.testing",
      deploymentTargets: .iOS("\(ios)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "{{ name }}FeatureInterface", path: "../Interface")
      ]
    )
  ]
)
"""
    ),

    // Unit Tests
    .string(
      path: "Projects/Features/{{ name }}/Tests/Project.swift",
      contents:
"""
import ProjectDescription

let project = Project(
  name: "{{ name }}FeatureTests",
  targets: [
    .target(
      name: "{{ name }}FeatureTests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(org).features.{{ name | lowercase }}.tests",
      deploymentTargets: .iOS("\(ios)"),
      sources: ["Sources/**"],
      dependencies: [
        .project(target: "{{ name }}FeatureImplement", path: "../Implement")
      ]
    )
  ]
)
"""
    ),
    .string(
      path: "Projects/Features/{{ name }}/Tests/Sources/{{ name }}FeatureTests.swift",
      contents:
"""
import XCTest
import ComposableArchitecture
@testable import {{ name }}FeatureImplement

final class {{ name }}FeatureTests: XCTestCase {
  func test_nop() {
    let store = TestStore(initialState: {{ name }}.Feature.State()) { {{ name }}.Feature() }
    // TODO: write tests
  }
}
"""
    )
  ]
)
