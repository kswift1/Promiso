import Foundation
import FirebaseFirestore

public enum FirebaseEnvironment: String, CaseIterable, Sendable {
  case dev = "Dev"
  case stage = "Stage"
  case release = "Release"

  static var `default`: FirebaseEnvironment {
    #if DEBUG
    return .stage
    #else
    return .release
    #endif
  }

  /// Firestore 경로 prefix (dev/stage/prod)
  var pathPrefix: String? {
    switch self {
    case .dev: return "dev"
    case .stage: return "stage"
    case .release: return "prod"
    }
  }

  /// Root 문서가 위치하는 최상위 컬렉션 이름
  var rootCollectionName: String { pathPrefix ?? "prod" }

  /// Firebase Functions env 파라미터
  public var firebaseEnv: String {
    switch self {
    case .dev, .stage: return "stage"
    case .release: return "prod"
    }
  }

  /// Firebase Storage 경로 prefix
  public var storagePrefix: String { pathPrefix ?? "prod" }

  /// 디버그 환경인지 여부
  public var isDebug: Bool {
    switch self {
    case .dev, .stage: return true
    case .release: return false
    }
  }
}

public final class FirebaseEnvironmentManager: ObservableObject {
  public static let shared = FirebaseEnvironmentManager()
  
  private let userDefaults: UserDefaults
  private let storageKey = "firestore.environment.selection"
  
  @Published public private(set) var current: FirebaseEnvironment
  
  public var availableEnvironments: [FirebaseEnvironment] {
    FirebaseEnvironment.allCases
  }
  
  private init(
    userDefaults: UserDefaults = .standard
  ) {
    self.userDefaults = userDefaults
    if let rawValue = userDefaults.string(forKey: storageKey),
       let stored = FirebaseEnvironment(rawValue: rawValue) {
      current = stored
    } else {
      current = .default
    }
  }
  
  public func setEnvironment(_ environment: FirebaseEnvironment) {
    guard current != environment else { return }
    current = environment
    userDefaults.set(environment.rawValue, forKey: storageKey)
  }
  
  /// 환경에 맞는 root 문서 참조 반환
  ///
  /// 경로: {prefix}/root (prefix = dev|prod)
  public func rootDocument(in db: Firestore = Firestore.firestore()) -> DocumentReference {
    db.collection(current.rootCollectionName).document("root")
  }
  
  public func collection(
    _ name: String,
    in db: Firestore = Firestore.firestore()
  ) -> CollectionReference {
    if let prefix = current.pathPrefix {
      // Dev/Release: {prefix}/root/{collection}
      return db.collection(prefix).document("root").collection(name)
    }

    // Fallback (should not happen)
    return db.collection(name)
  }
}

public extension Firestore {
  func environmentCollection(_ name: String) -> CollectionReference {
    FirebaseEnvironmentManager.shared.collection(name, in: self)
  }
  
  func environmentRootDocument() -> DocumentReference {
    FirebaseEnvironmentManager.shared.rootDocument(in: self)
  }
}
