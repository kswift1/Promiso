import Foundation
import FirebaseFirestore
import PromisoShared
import UIKit

// MARK: - Data Source

/// Firebase Firestore를 통한 알림 관련 데이터 관리
public final class NotificationRemoteDataSource: @unchecked Sendable {
  private let db: Firestore

  /// 현재 Firestore 환경
  private var currentEnvironment: FirebaseEnvironment {
    FirebaseEnvironmentManager.shared.current
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

  public init(db: Firestore = Firestore.firestore()) {
    self.db = db
  }

  // MARK: - FCM Token Management

  /// FCM 토큰 저장
  /// - Parameters:
  ///   - userId: 사용자 ID
  ///   - token: FCM 토큰
  public func saveFCMToken(userId: String, token: String) async throws {
    let usersCollection = db.environmentCollection("users")
    let userRef = usersCollection.document(userId)

    let deviceData: [String: Any] = [
      "fcmToken": token,
      "platform": "ios",
      "lastActiveAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp()
    ]

    // devices 필드에 deviceId를 키로 저장 (특정 경로만 업데이트하여 다른 디바이스 보존)
    try await userRef.setData([
      "devices.\(deviceId)": deviceData
    ], merge: true)

    AppLogger.notification.debug("FCM Token saved for user: \(userId), device: \(self.deviceId)")
  }

  /// FCM 토큰 삭제 (현재 디바이스)
  /// - Parameter userId: 사용자 ID
  public func deleteFCMToken(userId: String) async throws {
    let usersCollection = db.environmentCollection("users")
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
    let usersCollection = db.environmentCollection("users")
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
    let usersCollection = db.environmentCollection("users")
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
}

