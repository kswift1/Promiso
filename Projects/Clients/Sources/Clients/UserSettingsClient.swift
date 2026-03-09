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

  /// 일정 충돌 감지 임계값 업데이트
  public var updateConflictDetectionThreshold: @Sendable (_ userId: String, _ threshold: Int) async throws -> Void

  /// 브리핑 스타일 업데이트
  public var updateBriefingStyle: @Sendable (_ userId: String, _ style: BriefingStyle) async throws -> Void

  /// 브리핑 알림 시간 업데이트
  public var updateBriefingNotificationHour: @Sendable (_ userId: String, _ hour: Int?) async throws -> Void

  /// 선호 교통수단 업데이트
  public var updatePreferredTransport: @Sendable (_ userId: String, _ transport: PreferredTransport) async throws -> Void
}

// MARK: - Test & Preview Values

extension UserSettingsClient: TestDependencyKey {
  public static let testValue = Self(
    fetchSettings: unimplemented(
      "\(Self.self).fetchSettings",
      placeholder: UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
    ),
    updateGroupSortOption: unimplemented("\(Self.self).updateGroupSortOption"),
    updateConflictDetectionThreshold: unimplemented("\(Self.self).updateConflictDetectionThreshold"),
    updateBriefingStyle: unimplemented("\(Self.self).updateBriefingStyle"),
    updateBriefingNotificationHour: unimplemented("\(Self.self).updateBriefingNotificationHour"),
    updatePreferredTransport: unimplemented("\(Self.self).updatePreferredTransport")
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
    updateConflictDetectionThreshold: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updateBriefingStyle: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updateBriefingNotificationHour: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updatePreferredTransport: { _, _ in
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
      updateConflictDetectionThreshold: { userId, threshold in
        try await dataSource.updateConflictDetectionThreshold(userId: userId, threshold: threshold)
      },
      updateBriefingStyle: { userId, style in
        try await dataSource.updateBriefingStyle(userId: userId, style: style)
      },
      updateBriefingNotificationHour: { userId, hour in
        try await dataSource.updateBriefingNotificationHour(userId: userId, hour: hour)
      },
      updatePreferredTransport: { userId, transport in
        try await dataSource.updatePreferredTransport(userId: userId, transport: transport)
      }
    )
  }()
}
