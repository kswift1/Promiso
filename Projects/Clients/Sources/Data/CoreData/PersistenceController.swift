//
//  PersistenceController.swift
//  Clients
//

import CoreData

public final class PersistenceController {
  public static let shared = PersistenceController()

  public let container: NSPersistentContainer

  private init() {
    // 번들에서 모델 로드
    let bundle = Bundle(for: PersistenceController.self)
    guard let modelURL = bundle.url(forResource: "Promiso", withExtension: "momd"),
          let model = NSManagedObjectModel(contentsOf: modelURL) else {
      fatalError("Failed to load CoreData model")
    }

    container = NSPersistentContainer(name: "Promiso", managedObjectModel: model)

    container.loadPersistentStores { _, error in
      if let error = error as NSError? {
        fatalError("Failed to load persistent stores: \(error), \(error.userInfo)")
      }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
  }

  public var viewContext: NSManagedObjectContext {
    container.viewContext
  }

  public func newBackgroundContext() -> NSManagedObjectContext {
    container.newBackgroundContext()
  }
}
