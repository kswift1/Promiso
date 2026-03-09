import Foundation
import FirebaseFirestore
import PromisoShared

// MARK: - Data Source

/// Firestore를 통한 사용자 설정 데이터 관리
public actor UserSettingsRemoteDataSource {
  private let db: Firestore

  public init(db: Firestore = Firestore.firestore()) {
    self.db = db
  }

  /// 설정 문서 참조
  private func settingsRef(userId: String) -> DocumentReference {
    db.collection("users")
      .document(userId)
      .collection("settings")
      .document("main")
  }

  // MARK: - Settings Operations

  /// 사용자 설정 조회 (문서 없으면 기본값 반환)
  public func fetchSettings(userId: String) async throws -> UserSettings {
    let document = try await settingsRef(userId: userId).getDocument()

    guard document.exists, let data = document.data() else {
      return .default
    }

    let notificationEnabled = data["notificationEnabled"] as? Bool ?? true
    let groupSortOption = GroupSortOption.read(from: data["groupSortOption"] as? [String: Any])
    let proSettings = data["proSettings"] as? [String: Any]
    let conflictDetectionThreshold = proSettings?["conflictDetectionThresholdMinute"] as? Int ?? 0
    let briefingMap = proSettings?["briefing"] as? [String: Any]
    let briefingStyle = BriefingStyle(rawValue: briefingMap?["style"] as? String ?? "") ?? .friendly
    let briefingNotificationHour = briefingMap?["notificationHour"] as? Int
    let preferredTransport = PreferredTransport(rawValue: briefingMap?["preferredTransport"] as? String ?? "") ?? .all

    return UserSettings(
      notificationEnabled: notificationEnabled,
      groupSortOption: groupSortOption,
      conflictDetectionThreshold: conflictDetectionThreshold,
      briefingStyle: briefingStyle,
      briefingNotificationHour: briefingNotificationHour,
      preferredTransport: preferredTransport
    )
  }

  /// 그룹 정렬 옵션 업데이트
  public func updateGroupSortOption(userId: String, option: GroupSortOption) async throws {
    try await settingsRef(userId: userId).setData(
      ["groupSortOption": option.write()],
      merge: true
    )
  }

  /// 일정 충돌 감지 임계값 업데이트
  public func updateConflictDetectionThreshold(userId: String, threshold: Int) async throws {
    try await settingsRef(userId: userId).updateData([
      "proSettings.conflictDetectionThresholdMinute": threshold,
    ])
  }

  /// 브리핑 스타일 업데이트
  public func updateBriefingStyle(userId: String, style: BriefingStyle) async throws {
    try await settingsRef(userId: userId).updateData([
      "proSettings.briefing.style": style.rawValue,
    ])
  }

  /// 선호 교통수단 업데이트
  public func updatePreferredTransport(userId: String, transport: PreferredTransport) async throws {
    try await settingsRef(userId: userId).updateData([
      "proSettings.briefing.preferredTransport": transport.rawValue,
    ])
  }

  /// Pro 가입 시 기본 설정값 초기화
  public func initializeProDefaults(userId: String) async throws {
    try await settingsRef(userId: userId).setData([
      "proSettings": [
        "conflictDetectionThresholdMinute": 0,
        "briefing": [
          "style": BriefingStyle.friendly.rawValue,
          "notificationHour": 8,
          "timezone": TimeZone.current.identifier,
          "language": Locale.current.language.languageCode?.identifier ?? "ko",
          "preferredTransport": PreferredTransport.all.rawValue,
        ]
      ]
    ], merge: true)
  }

  /// 브리핑 알림 시간 업데이트
  public func updateBriefingNotificationHour(userId: String, hour: Int?) async throws {
    if let hour {
      try await settingsRef(userId: userId).updateData([
        "proSettings.briefing.notificationHour": hour,
        "proSettings.briefing.timezone": TimeZone.current.identifier,
        "proSettings.briefing.language": Locale.current.language.languageCode?.identifier ?? "ko",
      ])
    } else {
      try await settingsRef(userId: userId).updateData([
        "proSettings.briefing.notificationHour": FieldValue.delete(),
        "proSettings.briefing.timezone": FieldValue.delete(),
        "proSettings.briefing.language": FieldValue.delete(),
      ])
    }
  }
}
