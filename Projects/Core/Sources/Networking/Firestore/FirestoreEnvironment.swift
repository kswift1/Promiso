import Foundation
import Combine
import FirebaseFirestore

/// Firestore에서 사용할 환경 구분
public enum FirestoreEnvironment: String, CaseIterable, Sendable {
  case dev = "Dev"
  case release = "Release"
  
  public var displayName: String { rawValue }
  
  static var defaultEnvironment: FirestoreEnvironment {
    #if DEBUG
    return .dev
    #else
    return .release
    #endif
  }
}

/// Firestore 환경을 제어하고 루트 경로를 제공하는 매니저
public final class FirestoreEnvironmentManager: ObservableObject {
  public static let shared = FirestoreEnvironmentManager()
  
  private let userDefaultsKey = "firestore.environment.selection"
  private let rootDocumentID = "root"
  private let userDefaults: UserDefaults
  
  @Published public private(set) var current: FirestoreEnvironment
  public var availableEnvironments: [FirestoreEnvironment] { FirestoreEnvironment.allCases }
  
  private init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
    if
      let rawValue = userDefaults.string(forKey: userDefaultsKey),
      let stored = FirestoreEnvironment(rawValue: rawValue)
    {
      current = stored
    } else {
      current = FirestoreEnvironment.defaultEnvironment
    }
  }
  
  public func setEnvironment(_ environment: FirestoreEnvironment) {
    guard current != environment else { return }
    current = environment
    userDefaults.set(environment.rawValue, forKey: userDefaultsKey)
  }
  
  /// 현재 환경의 루트 Document Reference
  public func rootDocument(in db: Firestore = Firestore.firestore()) -> DocumentReference {
    db.collection(current.rawValue).document(rootDocumentID)
  }
  
  /// 현재 환경 하위의 컬렉션 Reference
  public func collection(_ name: String, in db: Firestore = Firestore.firestore()) -> CollectionReference {
    rootDocument(in: db).collection(name)
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
