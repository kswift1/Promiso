// Tuist/Templates/feature/feature.swift
import ProjectDescription

let name: Template.Attribute = .required("name")

let template = Template(
  description: "Feature (Interface/Implement/Testing/Tests + ExampleApp) - TCA 1.22.2",
  attributes: [name],
  items: [
    
    // ── 단일 Project.swift (5개 타겟: Interface/Implement/Testing/Tests/ExampleApp)
    .string(
      path: "Projects/Features/{{ name }}Feature/Project.swift",
      contents: #"""
import ProjectDescription
import ProjectDescriptionHelpers

private let feature: Feature = .{{ name | lowerFirstWord }}

let project = Project(
  name: feature.fullName,
  targets: [

    // Interface
    .target(
      name: "\(feature.fullName)Interface",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).interface",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Interface/Sources/**"],
      dependencies: DefaultExternalDependency.interface
    ),

    // Implement
    .target(
      name: "\(feature.fullName)Implement",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).implement",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Implement/Sources/**"],
      dependencies: [
        FeatureDependency.interface(feature)
      ] + DefaultExternalDependency.implement
    ),

    // Testing
    .target(
      name: "\(feature.fullName)Testing",
      destinations: .iOS,
      product: .framework,
      bundleId: "\(feature.defaultBundleIdPrefix).testing",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Testing/Sources/**"],
      dependencies: [
        FeatureDependency.interface(feature)
      ] + DefaultExternalDependency.testing
    ),

    // Unit Tests
    .target(
      name: "\(feature.fullName)Tests",
      destinations: .iOS,
      product: .unitTests,
      bundleId: "\(feature.defaultBundleIdPrefix).tests",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      sources: ["Tests/Sources/**"],
      dependencies: FeatureDependency.all(feature) + DefaultExternalDependency.tests
    ),

    // Example App (Demo)
    .target(
      name: "\(feature.fullName)Example",
      destinations: .iOS,
      product: .app,
      bundleId: "\(feature.defaultBundleIdPrefix).example",
      deploymentTargets: .iOS("\(AppConfig.deploymentTargets)"),
      infoPlist: .extendingDefault(with: [
        "UILaunchStoryboardName": .string("LaunchScreen")
      ]),
      sources: ["Example/Sources/**"],
      resources: ["Example/Resources/**"],
      dependencies: FeatureDependency.all(feature) + DefaultExternalDependency.example
    )
  ]
)
"""#
    ),
    
    // ── 소스 코드 뼈대
    
    // Interface
      .string(
        path: "Projects/Features/{{ name }}Feature/Interface/Sources/{{ name }}Entry.swift",
        contents: #"""
// MARK: - {{ name }}Entry.swift
// {{ name }} Feature의 Interface layer - TMA (Tuist Modular Architecture) 패턴을 따름
// 이 파일은 {{ name }} Feature의 public contract와 integration point를 정의

import SwiftUI
import ComposableArchitecture

// MARK: - Feature Entry Point

/// {{ name }} Feature integration을 위한 Entry Point
/// 상위 애플리케이션에 {{ name }} Feature를 임베딩하기 위한 깔끔한 interface 제공
/// 
/// 사용법:
/// ```swift
/// let entry = {{ name }}Entry.live()
/// let view = entry.makeView(.init())
/// ```
public struct {{ name }}Entry {
  private let _makeView: (Config) -> AnyView
  
  public init<Content: View>(@ViewBuilder makeView: @escaping (Config) -> Content) {
    self._makeView = { config in AnyView(makeView(config)) }
  }
  
  @ViewBuilder
  public func makeView(_ config: Config) -> some View {
    _makeView(config)
  }
}

// MARK: - Configuration

/// {{ name }} Feature 동작을 커스터마이징하기 위한 Configuration 객체
/// concurrency boundaries에서 안전한 사용을 위해 Sendable을 준수
public struct Config: Sendable, Equatable {
  // 필요에 따라 configuration 프로퍼티를 여기에 추가
  // 예시: public let theme: Theme
  // 예시: public let analyticsEnabled: Bool
  
  /// 표준 configuration을 생성하는 기본 initializer
  public init() {}
}

// MARK: - Navigation

/// {{ name }} Feature navigation을 위한 Route 정의
/// Feature 내에서 deep linking과 programmatic navigation에 사용
public enum {{ name }}Route: Hashable, CaseIterable {
  /// Feature의 main entry point를 나타내는 Root route
  case root
  
  // Feature가 성장함에 따라 추가 route를 여기에 추가
  // 예시: case detail(id: String)
  // 예시: case settings
}

// MARK: - Domain Models

/// {{ name }} Feature에 특화된 Domain model과 data structure
/// Feature의 핵심 책임에 집중하여 가볍게 유지
extension {{ name }}Entry {
  // Feature별 domain model을 여기에 추가
  // 예시:
  // public struct {{ name }}Item: Equatable, Identifiable {
  //   public let id: UUID
  //   public let name: String
  //   public init(id: UUID, name: String) { ... }
  // }
}
"""#
      ),
    
    // Implement
    .string(
      path: "Projects/Features/{{ name }}Feature/Implement/Sources/{{ name }}Feature.swift",
      contents: #"""
// MARK: - {{ name }}Feature.swift
// TCA 1.22.2를 사용한 {{ name }} Feature의 Implementation layer
// 이 파일은 핵심 business logic, state management, view implementation을 포함

import SwiftUI
import ComposableArchitecture
import {{ name }}FeatureInterface
import Perception

// MARK: - Feature Namespace

/// {{ name }} Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum {{ name }} {}

// MARK: - Core Feature Implementation

extension {{ name }} {
  
  // MARK: - Reducer
  
  /// {{ name }} Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  /// 
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    /// Reducer를 위한 기본 initializer
    /// Feature가 성장함에 따라 dependency나 configuration을 여기에 추가
    public init() {}
    
    // MARK: - State
    
    /// {{ name }} Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    /// 
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      // Feature별 state 프로퍼티를 여기에 추가
      // 예시: public var items: IdentifiedArrayOf<{{ name }}Item> = []
      // 예시: public var selectedItem: {{ name }}Item?
      
      /// State를 위한 기본 initializer
      public init() {}
    }
    
    // MARK: - Action
    
    /// {{ name }} Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      // Feature별 action을 여기에 추가
      // 예시: case itemSelected({{ name }}Item)
      // 예시: case deleteItem({{ name }}Item.ID)
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .onAppear:
          // view가 나타날 때 Feature 초기화
          return .none
        }
      }
    }
  }
  
  // MARK: - Root View
  
  /// {{ name }} Feature를 위한 Main view implementation
  /// 적절한 accessibility와 state handling을 통해 SwiftUI best practice를 따름
  public struct RootView: View {
    /// Feature의 state와 action dispatch 기능을 포함하는 Store
    private var store: StoreOf<Feature>
    
    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      WithPerceptionTracking {
        VStack {
          Text("{{ name }} Feature")
            .font(.title2)
            .fontWeight(.semibold)
          
          Text("{{ name }} Feature implementation입니다.")
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
          store.send(.onAppear)
        }
      }
    }
  }
}

// MARK: - Error Types
// Feature별 Error type이 필요한 경우 여기에 추가
// 예시:
// public enum {{ name }}Error: Error, Equatable, LocalizedError {
//   case networkError
//   case dataError
//   case custom(String)
// }
"""#
    ),
    
      .string(
        path: "Projects/Features/{{ name }}Feature/Implement/Sources/{{ name }}Entry+Live.swift",
        contents: #"""
// MARK: - {{ name }}Entry+Live.swift
// {{ name }} Feature entry point의 Live implementation
// 이 파일은 Interface layer와 구체적인 Implementation layer를 연결

import SwiftUI
import ComposableArchitecture
import {{ name }}FeatureInterface

// MARK: - Live Implementation

public extension {{ name }}Entry {
  
  /// {{ name }} Feature entry의 live instance를 생성
  static func live() -> Self {
    .init { _ in
      let store = Store(initialState: {{ name }}.Feature.State()) {
        {{ name }}.Feature()
      }
      
      {{ name }}.RootView(store: store)
    }
  }
  
  /// SwiftUI preview를 위한 preview instance를 생성
  static func preview() -> Self {
    .init { _ in
      let store = Store(initialState: {{ name }}.Feature.State()) {
        {{ name }}.Feature()
      }
      
      {{ name }}.RootView(store: store)
    }
  }
}
"""#
      ),
    
    // Testing placeholder
    .string(
      path: "Projects/Features/{{ name }}Feature/Testing/Sources/Placeholder.swift",
      contents: "// Testing 플레이스홀더"
    ),
    
    // Tests
    .string(
      path: "Projects/Features/{{ name }}Feature/Tests/Sources/{{ name }}FeatureTests.swift",
      contents: #"""
// MARK: - {{ name }}FeatureTests.swift
// TCA TestStore를 사용한 {{ name }} Feature의 포괄적인 test suite
// 이 파일은 business logic의 정확성과 state management의 무결성을 보장

import XCTest
import ComposableArchitecture
@testable import {{ name }}FeatureImplement

// MARK: - Feature Tests

/// {{ name }} Feature reducer와 business logic을 위한 Test suite
/// 예측 가능한 state testing과 side effect 검증을 위해 TCA의 TestStore를 사용
@MainActor
final class {{ name }}FeatureTests: XCTestCase {
  
  /// 기본 onAppear 동작을 테스트
  func test_onAppear() async {
    let store = TestStore(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    
    await store.send(.onAppear)
  }
  
  // 추가 테스트를 여기에 작성
}

// MARK: - Integration Tests

/// Integration tests for feature entry points and view integration
@MainActor
final class {{ name }}EntryTests: XCTestCase {
  
  /// Tests live entry point creation
  func test_liveEntry_createsValidInstance() {
    let entry = {{ name }}Entry.live()
    let view = entry.makeView(.init())
    
    XCTAssertNotNil(view)
  }
}
"""#
    ),
    
    // Example App Sources
    .string(
      path: "Projects/Features/{{ name }}Feature/Example/Sources/ExampleApp.swift",
      contents: #"""
// MARK: - {{ name }}FeatureExampleApp.swift
// {{ name }} Feature 개발과 테스트를 위한 독립 실행형 example 애플리케이션
// 이 앱은 Feature 개발과 visual testing을 위한 격리된 환경을 제공

import SwiftUI
import ComposableArchitecture
import {{ name }}FeatureImplement
import {{ name }}FeatureInterface

// MARK: - Example Application

/// {{ name }} Feature를 위한 독립 실행형 example 앱
/// 다양한 테스트 시나리오와 함께 격리된 개발 환경을 제공
@main
struct {{ name }}FeatureExampleApp: App {
  
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        ExampleContentView()
          .navigationTitle("{{ name }} Examples")
          .navigationBarTitleDisplayMode(.large)
      }
    }
  }
}

// MARK: - Content View

/// 다양한 Feature 시나리오를 보여주는 Main content view
private struct ExampleContentView: View {
  
  var body: some View {
    List {
      Section("기본 상태") {
        NavigationLink("기본 {{ name }}") {
          defaultExample
        }
      }
      
      Section("Entry Point Integration") {
        NavigationLink("Live Entry") {
          entryExample
        }
      }
    }
  }
  
  // MARK: - Example Views
  
  /// Default feature state example
  @ViewBuilder
  private var defaultExample: some View {
    let store = Store(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    
    {{ name }}.RootView(store: store)
  }
  
  /// Entry point integration example
  @ViewBuilder
  private var entryExample: some View {
    let entry = {{ name }}Entry.live()
    entry.makeView(.init())
  }
}

// MARK: - SwiftUI Previews

#Preview {
  let store = Store(initialState: {{ name }}.Feature.State()) {
    {{ name }}.Feature()
  }
  
  {{ name }}.RootView(store: store)
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
    // 🚨 이 파일은 자동 생성됩니다.
    // 이 파일을 수동으로 편집하지 마세요.
    //
    // 생성자: `tuist scaffold feature --name {{ name }}`
    // 위치: Tuist/Templates/feature/feature.swift
    //
    // 목적:
    // - Feature identifier를 안전하게 등록
    // - 사용법: Feature.{{ name | lowerFirstWord }}
    // ===============================================
    
    public extension Feature {
      /// 예시: Feature.rootTab / Feature.home / Feature.calendar ...
      static let {{ name | lowerFirstWord }} = Feature("{{ name }}")
    }
    """#
    ),
  ]
)
