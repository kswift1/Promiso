// MARK: - PromiseEntry.swift
// Promise Feature의 Interface layer - TMA (Tuist Modular Architecture) 패턴을 따름
// 이 파일은 Promise Feature의 public contract와 integration point를 정의

import SwiftUI
import ComposableArchitecture

// MARK: - Feature Entry Point

/// Promise Feature integration을 위한 Entry Point
/// 상위 애플리케이션에 Promise Feature를 임베딩하기 위한 깔끔한 interface 제공
/// 
/// 사용법:
/// ```swift
/// let entry = PromiseEntry.live()
/// let view = entry.makeView(.init())
/// ```
public struct PromiseEntry {
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

/// Promise Feature 동작을 커스터마이징하기 위한 Configuration 객체
/// concurrency boundaries에서 안전한 사용을 위해 Sendable을 준수
public struct Config: Sendable, Equatable {
  // 필요에 따라 configuration 프로퍼티를 여기에 추가
  // 예시: public let theme: Theme
  // 예시: public let analyticsEnabled: Bool
  
  /// 표준 configuration을 생성하는 기본 initializer
  public init() {}
}

// MARK: - Navigation

/// Promise Feature navigation을 위한 Route 정의
/// Feature 내에서 deep linking과 programmatic navigation에 사용
public enum PromiseRoute: Hashable, CaseIterable {
  /// Feature의 main entry point를 나타내는 Root route
  case root
  
  // Feature가 성장함에 따라 추가 route를 여기에 추가
  // 예시: case detail(id: String)
  // 예시: case settings
}

// MARK: - Domain Models

/// Promise Feature에 특화된 Domain model과 data structure
/// Feature의 핵심 책임에 집중하여 가볍게 유지
extension PromiseEntry {
  // Feature별 domain model을 여기에 추가
  // 예시:
  // public struct PromiseItem: Equatable, Identifiable {
  //   public let id: UUID
  //   public let name: String
  //   public init(id: UUID, name: String) { ... }
  // }
}