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
  public let scheduleId: String?
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
    scheduleId: String? = nil,
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
    self.scheduleId = scheduleId
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
  case scheduleInvitation = "schedule_invitation"
  case scheduleReminder = "schedule_reminder"
  case scheduleConfirmed = "schedule_confirmed"
  case scheduleCancelled = "schedule_cancelled"
  case scheduleUpdated = "schedule_updated"
  case groupInvitation = "group_invitation"
  case groupUpdate = "group_update"
  case attendanceResponse = "attendance_response"
  case system = "system"

  public static func fromWireValue(_ rawValue: String) -> Self? {
    switch rawValue {
    case "schedule_invitation", "promise_invitation":
      return .scheduleInvitation
    case "schedule_reminder", "promise_reminder":
      return .scheduleReminder
    case "schedule_confirmed", "promise_confirmed":
      return .scheduleConfirmed
    case "schedule_cancelled", "promise_cancelled":
      return .scheduleCancelled
    case "schedule_updated", "promise_updated":
      return .scheduleUpdated
    case "group_invitation":
      return .groupInvitation
    case "group_update":
      return .groupUpdate
    case "attendance_response":
      return .attendanceResponse
    case "system":
      return .system
    default:
      return nil
    }
  }

  public var wireValue: String {
    switch self {
    case .scheduleInvitation:
      return "promise_invitation"
    case .scheduleReminder:
      return "promise_reminder"
    case .scheduleConfirmed:
      return "promise_confirmed"
    case .scheduleCancelled:
      return "promise_cancelled"
    case .scheduleUpdated:
      return "promise_updated"
    case .groupInvitation:
      return "group_invitation"
    case .groupUpdate:
      return "group_update"
    case .attendanceResponse:
      return "attendance_response"
    case .system:
      return "system"
    }
  }

  /// 딥링크 처리에 필요한 필드 가이드
  public enum DeeplinkGuide {
    /// scheduleId + groupId 필요 → 일정 상세로 이동
    case scheduleAndGroup
    /// groupId만 필요 → 그룹 상세로 이동
    case groupOnly
    /// 딥링크 불필요 (앱만 열림)
    case none
  }

  /// 이 알림 타입의 딥링크 처리 가이드
  public var deeplinkGuide: DeeplinkGuide {
    switch self {
    case .scheduleInvitation, .scheduleReminder, .scheduleConfirmed, .scheduleCancelled,
         .scheduleUpdated, .attendanceResponse:
      return .scheduleAndGroup
    case .groupInvitation, .groupUpdate:
      return .groupOnly
    case .system:
      return .none
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)

    guard let value = Self.fromWireValue(rawValue) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown NotificationType wire value: \(rawValue)"
      )
    }

    self = value
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(wireValue)
  }
}

// MARK: - CodingKeys
extension NotificationDTO {
  enum CodingKeys: String, CodingKey {
    case userId
    case type
    case title
    case body
    case scheduleId
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

extension NotificationDTO {
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    let scheduleId = try container.decodeIfPresent(String.self, forKey: .scheduleId)
    let promiseId = try container.decodeIfPresent(String.self, forKey: .promiseId)

    self.init(
      userId: try container.decode(String.self, forKey: .userId),
      type: try container.decode(NotificationType.self, forKey: .type),
      title: try container.decode(String.self, forKey: .title),
      body: try container.decode(String.self, forKey: .body),
      scheduleId: scheduleId ?? promiseId,
      groupId: try container.decodeIfPresent(String.self, forKey: .groupId),
      relatedUserId: try container.decodeIfPresent(String.self, forKey: .relatedUserId),
      isRead: try container.decode(Bool.self, forKey: .isRead),
      isDelivered: try container.decode(Bool.self, forKey: .isDelivered),
      createdAt: try container.decode(Timestamp.self, forKey: .createdAt),
      readAt: try container.decodeIfPresent(Timestamp.self, forKey: .readAt),
      deliveredAt: try container.decodeIfPresent(Timestamp.self, forKey: .deliveredAt),
      data: try container.decodeIfPresent([String: String].self, forKey: .data)
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(userId, forKey: .userId)
    try container.encode(type, forKey: .type)
    try container.encode(title, forKey: .title)
    try container.encode(body, forKey: .body)
    try container.encodeIfPresent(scheduleId, forKey: .promiseId)
    try container.encodeIfPresent(groupId, forKey: .groupId)
    try container.encodeIfPresent(relatedUserId, forKey: .relatedUserId)
    try container.encode(isRead, forKey: .isRead)
    try container.encode(isDelivered, forKey: .isDelivered)
    try container.encode(createdAt, forKey: .createdAt)
    try container.encodeIfPresent(readAt, forKey: .readAt)
    try container.encodeIfPresent(deliveredAt, forKey: .deliveredAt)
    try container.encodeIfPresent(data, forKey: .data)
  }
}
