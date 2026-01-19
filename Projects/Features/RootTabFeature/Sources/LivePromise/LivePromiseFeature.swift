//
//  LivePromiseFeature.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ComposableArchitecture
import Clients
import PromisoShared

/// 약속 추적 (LiveActivity 기반 앱 내 뷰)
/// - CompactView: 하단 고정 바
/// - ExpandedView: 전체 화면
public enum LivePromise {}

// MARK: - Shared Data

extension LivePromise {
  /// Feature와 Detail이 공유하는 약속 데이터
  public struct Data: Equatable, Sendable {
    public var emoji: String
    public var title: String
    public var location: String?
    public var scheduledTime: Date?
    public var participants: [ParticipantState]
    public var currentUserId: String
    public var trackingDurationMinutes: Int
    public var isProcessingETAUpdate: Bool

    public init(
      emoji: String = "📍",
      title: String = "",
      location: String? = nil,
      scheduledTime: Date? = nil,
      participants: [ParticipantState] = [],
      currentUserId: String = "",
      trackingDurationMinutes: Int = 30,
      isProcessingETAUpdate: Bool = false
    ) {
      self.emoji = emoji
      self.title = title
      self.location = location
      self.scheduledTime = scheduledTime
      self.participants = participants
      self.currentUserId = currentUserId
      self.trackingDurationMinutes = trackingDurationMinutes
      self.isProcessingETAUpdate = isProcessingETAUpdate
    }

    // MARK: - Computed Properties

    /// 도착한 참가자 수
    public var arrivedCount: Int {
      participants.filter { $0.estimatedArrivalMinutes == 0 }.count
    }

    /// 이동 중인 참가자 수
    public var inTransitCount: Int {
      participants.filter { ($0.estimatedArrivalMinutes ?? -1) > 0 }.count
    }

    /// 현재 사용자의 참가자 상태
    public var currentUserParticipant: ParticipantState? {
      participants.first { $0.id == currentUserId }
    }

    /// 현재 사용자의 ETA
    public var currentUserETA: Int? {
      currentUserParticipant?.estimatedArrivalMinutes
    }
  }
}

// MARK: - Detail Feature

extension LivePromise {
  /// 상세 화면 탭 종류
  public enum DetailTab: String, CaseIterable, Equatable, Sendable {
    case status = "현황"
    case map = "지도"
    case chat = "채팅"
  }

  @Reducer
  public struct Detail {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 공유 데이터 (Feature와 동기화)
      @Shared public var data: LivePromise.Data

      /// 현재 선택된 탭
      var selectedTab: DetailTab = .status

      public init(data: Shared<LivePromise.Data>) {
        self._data = data
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case dismiss
      case tabSelected(DetailTab)
      case etaButtonTapped(Int)
      case copyButtonTapped
      case notificationButtonTapped
      case moreButtonTapped
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .dismiss:
          return .none

        case .tabSelected(let tab):
          state.selectedTab = tab
          return .none

        case .etaButtonTapped:
          // 부모에서 처리
          return .none

        case .copyButtonTapped:
          // TODO: 복사 기능 구현
          return .none

        case .notificationButtonTapped:
          // TODO: 알림 기능 구현
          return .none

        case .moreButtonTapped:
          // TODO: 더보기 기능 구현
          return .none
        }
      }
    }
  }
}

extension LivePromise {
  @Reducer
  public struct Feature {
    @Dependency(\.liveActivityClient) var liveActivityClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 공유 데이터 (Detail과 동기화)
      @Shared public var data: LivePromise.Data

      /// 대기 중인 ETA 업데이트 (Feature 전용)
      var pendingETAUpdate: ETAUpdate?

      // MARK: - Initializer

      public init(data: Shared<LivePromise.Data>) {
        self._data = data
      }

      public init(
        emoji: String = "📍",
        title: String = "",
        location: String? = nil,
        scheduledTime: Date? = nil,
        participants: [ParticipantState] = [],
        currentUserId: String = ""
      ) {
        self._data = Shared(value: LivePromise.Data(
          emoji: emoji,
          title: title,
          location: location,
          scheduledTime: scheduledTime,
          participants: participants,
          currentUserId: currentUserId
        ))
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case tapped
        case etaButtonTapped(Int)
        case refreshFromLiveActivity
      }

      public enum Internal: Equatable, Sendable {
        case liveActivityStateUpdated(PromiseActivityAttributes?, PromiseActivityAttributes.ContentState?)
        case processPendingETAUpdate(ETAUpdate)
        case etaUpdateSent
        case etaUpdateFailed
      }

      public enum Delegate: Equatable, Sendable {
        /// CompactView 탭 → 상세 뷰 표시 요청
        case showDetail
        case navigateToPromiseDetail(promiseId: String)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 현재 활성화된 LiveActivity 상태 동기화
            return .send(.view(.refreshFromLiveActivity))

          case .tapped:
            // 컴팩트 뷰 탭 → 부모에게 상세 뷰 표시 요청
            return .send(.delegate(.showDetail))

          case .etaButtonTapped(let minutes):
            return handleETAUpdate(state: &state, minutes: minutes)

          case .refreshFromLiveActivity:
            // LiveActivityClient에서 현재 상태 가져오기
            return .run { [liveActivityClient] send in
              // 현재 Activity 확인
              guard liveActivityClient.hasActiveActivity() else {
                // 활성 Activity 없음 → 상태 초기화
                await send(.internal(.liveActivityStateUpdated(nil, nil)))
                return
              }

              // Attributes와 ContentState 모두 가져오기
              let attributes = liveActivityClient.currentAttributes()
              let contentState = liveActivityClient.currentState()

              await send(.internal(.liveActivityStateUpdated(attributes, contentState)))
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .liveActivityStateUpdated(let attributes, let contentState):
            // LiveActivity 상태 동기화
            state.$data.withLock { data in
              if let attributes = attributes {
                data.emoji = attributes.emoji
                data.title = attributes.title
                data.location = attributes.location
                data.scheduledTime = attributes.scheduledTime
                data.trackingDurationMinutes = attributes.trackingDurationMinutes
              }

              if let contentState = contentState {
                data.participants = contentState.participants
                data.trackingDurationMinutes = contentState.trackingDurationMinutes
              }
            }

            return .none

          case .processPendingETAUpdate(let etaUpdate):
            // ETA 업데이트 처리
            guard let activityId = liveActivityClient.activeActivityId() else {
              state.$data.withLock { $0.isProcessingETAUpdate = false }
              return .none
            }

            return .run { [liveActivityClient] send in
              do {
                guard let currentState = liveActivityClient.currentState() else {
                  await send(.internal(.etaUpdateFailed))
                  return
                }

                let updatedState = currentState.updating(
                  participantId: etaUpdate.userId,
                  estimatedArrivalMinutes: etaUpdate.estimatedMinutes
                )

                try await liveActivityClient.update(activityId, updatedState)
                await send(.internal(.etaUpdateSent))
              } catch {
                await send(.internal(.etaUpdateFailed))
              }
            }

          case .etaUpdateSent:
            // ETA 업데이트 성공
            state.$data.withLock { $0.isProcessingETAUpdate = false }
            state.pendingETAUpdate = nil

            // 상태 새로고침
            return .send(.view(.refreshFromLiveActivity))

          case .etaUpdateFailed:
            // ETA 업데이트 실패
            state.$data.withLock { $0.isProcessingETAUpdate = false }
            state.pendingETAUpdate = nil
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Private Helpers

    private func handleETAUpdate(state: inout State, minutes: Int) -> Effect<Action> {
      guard !state.data.isProcessingETAUpdate else {
        return .none
      }

      let etaUpdate = ETAUpdate(
        promiseId: "", // LiveActivity에서 관리
        userId: state.data.currentUserId,
        estimatedMinutes: minutes,
        timestamp: Date()
      )

      state.pendingETAUpdate = etaUpdate
      state.$data.withLock { $0.isProcessingETAUpdate = true }

      return .send(.internal(.processPendingETAUpdate(etaUpdate)))
    }
  }
}
