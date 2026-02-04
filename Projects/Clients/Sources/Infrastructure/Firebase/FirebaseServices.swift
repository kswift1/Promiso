import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

// MARK: - Firestore / Storage / Functions Providers

public protocol FirestoreProviding {
  var db: Firestore { get }
}

public protocol StorageProviding {
  var storage: Storage { get }
}

public protocol FunctionsProviding {
  var functions: Functions { get }
}

public struct DefaultFirestoreProvider: FirestoreProviding {
  public let db: Firestore

  public init(app: FirebaseApp? = FirebaseApp.app()) {
    self.db = Firestore.firestore()
  }
}

public struct DefaultStorageProvider: StorageProviding {
  public let storage: Storage

  public init(app: FirebaseApp? = FirebaseApp.app()) {
    if let bucket = app?.options.storageBucket {
      self.storage = Storage.storage(url: "gs://\(bucket)")
    } else {
      self.storage = Storage.storage()
    }
  }
}

public struct DefaultFunctionsProvider: FunctionsProviding {
  public let functions: Functions

  public init(region: String = "asia-northeast3") {
    self.functions = Functions.functions(region: region)
  }
}
