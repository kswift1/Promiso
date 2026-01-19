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

// MARK: - Detail Feature

extension LivePromise {
  @Reducer
  public struct Detail {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 약속 이모지
      public var emoji: String
      /// 약속 제목
      public var title: String
      /// 약속 장소명
      public var location: String?
      /// 약속 시간
      public var scheduledTime: Date?
      /// 참가자 목록
      public var participants: [ParticipantState]
      /// 현재 사용자 ID
      public var currentUserId: String
      /// LiveActivity 추적 시간 (분)
      public var trackingDurationMinutes: Int
      /// ETA 업데이트 처리 중
      public var isProcessingETAUpdate: Bool

      public init(
        emoji: String,
        title: String,
        location: String?,
        scheduledTime: Date?,
        participants: [ParticipantState],
        currentUserId: String,
        trackingDurationMinutes: Int,
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

      /// 현재 사용자의 ETA
      public var currentUserETA: Int? {
        participants.first { $0.id == currentUserId }?.estimatedArrivalMinutes
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case dismiss
      case etaButtonTapped(Int)
    }

    public var body: some ReducerOf<Self> {
      Reduce { _, action in
        switch action {
        case .dismiss:
          return .none

        case .etaButtonTapped:
          // 부모에서 처리
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
      // MARK: - LiveActivity Data

      /// 약속 이모지
      public var emoji: String = "📍"

      /// 약속 제목
      public var title: String = ""

      /// 약속 장소명
      public var location: String?

      /// 약속 시간
      public var scheduledTime: Date?

      /// 참가자 목록
      public var participants: [ParticipantState] = []

      /// 현재 사용자 ID
      public var currentUserId: String = ""

      /// LiveActivity 추적 시간 (분)
      public var trackingDurationMinutes: Int = 30

      /// 대기 중인 ETA 업데이트
      var pendingETAUpdate: ETAUpdate?

      /// ETA 업데이트 처리 중
      var isProcessingETAUpdate: Bool = false

      // MARK: - Initializer

      public init(
        emoji: String = "📍",
        title: String = "",
        location: String? = nil,
        scheduledTime: Date? = nil,
        participants: [ParticipantState] = [],
        currentUserId: String = ""
      ) {
        self.emoji = emoji
        self.title = title
        self.location = location
        self.scheduledTime = scheduledTime
        self.participants = participants
        self.currentUserId = currentUserId
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
            if let attributes = attributes {
              state.emoji = attributes.emoji
              state.title = attributes.title
              state.location = attributes.location
              state.scheduledTime = attributes.scheduledTime
              state.trackingDurationMinutes = attributes.trackingDurationMinutes
            }

            if let contentState = contentState {
              state.participants = contentState.participants
              state.trackingDurationMinutes = contentState.trackingDurationMinutes
            }

            return .none

          case .processPendingETAUpdate(let etaUpdate):
            // ETA 업데이트 처리
            guard let activityId = liveActivityClient.activeActivityId() else {
              state.isProcessingETAUpdate = false
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
            state.isProcessingETAUpdate = false
            state.pendingETAUpdate = nil

            // 상태 새로고침
            return .send(.view(.refreshFromLiveActivity))

          case .etaUpdateFailed:
            // ETA 업데이트 실패
            state.isProcessingETAUpdate = false
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
      guard !state.isProcessingETAUpdate else {
        return .none
      }

      let etaUpdate = ETAUpdate(
        promiseId: "", // LiveActivity에서 관리
        userId: state.currentUserId,
        estimatedMinutes: minutes,
        timestamp: Date()
      )

      state.pendingETAUpdate = etaUpdate
      state.isProcessingETAUpdate = true

      return .send(.internal(.processPendingETAUpdate(etaUpdate)))
    }
  }
}
