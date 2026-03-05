import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

/// TCA용 사용자 설정 클라이언트
@DependencyClient
public struct UserSettingsClient: Sendable {
  /// 사용자 설정 조회
  public var fetchSettings: @Sendable (_ userId: String) async throws -> UserSettings

  /// 그룹 정렬 옵션 업데이트
  public var updateGroupSortOption: @Sendable (_ userId: String, _ option: GroupSortOption) async throws -> Void

  /// 사용자 플랜 업데이트
  public var updatePlan: @Sendable (_ userId: String, _ plan: UserPlan) async throws -> Void

  /// 일정 충돌 감지 임계값 업데이트
  public var updateConflictDetectionThreshold: @Sendable (_ userId: String, _ threshold: Int) async throws -> Void
}

// MARK: - Test & Preview Values

extension UserSettingsClient: TestDependencyKey {
  public static let testValue = Self(
    fetchSettings: unimplemented(
      "\\(Self.self).fetchSettings",
      placeholder: UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent, plan: .free)
    ),
    updateGroupSortOption: unimplemented("\\(Self.self).updateGroupSortOption"),
    updatePlan: unimplemented("\\(Self.self).updatePlan"),
    updateConflictDetectionThreshold: unimplemented("\\(Self.self).updateConflictDetectionThreshold")
  )

  public static let previewValue = Self(
    fetchSettings: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return UserSettings(
        notificationEnabled: true,
        groupSortOption: .joinedRecent,
        plan: .free
      )
    },
    updateGroupSortOption: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updatePlan: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updateConflictDetectionThreshold: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var userSettingsClient: UserSettingsClient {
    get { self[UserSettingsClient.self] }
    set { self[UserSettingsClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension UserSettingsClient: DependencyKey {
  public static let liveValue: UserSettingsClient = {
    let dataSource = UserSettingsRemoteDataSource()

    return Self(
      fetchSettings: { userId in
        try await dataSource.fetchSettings(userId: userId)
      },
      updateGroupSortOption: { userId, option in
        try await dataSource.updateGroupSortOption(userId: userId, option: option)
      },
      updatePlan: { userId, plan in
        try await dataSource.updatePlan(userId: userId, plan: plan)
      },
      updateConflictDetectionThreshold: { userId, threshold in
        try await dataSource.updateConflictDetectionThreshold(userId: userId, threshold: threshold)
      }
    )
  }()
}
