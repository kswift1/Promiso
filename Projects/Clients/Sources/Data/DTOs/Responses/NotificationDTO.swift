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
  case promiseUpdated = "promise_updated"
  case groupInvitation = "group_invitation"
  case groupUpdate = "group_update"
  case attendanceResponse = "attendance_response"
  case system = "system"

  /// 딥링크 처리에 필요한 필드 가이드
  public enum DeeplinkGuide {
    /// promiseId + groupId 필요 → 약속 상세로 이동
    case promiseAndGroup
    /// groupId만 필요 → 그룹 상세로 이동
    case groupOnly
    /// 딥링크 불필요 (앱만 열림)
    case none
  }

  /// 이 알림 타입의 딥링크 처리 가이드
  public var deeplinkGuide: DeeplinkGuide {
    switch self {
    case .promiseInvitation, .promiseReminder, .promiseConfirmed, .promiseCancelled,
         .promiseUpdated, .attendanceResponse:
      return .promiseAndGroup
    case .groupInvitation, .groupUpdate:
      return .groupOnly
    case .system:
      return .none
    }
  }
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
