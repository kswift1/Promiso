import ActivityKit
import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

public struct LiveActivityClient: Sendable {
  /// 라이브액티비티 지원 여부
  public var isSupported: @Sendable () -> Bool

  /// 현재 활성화된 라이브액티비티가 있는지
  public var hasActiveActivity: @Sendable () -> Bool

  /// 현재 활성화된 약속 ID
  public var activePromiseId: @Sendable () -> String?

  /// 라이브액티비티 시작 (Broadcast 채널 구독)
  /// - Parameters:
  ///   - attributes: 약속 속성
  ///   - initialState: 초기 상태
  ///   - channelId: APNs Broadcast 채널 ID
  /// - Returns: Activity ID
  public var start: @Sendable (
    _ attributes: PromiseActivityAttributes,
    _ initialState: PromiseActivityAttributes.ContentState,
    _ channelId: String
  ) async throws -> String

  /// 로컬 업데이트 (앱에서 직접 업데이트)
  public var updateLocal: @Sendable (
    _ activityId: String,
    _ state: PromiseActivityAttributes.ContentState
  ) async throws -> Void

  /// 라이브액티비티 종료
  public var end: @Sendable (_ activityId: String) async throws -> Void

  /// 모든 라이브액티비티 종료
  public var endAll: @Sendable () async -> Void
}

// MARK: - Test / Preview

extension LiveActivityClient: TestDependencyKey {
  public static let previewValue = Self(
    isSupported: { true },
    hasActiveActivity: { false },
    activePromiseId: { nil },
    start: { _, _, _ in "preview-activity-id" },
    updateLocal: { _, _ in },
    end: { _ in },
    endAll: { }
  )

  public static let testValue = Self(
    isSupported: unimplemented("\(Self.self).isSupported", placeholder: false),
    hasActiveActivity: unimplemented("\(Self.self).hasActiveActivity", placeholder: false),
    activePromiseId: unimplemented("\(Self.self).activePromiseId", placeholder: nil),
    start: unimplemented("\(Self.self).start", placeholder: ""),
    updateLocal: unimplemented("\(Self.self).updateLocal"),
    end: unimplemented("\(Self.self).end"),
    endAll: unimplemented("\(Self.self).endAll")
  )
}

// MARK: - Live

extension LiveActivityClient: DependencyKey {
  public static let liveValue: LiveActivityClient = Self(
    isSupported: {
      ActivityAuthorizationInfo().areActivitiesEnabled
    },

    hasActiveActivity: {
      !Activity<PromiseActivityAttributes>.activities.isEmpty
    },

    activePromiseId: {
      Activity<PromiseActivityAttributes>.activities.first?.attributes.promiseId
    },

    start: { attributes, initialState, channelId in
      let content = ActivityContent(
        state: initialState,
        staleDate: nil
      )

      let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: .channel(channelId)
      )

      return activity.id
    },

    updateLocal: { activityId, state in
      guard let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      let content = ActivityContent(state: state, staleDate: nil)
      await activity.update(content)
    },

    end: { activityId in
      guard let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      await activity.end(nil, dismissalPolicy: .immediate)
    },

    endAll: {
      for activity in Activity<PromiseActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  )
}

// MARK: - Error

public enum LiveActivityClientError: Error, Equatable, LocalizedError {
  case notSupported
  case activityNotFound
  case startFailed
  case updateFailed

  public var errorDescription: String? {
    switch self {
    case .notSupported:
      return "이 기기에서는 라이브액티비티를 지원하지 않습니다."
    case .activityNotFound:
      return "활성화된 라이브액티비티를 찾을 수 없습니다."
    case .startFailed:
      return "라이브액티비티 시작에 실패했습니다."
    case .updateFailed:
      return "라이브액티비티 업데이트에 실패했습니다."
    }
  }
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}
