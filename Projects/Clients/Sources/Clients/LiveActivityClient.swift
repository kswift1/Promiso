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

  /// 현재 활성화된 Activity ID
  public var activeActivityId: @Sendable () -> String?

  /// 현재 활성화된 Activity의 ContentState
  public var currentState: @Sendable () -> PromiseActivityAttributes.ContentState?

  /// 현재 활성화된 Activity의 Attributes
  public var currentAttributes: @Sendable () -> PromiseActivityAttributes?

  /// 라이브액티비티 시작
  /// - Returns: Activity ID
  public var start: @Sendable (
    _ attributes: PromiseActivityAttributes,
    _ initialState: PromiseActivityAttributes.ContentState
  ) async throws -> String

  /// 상태 업데이트
  public var update: @Sendable (
    _ activityId: String,
    _ state: PromiseActivityAttributes.ContentState
  ) async throws -> Void

  /// 라이브액티비티 종료
  public var end: @Sendable (_ activityId: String) async throws -> Void

  /// 모든 라이브액티비티 종료
  public var endAll: @Sendable () async -> Void

  /// 대기 중인 ETA 업데이트 확인
  public var pendingETAUpdate: @Sendable () -> ETAUpdate?

  /// ETA 업데이트 클리어
  public var clearETAUpdate: @Sendable () -> Void

  /// ContentState 업데이트 스트림 구독
  /// APNs 업데이트 시 앱 내 View 자동 동기화를 위해 사용
  public var observeStateUpdates: @Sendable (
    _ promiseId: String
  ) -> AsyncStream<PromiseActivityAttributes.ContentState>?

  /// Push Token 업데이트 스트림 구독
  /// APNs 원격 업데이트를 위해 백엔드에 토큰 전송 필요
  public var observePushTokenUpdates: @Sendable (
    _ promiseId: String
  ) -> AsyncStream<String>?

  // MARK: - Push to Start

  /// 현재 Push to Start 토큰 (앱 시작 시 백엔드에 등록 필요)
  public var pushToStartToken: @Sendable () async -> String?

  /// Push to Start 토큰 업데이트 스트림 구독
  /// 토큰이 변경될 때마다 백엔드에 재등록 필요
  public var observePushToStartTokenUpdates: @Sendable () -> AsyncStream<String>
}

// MARK: - Test / Preview

extension LiveActivityClient: TestDependencyKey {
  public static let previewValue = Self(
    isSupported: { true },
    hasActiveActivity: { false },
    activePromiseId: { nil },
    activeActivityId: { nil },
    currentState: { nil },
    currentAttributes: { nil },
    start: { _, _ in "preview-activity-id" },
    update: { _, _ in },
    end: { _ in },
    endAll: { },
    pendingETAUpdate: { nil },
    clearETAUpdate: { },
    observeStateUpdates: { _ in nil },
    observePushTokenUpdates: { _ in nil },
    pushToStartToken: { nil },
    observePushToStartTokenUpdates: { AsyncStream { $0.finish() } }
  )

  public static let testValue = Self(
    isSupported: unimplemented("\(Self.self).isSupported", placeholder: false),
    hasActiveActivity: unimplemented("\(Self.self).hasActiveActivity", placeholder: false),
    activePromiseId: unimplemented("\(Self.self).activePromiseId", placeholder: nil),
    activeActivityId: unimplemented("\(Self.self).activeActivityId", placeholder: nil),
    currentState: unimplemented("\(Self.self).currentState", placeholder: nil),
    currentAttributes: unimplemented("\(Self.self).currentAttributes", placeholder: nil),
    start: unimplemented("\(Self.self).start", placeholder: ""),
    update: unimplemented("\(Self.self).update"),
    end: unimplemented("\(Self.self).end"),
    endAll: unimplemented("\(Self.self).endAll"),
    pendingETAUpdate: unimplemented("\(Self.self).pendingETAUpdate", placeholder: nil),
    clearETAUpdate: unimplemented("\(Self.self).clearETAUpdate"),
    observeStateUpdates: unimplemented("\(Self.self).observeStateUpdates", placeholder: nil),
    observePushTokenUpdates: unimplemented("\(Self.self).observePushTokenUpdates", placeholder: nil),
    pushToStartToken: unimplemented("\(Self.self).pushToStartToken", placeholder: nil),
    observePushToStartTokenUpdates: unimplemented("\(Self.self).observePushToStartTokenUpdates", placeholder: AsyncStream { $0.finish() })
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

    activeActivityId: {
      Activity<PromiseActivityAttributes>.activities.first?.id
    },

    currentState: {
      Activity<PromiseActivityAttributes>.activities.first?.content.state
    },

    currentAttributes: {
      Activity<PromiseActivityAttributes>.activities.first?.attributes
    },

    start: { attributes, initialState in
      let content = ActivityContent(
        state: initialState,
        staleDate: nil
      )

      // APNs 원격 업데이트를 위해 pushType: .token 사용
      // Push token은 observePushTokenUpdates 스트림으로 전달됨
      let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: .token
      )

      return activity.id
    },

    update: { activityId, state in
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
    },

    pendingETAUpdate: {
      guard let data = UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
        .data(forKey: LiveActivityIntentKey.etaUpdateKey) else {
        return nil
      }
      return try? JSONDecoder().decode(ETAUpdate.self, from: data)
    },

    clearETAUpdate: {
      UserDefaults(suiteName: LiveActivityIntentKey.suiteName)?
        .removeObject(forKey: LiveActivityIntentKey.etaUpdateKey)
    },

    observeStateUpdates: { promiseId in
      guard let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.attributes.promiseId == promiseId }) else {
        return nil
      }

      return AsyncStream { continuation in
        let task = Task {
          for await state in activity.contentStateUpdates {
            continuation.yield(state)
          }
          continuation.finish()
        }

        continuation.onTermination = { _ in
          task.cancel()
        }
      }
    },

    observePushTokenUpdates: { promiseId in
      guard let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.attributes.promiseId == promiseId }) else {
        return nil
      }

      return AsyncStream { continuation in
        let task = Task {
          for await tokenData in activity.pushTokenUpdates {
            let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
            continuation.yield(tokenString)
          }
          continuation.finish()
        }

        continuation.onTermination = { _ in
          task.cancel()
        }
      }
    },

    // MARK: - Push to Start

    pushToStartToken: {
      for await tokenData in Activity<PromiseActivityAttributes>.pushToStartTokenUpdates {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        return tokenString
      }
      return nil
    },

    observePushToStartTokenUpdates: {
      AsyncStream { continuation in
        let task = Task {
          for await tokenData in Activity<PromiseActivityAttributes>.pushToStartTokenUpdates {
            let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
            continuation.yield(tokenString)
          }
          continuation.finish()
        }

        continuation.onTermination = { _ in
          task.cancel()
        }
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
