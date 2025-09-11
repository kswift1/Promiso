import ComposableArchitecture
import Foundation

// MARK: - Base Dependency Client Protocol

/// 모든 Dependency Client가 준수해야 하는 기본 프로토콜
public protocol DependencyClientProtocol {
  /// Live (Production) 구현체
  static var liveValue: Self { get }
  /// Test용 구현체
  static var testValue: Self { get }
  /// Preview용 구현체
  static var previewValue: Self { get }
}

// MARK: - Dependency Registration Helper

/// 앱 시작 시 모든 의존성을 등록하는 헬퍼
public enum DependencyRegistration {
  /// 프로덕션 의존성들을 등록
  public static func registerLiveDependencies() {
    // Feature별 의존성들이 여기서 등록됨
    // 예: DependencyValues.homeFeature = .liveValue
  }
  
  /// 테스트용 의존성들을 등록
  public static func registerTestDependencies() {
    // 테스트용 의존성들이 여기서 등록됨
    // 예: DependencyValues.homeFeature = .testValue
  }
  
  /// Preview용 의존성들을 등록
  public static func registerPreviewDependencies() {
    // Preview용 의존성들이 여기서 등록됨
    // 예: DependencyValues.homeFeature = .previewValue
  }
}

// MARK: - Dependency Macros Support

/// Dependency Key 생성을 위한 매크로 지원
public protocol AutoDependencyKey: DependencyKey {}

extension AutoDependencyKey where Self: DependencyClientProtocol {
  public static var liveValue: Self { Self.liveValue }
  public static var testValue: Self { Self.testValue }
}

// MARK: - Dependency Context

/// 의존성 컨텍스트 (Live, Test, Preview)
public enum DependencyContext {
  case live
  case test 
  case preview
}

/// 현재 의존성 컨텍스트를 관리하는 클래스
public final class DependencyContextManager: @unchecked Sendable {
  public static let shared = DependencyContextManager()
  
  private var _context: DependencyContext = .live
  private let queue = DispatchQueue(label: "dependency-context", attributes: .concurrent)
  
  private init() {}
  
  public var context: DependencyContext {
    queue.sync { _context }
  }
  
  public func setContext(_ context: DependencyContext) {
    queue.async(flags: .barrier) {
      self._context = context
    }
  }
}