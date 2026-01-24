import Foundation
import FirebaseFirestore
import PromisoShared

// MARK: - Data Source

/// Firestore를 통한 사용자 설정 데이터 관리
public final class UserSettingsRemoteDataSource: @unchecked Sendable {
  private let db: Firestore

  public init(db: Firestore = Firestore.firestore()) {
    self.db = db
  }

  // MARK: - Settings Operations

  /// 사용자 설정 조회
  public func fetchSettings(userId: String) async throws -> UserSettings {
    let doc = try await db
      .collection("users")
      .document(userId)
      .collection("settings")
      .document("main")
      .getDocument()

    guard doc.exists else {
      // 문서가 없으면 기본값 반환
      return UserSettings(
        notificationEnabled: true,
        groupSortOption: .joinedRecent
      )
    }

    let data = doc.data() ?? [:]
    return UserSettings(
      notificationEnabled: data["notificationEnabled"] as? Bool ?? true,
      groupSortOption: parseGroupSortOption(data["groupSortOption"] as? String)
    )
  }

  /// 그룹 정렬 옵션 업데이트
  public func updateGroupSortOption(userId: String, option: GroupSortOption) async throws {
    try await db
      .collection("users")
      .document(userId)
      .collection("settings")
      .document("main")
      .setData([
        "groupSortOption": option.rawValue
      ], merge: true)
  }

  /// 알림 활성화 토글
  public func updateNotificationEnabled(userId: String, enabled: Bool) async throws {
    try await db
      .collection("users")
      .document(userId)
      .collection("settings")
      .document("main")
      .setData([
        "notificationEnabled": enabled
      ], merge: true)
  }

  // MARK: - Helpers

  private func parseGroupSortOption(_ rawValue: String?) -> GroupSortOption {
    guard let rawValue = rawValue,
          let option = GroupSortOption(rawValue: rawValue) else {
      return .joinedRecent  // 기본값
    }
    return option
  }
}
