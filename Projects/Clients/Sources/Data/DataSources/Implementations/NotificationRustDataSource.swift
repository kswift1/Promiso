import Foundation
import PromisoShared

// MARK: - Response DTOs

private struct RustNotificationResponse: Decodable {
  let id: String
  let notificationType: String
  let title: String
  let body: String
  let scheduleId: String?
  let groupId: String?
  let relatedUserId: String?
  let isRead: Bool
  let createdAt: Date
  let readAt: Date?
  let data: [String: String]?
}

private struct RustUnreadCountResponse: Decodable {
  let count: Int
}

private struct RustSuccessResponse: Decodable {
  let success: Bool?
}

// MARK: - Request DTOs

private struct UpsertDeviceBody: Encodable {
  let deviceId: String
  let platform: String?
}

private struct UpsertNotificationEndpointBody: Encodable {
  let token: String
}

private struct UpsertLiveActivityEndpointBody: Encodable {
  let pushToStartToken: String?
  let liveActivityPushToken: String?
}

private struct DeleteBatchBody: Encodable {
  let notificationIds: [String]
}

private struct EmptyBody: Encodable {}

// MARK: - Changes DTO

private struct ChangeDTO: Decodable {
  let label: String
  let before: String
  let after: String
}

// MARK: - NotificationRustDataSource

public actor NotificationRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  /// 현재 디바이스 ID (앱 설치 시 생성되는 고유 ID)
  private var deviceId: String {
    let key = AppConstants.UserDefaults.deviceId
    if let existingId = UserDefaults.standard.string(forKey: key) {
      return existingId
    }
    let newId = UUID().uuidString
    UserDefaults.standard.set(newId, forKey: key)
    return newId
  }

  // MARK: - Device Management

  private func ensureDeviceExists() async throws {
    let body = UpsertDeviceBody(
      deviceId: deviceId,
      platform: "ios"
    )
    let _: RustSuccessResponse = try await api.put("/api/v1/devices", body: body)
  }

  /// 일반 알림용 토큰 저장
  /// - Parameter token: 현재는 FCM 토큰
  public func saveNotificationToken(_ token: String) async throws {
    try await ensureDeviceExists()
    let body = UpsertNotificationEndpointBody(token: token)
    let _: RustSuccessResponse = try await api.put(
      "/api/v1/devices/\(deviceId)/notification-endpoints/fcm",
      body: body
    )
  }

  /// 현재 디바이스 등록 삭제
  public func deleteCurrentDevice() async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/devices/\(deviceId)")
  }

  /// 모든 디바이스 삭제
  public func deleteAllDevices() async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/devices")
  }

  /// Push to Start 토큰 저장
  /// - Parameter token: Push to Start 토큰
  public func saveLiveActivityPushToStartToken(_ token: String) async throws {
    try await ensureDeviceExists()
    let body = UpsertLiveActivityEndpointBody(
      pushToStartToken: token,
      liveActivityPushToken: nil
    )
    let _: RustSuccessResponse = try await api.put(
      "/api/v1/devices/\(deviceId)/live-activity-endpoint",
      body: body
    )
  }

  // MARK: - Notification List

  /// 알림 목록 조회
  /// - Parameters:
  ///   - limit: 조회 개수
  ///   - lastCreatedAt: 페이지네이션 커서 (마지막 알림의 createdAt)
  /// - Returns: 알림 목록
  public func getNotifications(
    limit: Int,
    lastCreatedAt: Date?
  ) async throws -> [NotificationModel] {
    var path = "/api/v1/notifications?limit=\(limit)"
    if let lastCreatedAt {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let dateString = formatter.string(from: lastCreatedAt)
      let encoded = dateString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dateString
      path += "&before=\(encoded)"
    }
    let response: [RustNotificationResponse] = try await api.get(path)
    return response.map { $0.toModel() }
  }

  /// 안 읽은 알림 개수 조회
  /// - Returns: 안 읽은 알림 개수
  public func getUnreadCount() async throws -> Int {
    let response: RustUnreadCountResponse = try await api.get("/api/v1/notifications/unread-count")
    return response.count
  }

  // MARK: - Read Status

  /// 알림 읽음 처리
  /// - Parameter notificationId: 알림 ID
  public func markAsRead(notificationId: String) async throws {
    let _: RustSuccessResponse = try await api.patch(
      "/api/v1/notifications/\(notificationId)/read",
      body: EmptyBody()
    )
  }

  /// 전체 알림 읽음 처리
  public func markAllAsRead() async throws {
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/notifications/mark-all-read",
      body: EmptyBody()
    )
  }

  // MARK: - Delete

  /// 알림 삭제 (배치)
  /// - Parameter notificationIds: 삭제할 알림 ID 목록
  public func deleteNotifications(notificationIds: [String]) async throws {
    let body = DeleteBatchBody(notificationIds: notificationIds)
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/notifications/delete-batch",
      body: body
    )
  }

  /// 전체 알림 삭제
  public func deleteAllNotifications() async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/notifications")
  }
}

// MARK: - DTO -> Model 변환

extension RustNotificationResponse {
  fileprivate func toModel() -> NotificationModel {
    // notificationType 문자열 -> NotificationCategory 변환
    // Rust 서버는 snake_case로 전달하므로 rawValue로 직접 매핑
    let category: NotificationCategory = {
      // 기존 Firebase의 fromWireValue 패턴과 동일한 매핑 지원
      switch notificationType {
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
      case "location_sharing_reminder":
        return .locationSharingReminder
      default:
        return .system
      }
    }()

    // changes JSON 파싱 (data["changes"]에 JSON 문자열로 저장)
    var changes: [NotificationChange]?
    if let changesJson = data?["changes"],
       let jsonData = changesJson.data(using: .utf8) {
      if let decoded = try? JSONDecoder().decode([ChangeDTO].self, from: jsonData) {
        changes = decoded.map {
          NotificationChange(label: $0.label, before: $0.before, after: $0.after)
        }
      }
    }

    return NotificationModel(
      notificationId: id,
      userId: "", // Rust API는 인증된 사용자 기준이므로 서버에서 userId를 별도 반환하지 않을 수 있음
      type: category,
      title: title,
      body: body,
      scheduleId: scheduleId,
      groupId: groupId,
      relatedUserId: relatedUserId,
      isRead: isRead,
      createdAt: createdAt,
      readAt: readAt,
      imageUrl: data?["imageUrl"],
      changes: changes
    )
  }
}
