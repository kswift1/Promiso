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
  /// 이 Feature의 main view를 생성하는 Factory function
  /// - Parameter config: Feature 동작을 커스터마이징하기 위한 Configuration 객체
  /// - Returns: Feature의 root interface를 포함하는 Type-erased SwiftUI view
  public var makeView: (_ config: Config) -> AnyView
  
  /// Feature entry instance 생성을 위한 Designated initializer
  /// - Parameter makeView: Feature의 interface contract에 맞는 View factory closure
  public init(makeView: @escaping (_ config: Config) -> AnyView) { 
    self.makeView = makeView 
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
      // MARK: UI State
      /// Feature가 현재 async operation을 수행 중인지 추적
      public var isLoading: Bool = false
      
      /// 사용자 대상 error message 표시를 위한 Error state
      public var error: {{ name }}Error?
      
      // Feature별 state 프로퍼티를 여기에 추가
      // 예시: public var items: IdentifiedArrayOf<{{ name }}Item> = []
      // 예시: public var selectedItem: {{ name }}Item?
      
      /// State를 위한 기본 initializer
      /// 모든 state 프로퍼티에 대해 합리적인 기본값을 제공
      
      public init(
        isLoading: Bool = false,
        error: {{ name }}Error? = nil
      ) {
        self.isLoading = isLoading
        self.error = error
      }
    }
    
    // MARK: - Action
    
    /// {{ name }} Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action: Equatable, Sendable {
      // MARK: Lifecycle Actions
      /// view가 처음 나타날 때 트리거
      case onAppear
      
      /// view가 data를 새로고침해야 할 때 트리거
      case refresh
      
      // MARK: User Actions
      /// 사용자 상호작용 예시 - Feature별 action으로 교체
      case didTapAction
      
      // MARK: Internal Actions
      /// async operation 완료 처리를 위한 Internal action
      case loadDataResponse(Result<Void, {{ name }}Error>)
      
      /// error state 해제를 위한 Action
      case dismissError
      
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
          state.isLoading = true
          state.error = nil
          
          // async data loading 시뮬레이션
          return .run { send in
            await send(.loadDataResponse(.success(())))
          }
          
        case .refresh:
          // pull-to-refresh 또는 명시적 refresh 요청 처리
          state.isLoading = true
          state.error = nil
          
          return .run { send in
            await send(.loadDataResponse(.success(())))
          }
          
        case .didTapAction:
          // 사용자 상호작용 처리
          // 여기에 business logic을 추가
          return .none
          
        case let .loadDataResponse(.success):
          // 성공적인 data loading 처리
          state.isLoading = false
          return .none
          
        case let .loadDataResponse(.failure(error)):
          // data loading 실패 처리
          state.isLoading = false
          state.error = error
          return .none
          
        case .dismissError:
          // error state 정리
          state.error = nil
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
    @Bindable private var store: StoreOf<Feature>
    
    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      NavigationStack {
        contentView
          .navigationTitle("{{ name }}")
          .onAppear {
            store.send(.onAppear)
          }
          .refreshable {
            store.send(.refresh)
          }
          .alert(
            "Error",
            isPresented: .constant(store.error != nil),
            presenting: store.error
          ) { error in
            Button("OK") {
              store.send(.dismissError)
            }
          } message: { error in
            Text(error.localizedDescription)
          }
      }
    }
    
    // MARK: - Content View
    
    /// Feature의 interface를 보여주는 Main content view
    @ViewBuilder
    private var contentView: some View {
      if store.isLoading {
        loadingView
      } else {
        mainContentView
      }
    }
    
    /// Loading state view
    @ViewBuilder
    private var loadingView: some View {
      ProgressView("Loading...")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// data가 로드되었을 때의 Main content
    @ViewBuilder
    private var mainContentView: some View {
      VStack(spacing: 24) {
        // Feature 아이콘 또는 헤더
        Image(systemName: "star.circle.fill")
          .font(.system(size: 60))
          .foregroundColor(.accentColor)
        
        // Feature 제목
        Text("{{ name }} Feature")
          .font(.title2)
          .fontWeight(.semibold)
        
        // Feature 설명
        Text("{{ name }} Feature implementation입니다.")
          .font(.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        
        // Action 버튼
        Button("Tap Action") {
          store.send(.didTapAction)
        }
        .buttonStyle(.borderedProminent)
        
        Spacer()
      }
      .padding()
    }
  }
}

// MARK: - Error Types

/// {{ name }} Feature에 특화된 Error type
/// 사용자 친화적인 메시지와 함께 구조화된 error handling을 제공
public enum {{ name }}Error: Error, Equatable, LocalizedError {
  /// Network 연결 또는 server error
  case networkError
  
  /// Data parsing 또는 validation error
  case dataError
  
  /// 커스텀 메시지를 가진 Generic error
  case custom(String)
  
  /// 사용자 친화적인 error 설명
  public var errorDescription: String? {
    switch self {
    case .networkError:
      return "네트워크 연결에 실패했습니다. 다시 시도해 주세요."
    case .dataError:
      return "데이터를 처리할 수 없습니다. 다시 시도해 주세요."
    case .custom(let message):
      return message
    }
  }
}
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
  /// 메인 애플리케이션에서 사용해야 하는 production implementation
  /// 
  /// Live implementation:
  /// - 기본 initial state로 TCA store를 생성
  /// - production dependency로 reducer를 구성
  /// - 적절히 구성된 SwiftUI view를 반환
  /// 
  /// - Returns: production 사용을 위해 구성된 {{ name }}Entry
  static func live() -> Self {
    .init { config in
      // initial state로 TCA store 생성
      let store = Store(
        initialState: {{ name }}.Feature.State()
      ) {
        {{ name }}.Feature()
          // Feature가 성장함에 따라 dependency를 여기에 추가
          // 예시: ._printChanges() for debugging
      }
      
      // AnyView로 감싼 root view 반환
      return AnyView(
        {{ name }}.RootView(store: store)
      )
    }
  }
  
  /// SwiftUI preview와 testing을 위한 preview instance를 생성함
  /// 이 버전은 mock data와 간소화된 configuration을 사용함
  /// 
  /// - Parameter state: preview 시나리오를 위한 선택적 initial state
  /// - Returns: preview 사용을 위해 구성된 {{ name }}Entry
  static func preview(
    state: {{ name }}.Feature.State = .init()
  ) -> Self {
    .init { _ in
      let store = Store(initialState: state) {
        {{ name }}.Feature()
          ._printChanges()
      }
      
      return AnyView(
        {{ name }}.RootView(store: store)
      )
    }
  }
  
  /// unit testing을 위한 mock instance를 생성함
  /// 특정 시나리오 테스트를 위한 커스텀 store injection을 허용함
  /// 
  /// - Parameter store: testing을 위해 미리 구성된 store
  /// - Returns: testing을 위해 구성된 {{ name }}Entry
  static func mock(
    store: StoreOf<{{ name }}.Feature>
  ) -> Self {
    .init { _ in
      AnyView(
        {{ name }}.RootView(store: store)
      )
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
  
  // MARK: - Lifecycle Tests
  
  /// initial state와 onAppear 동작을 테스트
  func test_onAppear_startsLoadingAndCompletes() async {
    let store = TestStore(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    
    // onAppear가 loading을 트리거하는지 테스트
    await store.send(.onAppear) {
      $0.isLoading = true
      $0.error = nil
    }
    
    // async 완료를 테스트
    await store.receive(.loadDataResponse(.success(()))) {
      $0.isLoading = false
    }
  }
  
  /// refresh 기능을 테스트
  func test_refresh_reloadsData() async {
    let store = TestStore(
      initialState: {{ name }}.Feature.State(isLoading: false)
    ) {
      {{ name }}.Feature()
    }
    
    await store.send(.refresh) {
      $0.isLoading = true
      $0.error = nil
    }
    
    await store.receive(.loadDataResponse(.success(()))) {
      $0.isLoading = false
    }
  }
  
  // MARK: - Error Handling Tests
  
  /// Tests error handling during data loading
  func test_loadDataFailure_setsErrorState() async {
    let store = TestStore(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    
    let error = {{ name }}Error.networkError
    
    await store.send(.onAppear) {
      $0.isLoading = true
    }
    
    await store.receive(.loadDataResponse(.failure(error))) {
      $0.isLoading = false
      $0.error = error
    }
  }
  
  /// Tests error dismissal functionality
  func test_dismissError_clearsErrorState() async {
    let store = TestStore(
      initialState: {{ name }}.Feature.State(
        error: {{ name }}Error.dataError
      )
    ) {
      {{ name }}.Feature()
    }
    
    await store.send(.dismissError) {
      $0.error = nil
    }
  }
  
  // MARK: - User Interaction Tests
  
  /// Tests user action handling
  func test_didTapAction_handlesUserInteraction() async {
    let store = TestStore(initialState: {{ name }}.Feature.State()) {
      {{ name }}.Feature()
    }
    
    await store.send(.didTapAction)
    // Add assertions for expected state changes or side effects
  }
  
  // MARK: - State Tests
  
  /// Tests initial state configuration
  func test_initialState_hasCorrectDefaults() {
    let state = {{ name }}.Feature.State()
    
    XCTAssertFalse(state.isLoading)
    XCTAssertNil(state.error)
    // Add assertions for additional state properties
  }
  
  /// Tests state equality for proper SwiftUI updates
  func test_state_equatableConformance() {
    let state1 = {{ name }}.Feature.State(isLoading: true)
    let state2 = {{ name }}.Feature.State(isLoading: true)
    let state3 = {{ name }}.Feature.State(isLoading: false)
    
    XCTAssertEqual(state1, state2)
    XCTAssertNotEqual(state1, state3)
  }
}

// MARK: - Error Tests

/// Test suite for {{ name }}Error type and error handling
final class {{ name }}ErrorTests: XCTestCase {
  
  /// Tests error localized descriptions
  func test_errorDescriptions_provideUserFriendlyMessages() {
    let networkError = {{ name }}Error.networkError
    let dataError = {{ name }}Error.dataError
    let customError = {{ name }}Error.custom("Test message")
    
    XCTAssertEqual(networkError.errorDescription, "Network connection failed. Please try again.")
    XCTAssertEqual(dataError.errorDescription, "Unable to process data. Please try again.")
    XCTAssertEqual(customError.errorDescription, "Test message")
  }
  
  /// Tests error equality for state management
  func test_errorEquality() {
    let error1 = {{ name }}Error.networkError
    let error2 = {{ name }}Error.networkError
    let error3 = {{ name }}Error.dataError
    let error4 = {{ name }}Error.custom("Test")
    let error5 = {{ name }}Error.custom("Test")
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertEqual(error4, error5)
  }
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
  
  /// Tests preview entry point with custom state
  func test_previewEntry_acceptsCustomState() {
    let customState = {{ name }}.Feature.State(isLoading: true)
    let entry = {{ name }}Entry.preview(state: customState)
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
      // Default State Section
      Section("기본 상태") {
        NavigationLink("기본 {{ name }}") {
          defaultExample
        }
      }
      
      // Loading State Section
      Section("로딩 상태") {
        NavigationLink("로딩 상태") {
          loadingExample
        }
      }
      
      // Error State Section
      Section("에러 상태") {
        NavigationLink("네트워크 에러") {
          errorExample({{ name }}Error.networkError)
        }
        
        NavigationLink("데이터 에러") {
          errorExample({{ name }}Error.dataError)
        }
        
        NavigationLink("커스텀 에러") {
          errorExample({{ name }}Error.custom("문제가 발생했습니다!"))
        }
      }
      
      // Entry Point Section
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
        ._printChanges()
    }
    
    {{ name }}.RootView(store: store)
  }
  
  /// Loading state example
  @ViewBuilder
  private var loadingExample: some View {
    let store = Store(
      initialState: {{ name }}.Feature.State(isLoading: true)
    ) {
      {{ name }}.Feature()
        ._printChanges()
    }
    
    {{ name }}.RootView(store: store)
  }
  
  /// Error state example
  /// - Parameter error: The error to display
  @ViewBuilder
  private func errorExample(_ error: {{ name }}Error) -> some View {
    let store = Store(
      initialState: {{ name }}.Feature.State(error: error)
    ) {
      {{ name }}.Feature()
        ._printChanges()
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

/// SwiftUI previews for different feature states
#Preview("Default State") {
  let store = Store(initialState: {{ name }}.Feature.State()) {
    {{ name }}.Feature()
  }
  
  return NavigationStack {
    {{ name }}.RootView(store: store)
  }
}

#Preview("Loading State") {
  let store = Store(
    initialState: {{ name }}.Feature.State(isLoading: true)
  ) {
    {{ name }}.Feature()
  }
  
  return NavigationStack {
    {{ name }}.RootView(store: store)
  }
}

#Preview("Error State") {
  let store = Store(
    initialState: {{ name }}.Feature.State(error: .networkError)
  ) {
    {{ name }}.Feature()
  }
  
  return NavigationStack {
    {{ name }}.RootView(store: store)
  }
}

#Preview("Entry Point") {
  let entry = {{ name }}Entry.preview()
  return entry.makeView(.init())
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
