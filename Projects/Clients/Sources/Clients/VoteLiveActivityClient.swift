import ActivityKit
import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

public struct VoteLiveActivityClient: Sendable {
  /// 라이브액티비티 지원 여부
  public var isSupported: @Sendable () -> Bool

  /// 현재 활성화된 투표 Activity가 있는지
  public var hasActiveActivity: @Sendable () -> Bool

  /// 현재 활성화된 일정 ID
  public var activeScheduleId: @Sendable () -> String?

  /// 라이브액티비티 시작 (로컬에서 직접 시작할 때)
  /// - Returns: Activity ID
  public var start: @Sendable (
    _ attributes: VoteActivityAttributes,
    _ initialState: VoteActivityAttributes.ContentState
  ) async throws -> String

  /// 상태 업데이트
  public var update: @Sendable (
    _ activityId: String,
    _ state: VoteActivityAttributes.ContentState
  ) async throws -> Void

  /// 라이브액티비티 종료
  public var end: @Sendable (_ activityId: String) async throws -> Void

  /// 모든 투표 라이브액티비티 종료
  public var endAll: @Sendable () async -> Void

  /// ContentState 업데이트 스트림 구독
  /// APNs 업데이트 시 앱 내 View 자동 동기화를 위해 사용
  public var observeStateUpdates: @Sendable (
    _ scheduleId: String
  ) -> AsyncStream<VoteActivityAttributes.ContentState>?

  // MARK: - Push to Start

  /// 현재 Push to Start 토큰 (앱 시작 시 백엔드에 등록 필요)
  public var pushToStartToken: @Sendable () async -> String?

  /// Push to Start 토큰 업데이트 스트림 구독
  /// 토큰이 변경될 때마다 백엔드에 재등록 필요
  public var observePushToStartTokenUpdates: @Sendable () -> AsyncStream<String>

  /// 라이브액티비티 시작/종료 감지 스트림
  /// Push-to-Start로 시작된 Activity도 감지 가능
  public var observeActivityUpdates: @Sendable () -> AsyncStream<VoteActivityUpdate>
}

// MARK: - Vote Activity Update

public struct VoteActivityUpdate: Sendable, Equatable {
  public let attributes: VoteActivityAttributes?
  public let contentState: VoteActivityAttributes.ContentState?
  public let activityState: ActivityStateValue

  public var isActive: Bool {
    activityState == .active
  }

  public init(
    attributes: VoteActivityAttributes?,
    contentState: VoteActivityAttributes.ContentState?,
    activityState: ActivityStateValue
  ) {
    self.attributes = attributes
    self.contentState = contentState
    self.activityState = activityState
  }
}

// MARK: - Test / Preview

extension VoteLiveActivityClient: TestDependencyKey {
  public static let previewValue = Self(
    isSupported: { true },
    hasActiveActivity: { false },
    activeScheduleId: { nil },
    start: { _, _ in "preview-vote-activity-id" },
    update: { _, _ in },
    end: { _ in },
    endAll: { },
    observeStateUpdates: { _ in nil },
    pushToStartToken: { nil },
    observePushToStartTokenUpdates: { AsyncStream { $0.finish() } },
    observeActivityUpdates: { AsyncStream { $0.finish() } }
  )

  public static let testValue = Self(
    isSupported: unimplemented("\(Self.self).isSupported", placeholder: false),
    hasActiveActivity: unimplemented("\(Self.self).hasActiveActivity", placeholder: false),
    activeScheduleId: unimplemented("\(Self.self).activeScheduleId", placeholder: nil),
    start: unimplemented("\(Self.self).start", placeholder: ""),
    update: unimplemented("\(Self.self).update"),
    end: unimplemented("\(Self.self).end"),
    endAll: unimplemented("\(Self.self).endAll"),
    observeStateUpdates: unimplemented("\(Self.self).observeStateUpdates", placeholder: nil),
    pushToStartToken: unimplemented("\(Self.self).pushToStartToken", placeholder: nil),
    observePushToStartTokenUpdates: unimplemented("\(Self.self).observePushToStartTokenUpdates", placeholder: AsyncStream { $0.finish() }),
    observeActivityUpdates: unimplemented("\(Self.self).observeActivityUpdates", placeholder: AsyncStream { $0.finish() })
  )
}

// MARK: - Live

extension VoteLiveActivityClient: DependencyKey {
  public static let liveValue: VoteLiveActivityClient = Self(
    isSupported: {
      ActivityAuthorizationInfo().areActivitiesEnabled
    },

    hasActiveActivity: {
      !Activity<VoteActivityAttributes>.activities.isEmpty
    },

    activeScheduleId: {
      Activity<VoteActivityAttributes>.activities.first?.attributes.scheduleId
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
      guard let activity = Activity<VoteActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      let content = ActivityContent(state: state, staleDate: nil)
      await activity.update(content)
    },

    end: { activityId in
      guard let activity = Activity<VoteActivityAttributes>.activities
        .first(where: { $0.id == activityId }) else {
        throw LiveActivityClientError.activityNotFound
      }

      await activity.end(nil, dismissalPolicy: .immediate)
    },

    endAll: {
      for activity in Activity<VoteActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    },

    observeStateUpdates: { scheduleId in
      guard let activity = Activity<VoteActivityAttributes>.activities
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
      for await tokenData in Activity<VoteActivityAttributes>.pushToStartTokenUpdates {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        return tokenString
      }
      return nil
    },

    observePushToStartTokenUpdates: {
      AsyncStream { continuation in
        let task = Task {
          for await tokenData in Activity<VoteActivityAttributes>.pushToStartTokenUpdates {
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
          for await activity in Activity<VoteActivityAttributes>.activityUpdates {
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

            AppLogger.liveActivity.debug("voteActivityUpdates: \(stateValue.rawValue)")

            let update = VoteActivityUpdate(
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
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var voteLiveActivityClient: VoteLiveActivityClient {
    get { self[VoteLiveActivityClient.self] }
    set { self[VoteLiveActivityClient.self] = newValue }
  }
}
