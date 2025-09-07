// Tuist/Templates/feature/feature.swift
import ProjectDescription

let name: Template.Attribute = .required("name")

let template = Template(
  description: "Feature (Interface/Implement/Testing/Tests + ExampleApp) - TCA 1.22.2",
  attributes: [name],
  items: [
    
    // ── 단일 Project.swift (5 타깃: Interface/Implement/Testing/Tests/ExampleApp)
    .string(
      path: "Projects/Features/{{ name }}Feature/Project.swift",
      contents: #"""
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: "{{ name }}Feature",
  targets: [

    // Interface
    .target(
      name: "{{ name }}Interface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.{{ name | lowercase }}.interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: []
    ),

    // Implement
    .target(
      name: "{{ name }}Implement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.{{ name | lowercase }}.implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        .project(target: "{{ name }}Interface", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Testing
    .target(
      name: "{{ name }}Testing",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(AppConfig.name).features.{{ name | lowercase }}.testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        .project(target: "{{ name }}Interface", path: ".")
      ]
    ),

    // Unit Tests
    .target(
      name: "{{ name }}Tests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(AppConfig.name).features.{{ name | lowercase }}.tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: [
        .project(target: "{{ name }}Implement", path: "."),
        .external(name: "ComposableArchitecture")
      ]
    ),

    // Example App (Demo)
    .target(
      name: "{{ name }}Example",
      destinations: .iOS,
      product: .app,
      bundleId: "\(AppConfig.name).features.{{ name | lowercase }}.example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: [
        .project(target: "{{ name }}Implement", path: ".")
      ]
    )
  ]
)
"""#
    ),
    
    // ── 소스 뼈대
    
    // Interface
      .string(
        path: "Projects/Features/{{ name }}Feature/Interface/Sources/{{ name }}Entry.swift",
        contents: #"""
import SwiftUI

public struct {{ name }}Entry {
  public var makeView: (_ config: Config) -> AnyView
  public init(makeView: @escaping (_ config: Config) -> AnyView) { self.makeView = makeView }
}

public struct Config: Sendable { public init() {} }
public enum {{ name }}Route: Hashable { case root }
"""#
      ),
    
    // Implement
    .string(
      path: "Projects/Features/{{ name }}Feature/Implement/Sources/{{ name }}Feature.swift",
      contents: #"""
import SwiftUI
import ComposableArchitecture
import {{ name }}Interface

public enum {{ name }} {}

extension {{ name }} {
  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      public init() {}
    }

    public enum Action: Equatable {
      case didTap
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .didTap:
          return .none
        }
      }
    }
  }

  public struct RootView: View {
    let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) { self.store = store }

    public var body: some View {
      WithPerceptionTracking {
        VStack(spacing: 16) {
          Text("{{ name }} Feature").font(.title2)
          Button("Tap") { store.send(.didTap) }
            .buttonStyle(.borderedProminent)
        }
        .padding()
      }
    }
  }
}
"""#
    ),
    
      .string(
        path: "Projects/Features/{{ name }}Feature/Implement/Sources/{{ name }}Entry+Live.swift",
        contents: #"""
import SwiftUI
import ComposableArchitecture
import {{ name }}Interface

public extension {{ name }}Entry {
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: {{ name }}.Feature.State()) {
        {{ name }}.Feature()
      }
      return AnyView({{ name }}.RootView(store: store))
    }
  }
}
"""#
      ),
    
    // Testing placeholder
    .string(
      path: "Projects/Features/{{ name }}Feature/Testing/Sources/Placeholder.swift",
      contents: "// Testing placeholder"
    ),
    
    // Tests
    .string(
      path: "Projects/Features/{{ name }}Feature/Tests/Sources/{{ name }}FeatureTests.swift",
      contents: #"""
import XCTest
import ComposableArchitecture
@testable import {{ name }}FeatureImplement

final class {{ name }}FeatureTests: XCTestCase {
  func test_placeholder() async {
    let store = TestStore(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    await store.send(.didTap)
  }
}
"""#
    ),
    
    // Example App Sources
    .string(
      path: "Projects/Features/{{ name }}Feature/Example/Sources/ExampleApp.swift",
      contents: #"""
import SwiftUI
import ComposableArchitecture
import {{ name }}FeatureImplement

@main
struct {{ name }}FeatureExampleApp: App {
  var body: some Scene {
    WindowGroup {
      let store = Store(initialState: {{ name }}.Feature.State()) {
        {{ name }}.Feature()
      }
      {{ name }}.RootView(store: store)
    }
  }
}
"""#
    ),
    
    // Example App LaunchScreen
    .string(
      path: "Projects/Features/{{ name }}Feature/Example/Resources/LaunchScreen.storyboard",
      contents: #"""
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="16096" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="UIViewController">
  <scenes>
    <scene sceneID="tne-QT-ifu">
      <objects>
        <viewController id="BYZ-38-t0r">
          <view key="view" contentMode="scaleToFill" id="8bC-Xf-vdC">
            <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
            <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
            <color key="backgroundColor" systemColor="systemBackgroundColor"/>
            <viewLayoutGuide key="safeArea" id="6Tk-OE-BBY"/>
          </view>
        </viewController>
        <placeholder placeholderIdentifier="IBFirstResponder" id="dkx-z0-nzr" userLabel="First Responder"/>
      </objects>
    </scene>
  </scenes>
</document>
"""#
    ),
    .string(
      path: "Tuist/ProjectDescriptionHelpers/FeatureFactory/Features/Features+{{ name }}.swift",
      contents: #"""
    import ProjectDescription
    
    // ===============================================
    // 🚨 This file is auto-generated.
    // Do NOT edit this file manually.
    //
    // Generated by: `tuist scaffold feature --name {{ name }}`
    // Location: Tuist/Templates/feature/feature.swift
    //
    // Purpose:
    // - Register Feature identifier safely
    // - Use as: Feature.{{ name | lowerFirstWord }}
    // ===============================================
    
    public extension Feature {
      /// Example: Feature.rootTab / Feature.home / Feature.calendar ...
      static let {{ name | lowerFirstWord }} = Feature("{{ name }}")
    }
    """#
    ),
  ]
)
