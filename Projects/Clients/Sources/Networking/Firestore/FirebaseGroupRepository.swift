import Foundation
import FirebaseFirestore
import Shared

/// 그룹 관련 Repository (Firestore 구현)
//public final class FirebaseGroupRepository: GroupRepositoryProtocol {
//  public func uploadGroupImage(creatorId: String, imageData: Data) async throws -> String {
//    let uploadData = compressImageDataForUpload(imageData) ?? imageData
//    let photoPath = "group_images/tmp/\(creatorId)/\(UUID().uuidString).jpg"
//    let ref = storage.reference().child(photoPath)
//
//    let metadata = StorageMetadata()
//    metadata.contentType = "image/jpeg"
//
//    do {
//      _ = try await ref.putDataAsync(uploadData, metadata: metadata)
//      return photoPath
//    } catch {
//      throw GroupRemoteDataSourceError.imageUploadFailed
//    }
//  }
//  
//  public func deleteImage(at path: String) async throws {
//    <#code#>
//  }
//  
//  public func createGroup(name: String, maxMembers: Int, creatorId: String, photoPath: String?) async throws -> (id: String, inviteCode: String) {
//    <#code#>
//  }
//  
//  private let firestore: FirestoreProviding
//  private var db: Firestore { firestore.db }
//  private let collectionName: String
//
//  public init(
//    firestore: FirestoreProviding = DefaultFirestoreProvider(),
//    collectionName: String = "groups"
//  ) {
//    self.firestore = firestore
//    self.collectionName = collectionName
//  }
//  
//  // MARK: - CRUD Operations
//  
//  /// 그룹 생성
//  public func createGroup(_ group: Group) async throws -> String {
//    let ref = db.environmentCollection(collectionName).document(group.id)
//    try await ref.setData(groupToData(group, isNew: true))
//    return ref.documentID
//  }
//  
//  /// 그룹 업데이트
//  public func updateGroup(_ group: Group) async throws {
//    let ref = db.environmentCollection(collectionName).document(group.id)
//    var data = groupToData(group, isNew: false)
//    data["updatedAt"] = Timestamp(date: Date())
//    try await ref.updateData(data)
//  }
//  
//  /// 그룹 삭제 (soft delete)
//  public func deleteGroup(id: String) async throws {
//    let ref = db.environmentCollection(collectionName).document(id)
//    try await ref.updateData([
//      "isDeleted": true,
//      "updatedAt": Timestamp(date: Date())
//    ])
//  }
//  
//  /// 그룹 조회
//  public func getGroup(id: String) async throws -> Group? {
//    let ref = db.environmentCollection(collectionName).document(id)
//    let document = try await ref.getDocument()
//    guard document.exists else { return nil }
//    return try documentToGroup(document)
//  }
//  
//  // MARK: - Query Operations
//  
//  /// 사용자의 그룹 목록 조회
//  public func getUserGroups(userId: String) async throws -> [Group] {
//    let query = db.environmentCollection(collectionName)
//      .whereField("memberIds", arrayContains: userId)
//      .whereField("isDeleted", isEqualTo: false)
//    let snapshot = try await query.getDocuments()
//    return snapshot.documents.compactMap { try? documentToGroup($0) }
//  }
//  
//  /// 그룹 검색
//  public func searchGroups(query: String) async throws -> [Group] {
//    let lowercased = query.lowercased()
//    let snapshot = try await db.environmentCollection(collectionName)
//      .whereField("name_lowercase", isGreaterThanOrEqualTo: lowercased)
//      .whereField("name_lowercase", isLessThan: lowercased + "\u{f8ff}")
//      .whereField("isDeleted", isEqualTo: false)
//      .getDocuments()
//    return snapshot.documents.compactMap { try? documentToGroup($0) }
//  }
//  
//  /// 공개 그룹 목록 조회
//  public func getPublicGroups(limit: Int) async throws -> [Group] {
//    let snapshot = try await db.environmentCollection(collectionName)
//      .whereField("isPublic", isEqualTo: true)
//      .whereField("isDeleted", isEqualTo: false)
//      .order(by: "memberCount", descending: true)
//      .limit(to: limit)
//      .getDocuments()
//    return snapshot.documents.compactMap { try? documentToGroup($0) }
//  }
//  
//  // MARK: - Helpers
//  
//  private func groupToData(_ group: Group, isNew: Bool) -> [String: Any] {
//    var data: [String: Any] = [
//      "id": group.id,
//      "name": group.name,
//      "name_lowercase": group.name.lowercased(),
//      "memberCount": group.memberCount,
//      "isPublic": group.isPublic,
//      "isDeleted": false,
//      "updatedAt": Timestamp(date: Date())
//    ]
//    
//    if let description = group.description {
//      data["description"] = description
//    }
//    
//    if isNew {
//      data["createdAt"] = Timestamp(date: Date())
//    }
//    
//    return data
//  }
//  
//  private func documentToGroup(_ document: DocumentSnapshot) throws -> Group? {
//    guard document.exists else { return nil }
//    let data = document.data() ?? [:]
//    
//    return Group(
//      id: data["id"] as? String ?? document.documentID,
//      name: data["name"] as? String ?? "",
//      description: data["description"] as? String,
//      isPublic: data["isPublic"] as? Bool ?? false,
//      memberCount: data["memberCount"] as? Int ?? 0
//    )
//  }
//}
