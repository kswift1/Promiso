import Foundation
import FirebaseFirestore

/// Firestore Notifications 컬렉션 문서 모델
public struct NotificationDTO: Codable {
  // MARK: - 기본 정보
  public let userId: String
  public let type: NotificationType
  public let title: String
  public let body: String
  
  // MARK: - 관련 데이터
  public let promiseId: String?
  public let groupId: String?
  public let relatedUserId: String?
  
  // MARK: - 상태
  public let isRead: Bool
  public let isDelivered: Bool
  
  // MARK: - 타임스탬프
  public let createdAt: Timestamp
  public let readAt: Timestamp?
  public let deliveredAt: Timestamp?
  
  // MARK: - 추가 데이터
  public let data: [String: String]?
  
  public init(
    userId: String,
    type: NotificationType,
    title: String,
    body: String,
    promiseId: String? = nil,
    groupId: String? = nil,
    relatedUserId: String? = nil,
    isRead: Bool = false,
    isDelivered: Bool = false,
    createdAt: Timestamp = Timestamp(),
    readAt: Timestamp? = nil,
    deliveredAt: Timestamp? = nil,
    data: [String: String]? = nil
  ) {
    self.userId = userId
    self.type = type
    self.title = title
    self.body = body
    self.promiseId = promiseId
    self.groupId = groupId
    self.relatedUserId = relatedUserId
    self.isRead = isRead
    self.isDelivered = isDelivered
    self.createdAt = createdAt
    self.readAt = readAt
    self.deliveredAt = deliveredAt
    self.data = data
  }
}

// MARK: - NotificationType
public enum NotificationType: String, Codable, CaseIterable {
  case promiseInvitation = "promise_invitation"
  case promiseReminder = "promise_reminder"
  case promiseConfirmed = "promise_confirmed"
  case promiseCancelled = "promise_cancelled"
  case groupInvitation = "group_invitation"
  case groupUpdate = "group_update"
  case attendanceResponse = "attendance_response"
  case system = "system"
}

// MARK: - CodingKeys
extension NotificationDTO {
  enum CodingKeys: String, CodingKey {
    case userId
    case type
    case title
    case body
    case promiseId
    case groupId
    case relatedUserId
    case isRead
    case isDelivered
    case createdAt
    case readAt
    case deliveredAt
    case data
  }
}
