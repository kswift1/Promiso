import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Models

/// 사용자 설정 정보
public struct UserSettings: Equatable, Sendable {
  public var notificationEnabled: Bool
  public var groupSortOption: GroupSortOption

  public init(
    notificationEnabled: Bool,
    groupSortOption: GroupSortOption
  ) {
    self.notificationEnabled = notificationEnabled
    self.groupSortOption = groupSortOption
  }
}

// MARK: - Client

/// TCA용 사용자 설정 클라이언트
@DependencyClient
public struct UserSettingsClient: Sendable {
  /// 사용자 설정 조회
  public var fetchSettings: @Sendable (_ userId: String) async throws -> UserSettings

  /// 그룹 정렬 옵션 업데이트
  public var updateGroupSortOption: @Sendable (_ userId: String, _ option: GroupSortOption) async throws -> Void

  /// 알림 활성화 토글
  public var updateNotificationEnabled: @Sendable (_ userId: String, _ enabled: Bool) async throws -> Void
}

// MARK: - Test & Preview Values

extension UserSettingsClient: TestDependencyKey {
  public static let testValue = Self(
    fetchSettings: unimplemented(
      "\\(Self.self).fetchSettings",
      placeholder: UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
    ),
    updateGroupSortOption: unimplemented("\\(Self.self).updateGroupSortOption"),
    updateNotificationEnabled: unimplemented("\\(Self.self).updateNotificationEnabled")
  )

  public static let previewValue = Self(
    fetchSettings: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return UserSettings(
        notificationEnabled: true,
        groupSortOption: .joinedRecent
      )
    },
    updateGroupSortOption: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updateNotificationEnabled: { _, _ in
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
      updateNotificationEnabled: { userId, enabled in
        try await dataSource.updateNotificationEnabled(userId: userId, enabled: enabled)
      }
    )
  }()
}
