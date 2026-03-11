//
//  LiveScheduleFeature.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ExternalDependency
import Clients
import PromisoShared

/// 일정 추적 (LiveActivity 기반 앱 내 뷰)
/// - CompactView: 하단 고정 바
/// - ExpandedView: 전체 화면
public enum LiveSchedule {}

// MARK: - Shared Data

extension LiveSchedule {
  /// Feature와 Detail이 공유하는 일정 데이터
  public struct Data: Equatable, Sendable {
    // FIXME: 추후 모델로 묶자
    public var emoji: String
    public var title: String
    public var location: String?
    public var latitude: Double?
    public var longitude: Double?
    public var scheduledTime: Date?
    public var participants: [ParticipantState]
    public var currentUserId: String
    public var trackingDurationMinutes: Int
    public var isProcessingETAUpdate: Bool
    public var hostId: String
    public var hostName: String?
    public var groupName: String?
    public var groupImageUrl: String?

    public init(
      emoji: String = "📍",
      title: String = "",
      location: String? = nil,
      latitude: Double? = nil,
      longitude: Double? = nil,
      scheduledTime: Date? = nil,
      participants: [ParticipantState] = [],
      currentUserId: String = "",
      trackingDurationMinutes: Int = 30,
      isProcessingETAUpdate: Bool = false,
      hostId: String = "",
      hostName: String? = nil,
      groupName: String? = nil,
      groupImageUrl: String? = nil
    ) {
      self.emoji = emoji
      self.title = title
      self.location = location
      self.latitude = latitude
      self.longitude = longitude
      self.scheduledTime = scheduledTime
      self.participants = participants
      self.currentUserId = currentUserId
      self.trackingDurationMinutes = trackingDurationMinutes
      self.isProcessingETAUpdate = isProcessingETAUpdate
      self.hostId = hostId
      self.hostName = hostName
      self.groupName = groupName
      self.groupImageUrl = groupImageUrl
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

    /// 좌표 정보가 있는지 확인
    public var hasCoordinates: Bool {
      latitude != nil && longitude != nil
    }
  }
}

private extension LiveActivityClientError {
  var userMessage: String {
    switch self {
    case .notSupported:
      return LocalizedStrings.LiveSchedule.errorNotSupported
    case .activityNotFound:
      return LocalizedStrings.LiveSchedule.errorActivityNotFound
    case .startFailed:
      return LocalizedStrings.LiveSchedule.errorStartFailed
    case .updateFailed:
      return LocalizedStrings.LiveSchedule.errorUpdateFailed
    }
  }
}

// MARK: - Detail Feature

extension LiveSchedule {
  /// 상세 화면 탭 종류
  public enum DetailTab: String, CaseIterable, Equatable, Sendable {
    case status = "status"
    case map = "map"
    case chat = "chat"

    var displayTitle: String {
      switch self {
      case .status: return LocalizedStrings.LiveSchedule.tabStatus
      case .map: return LocalizedStrings.LiveSchedule.tabMap
      case .chat: return LocalizedStrings.LiveSchedule.tabChat
      }
    }
  }

  /// 일정 추적 상세 화면 Reducer
  /// ExpandedView에서 사용되며, 탭 전환 및 액션 버튼 처리
  @Reducer
  public struct Detail {
    @Dependency(\.hapticFeedback) private var hapticFeedback
    @Dependency(\.mapClient) private var mapClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 공유 데이터 (Feature와 동기화)
      @Shared public var data: LiveSchedule.Data

      /// 일정 모델 (ScheduleCard와 동일한 헤더 표시용)
      public var schedule: ScheduleModel?

      /// 현재 사용자 ID
      public var currentUserId: String

      /// 그룹 멤버 정보 (호스트 표시용)
      public var groupMembers: [UserPublicModel]?

      /// 현재 선택된 탭
      public var selectedTab: DetailTab = .status

      /// 직접 입력 분 값
      public var customMinuteInput: String = ""

      /// 상태 변경 시트 표시 여부
      public var isETASheetPresented: Bool = false

      public init(
        data: Shared<LiveSchedule.Data>,
        schedule: ScheduleModel? = nil,
        currentUserId: String = "",
        groupMembers: [UserPublicModel]? = nil
      ) {
        self._data = data
        self.schedule = schedule
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case delegate(Delegate)

      @CasePathable
      public enum View: Equatable, Sendable {
        /// 탭 선택
        case tabSelected(DetailTab)
        /// ETA 버튼 탭
        case etaButtonTapped(Int)
        /// 직접 입력 값 변경
        case customMinuteInputChanged(String)
        /// 직접 입력 제출
        case submitCustomMinute
        /// 복사 버튼 탭
        case copyButtonTapped
        /// 알림 버튼 탭
        case notificationButtonTapped
        /// 더보기 버튼 탭
        case moreButtonTapped
        /// 상태 변경 시트 표시
        case showETASheet
        /// 상태 변경 시트 닫기
        case hideETASheet
        /// 길찾기 버튼 탭
        case directionsTapped
      }

      @CasePathable
      public enum Delegate: Equatable, Sendable {
        /// ETA 업데이트 요청 (부모에서 처리)
        case updateETA(Int)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .tabSelected(let tab):
            state.selectedTab = tab
            return .run { _ in
              await hapticFeedback.light()
            }

          case .etaButtonTapped(let minutes):
            state.customMinuteInput = ""
            state.isETASheetPresented = false
            return .run { send in
              await hapticFeedback.medium()
              await send(.delegate(.updateETA(minutes)))
            }

          case .customMinuteInputChanged(let value):
            // 숫자만 허용
            state.customMinuteInput = value.filter { $0.isNumber }
            return .none

          case .submitCustomMinute:
            guard let minutes = Int(state.customMinuteInput), minutes > 0 else {
              return .run { _ in
                await hapticFeedback.error()
              }
            }
            state.customMinuteInput = ""
            state.isETASheetPresented = false
            return .run { send in
              await hapticFeedback.medium()
              await send(.delegate(.updateETA(minutes)))
            }

          case .copyButtonTapped:
            // TODO: 복사 기능 구현
            return .run { _ in
              await hapticFeedback.light()
            }

          case .notificationButtonTapped:
            // TODO: 알림 기능 구현
            return .run { _ in
              await hapticFeedback.light()
            }

          case .moreButtonTapped:
            // TODO: 더보기 기능 구현
            return .run { _ in
              await hapticFeedback.light()
            }

          case .showETASheet:
            state.isETASheetPresented = true
            return .run { _ in
              await hapticFeedback.light()
            }

          case .hideETASheet:
            state.isETASheetPresented = false
            return .none

          case .directionsTapped:
            guard let latitude = state.data.latitude,
                  let longitude = state.data.longitude else {
              return .none
            }
            let coordinate = Coordinate(latitude: latitude, longitude: longitude)
            mapClient.openDirections(nil, coordinate, state.data.location, .car)
            return .run { _ in
              await hapticFeedback.light()
            }
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}

extension LiveSchedule {
  @Reducer
  public struct Feature {
    @Dependency(\.liveActivityClient) var liveActivityClient
    @Dependency(\.scheduleClient) var scheduleClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      /// 공유 데이터 (Detail과 동기화)
      @Shared public var data: LiveSchedule.Data

      /// 대기 중인 ETA 업데이트 (Feature 전용)
      var pendingETAUpdate: ETAUpdate?

      // MARK: - Initializer

      public init(data: Shared<LiveSchedule.Data>) {
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
        self._data = Shared(value: LiveSchedule.Data(
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

      @CasePathable
      public enum Internal: Equatable, Sendable {
        case liveActivityStateUpdated(ScheduleActivityAttributes?, ScheduleActivityAttributes.ContentState?)
        case processPendingETAUpdate(ETAUpdate)
        case etaUpdateSent
        case etaUpdateFailed
        /// ContentState 스트림 구독 시작
        case observeContentStateUpdates
        /// ContentState 스트림에서 새 상태 수신
        case contentStateUpdated(ScheduleActivityAttributes.ContentState)
        // Push Token 관련 액션 제거됨 - iOS 18 Broadcast 방식 사용
      }

      @CasePathable
      public enum Delegate: Equatable, Sendable {
        /// CompactView 탭 → 상세 뷰 표시 요청
        case showDetail
        case navigateToScheduleDetail(scheduleId: String)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 현재 활성화된 LiveActivity 상태 동기화 및 스트림 구독 시작
            // iOS 18 Broadcast 방식으로 전환되어 Push Token 구독 제거됨
            return .merge(
              .send(.view(.refreshFromLiveActivity)),
              .send(.internal(.observeContentStateUpdates))
            )

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
                data.latitude = attributes.latitude
                data.longitude = attributes.longitude
                data.scheduledTime = attributes.scheduledTime
                data.trackingDurationMinutes = attributes.trackingDurationMinutes
                data.hostId = attributes.hostId
                data.hostName = attributes.hostName
                data.currentUserId = attributes.currentUserId
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
              } catch let clientError as LiveActivityClientError {
                AppLogger.liveActivity.error("ETA 업데이트 실패: \(clientError.userMessage)")
                await send(.internal(.etaUpdateFailed))
              } catch {
                AppLogger.liveActivity.error("ETA 업데이트 실패: \(error.localizedDescription)")
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

          case .observeContentStateUpdates:
            // APNs 업데이트 시 ContentState 스트림 구독
            guard let scheduleId = liveActivityClient.activeScheduleId(),
                  let stream = liveActivityClient.observeStateUpdates(scheduleId) else {
              return .none
            }

            return .run { send in
              for await contentState in stream {
                await send(.internal(.contentStateUpdated(contentState)))
              }
            }

          case .contentStateUpdated(let contentState):
            // APNs로 업데이트된 ContentState 동기화
            state.$data.withLock { data in
              data.participants = contentState.participants
              data.trackingDurationMinutes = contentState.trackingDurationMinutes
            }
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
        scheduleId: "", // LiveActivity에서 관리
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
