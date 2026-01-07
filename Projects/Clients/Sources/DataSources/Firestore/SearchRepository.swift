import Foundation
import FirebaseFirestore
import Combine
import PromisoShared

/// 검색 관련 Firestore 작업을 담당하는 Repository
//public class SearchRepository {
//  private let db = Firestore.firestore()
//  
//  // MARK: - Promise Search
//  
//  /// 약속 제목으로 검색 (prefix 검색)
//  public func searchPromises(
//    query: String,
//    groupId: String? = nil,
//    limit: Int = 20
//  ) async throws -> [PromiseDocument] {
//    let searchTerm = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else { return [] }
//    
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("titleLower", isGreaterThanOrEqualTo: searchTerm)
//      .whereField("titleLower", isLessThan: searchTerm + "\u{f8ff}")
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "titleLower")
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: PromiseDocument.self)
//    }
//  }
//  
//  /// 약속 설명으로 검색 (키워드 검색)
//  public func searchPromisesByDescription(
//    keywords: [String],
//    groupId: String? = nil,
//    limit: Int = 20
//  ) async throws -> [PromiseDocument] {
//    guard !keywords.isEmpty else { return [] }
//    
//    // Firestore의 제한으로 인해 첫 번째 키워드만 사용
//    let firstKeyword = keywords.first!.lowercased()
//    
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("description", isGreaterThanOrEqualTo: firstKeyword)
//      .whereField("description", isLessThan: firstKeyword + "\u{f8ff}")
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "description")
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    let results = try snapshot.documents.compactMap { document in
//      try document.data(as: PromiseDocument.self)
//    }
//    
//    // 클라이언트 사이드에서 추가 키워드 필터링
//    return results.filter { promise in
//      keywords.allSatisfy { keyword in
//        promise.description?.lowercased().contains(keyword.lowercased()) == true
//      }
//    }
//  }
//  
//  /// 위치로 약속 검색
//  public func searchPromisesByLocation(
//    locationName: String,
//    groupId: String? = nil,
//    limit: Int = 20
//  ) async throws -> [PromiseDocument] {
//    let searchTerm = locationName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else { return [] }
//    
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("location.name", isGreaterThanOrEqualTo: searchTerm)
//      .whereField("location.name", isLessThan: searchTerm + "\u{f8ff}")
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "location.name")
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: PromiseDocument.self)
//    }
//  }
//  
//  // MARK: - Group Search
//  
//  /// 그룹 이름으로 검색
//  public func searchGroups(
//    query: String,
//    limit: Int = 20
//  ) async throws -> [GroupDocument] {
//    let searchTerm = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else { return [] }
//    
//    let firestoreQuery = db.environmentCollection("groups")
//      .whereField("name", isGreaterThanOrEqualTo: searchTerm)
//      .whereField("name", isLessThan: searchTerm + "\u{f8ff}")
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "name")
//      .limit(to: limit)
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: GroupDocument.self)
//    }
//  }
//  
//  // MARK: - User Search
//  
//  /// 사용자 이름으로 검색
//  public func searchUsers(
//    query: String,
//    limit: Int = 20
//  ) async throws -> [UserDocument] {
//    let searchTerm = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else { return [] }
//    
//    let firestoreQuery = db.environmentCollection("users")
//      .whereField("name", isGreaterThanOrEqualTo: searchTerm)
//      .whereField("name", isLessThan: searchTerm + "\u{f8ff}")
//      .order(by: "name")
//      .limit(to: limit)
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: UserDocument.self)
//    }
//  }
//  
//  // MARK: - Advanced Search
//  
//  /// 통합 검색 (약속, 그룹, 사용자)
//  public func searchAll(
//    query: String,
//    groupId: String? = nil,
//    limit: Int = 10
//  ) async throws -> SearchResults {
//    let searchTerm = query.trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else {
//      return SearchResults(promises: [], groups: [], users: [])
//    }
//    
//    async let promises = searchPromises(query: searchTerm, groupId: groupId, limit: limit)
//    async let groups = searchGroups(query: searchTerm, limit: limit)
//    async let users = searchUsers(query: searchTerm, limit: limit)
//    
//    return try await SearchResults(
//      promises: promises,
//      groups: groups,
//      users: users
//    )
//  }
//  
//  /// 날짜 범위로 약속 검색
//  public func searchPromisesByDateRange(
//    startDate: Date,
//    endDate: Date,
//    groupId: String? = nil,
//    limit: Int = 50
//  ) async throws -> [PromiseDocument] {
//    let calendarKeyGenerator = CalendarKeyGenerator()
//    let startKey = calendarKeyGenerator.generateYyyymmddKey(for: startDate)
//    let endKey = calendarKeyGenerator.generateYyyymmddKey(for: endDate)
//    
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("localYyyymmdd", isGreaterThanOrEqualTo: startKey)
//      .whereField("localYyyymmdd", isLessThanOrEqualTo: endKey)
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "localYyyymmdd")
//      .order(by: "startAt")
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: PromiseDocument.self)
//    }
//  }
//  
//  /// 호스트별 약속 검색
//  public func searchPromisesByHost(
//    hostId: String,
//    groupId: String? = nil,
//    limit: Int = 20
//  ) async throws -> [PromiseDocument] {
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("hostId", isEqualTo: hostId)
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "startAt", descending: true)
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    let snapshot = try await firestoreQuery.getDocuments()
//    return try snapshot.documents.compactMap { document in
//      try document.data(as: PromiseDocument.self)
//    }
//  }
//  
//  // MARK: - Real-time Search
//  
//  /// 실시간 검색 결과 리스너
//  public func observeSearchResults(
//    query: String,
//    groupId: String? = nil,
//    limit: Int = 20
//  ) -> AnyPublisher<[PromiseDocument], Error> {
//    let searchTerm = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
//    guard !searchTerm.isEmpty else {
//      return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
//    }
//    
//    var firestoreQuery = db.environmentCollection("promises")
//      .whereField("titleLower", isGreaterThanOrEqualTo: searchTerm)
//      .whereField("titleLower", isLessThan: searchTerm + "\u{f8ff}")
//      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "titleLower")
//      .limit(to: limit)
//    
//    if let groupId = groupId {
//      firestoreQuery = firestoreQuery.whereField("groupId", isEqualTo: groupId)
//    }
//    
//    return FirestoreQuery(query: firestoreQuery)
//      .map { snapshot in
//        snapshot.documents.compactMap { document in
//          try? document.data(as: PromiseDocument.self)
//        }
//      }
//      .eraseToAnyPublisher()
//  }
//}

// MARK: - Search Results Model
public struct SearchResults {
  public let promises: [PromiseDTO]
  public let groups: [GroupDocument]
  public let users: [UserPrivateModel]

  public init(
    promises: [PromiseDTO],
    groups: [GroupDocument],
    users: [UserPrivateModel]
  ) {
    self.promises = promises
    self.groups = groups
    self.users = users
  }

  public var isEmpty: Bool {
    return promises.isEmpty && groups.isEmpty && users.isEmpty
  }

  public var totalCount: Int {
    return promises.count + groups.count + users.count
  }
}
