import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Feature Namespace

public enum OverlayScheduleDetail {}

// MARK: - Feature Implementation

extension OverlayScheduleDetail {
  @Reducer
  public struct Feature {
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.weatherClient) var weatherClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.mapClient) var mapClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      var item: HomeModels.ScheduleItem
      let currentUserId: String
      var groupMembers: [UserPublicModel]?
      var weatherInfo: WeatherInfo?
      var respondingState: RespondingState = .idle
      var toastMessage: ToastMessage?

      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      var groupMembersCache: [String: [UserPublicModel]] = [:]

      public init(
        item: HomeModels.ScheduleItem,
        currentUserId: String,
        groupMembers: [UserPublicModel]? = nil
      ) {
        self.item = item
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
      }
    }

    // MARK: - Supporting Types

    enum RespondingState: Equatable {
      case idle, accepting, rejecting, resetting
    }

    enum TimeContext: Equatable {
      case todayUpcoming
      case inProgress
      case upcoming(dDay: Int)
      case past
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case backTapped
        case acceptTapped
        case rejectTapped
        case resetTapped
        case openFullDetailTapped
        case directionsTapped
        case toastDismissed
      }

      @CasePathable
      public enum InternalAction: Sendable {
        case respondPromise(status: PromiseAttendanceStatus)
        case respondDone(status: PromiseAttendanceStatus)
        case respondFailed(error: AppError)
        case fetchWeather
        case weatherFetched(Result<WeatherInfo, Error>)
      }

      @CasePathable
      public enum DelegateAction: Sendable {
        case openFullDetail(HomeModels.ScheduleItem)
        case promiseResponseUpdated(PromiseModel)
        case dismiss
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: View Actions

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            let cacheKey = state.item.id
            if let cached = state.weatherCache[cacheKey] {
              state.weatherInfo = cached
            }
            let needsWeatherFetch = isWeatherStale(state.weatherInfo)
            let hasLocation = state.item.location != nil
            if needsWeatherFetch && hasLocation {
              return .send(.internal(.fetchWeather))
            }
            return .none

          case .backTapped:
            return .send(.delegate(.dismiss))

          case .acceptTapped:
            guard state.respondingState == .idle, state.promise != nil else { return .none }
            state.respondingState = .accepting
            return .send(.internal(.respondPromise(status: .accepted)))

          case .rejectTapped:
            guard state.respondingState == .idle, state.promise != nil else { return .none }
            state.respondingState = .rejecting
            return .send(.internal(.respondPromise(status: .declined)))

          case .resetTapped:
            guard state.respondingState == .idle, state.promise != nil else { return .none }
            state.respondingState = .resetting
            return .send(.internal(.respondPromise(status: .pending)))

          case .openFullDetailTapped:
            return .send(.delegate(.openFullDetail(state.item)))

          case .directionsTapped:
            guard
              let location = state.item.location,
              let lat = location.latitude,
              let lng = location.longitude
            else { return .none }
            mapClient.openDirections(
              Coordinate(latitude: lat, longitude: lng),
              location.name
            )
            return .none

          case .toastDismissed:
            state.toastMessage = nil
            return .none
          }

        // MARK: Internal Actions

        case .internal(let internalAction):
          switch internalAction {
          case .respondPromise(let status):
            guard let promise = state.promise else { return .none }
            let promiseId = promise.id
            return .run { [promiseClient, calendarSyncClient] send in
              do {
                let result = try await promiseClient.respondPromise(promiseId, status)
                await send(.internal(.respondDone(status: status)))

                // 캘린더 동기화: 수락 + 확정 시 추가
                if status == .accepted,
                   result.isConfirmed,
                   let confirmedPromise = result.confirmedPromise {
                  try? await calendarSyncClient.addPromise(confirmedPromise, true)
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
            guard var promise = state.promise else { return .none }

            var newAccepted = promise.votes.accepted.filter { $0 != state.currentUserId }
            var newDeclined = promise.votes.declined.filter { $0 != state.currentUserId }

            switch status {
            case .accepted:
              newAccepted.append(state.currentUserId)
            case .declined:
              newDeclined.append(state.currentUserId)
            case .pending:
              break
            }

            promise.votes = PromiseVotesModel(
              accepted: newAccepted,
              declined: newDeclined,
              until: promise.votes.until
            )
            state.item = .promise(promise)
            return .send(.delegate(.promiseResponseUpdated(promise)))

          case .respondFailed(let error):
            state.respondingState = .idle
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.OverlayScheduleDetail.respondFailed,
              subtitle: error.message,
              position: .top
            )
            return .none

          case .fetchWeather:
            guard
              let location = state.item.location,
              let lat = location.latitude,
              let lng = location.longitude
            else { return .none }

            let startAt = state.item.startAt
            // 과거 일정은 날씨 조회 안 함
            guard startAt > Date() else { return .none }
            // 예보 범위(10일) 밖이면 조회 안 함
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)
            guard startAt < maxDate else { return .none }

            return .run { [weatherClient] send in
              do {
                let info = try await weatherClient.getWeather(lat, lng, startAt)
                await send(.internal(.weatherFetched(.success(info))))
              } catch {
                await send(.internal(.weatherFetched(.failure(error))))
              }
            }

          case .weatherFetched(let result):
            if case .success(let info) = result {
              state.weatherInfo = info
              let cacheKey = state.item.id
              state.$weatherCache.withLock { $0[cacheKey] = info }
            }
            return .none
          }

        // MARK: Delegate Actions

        case .delegate:
          return .none
        }
      }
    }

    // MARK: - Private Helpers

    private static let weatherStalenessInterval: TimeInterval = 6 * 3600

    private func isWeatherStale(_ info: WeatherInfo?) -> Bool {
      guard let info else { return true }
      return Date().timeIntervalSince(info.fetchedAt) > Self.weatherStalenessInterval
    }
  }
}

// MARK: - Computed Properties

extension OverlayScheduleDetail.Feature.State {
  var promise: PromiseModel? {
    if case .promise(let p) = item { return p } else { return nil }
  }

  var personalEvent: PersonalEventModel? {
    if case .personalEvent(let e) = item { return e } else { return nil }
  }

  var isPromise: Bool { promise != nil }

  var timeContext: OverlayScheduleDetail.Feature.TimeContext {
    let now = Date()
    let calendar = Calendar.current
    let startAt = item.startAt
    let effectiveEndAt = item.effectiveEndAt

    if now > effectiveEndAt { return .past }
    if startAt <= now && now <= effectiveEndAt { return .inProgress }

    let todayStart = calendar.startOfDay(for: now)
    let startDayStart = calendar.startOfDay(for: startAt)
    let dDay = calendar.dateComponents([.day], from: todayStart, to: startDayStart).day ?? 0

    if dDay == 0 { return .todayUpcoming }
    return .upcoming(dDay: dDay)
  }

  var countdownText: String {
    let interval = item.startAt.timeIntervalSince(Date())
    guard interval > 0 else { return "" }
    let hours = Int(interval / 3600)
    let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
    if hours > 0 { return "\(hours)시간 \(minutes)분" }
    return "\(minutes)분"
  }

  var myVoteStatus: PromiseAttendanceStatus {
    guard let promise else { return .pending }
    switch promise.myVoteStatus(userId: currentUserId) {
    case .accepted: return .accepted
    case .declined: return .declined
    case .pending: return .pending
    }
  }

  var acceptedCount: Int { promise?.votes.accepted.count ?? 0 }
  var declinedCount: Int { promise?.votes.declined.count ?? 0 }

  var totalMemberCount: Int { groupMembers?.count ?? promise?.minimumParticipants ?? 0 }

  var confirmationProgress: String {
    guard let promise else { return "" }
    let needed = promise.minimumParticipants - acceptedCount
    if needed <= 0 { return LocalizedStrings.OverlayScheduleDetail.confirmed }
    return LocalizedStrings.OverlayScheduleDetail.confirmationRemaining(needed)
  }

  var responseStatus: PromiseResponseStatus {
    promise?.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count) ?? .needResponse
  }
}
