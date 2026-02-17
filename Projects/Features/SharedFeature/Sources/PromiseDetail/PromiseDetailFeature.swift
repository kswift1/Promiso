import ComposableArchitecture
import Clients
import PromisoShared

public enum PromiseDetail {}

extension PromiseDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.mapClient) var mapClient
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.weatherClient) var weatherClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var promise: PromiseModel
      let currentUserId: String
      var respondingState: RespondingState = .idle
      var isDeleting: Bool = false
      var showShareSheet: Bool = false

      // 그룹 멤버 정보 (참여자 이름 표시용)
      var groupMembers: [UserPublicModel]?
      var isLoadingMembers: Bool = false

      // 날씨 정보
      var weatherInfo: WeatherInfo?

      /// 날씨 캐시 (전역 공유)
      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

      /// 그룹 멤버 캐시 (전역 공유)
      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      var groupMembersCache: [String: [UserPublicModel]] = [:]

      /// 그룹 캘린더 동기화 설정 캐시 (전역 공유)
      @Shared(.inMemory(AppConstants.SharedState.groupCalendarSyncCache))
      var groupCalendarSyncCache: [String: Bool] = [:]

      // 멤버 시트 상태
      var memberSheet: MemberSheetState?

      // 지도 상세 시트 상태
      var showMapDetail: Bool = false

      // 수정 시트 상태
      @Presents var editPromise: EditPromise.Feature.State?

      // 삭제 확인 알럿
      @Presents var alert: AlertState<Action.Alert>?

      var toastMessage: ToastMessage?

      public init(
        promise: PromiseModel,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.promise = promise
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }

      /// 약속 호스트 여부
      var isHost: Bool {
        promise.isHost(userId: currentUserId)
      }

      /// 그룹 호스트 여부
      var isGroupHost: Bool {
        promise.group?.createdBy == currentUserId
      }

      /// 관리 권한 여부 (약속 호스트 또는 그룹 호스트)
      var canManage: Bool {
        isHost || isGroupHost
      }

      var myVoteStatus: VoteStatus {
        promise.myVoteStatus(userId: currentUserId)
      }

      var responseStatus: PromiseResponseStatus {
        promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count)
      }

      /// 수정 가능 여부 (관리 권한 && 시작 전)
      var canEdit: Bool {
        canManage && promise.startAt > Date()
      }

    }

    enum RespondingState: Equatable {
      case idle, accepting, rejecting, resetting
    }

    public struct MemberSheetState: Equatable, Identifiable {
      public var id: String { title }
      let title: String
      let members: [UserPublicModel]
      let colorType: ParticipantColorType
    }

    public enum ParticipantColorType: Sendable, Equatable {
      case accepted   // green
      case declined   // red
      case pending    // gray
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)
      case editPromise(PresentationAction<EditPromise.Feature.Action>)
      case alert(PresentationAction<Alert>)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case dismissTapped
        case acceptTapped
        case rejectTapped
        case resetTapped
        case deleteTapped
        case editTapped
        case shareTapped
        case shareSheetDismissed
        case participantGroupTapped(title: String, userIds: [String], colorType: ParticipantColorType)
        case memberSheetDismissed
        case directionsTapped
        case mapTapped
        case mapDetailDismissed
        case toastDismissed
      }

      @CasePathable
      public enum Alert: Sendable {
        case confirmDelete
      }

      @CasePathable
      public enum Internal: Sendable {
        case respondPromise(status: PromiseAttendanceStatus)
        case respondDone(status: PromiseAttendanceStatus)
        case respondFailed(error: AppError)
        case deletePromise
        case deleteDone
        case deleteFailed(error: AppError)
        case promiseUpdated(PromiseModel)
        case fetchGroupMembers
        case groupMembersFetched(Result<[UserPublicModel], Error>)
        case fetchRealPromise
        case realPromiseFetched(Result<PromiseModel, Error>)
        case fetchWeather
        case weatherFetched(Result<WeatherInfo, Error>)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case dismiss
        case promiseDeleted(id: String)
        case promiseUpdated(PromiseModel)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 날씨 캐시 확인
            if let cached = state.weatherCache[state.promise.id] {
              state.weatherInfo = cached
            }

            let needsWeatherFetch = state.weatherInfo == nil
              || isWeatherStale(state.weatherInfo)

            // 그룹 멤버 캐시 확인 → 없으면 로드
            if state.groupMembers == nil {
              // 캐시에서 먼저 확인
              if let cached = state.groupMembersCache[state.promise.groupId] {
                state.groupMembers = cached
                if needsWeatherFetch {
                  return .send(.internal(.fetchWeather))
                }
                return .none
              }
              // 캐시 miss → 서버에서 로드 + 날씨
              state.isLoadingMembers = true
              return .merge(
                .send(.internal(.fetchGroupMembers)),
                needsWeatherFetch ? .send(.internal(.fetchWeather)) : .none
              )
            }
            if needsWeatherFetch {
              return .send(.internal(.fetchWeather))
            }
            return .none

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .acceptTapped:
            guard state.respondingState == .idle else { return .none }
            state.respondingState = .accepting
            return .send(.internal(.respondPromise(status: .accepted)))

          case .rejectTapped:
            guard state.respondingState == .idle else { return .none }
            state.respondingState = .rejecting
            return .send(.internal(.respondPromise(status: .declined)))

          case .resetTapped:
            guard state.respondingState == .idle else { return .none }
            state.respondingState = .resetting
            return .send(.internal(.respondPromise(status: .pending)))

          case .deleteTapped:
            guard !state.isDeleting else { return .none }
            let promiseTitle = state.promise.title
            state.alert = AlertState {
              TextState("약속 삭제")
            } actions: {
              ButtonState(role: .cancel) {
                TextState("취소")
              }
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("삭제")
              }
            } message: {
              TextState("'\(promiseTitle)' 약속을 삭제하시겠습니까?\n삭제된 약속은 복구할 수 없습니다.")
            }
            return .none

          case .editTapped:
            guard state.canEdit else { return .none }
            let maxMembers = state.groupMembers?.count ?? state.promise.minimumParticipants
            state.editPromise = EditPromise.Feature.State(
              promise: state.promise,
              maxMembers: maxMembers
            )
            return .none

          case .shareTapped:
            state.showShareSheet = true
            return .none

          case .shareSheetDismissed:
            state.showShareSheet = false
            return .none

          case let .participantGroupTapped(title, userIds, colorType):
            guard let members = state.groupMembers else { return .none }
            let resolvedMembers = userIds.compactMap { userId in
              members.first { $0.userId == userId }
            }
            state.memberSheet = MemberSheetState(
              title: title,
              members: resolvedMembers,
              colorType: colorType
            )
            return .none

          case .memberSheetDismissed:
            state.memberSheet = nil
            return .none

          case .directionsTapped:
            guard let location = state.promise.location,
                  let lat = location.latitude,
                  let lng = location.longitude else {
              return .none
            }
            let coordinate = Coordinate(latitude: lat, longitude: lng)
            mapClient.openDirections(coordinate, location.name)
            return .none

          case .mapTapped:
            guard state.promise.location?.latitude != nil,
                  state.promise.location?.longitude != nil else {
              return .none
            }
            state.showMapDetail = true
            return .none

          case .mapDetailDismissed:
            state.showMapDetail = false
            return .none

          case .toastDismissed:
            state.toastMessage = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .respondPromise(let status):
            let promiseId = state.promise.id
            let groupId = state.promise.groupId
            let calendarSyncCache = state.groupCalendarSyncCache
            return .run { [promiseClient, calendarSyncClient] send in
              do {
                let result = try await promiseClient.respondPromise(promiseId, status)
                await send(.internal(.respondDone(status: status)))

                // 캘린더 동기화: 수락 + 확정 시 추가
                if status == .accepted,
                   result.isConfirmed,
                   let confirmedPromise = result.confirmedPromise {
                  let groupCalendarSync = calendarSyncCache[confirmedPromise.groupId] ?? true
                  try? await calendarSyncClient.addPromise(confirmedPromise, groupCalendarSync)
                }

                // 캘린더 동기화: 거절 시 제거
                if status == .declined {
                  try? await calendarSyncClient.removePromise(promiseId)
                }
              } catch {
                await send(.internal(.respondFailed(error: AppError(error))))
              }
            }

          case .respondDone(let status):
            state.respondingState = .idle

            // Analytics 이벤트 로깅
            switch status {
            case .accepted:
              analyticsClient.logEvent(
                AnalyticsClient.EventName.promiseResponseYes,
                [
                  AnalyticsClient.ParameterKey.promiseID: state.promise.id,
                  AnalyticsClient.ParameterKey.promiseTitle: state.promise.title
                ]
              )
            case .declined:
              analyticsClient.logEvent(
                AnalyticsClient.EventName.promiseResponseNo,
                [
                  AnalyticsClient.ParameterKey.promiseID: state.promise.id,
                  AnalyticsClient.ParameterKey.promiseTitle: state.promise.title
                ]
              )
            case .pending:
              break // 응답 취소는 이벤트 없음
            }

            // 로컬 상태 업데이트 (immutable이므로 새로 생성)
            var newAccepted = state.promise.votes.accepted.filter { $0 != state.currentUserId }
            var newDeclined = state.promise.votes.declined.filter { $0 != state.currentUserId }

            switch status {
            case .accepted:
              newAccepted.append(state.currentUserId)
            case .declined:
              newDeclined.append(state.currentUserId)
            case .pending:
              break // 둘 다 제거된 상태 유지
            }

            state.promise.votes = PromiseVotesModel(
              accepted: newAccepted,
              declined: newDeclined,
              until: state.promise.votes.until
            )

            return .send(.delegate(.promiseUpdated(state.promise)))

          case .respondFailed(let error):
            state.respondingState = .idle
            state.toastMessage = ToastMessage(
              type: .error,
              title: "응답 전송에 실패했어요",
              subtitle: error.message,
              position: .top
            )
            return .none

          case .deletePromise:
            let promiseId = state.promise.id
            return .run { [promiseClient] send in
              do {
                try await promiseClient.deletePromise(promiseId)
                await send(.internal(.deleteDone))
              } catch {
                await send(.internal(.deleteFailed(error: AppError(error))))
              }
            }

          case .deleteDone:
            state.isDeleting = false
            return .send(.delegate(.promiseDeleted(id: state.promise.id)))

          case .deleteFailed(let error):
            state.isDeleting = false
            state.toastMessage = ToastMessage(
              type: .error,
              title: "약속 삭제에 실패했어요",
              subtitle: error.message,
              position: .top
            )
            return .none

          case .promiseUpdated(let promise):
            state.promise = promise
            return .none

          case .fetchGroupMembers:
            let groupId = state.promise.groupId
            return .run { [groupClient] send in
              do {
                let members = try await groupClient.fetchGroupMembers(groupId)
                await send(.internal(.groupMembersFetched(.success(members))))
              } catch {
                await send(.internal(.groupMembersFetched(.failure(error))))
              }
            }

          case .groupMembersFetched(let result):
            state.isLoadingMembers = false
            switch result {
            case .success(let members):
              state.groupMembers = members
              // 캐시에도 저장
              state.$groupMembersCache.withLock { $0[state.promise.groupId] = members }
            case .failure:
              break // 실패해도 UI는 진행
            }
            return .none

          case .fetchRealPromise:
            let promiseId = state.promise.id
            return .run { [promiseClient] send in
              do {
                if let promise = try await promiseClient.getPromise(promiseId) {
                  await send(.internal(.realPromiseFetched(.success(promise))))
                }
                // nil이면 무시 (기존 데이터 유지)
              } catch {
                await send(.internal(.realPromiseFetched(.failure(error))))
              }
            }

          case .realPromiseFetched(let result):
            switch result {
            case .success(let promise):
              state.promise = promise
            case .failure:
              break // 실패해도 기존 데이터 유지
            }
            return .none

          case .fetchWeather:
            guard let lat = state.promise.location?.latitude,
                  let lng = state.promise.location?.longitude,
                  !state.promise.isPast else {
              return .none
            }
            // 예보 범위(10일) 밖이면 조회 안 함
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)
            guard state.promise.startAt < maxDate else { return .none }

            let date = state.promise.startAt
            return .run { [weatherClient] send in
              do {
                let info = try await weatherClient.getWeather(lat, lng, date)
                await send(.internal(.weatherFetched(.success(info))))
              } catch {
                await send(.internal(.weatherFetched(.failure(error))))
              }
            }

          case .weatherFetched(let result):
            if case .success(let info) = result {
              state.weatherInfo = info
              state.$weatherCache.withLock { $0[state.promise.id] = info }
            }
            return .none
          }

        case .delegate:
          return .none

        case .editPromise(.presented(.delegate(.cancelled))):
          state.editPromise = nil
          return .none

        case .editPromise(.presented(.delegate(.promiseUpdated(let promise)))):
          state.editPromise = nil
          state.promise = promise
          return .send(.delegate(.promiseUpdated(promise)))

        case .editPromise:
          return .none

        case .alert(.presented(.confirmDelete)):
          state.isDeleting = true
          return .send(.internal(.deletePromise))

        case .alert:
          return .none
        }
      }
      .ifLet(\.$editPromise, action: \.editPromise) {
        EditPromise.Feature()
      }
      .ifLet(\.$alert, action: \.alert)
    }

    private func isWeatherStale(_ info: WeatherInfo?) -> Bool {
      guard let info else { return true }
      return Date().timeIntervalSince(info.fetchedAt) > 6 * 3600
    }
  }
}
