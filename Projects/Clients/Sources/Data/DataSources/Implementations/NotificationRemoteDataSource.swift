import Foundation
import FirebaseFirestore
import PromisoShared
import UIKit

// MARK: - Internal DTOs

/// changes JSON 디코딩용 내부 DTO
private struct ChangeDTO: Decodable {
  let label: String
  let before: String
  let after: String
}

// MARK: - Data Source

/// Firebase Firestore를 통한 알림 관련 데이터 관리
public actor NotificationRemoteDataSource {
  private let db: Firestore

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

  public init(db: Firestore = Firestore.firestore()) {
    self.db = db
  }

  // MARK: - Notification Token Management

  /// 일반 알림 토큰 저장
  /// - Parameters:
  ///   - userId: 사용자 ID
  ///   - token: 현재는 FCM 토큰
  public func saveNotificationToken(userId: String, token: String) async throws {
    let usersCollection = db.collection("users")
    let userRef = usersCollection.document(userId)
    let platform = await MainActor.run { UIDevice.current.systemName.lowercased() }

    let deviceData: [String: Any] = [
      "fcmToken": token,
      "platform": platform,
      "lastActiveAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp()
    ]

    // devices 필드에 deviceId를 키로 저장 (중첩 딕셔너리 사용)
    // setData는 dot notation을 리터럴 필드명으로 처리하므로 중첩 구조로 전달
    try await userRef.setData([
      "devices": [
        deviceId: deviceData
      ]
    ], merge: true)

    AppLogger.notification.debug("FCM Token saved for user: \(userId), device: \(self.deviceId)")
  }

  /// 현재 디바이스 등록 삭제
  /// - Parameter userId: 사용자 ID
  public func deleteCurrentDeviceRegistration(userId: String) async throws {
    let usersCollection = db.collection("users")
    let userRef = usersCollection.document(userId)

    // 현재 디바이스의 토큰만 삭제
    try await userRef.updateData([
      "devices.\(deviceId)": FieldValue.delete()
    ])

    AppLogger.notification.debug("FCM Token deleted for user: \(userId), device: \(self.deviceId)")
  }

  /// FCM 토큰 갱신 (마지막 활성 시간 업데이트)
  /// - Parameters:
  ///   - userId: 사용자 ID
  ///   - token: FCM 토큰
  public func updateFCMToken(userId: String, token: String) async throws {
    let usersCollection = db.collection("users")
    let userRef = usersCollection.document(userId)

    try await userRef.updateData([
      "devices.\(deviceId).fcmToken": token,
      "devices.\(deviceId).lastActiveAt": FieldValue.serverTimestamp()
    ])

    AppLogger.notification.debug("FCM Token updated for user: \(userId), device: \(self.deviceId)")
  }

  /// 현재 디바이스의 FCM 토큰 조회
  /// - Parameter userId: 사용자 ID
  /// - Returns: FCM 토큰 (없으면 nil)
  public func getFCMToken(userId: String) async throws -> String? {
    let usersCollection = db.collection("users")
    let userRef = usersCollection.document(userId)

    let document = try await userRef.getDocument()
    guard let data = document.data(),
          let devices = data["devices"] as? [String: Any],
          let deviceInfo = devices[deviceId] as? [String: Any],
          let token = deviceInfo["fcmToken"] as? String else {
      return nil
    }

    return token
  }

  // MARK: - Notification List

  /// 알림 목록 조회
  /// - Parameters:
  ///   - userId: 사용자 ID
  ///   - filter: 필터 (전체/안읽음)
  ///   - limit: 조회 개수
  ///   - lastCreatedAt: 페이지네이션 커서
  /// - Returns: 알림 목록
  public func getNotifications(
    userId: String,
    filter: NotificationFilter,
    limit: Int,
    lastCreatedAt: Date?
  ) async throws -> [NotificationModel] {
    let notificationsCollection = db.collection("notifications")

    var query: Query = notificationsCollection
      .whereField("userId", isEqualTo: userId)

    // 안 읽음 필터
    if filter == .unread {
      query = query.whereField("isRead", isEqualTo: false)
    }

    // 정렬 (최신순)
    query = query.order(by: "createdAt", descending: true)

    // 페이지네이션
    if let lastCreatedAt = lastCreatedAt {
      query = query.start(after: [Timestamp(date: lastCreatedAt)])
    }

    // 개수 제한
    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()

    let notifications = snapshot.documents.compactMap { document -> NotificationModel? in
      do {
        let dto = try document.data(as: NotificationDTO.self)

        // changes JSON 파싱
        var changes: [NotificationChange]?
        if let changesJson = dto.data?["changes"],
           let jsonData = changesJson.data(using: .utf8) {
          do {
            let decoded = try JSONDecoder().decode([ChangeDTO].self, from: jsonData)
            changes = decoded.map {
              NotificationChange(
                label: $0.label,
                before: $0.before,
                after: $0.after
              )
            }
          } catch {
            AppLogger.notification.error("'changes' JSON 파싱 실패: \(error.localizedDescription), json: \(changesJson)")
          }
        }

        return NotificationModel(
          notificationId: document.documentID,
          userId: dto.userId,
          type: NotificationCategory(rawValue: dto.type.rawValue) ?? .system,
          title: dto.title,
          body: dto.body,
          scheduleId: dto.scheduleId,
          groupId: dto.groupId,
          relatedUserId: dto.relatedUserId,
          isRead: dto.isRead,
          createdAt: dto.createdAt.dateValue(),
          readAt: dto.readAt?.dateValue(),
          imageUrl: dto.data?["imageUrl"],
          changes: changes
        )
      } catch {
        AppLogger.notification.error("알림 파싱 실패: \(error.localizedDescription)")
        return nil
      }
    }

    AppLogger.notification.debug("알림 \(notifications.count)개 조회 (userId: \(userId), filter: \(filter.rawValue))")
    return notifications
  }

  /// 안 읽은 알림 개수 조회
  /// - Parameter userId: 사용자 ID
  /// - Returns: 안 읽은 알림 개수
  public func getUnreadCount(userId: String) async throws -> Int {
    let notificationsCollection = db.collection("notifications")

    let query = notificationsCollection
      .whereField("userId", isEqualTo: userId)
      .whereField("isRead", isEqualTo: false)

    let snapshot = try await query.count.getAggregation(source: .server)
    let count = Int(truncating: snapshot.count)

    AppLogger.notification.debug("안 읽은 알림 \(count)개 (userId: \(userId))")
    return count
  }

  // MARK: - Read Status

  /// 알림 읽음 처리
  /// - Parameter notificationId: 알림 ID
  public func markAsRead(notificationId: String) async throws {
    let notificationsCollection = db.collection("notifications")
    let notificationRef = notificationsCollection.document(notificationId)

    try await notificationRef.updateData([
      "isRead": true,
      "readAt": FieldValue.serverTimestamp()
    ])

    AppLogger.notification.debug("알림 읽음 처리 (notificationId: \(notificationId))")
  }

  /// 전체 알림 읽음 처리
  /// - Parameter userId: 사용자 ID
  public func markAllAsRead(userId: String) async throws {
    let notificationsCollection = db.collection("notifications")

    // 안 읽은 알림만 조회
    let query = notificationsCollection
      .whereField("userId", isEqualTo: userId)
      .whereField("isRead", isEqualTo: false)

    let snapshot = try await query.getDocuments()
    let documents = snapshot.documents

    guard !documents.isEmpty else {
      AppLogger.notification.debug("읽음 처리할 알림 없음 (userId: \(userId))")
      return
    }

    // Firestore 배치는 500개 제한이므로 청크 단위로 처리
    let chunkSize = 500
    for chunkStart in stride(from: 0, to: documents.count, by: chunkSize) {
      let chunkEnd = min(chunkStart + chunkSize, documents.count)
      let chunk = documents[chunkStart..<chunkEnd]

      let batch = db.batch()
      for document in chunk {
        batch.updateData([
          "isRead": true,
          "readAt": FieldValue.serverTimestamp()
        ], forDocument: document.reference)
      }
      try await batch.commit()
    }

    AppLogger.notification.debug("전체 알림 읽음 처리 (\(documents.count)개, userId: \(userId))")
  }

  // MARK: - Delete

  /// 알림 삭제
  /// - Parameter notificationIds: 삭제할 알림 ID 목록
  public func deleteNotifications(notificationIds: [String]) async throws {
    guard !notificationIds.isEmpty else { return }

    let notificationsCollection = db.collection("notifications")

    // 배치 삭제 (500개 제한)
    let batch = db.batch()
    for notificationId in notificationIds.prefix(500) {
      let ref = notificationsCollection.document(notificationId)
      batch.deleteDocument(ref)
    }

    try await batch.commit()

    AppLogger.notification.debug("알림 \(notificationIds.count)개 삭제")
  }

  /// 전체 알림 삭제
  /// - Parameter userId: 사용자 ID
  public func deleteAllNotifications(userId: String) async throws {
    let notificationsCollection = db.collection("notifications")

    let query = notificationsCollection
      .whereField("userId", isEqualTo: userId)

    let snapshot = try await query.getDocuments()
    let documents = snapshot.documents

    guard !documents.isEmpty else {
      AppLogger.notification.debug("삭제할 알림 없음 (userId: \(userId))")
      return
    }

    // Firestore 배치는 500개 제한이므로 청크 단위로 처리
    let chunkSize = 500
    for chunkStart in stride(from: 0, to: documents.count, by: chunkSize) {
      let chunkEnd = min(chunkStart + chunkSize, documents.count)
      let chunk = documents[chunkStart..<chunkEnd]

      let batch = db.batch()
      for document in chunk {
        batch.deleteDocument(document.reference)
      }
      try await batch.commit()
    }

    AppLogger.notification.debug("전체 알림 삭제 (\(documents.count)개, userId: \(userId))")
  }
}
