import Foundation
import FirebaseFirestore

/// Firestore Groups 컬렉션 DTO
struct GroupDTO: Codable {
  // MARK: - 기본 정보
  let name: String
  let description: String?
  let imageUrl: String?

  // MARK: - 멤버 관리
  let memberIds: [String]

  // MARK: - 설정
  let maxMembers: Int

  // MARK: - 메타데이터
  let inviteCode: String
  let createdBy: String
  let createdAt: Timestamp
  let updatedAt: Timestamp
}
