import Foundation
import FirebaseFirestore

/// Firebase 환경 (프로젝트 분리 후)
///
/// 각 환경은 별도의 Firebase 프로젝트로 분리됨:
/// - promiso-dev: 개발 환경
/// - promiso-stage: 스테이징 환경
/// - promiso-prod: 프로덕션 환경
///
/// GoogleService-Info.plist에 따라 환경이 결정됨.
public enum FirebaseEnvironment: String, CaseIterable, Sendable {
  case dev = "Dev"
  case stage = "Stage"
  case release = "Release"

  static var `default`: FirebaseEnvironment {
    #if DEBUG
    return .dev
    #else
    return .release
    #endif
  }

  /// 디버그 환경인지 여부
  public var isDebug: Bool {
    switch self {
    case .dev, .stage: return true
    case .release: return false
    }
  }
}

/// Firebase 환경 관리자
///
/// 프로젝트 분리 후에는 GoogleService-Info.plist에 따라 환경이 결정됨.
public final class FirebaseEnvironmentManager: ObservableObject, @unchecked Sendable {
  public static let shared = FirebaseEnvironmentManager()

  @Published public private(set) var current: FirebaseEnvironment

  private init() {
    current = .default
  }

  /// 컬렉션 참조 반환 (루트 레벨)
  public func collection(
    _ name: String,
    in db: Firestore = Firestore.firestore()
  ) -> CollectionReference {
    db.collection(name)
  }
}

public extension Firestore {
  /// 컬렉션 참조 반환 (루트 레벨)
  func environmentCollection(_ name: String) -> CollectionReference {
    collection(name)
  }
}
