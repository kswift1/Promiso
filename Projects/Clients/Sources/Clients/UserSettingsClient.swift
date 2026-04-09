import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

/// TCA용 사용자 설정 클라이언트
@DependencyClient
public struct UserSettingsClient: Sendable {
  /// 사용자 설정 조회
  public var fetchSettings: @Sendable (_ userId: String) async throws -> UserSettings

  /// Pro 설정 존재 여부 확인
  public var hasProSettings: @Sendable (_ userId: String) async throws -> Bool

  /// 그룹 정렬 옵션 업데이트
  public var updateGroupSortOption: @Sendable (_ userId: String, _ option: GroupSortOption) async throws -> Void

  /// 일정 충돌 감지 임계값 업데이트
  public var updateConflictDetectionThreshold: @Sendable (_ userId: String, _ threshold: Int) async throws -> Void

  /// 브리핑 스타일 업데이트
  public var updateBriefingStyle: @Sendable (_ userId: String, _ style: BriefingStyle) async throws -> Void

  /// 브리핑 알림 시간 업데이트
  public var updateBriefingNotificationHour: @Sendable (_ userId: String, _ hour: Int?) async throws -> Void

  /// 이용 가능 교통수단 업데이트
  public var updateAvailableTransports: @Sendable (_ userId: String, _ transports: Set<AvailableTransport>) async throws -> Void

  /// 브리핑 기본 위치 업데이트
  public var updateBriefingDefaultLocation: @Sendable (_ userId: String, _ location: LocationInfoModel?) async throws -> Void

  /// Pro 가입 시 기본 설정값 초기화
  public var initializeProDefaults: @Sendable (_ userId: String) async throws -> Void
}

// MARK: - Test & Preview Values

extension UserSettingsClient: TestDependencyKey {
  public static let testValue = Self(
    fetchSettings: unimplemented(
      "\(Self.self).fetchSettings",
      placeholder: UserSettings(notificationEnabled: true, groupSortOption: .joinedRecent)
    ),
    hasProSettings: unimplemented("\(Self.self).hasProSettings", placeholder: false),
    updateGroupSortOption: unimplemented("\(Self.self).updateGroupSortOption"),
    updateConflictDetectionThreshold: unimplemented("\(Self.self).updateConflictDetectionThreshold"),
    updateBriefingStyle: unimplemented("\(Self.self).updateBriefingStyle"),
    updateBriefingNotificationHour: unimplemented("\(Self.self).updateBriefingNotificationHour"),
    updateAvailableTransports: unimplemented("\(Self.self).updateAvailableTransports"),
    updateBriefingDefaultLocation: unimplemented("\(Self.self).updateBriefingDefaultLocation"),
    initializeProDefaults: unimplemented("\(Self.self).initializeProDefaults")
  )

  public static let previewValue = Self(
    fetchSettings: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return UserSettings(
        notificationEnabled: true,
        groupSortOption: .joinedRecent
      )
    },
    hasProSettings: { _ in
      try await Task.sleep(for: .seconds(0.1))
      return false
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
    updateAvailableTransports: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    updateBriefingDefaultLocation: { _, _ in
      try await Task.sleep(for: .seconds(0.2))
    },
    initializeProDefaults: { _ in
      try await Task.sleep(for: .seconds(0.3))
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
    let firebaseDataSource = UserSettingsRemoteDataSource()
    let rustDataSource = UserSettingsRustDataSource(
      api: RustAPIClient()
    )
    let featureFlags = FeatureFlagsClient.liveValue

    return Self(
      fetchSettings: { userId in
        if featureFlags.useRustAPI(.settings) {
          return try await rustDataSource.fetchSettings(userId: userId)
        }
        return try await firebaseDataSource.fetchSettings(userId: userId)
      },
      hasProSettings: { userId in
        if featureFlags.useRustAPI(.settings) {
          return try await rustDataSource.hasProSettings(userId: userId)
        }
        return try await firebaseDataSource.hasProSettings(userId: userId)
      },
      updateGroupSortOption: { userId, option in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateGroupSortOption(userId: userId, option: option)
        } else {
          try await firebaseDataSource.updateGroupSortOption(userId: userId, option: option)
        }
      },
      updateConflictDetectionThreshold: { userId, threshold in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateConflictDetectionThreshold(userId: userId, threshold: threshold)
        } else {
          try await firebaseDataSource.updateConflictDetectionThreshold(userId: userId, threshold: threshold)
        }
      },
      updateBriefingStyle: { userId, style in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateBriefingStyle(userId: userId, style: style)
        } else {
          try await firebaseDataSource.updateBriefingStyle(userId: userId, style: style)
        }
      },
      updateBriefingNotificationHour: { userId, hour in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateBriefingNotificationHour(userId: userId, hour: hour)
        } else {
          try await firebaseDataSource.updateBriefingNotificationHour(userId: userId, hour: hour)
        }
      },
      updateAvailableTransports: { userId, transports in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateAvailableTransports(userId: userId, transports: transports)
        } else {
          try await firebaseDataSource.updateAvailableTransports(userId: userId, transports: transports)
        }
      },
      updateBriefingDefaultLocation: { userId, location in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.updateBriefingDefaultLocation(userId: userId, location: location)
        } else {
          try await firebaseDataSource.updateBriefingDefaultLocation(userId: userId, location: location)
        }
      },
      initializeProDefaults: { userId in
        if featureFlags.useRustAPI(.settings) {
          try await rustDataSource.initializeProDefaults(userId: userId)
        } else {
          try await firebaseDataSource.initializeProDefaults(userId: userId)
        }
      }
    )
  }()
}
