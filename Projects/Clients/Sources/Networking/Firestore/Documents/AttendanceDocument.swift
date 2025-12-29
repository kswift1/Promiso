import Foundation
import FirebaseFirestore

/// Firestore Attendances 서브컬렉션 문서 모델
public struct AttendanceDocument: Codable {
  // MARK: - 사용자 정보
  public let userId: String
  public let userName: String // 캐시
  public let profileImageUrl: String? // 캐시
  
  // MARK: - 상태
  public let status: AttendanceStatus
  
  // MARK: - 응답
  public let respondedAt: Timestamp?
  public let message: String?
  public let isHost: Bool
  
  // MARK: - 알림
  public let notificationSent: Bool
  public let lastViewedAt: Timestamp?
  public let reminderSentAt: Timestamp?
  
  // MARK: - 메타데이터
  public let invitedAt: Timestamp
  public let invitedBy: String
  
  public init(
    userId: String,
    userName: String,
    profileImageUrl: String? = nil,
    status: AttendanceStatus = .pending,
    respondedAt: Timestamp? = nil,
    message: String? = nil,
    isHost: Bool = false,
    notificationSent: Bool = false,
    lastViewedAt: Timestamp? = nil,
    reminderSentAt: Timestamp? = nil,
    invitedAt: Timestamp = Timestamp(),
    invitedBy: String
  ) {
    self.userId = userId
    self.userName = userName
    self.profileImageUrl = profileImageUrl
    self.status = status
    self.respondedAt = respondedAt
    self.message = message
    self.isHost = isHost
    self.notificationSent = notificationSent
    self.lastViewedAt = lastViewedAt
    self.reminderSentAt = reminderSentAt
    self.invitedAt = invitedAt
    self.invitedBy = invitedBy
  }
}

// MARK: - AttendanceStatus
public enum AttendanceStatus: String, Codable, CaseIterable {
  case pending = "pending"
  case accepted = "accepted"
  case declined = "declined"
  case tentative = "tentative"
}

// MARK: - CodingKeys
extension AttendanceDocument {
  enum CodingKeys: String, CodingKey {
    case userId
    case userName
    case profileImageUrl
    case status
    case respondedAt
    case message
    case isHost
    case notificationSent
    case lastViewedAt
    case reminderSentAt
    case invitedAt
    case invitedBy
  }
}
