//
//  SearchHistoryClient.swift
//  Clients
//

import ComposableArchitecture
import CoreData
import Foundation

// MARK: - Search History Item

public struct SearchHistoryItem: Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let address: String?
  public let latitude: Double?
  public let longitude: Double?
  public let createdAt: Date

  public init(
    id: String,
    name: String,
    address: String?,
    latitude: Double?,
    longitude: Double?,
    createdAt: Date
  ) {
    self.id = id
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.createdAt = createdAt
  }

  /// Place로 변환
  public func toPlace() -> Place {
    Place(
      id: id,
      name: name,
      coordinate: Coordinate(
        latitude: latitude ?? 0,
        longitude: longitude ?? 0
      ),
      address: address
    )
  }
}

// MARK: - Client

public struct SearchHistoryClient: Sendable {
  public var fetchHistory: @Sendable () async throws -> [SearchHistoryItem]
  public var savePlace: @Sendable (Place) async throws -> Void
  public var deleteItem: @Sendable (String) async throws -> Void
  public var clearAll: @Sendable () async throws -> Void
}

// MARK: - Test / Preview

extension SearchHistoryClient: TestDependencyKey {
  public static let previewValue = Self(
    fetchHistory: { [] },
    savePlace: { _ in },
    deleteItem: { _ in },
    clearAll: { }
  )

  public static let testValue = Self(
    fetchHistory: unimplemented("\(Self.self).fetchHistory", placeholder: []),
    savePlace: unimplemented("\(Self.self).savePlace"),
    deleteItem: unimplemented("\(Self.self).deleteItem"),
    clearAll: unimplemented("\(Self.self).clearAll")
  )
}

// MARK: - Live

extension SearchHistoryClient: DependencyKey {
  public static let liveValue = Self(
    fetchHistory: {
      let context = PersistenceController.shared.viewContext
      let request = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryEntity")
      request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
      request.fetchLimit = 20

      let results = try context.fetch(request)

      return results.compactMap { entity -> SearchHistoryItem? in
        guard let placeId = entity.value(forKey: "placeId") as? String,
              let name = entity.value(forKey: "name") as? String,
              let createdAt = entity.value(forKey: "createdAt") as? Date else {
          return nil
        }

        let address = entity.value(forKey: "address") as? String
        let latitude = entity.value(forKey: "latitude") as? Double
        let longitude = entity.value(forKey: "longitude") as? Double

        return SearchHistoryItem(
          id: placeId,
          name: name,
          address: address,
          latitude: latitude,
          longitude: longitude,
          createdAt: createdAt
        )
      }
    },

    savePlace: { place in
      let context = PersistenceController.shared.newBackgroundContext()

      try await context.perform {
        // 기존 항목 확인 및 삭제 (중복 방지)
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryEntity")
        fetchRequest.predicate = NSPredicate(format: "placeId == %@", place.id)

        let existing = try context.fetch(fetchRequest)
        for item in existing {
          context.delete(item)
        }

        // 새 항목 추가
        guard let entity = NSEntityDescription.entity(forEntityName: "SearchHistoryEntity", in: context) else {
          return
        }

        let newItem = NSManagedObject(entity: entity, insertInto: context)
        newItem.setValue(place.id, forKey: "placeId")
        newItem.setValue(place.name, forKey: "name")
        newItem.setValue(place.displayAddress, forKey: "address")
        newItem.setValue(place.coordinate.latitude, forKey: "latitude")
        newItem.setValue(place.coordinate.longitude, forKey: "longitude")
        newItem.setValue(Date(), forKey: "createdAt")

        try context.save()
      }
    },

    deleteItem: { placeId in
      let context = PersistenceController.shared.newBackgroundContext()

      try await context.perform {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SearchHistoryEntity")
        fetchRequest.predicate = NSPredicate(format: "placeId == %@", placeId)

        let results = try context.fetch(fetchRequest)
        for item in results {
          context.delete(item)
        }

        try context.save()
      }
    },

    clearAll: {
      let context = PersistenceController.shared.newBackgroundContext()

      try await context.perform {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SearchHistoryEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        try context.execute(deleteRequest)
        try context.save()
      }
    }
  )
}

// MARK: - Dependency Registration

public extension DependencyValues {
  var searchHistoryClient: SearchHistoryClient {
    get { self[SearchHistoryClient.self] }
    set { self[SearchHistoryClient.self] = newValue }
  }
}
