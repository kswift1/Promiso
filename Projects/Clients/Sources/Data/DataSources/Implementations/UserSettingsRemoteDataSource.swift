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
    db.environmentCollection("users")
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
    let plan = UserPlan(rawValue: data["plan"] as? String ?? "") ?? .free
    let conflictDetectionThreshold = data["conflictDetectionThreshold"] as? Int ?? 0

    return UserSettings(
      notificationEnabled: notificationEnabled,
      groupSortOption: groupSortOption,
      plan: plan,
      conflictDetectionThreshold: conflictDetectionThreshold
    )
  }

  /// 그룹 정렬 옵션 업데이트
  public func updateGroupSortOption(userId: String, option: GroupSortOption) async throws {
    try await settingsRef(userId: userId).setData(
      ["groupSortOption": option.write()],
      merge: true
    )
  }

  /// 사용자 플랜 업데이트
  public func updatePlan(userId: String, plan: UserPlan) async throws {
    try await settingsRef(userId: userId).setData(
      ["plan": plan.rawValue],
      merge: true
    )
  }

  /// 일정 충돌 감지 임계값 업데이트
  public func updateConflictDetectionThreshold(userId: String, threshold: Int) async throws {
    try await settingsRef(userId: userId).setData(
      ["conflictDetectionThreshold": threshold],
      merge: true
    )
  }
}
