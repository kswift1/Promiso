import Foundation
import FirebaseFirestore
import FirebaseFunctions
import PromisoShared
import UIKit

// MARK: - Firebase 상수

private enum FirebaseConstants {
  static let region = "asia-northeast3"
  static let registerPushToStartToken = "registerPushToStartToken"
}

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
      "platform": UIDevice.current.systemName.lowercased(),
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

  // MARK: - LiveActivity Push to Start Token

  /// LiveActivity Push to Start 토큰 저장
  /// - Parameters:
  ///   - userId: 사용자 ID
  ///   - token: Push to Start 토큰
  public func saveLiveActivityPushToStartToken(userId: String, token: String) async throws {
    let functions = Functions.functions(region: FirebaseConstants.region)
    let callable = functions.httpsCallable(FirebaseConstants.registerPushToStartToken)

    var callableData: [String: Any] = [
      "token": token,
      "deviceId": deviceId
    ]

    // env 파라미터 추가
    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
    }

    do {
      _ = try await callable.call(callableData)
      AppLogger.liveActivity.info("✅ Push to Start 토큰 등록 성공 (userId: \(userId), deviceId: \(self.deviceId))")
    } catch {
      AppLogger.liveActivity.error("❌ Push to Start 토큰 등록 실패: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Helper

  private func functionsEnvironmentParam() -> String? {
    switch currentEnvironment {
    case .dev, .stage:
      return "stage"
    case .release:
      return nil
    }
  }
}

