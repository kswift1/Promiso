import Foundation
import PromisoShared

// MARK: - NotificationModel

/// 알림 도메인 모델
public struct NotificationModel: Equatable, Hashable, Identifiable, Sendable {
  // MARK: - Identifiable

  public var id: String { notificationId }

  // MARK: - Properties

  /// 알림 ID (Firestore document ID)
  public let notificationId: String

  /// 수신자 ID
  public let userId: String

  /// 알림 타입
  public let type: NotificationCategory

  /// 알림 제목
  public let title: String

  /// 알림 본문
  public let body: String

  /// 관련 일정 ID (딥링크용)
  public let scheduleId: String?

  /// 관련 그룹 ID (딥링크용)
  public let groupId: String?

  /// 관련 사용자 ID (발신자)
  public let relatedUserId: String?

  /// 읽음 여부
  public let isRead: Bool

  /// 생성 시각
  public let createdAt: Date

  /// 읽은 시각
  public let readAt: Date?

  // MARK: - Initializer

  public init(
    notificationId: String,
    userId: String,
    type: NotificationCategory,
    title: String,
    body: String,
    scheduleId: String? = nil,
    groupId: String? = nil,
    relatedUserId: String? = nil,
    isRead: Bool = false,
    createdAt: Date = Date(),
    readAt: Date? = nil
  ) {
    self.notificationId = notificationId
    self.userId = userId
    self.type = type
    self.title = title
    self.body = body
    self.scheduleId = scheduleId
    self.groupId = groupId
    self.relatedUserId = relatedUserId
    self.isRead = isRead
    self.createdAt = createdAt
    self.readAt = readAt
  }
}

// MARK: - NotificationCategory

/// 알림 카테고리 (UI 표시용)
public enum NotificationCategory: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
  case scheduleInvitation = "schedule_invitation"
  case scheduleReminder = "schedule_reminder"
  case scheduleConfirmed = "schedule_confirmed"
  case scheduleCancelled = "schedule_cancelled"
  case scheduleUpdated = "schedule_updated"
  case groupInvitation = "group_invitation"
  case groupUpdate = "group_update"
  case attendanceResponse = "attendance_response"
  case system = "system"

  /// 아이콘 이름 (SF Symbol)
  public var iconName: String {
    switch self {
    case .scheduleInvitation: return "envelope.fill"
    case .scheduleReminder: return "bell.fill"
    case .scheduleConfirmed: return "checkmark.circle.fill"
    case .scheduleCancelled: return "xmark.circle.fill"
    case .scheduleUpdated: return "pencil.circle.fill"
    case .groupInvitation: return "person.badge.plus.fill"
    case .groupUpdate: return "person.3.fill"
    case .attendanceResponse: return "hand.raised.fill"
    case .system: return "info.circle.fill"
    }
  }

  /// 아이콘 색상
  public var iconColorName: String {
    switch self {
    case .scheduleInvitation: return "pmindigo"
    case .scheduleReminder: return "pmorange"
    case .scheduleConfirmed: return "pmgreen"
    case .scheduleCancelled: return "pmred"
    case .scheduleUpdated: return "pmblue"
    case .groupInvitation: return "pmpurple"
    case .groupUpdate: return "pmteal"
    case .attendanceResponse: return "pmyellow"
    case .system: return "pmgray"
    }
  }

  /// 딥링크 타입
  public enum DeeplinkType {
    case schedule(scheduleId: String, groupId: String)
    case group(groupId: String)
    case none
  }

  /// 딥링크 생성
  public func deeplink(scheduleId: String?, groupId: String?) -> DeeplinkType {
    switch self {
    case .scheduleInvitation, .scheduleReminder, .scheduleConfirmed,
         .scheduleCancelled, .scheduleUpdated, .attendanceResponse:
      guard let scheduleId = scheduleId, let groupId = groupId else {
        return .none
      }
      return .schedule(scheduleId: scheduleId, groupId: groupId)
    case .groupInvitation, .groupUpdate:
      guard let groupId = groupId else {
        return .none
      }
      return .group(groupId: groupId)
    case .system:
      return .none
    }
  }
}

// MARK: - NotificationFilter

/// 알림 필터
public enum NotificationFilter: String, CaseIterable, Equatable, Hashable, Sendable {
  case all = "all"
  case unread = "unread"
}

// MARK: - Computed Properties

extension NotificationModel {
  /// 생성 시각 상대 표시 (예: "방금 전", "5분 전", "어제")
  public var relativeTimeString: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = LocaleManager.appLocale
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: createdAt, relativeTo: Date())
  }

  /// 딥링크 타입
  public var deeplinkType: NotificationCategory.DeeplinkType {
    type.deeplink(scheduleId: scheduleId, groupId: groupId)
  }
}
