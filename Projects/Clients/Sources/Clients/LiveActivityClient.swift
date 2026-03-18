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

  /// 현재 활성화된 일정 ID
  public var activeScheduleId: @Sendable () -> String?

  /// 현재 활성화된 Activity ID
  public var activeActivityId: @Sendable () -> String?

  /// 현재 활성화된 Activity의 ContentState
  public var currentState: @Sendable () -> ScheduleActivityAttributes.ContentState?

  /// 현재 활성화된 Activity의 Attributes
  public var currentAttributes: @Sendable () -> ScheduleActivityAttributes?

  /// 라이브액티비티 시작
  /// - Returns: Activity ID
  public var start: @Sendable (
    _ attributes: ScheduleActivityAttributes,
    _ initialState: ScheduleActivityAttributes.ContentState
  ) async throws -> String

  /// 상태 업데이트
  public var update: @Sendable (
    _ activityId: String,
    _ state: ScheduleActivityAttributes.ContentState
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
    _ scheduleId: String
  ) -> AsyncStream<ScheduleActivityAttributes.ContentState>?

  // Push Token 관련 기능 제거됨 - iOS 18 Broadcast 방식 사용
  // Broadcast는 채널 기반이므로 개별 토큰 관리 불필요

  // MARK: - Push to Start

  /// 현재 Push to Start 토큰 (앱 시작 시 백엔드에 등록 필요)
  public var pushToStartToken: @Sendable () async -> String?

  /// Push to Start 토큰 업데이트 스트림 구독
  /// 토큰이 변경될 때마다 백엔드에 재등록 필요
  public var observePushToStartTokenUpdates: @Sendable () -> AsyncStream<String>

  // MARK: - Activity Updates

  /// 라이브액티비티 시작/종료 감지 스트림
  /// Push-to-Start로 시작된 Activity도 감지 가능
  public var observeActivityUpdates: @Sendable () -> AsyncStream<ActivityUpdate>

  /// 특정 Activity의 상태 변화 감지 스트림
  /// Activity가 dismissed/ended 될 때 감지 가능
  public var observeActivityStateUpdates: @Sendable (_ activityId: String) -> AsyncStream<ActivityStateValue>?
}

// MARK: - Activity Update

public struct ActivityUpdate: Sendable, Equatable {
  public let attributes: ScheduleActivityAttributes?
  public let contentState: ScheduleActivityAttributes.ContentState?
  public let activityState: ActivityStateValue

  public var isActive: Bool {
    activityState == .active
  }

  public init(
    attributes: ScheduleActivityAttributes?,
    contentState: ScheduleActivityAttributes.ContentState?,
    activityState: ActivityStateValue
  ) {
    self.attributes = attributes
    self.contentState = contentState
    self.activityState = activityState
  }
}

/// ActivityKit.ActivityState를 Sendable/Equatable로 래핑
public enum ActivityStateValue: String, Sendable, Equatable {
  case active
  case dismissed
  case ended
  case stale
  case unknown
}

// MARK: - Test / Preview

extension LiveActivityClient: TestDependencyKey {
  public static let previewValue = Self(
    isSupported: { true },
    hasActiveActivity: { false },
    activeScheduleId: { nil },
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
    pushToStartToken: { nil },
    observePushToStartTokenUpdates: { AsyncStream { $0.finish() } },
    observeActivityUpdates: { AsyncStream { $0.finish() } },
    observeActivityStateUpdates: { _ in nil }
  )

  public static let testValue = Self(
    isSupported: unimplemented("\(Self.self).isSupported", placeholder: false),
    hasActiveActivity: unimplemented("\(Self.self).hasActiveActivity", placeholder: false),
    activeScheduleId: unimplemented("\(Self.self).activeScheduleId", placeholder: nil),
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
    pushToStartToken: unimplemented("\(Self.self).pushToStartToken", placeholder: nil),
    observePushToStartTokenUpdates: unimplemented("\(Self.self).observePushToStartTokenUpdates", placeholder: AsyncStream { $0.finish() }),
    observeActivityUpdates: unimplemented("\(Self.self).observeActivityUpdates", placeholder: AsyncStream { $0.finish() }),
    observeActivityStateUpdates: unimplemented("\(Self.self).observeActivityStateUpdates", placeholder: nil)
  )
}

// MARK: - Live

extension LiveActivityClient: DependencyKey {
  public static let liveValue: LiveActivityClient = Self(
    isSupported: {
      ActivityAuthorizationInfo().areActivitiesEnabled
    },

    hasActiveActivity: {
      !Activity<ScheduleActivityAttributes>.activities.isEmpty
    },

    activeScheduleId: {
      Activity<ScheduleActivityAttributes>.activities.first?.attributes.scheduleId
    },

    activeActivityId: {
      Activity<ScheduleActivityAttributes>.activities.first?.id
    },

    currentState: {
      Activity<ScheduleActivityAttributes>.activities.first?.content.state
    },

    currentAttributes: {
      Activity<ScheduleActivityAttributes>.activities.first?.attributes
    },

    start: { attributes, initialState in
      let content = ActivityContent(
        state: initialState,
        staleDate: nil
      )

      // iOS 18 Broadcast 방식: Apple이 생성한 channelId 사용
      // 모든 참가자가 동일한 채널을 구독하여 업데이트 수신
      let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: .channel(attributes.channelId)
      )

      return activity.id
    },

    update: { activityId, state in
      guard let activity = Activity<ScheduleActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      let content = ActivityContent(state: state, staleDate: nil)
      await activity.update(content)
    },

    end: { activityId in
      guard let activity = Activity<ScheduleActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      await activity.end(nil, dismissalPolicy: .immediate)
    },

    endAll: {
      for activity in Activity<ScheduleActivityAttributes>.activities {
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

    observeStateUpdates: { scheduleId in
      guard let activity = Activity<ScheduleActivityAttributes>.activities
        .first(where: { $0.attributes.scheduleId == scheduleId }) else {
        return nil
      }

      return AsyncStream { continuation in
        let task = Task {
          for await content in activity.contentUpdates {
            continuation.yield(content.state)
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
      for await tokenData in Activity<ScheduleActivityAttributes>.pushToStartTokenUpdates {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        return tokenString
      }
      return nil
    },

    observePushToStartTokenUpdates: {
      AsyncStream { continuation in
        let task = Task {
          for await tokenData in Activity<ScheduleActivityAttributes>.pushToStartTokenUpdates {
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

    // MARK: - Activity Updates

    observeActivityUpdates: {
      AsyncStream { continuation in
        let task = Task {
          for await activity in Activity<ScheduleActivityAttributes>.activityUpdates {
            let stateValue: ActivityStateValue
            switch activity.activityState {
            case .active:
              stateValue = .active
            case .dismissed:
              stateValue = .dismissed
            case .ended:
              stateValue = .ended
            case .stale:
              stateValue = .stale
            default:
              stateValue = .unknown
            }

            AppLogger.liveActivity.debug("activityUpdates: \(stateValue.rawValue)")

            let update = ActivityUpdate(
              attributes: activity.attributes,
              contentState: activity.content.state,
              activityState: stateValue
            )
            continuation.yield(update)
          }
          continuation.finish()
        }

        continuation.onTermination = { _ in
          task.cancel()
        }
      }
    },

    // MARK: - Activity State Updates

    observeActivityStateUpdates: { activityId in
      guard let activity = Activity<ScheduleActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        AppLogger.liveActivity.warning("observeActivityStateUpdates: Activity not found")
        return nil
      }

      AppLogger.liveActivity.debug("observeActivityStateUpdates: 구독 시작")

      return AsyncStream { continuation in
        let task = Task {
          for await state in activity.activityStateUpdates {
            let stateValue: ActivityStateValue
            switch state {
            case .active:
              stateValue = .active
            case .dismissed:
              stateValue = .dismissed
            case .ended:
              stateValue = .ended
            case .stale:
              stateValue = .stale
            default:
              stateValue = .unknown
            }

            AppLogger.liveActivity.debug("activityStateUpdates: \(stateValue.rawValue)")
            continuation.yield(stateValue)

            // dismissed나 ended면 스트림 종료
            if stateValue == .dismissed || stateValue == .ended {
              continuation.finish()
              break
            }
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

public enum LiveActivityClientError: Error, Equatable {
  case notSupported
  case activityNotFound
  case startFailed
  case updateFailed
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}
