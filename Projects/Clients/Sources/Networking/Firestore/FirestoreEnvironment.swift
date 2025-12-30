import Foundation
import FirebaseFirestore

public enum FirestoreEnvironment: String, CaseIterable, Sendable {
  case dev = "Dev"
  case release = "Release"

  static var `default`: FirestoreEnvironment {
    #if DEBUG
    return .dev
    #else
    return .release
    #endif
  }

  /// Firestore 경로 prefix (dev/ 또는 없음)
  var pathPrefix: String? {
    switch self {
    case .dev: return "dev"
    case .release: return nil
    }
  }

  var rootCollectionName: String { rawValue }
}

public final class FirestoreEnvironmentManager: ObservableObject {
  public static let shared = FirestoreEnvironmentManager()
  
  private let userDefaults: UserDefaults
  private let storageKey = "firestore.environment.selection"
  
  @Published public private(set) var current: FirestoreEnvironment
  
  public var availableEnvironments: [FirestoreEnvironment] {
    FirestoreEnvironment.allCases
  }
  
  private init(
    userDefaults: UserDefaults = .standard
  ) {
    self.userDefaults = userDefaults
    if let rawValue = userDefaults.string(forKey: storageKey),
       let stored = FirestoreEnvironment(rawValue: rawValue) {
      current = stored
    } else {
      current = .default
    }
  }
  
  public func setEnvironment(_ environment: FirestoreEnvironment) {
    guard current != environment else { return }
    current = environment
    userDefaults.set(environment.rawValue, forKey: storageKey)
  }
  
  public func rootDocument(in db: Firestore = Firestore.firestore()) -> DocumentReference {
    db.collection(current.rootCollectionName).document("root")
  }
  
  public func collection(
    _ name: String,
    in db: Firestore = Firestore.firestore()
  ) -> CollectionReference {
    if let prefix = current.pathPrefix {
      // Dev: dev/{collection}
      return db.collection(prefix).document("root").collection(name)
    } else {
      // Release: {collection}
      return db.collection(name)
    }
  }
}

public extension Firestore {
  func environmentCollection(_ name: String) -> CollectionReference {
    FirestoreEnvironmentManager.shared.collection(name, in: self)
  }
  
  func environmentRootDocument() -> DocumentReference {
    FirestoreEnvironmentManager.shared.rootDocument(in: self)
  }
}
