import Foundation
import FirebaseFirestore

public struct GroupCreationPayload: Sendable {
  public let name: String
  public let maxMembers: Int
  public let creatorId: String
  public let creatorName: String
  public let creatorNickname: String
  public let creatorProfileImageURL: String?
  
  public init(
    name: String,
    maxMembers: Int,
    creatorId: String,
    creatorName: String,
    creatorNickname: String,
    creatorProfileImageURL: String?
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.creatorId = creatorId
    self.creatorName = creatorName
    self.creatorNickname = creatorNickname
    self.creatorProfileImageURL = creatorProfileImageURL
  }
}

public enum GroupRemoteDataSourceError: Error, LocalizedError {
  case failedToGenerateInviteCode
  case invalidCreator
  
  public var errorDescription: String? {
    switch self {
    case .failedToGenerateInviteCode:
      return "초대 코드를 생성하지 못했어요. 잠시 후 다시 시도해주세요."
    case .invalidCreator:
      return "사용자 정보가 없어 그룹을 생성할 수 없어요."
    }
  }
}

public final class GroupRemoteDataSource {
  private let db: Firestore
  private let environmentManager: FirestoreEnvironmentManager
  private let inviteCodeLength = 6
  private let maxInviteCodeAttempts = 5
  
  public init(
    db: Firestore = Firestore.firestore(),
    environmentManager: FirestoreEnvironmentManager = .shared
  ) {
    self.db = db
    self.environmentManager = environmentManager
  }
  
  public func createGroup(_ payload: GroupCreationPayload) async throws -> String {
    guard !payload.creatorId.isEmpty else {
      throw GroupRemoteDataSourceError.invalidCreator
    }
    
    let groupsCollection = environmentManager.collection("groups", in: db)
    let inviteCode = try await generateUniqueInviteCode(in: groupsCollection)
    let groupRef = groupsCollection.document()
    let timestamp = Timestamp(date: Date())
    
    let document = GroupDocument(
      name: payload.name,
      description: nil,
      emoji: nil,
      themeColor: nil,
      memberCount: 1,
      activePromiseCount: 0,
      maxMembers: payload.maxMembers,
      requireApproval: false,
      defaultMinimumParticipants: 2,
      inviteCode: inviteCode,
      createdBy: payload.creatorId,
      createdAt: timestamp,
      updatedAt: timestamp,
      isDeleted: false
    )
    
    try groupRef.setData(from: document)
    
    let memberDocument = GroupMemberDocument(
      userId: payload.creatorId,
      userName: payload.creatorName,
      profileImageUrl: payload.creatorProfileImageURL,
      role: "admin",
      nickname: payload.creatorNickname,
      joinedAt: timestamp,
      invitedBy: payload.creatorId
    )
    
    try groupRef
      .collection("members")
      .document(payload.creatorId)
      .setData(from: memberDocument)
    
    return groupRef.documentID
  }
  
  private func generateUniqueInviteCode(
    in collection: CollectionReference
  ) async throws -> String {
    for _ in 0..<maxInviteCodeAttempts {
      let code = randomInviteCode(length: inviteCodeLength)
      let snapshot = try await collection
        .whereField("inviteCode", isEqualTo: code)
        .limit(to: 1)
        .getDocuments()
      if snapshot.documents.isEmpty {
        return code
      }
    }
    throw GroupRemoteDataSourceError.failedToGenerateInviteCode
  }
  
  private func randomInviteCode(length: Int) -> String {
    let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    return String((0..<length).compactMap { _ in characters.randomElement() })
  }
}
