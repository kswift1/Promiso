//
//  CreateGroupFeature.swift
//  GroupFeature
//
//  Created by 김성원 on 9/30/25.
//

import PhotosUI
import _PhotosUI_SwiftUI
import PromisoShared

// TODO: LiveActivity 활성화 선택 화면 추가, 지도 추가
public enum CreatePromise {
  
  
  @Reducer
  public struct Feature {

    @Dependency(\.continuousClock) var clock
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.mapClient) var mapClient
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.scheduleConflictClient) var scheduleConflictClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.weatherClient) var weatherClient


    private enum CancelID: Hashable {
      case emojiSuggestDebounce
      case conflictCheckDebounce
      case weatherFetchDebounce
    }
    
    @ObservableState
    public struct State: Equatable {
      static let maxActivePromisesPerGroup = 10

      var currentStep: CreatePromiseStep = .first
      var promise: PromiseModel = .empty
      var groupListState: LoadingState<[GroupModel]> = .idle
      var groupSummaries: [UserGroupInfo]?
      var groupPromiseCounts: [String: Int] = [:]
      var isCreatingPromise: Bool = false
      var creationError: Clients.PromiseClientError?
      var isEmojiLoading: Bool = false

      // LiveActivity 정보 팝오버 상태
      var showLiveActivityInfo: Bool = false
      var hasSeenLiveActivityInfo: Bool = true  // 기본 true (로드 전까지 팝업 안 띄움)

      // 장소 사용 여부 (토글 상태)
      var useLocation: Bool = false

      // 이미지 첨부
      var localImageData: [Data] = []
      var isUploadingImages: Bool = false

      // 일정 충돌 감지
      var currentUserId: String = ""
      var conflicts: [ScheduleConflict] = []
      var isCheckingConflicts: Bool = false
      var conflictDetectionThreshold: Int = 0
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      // 날씨 힌트 (보너스)
      var weatherState: LoadingState<WeatherInfo> = .idle

      // 장소 선택 sheet
      @Presents var locationPicker: LocationPicker.Feature.State?

      // pre-fill 정보 (퀵 약속에서 전달)
      var prefillInfo: PromiseExtractedInfo?

      public init(
        currentStep: CreatePromiseStep = .first,
        promise: PromiseModel = .empty,
        groupListState: LoadingState<[GroupModel]> = .idle,
        groupSummaries: [UserGroupInfo]? = nil,
        groupPromiseCounts: [String: Int] = [:],
        isCreatingPromise: Bool = false,
        creationError: Clients.PromiseClientError? = nil,
        isEmojiLoading: Bool = false,
        showLiveActivityInfo: Bool = false,
        hasSeenLiveActivityInfo: Bool = true,
        useLocation: Bool = false,
        currentUserId: String = "",
        locationPicker: LocationPicker.Feature.State? = nil,
        prefillInfo: PromiseExtractedInfo? = nil,
        weatherState: LoadingState<WeatherInfo> = .idle
      ) {
        self.currentStep = currentStep
        self.promise = promise
        self.groupListState = groupListState
        self.groupSummaries = groupSummaries
        self.groupPromiseCounts = groupPromiseCounts
        self.isCreatingPromise = isCreatingPromise
        self.creationError = creationError
        self.isEmojiLoading = isEmojiLoading
        self.showLiveActivityInfo = showLiveActivityInfo
        self.hasSeenLiveActivityInfo = hasSeenLiveActivityInfo
        self.useLocation = useLocation
        self.currentUserId = currentUserId
        self.locationPicker = locationPicker
        self.prefillInfo = prefillInfo
        self.weatherState = weatherState
      }

      /// 그룹이 활성 약속 제한에 도달했는지 확인
      func isGroupAtLimit(_ groupId: String) -> Bool {
        guard let count = groupPromiseCounts[groupId] else { return false }
        return count >= Self.maxActivePromisesPerGroup
      }

      var firstButtonDisabled: Bool {
        if !promise.isTitleValid {
          return true
        }

        if promise.group == nil {
          return true
        }

        return false
      }

      var secondButtonDisabled: Bool {
        // 시작 시간이 현재보다 미래인지 확인
        guard promise.isStartTimeValid else { return true }

        // 종료 시간을 사용하는 경우, 시작 시간보다 이후인지 확인
        guard promise.isEndTimeValid else { return true }

        // 최소 참가 인원이 유효한지 확인
        guard promise.isMinimumParticipantsValid else { return true }

        // 장소 사용 토글이 켜져있으면 장소 선택 필수
        if useLocation && promise.location == nil {
          return true
        }

        return false
      }

      var thirdButtonDisabled: Bool {
        isCreatingPromise // 생성 중일 때만 비활성화
      }
    }
    
    public enum Action: Sendable {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)
      case locationPicker(PresentationAction<LocationPicker.Feature.Action>)
      
      // 사용자가 트리거하는 UI 이벤트
      public enum View: Sendable {
        case onAppear
        case nextStep
        case previousStep
        case requestCreatingPromise
        case setTitle(String)
        case groupSelected(GroupModel)
        case setStartDate(Date)
        case setEndDate(Date?)
        case toggleUseEndTime
        case incrementParticipants
        case decrementParticipants
        case setDescription(String)
        case setTrackingStartMinutes(Int?)
        case retryLoadGroups
        case clearCreationError
        case createGroupTapped
        // LiveActivity 정보 팝오버
        case liveActivityInfoButtonTapped
        case liveActivityInfoDismissed
        case arrivalSharingSectionAppeared
        // 장소 선택
        case locationPickerTapped
        case setLocation(LocationInfoModel?)
        case toggleUseLocation
        // 이미지 첨부
        case photosSelected([PhotosPickerItem])
        case removeLocalImage(Int)
      }
      
      // 내부에서만 발생하는 이벤트 (이펙트 응답/디바운스 등)
      public enum Internal: Sendable {
        case titleDebounced(String)
        case emojiGenerationResponse(Result<String, Error>)
        case fetchGroupList
        case groupListResponse(Result<[GroupModel], Error>)
        case fetchPromiseCounts([String])
        case promiseCountsResponse([String: Int])
        case createPromiseResponse(Result<String, Clients.PromiseClientError>)
        case photosLoaded([Data])
        case imageUploadCompleted(Result<[String], Error>)
        case liveActivityInfoSeenLoaded(Bool)
        case conflictsLoaded([ScheduleConflict])
        case settingsLoaded(UserSettings)
        case weatherResponse(Result<WeatherInfo, Error>)
      }
      
      // 상위 전달 이벤트 (네비/라우팅/완료 알림 등)
      public enum Delegate: Sendable {
        case promiseCreated(id: String)
        case dismiss
        case createGroupRequested
      }
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
          
          // MARK: - View
        case .view(let viewAction):
          switch viewAction {
            
          case .onAppear:
            return .merge(
              .send(.internal(.fetchGroupList)),
              .run { [userSettingsClient, state] send in
                guard !state.currentUserId.isEmpty else { return }
                if let settings = try? await userSettingsClient.fetchSettings(state.currentUserId) {
                  await send(.internal(.settingsLoaded(settings)))
                }
              }
            )
            
          case .nextStep:
            state.currentStep.next()
            return .none
            
          case .previousStep:
            state.currentStep.previous()
            return .none
            
          case .requestCreatingPromise:
            state.isCreatingPromise = true
            state.creationError = nil
            // groupId 설정 (hostId는 서버에서 auth.uid로 설정)
            var promiseToCreate = state.promise
            promiseToCreate.groupId = state.promise.group?.id ?? ""
            let localImages = state.localImageData
            state.isUploadingImages = !localImages.isEmpty
            return .run { [promise = promiseToCreate, promiseClient, imageUploadClient] send in
              do {
                let promiseId = try await promiseClient.createPromise(promise)

                // 이미지가 있으면 업로드 후 약속 업데이트
                if !localImages.isEmpty {
                  do {
                    let imageUrls = try await imageUploadClient.uploadImages(localImages, "promise_images/\(promise.groupId)/\(promiseId)")
                    var updatedPromise = promise
                    updatedPromise.id = promiseId
                    updatedPromise.imageUrls = imageUrls
                    try await promiseClient.updatePromise(updatedPromise)
                  } catch {
                    AppLogger.general.error("이미지 업로드 실패: \(error.localizedDescription)")
                    // 이미지 업로드 실패해도 약속 생성은 성공 처리
                  }
                }

                await send(.internal(.createPromiseResponse(.success(promiseId))))
              } catch let e as Clients.PromiseClientError {
                await send(.internal(.createPromiseResponse(.failure(e))))
              } catch {
                await send(.internal(.createPromiseResponse(.failure(.unknown(String(describing: error))))))
              }
            }
            
          case .setTitle(let title):
            state.promise.title = title
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
              state.isEmojiLoading = false
              state.promise.emoji = nil
            }
            return .merge(
              .cancel(id: CancelID.emojiSuggestDebounce),
              .run { [clock, title] send in
                try await clock.sleep(for: .milliseconds(1_000))
                await send(.internal(.titleDebounced(title)))
              }
                .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
            )

          case .groupSelected(let group):
            state.promise.group = group
            if group.maxMembers <= 1 {
              state.promise.minimumParticipants = 1
            } else {
              let defaultMinimum = max(2, Int(ceil(Double(group.maxMembers) / 2.0)))
              state.promise.minimumParticipants = defaultMinimum
            }
            return .none

          case .retryLoadGroups:
            return .send(.internal(.fetchGroupList))

          case .clearCreationError:
            state.creationError = nil
            return .none

          case .setEndDate(let date):
            state.promise.endAt = date
            return checkConflictsEffect(state: &state)

          case .toggleUseEndTime:
            if state.promise.endAt == nil {
              state.promise.endAt = state.promise.startAt.addingTimeInterval(7200)
            } else {
              state.promise.endAt = nil
            }
            return checkConflictsEffect(state: &state)

          case .incrementParticipants:
            guard let max = state.promise.group?.maxMembers else { return .none }
            let current = state.promise.minimumParticipants
            if current < max { state.promise.minimumParticipants = current + 1 }
            return .none

          case .decrementParticipants:
            // P6: 멀티 멤버 그룹에서 최소 참가 인원 하한은 2명 (1명 그룹은 isFixedAtOne UI로 고정)
            let current = state.promise.minimumParticipants
            if current > 2 { state.promise.minimumParticipants = current - 1 }
            return .none

          case .setDescription(let description):
            let trimmed = String(description.prefix(500))
            state.promise.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .setTrackingStartMinutes(let minutes):
            state.promise.trackingStartMinutesBefore = minutes
            return .none

          case .setStartDate(let date):
            state.promise.startAt = date
            if let end = state.promise.endAt, end <= date {
              state.promise.endAt = date.addingTimeInterval(7200)
            }
            return .merge(
              checkConflictsEffect(state: &state),
              fetchWeatherHintEffect(state: &state, debounce: true)
            )

          case .createGroupTapped:
            return .send(.delegate(.createGroupRequested))

          case .liveActivityInfoButtonTapped:
            state.showLiveActivityInfo = true
            return .none

          case .liveActivityInfoDismissed:
            state.showLiveActivityInfo = false
            // 팝오버를 봤으므로 저장
            if !state.hasSeenLiveActivityInfo {
              state.hasSeenLiveActivityInfo = true
              return .run { [userDefaultsClient] _ in
                userDefaultsClient.markLiveActivityInfoSeen()
              }
            }
            return .none

          case .arrivalSharingSectionAppeared:
            // 본 적 있는지 확인
            return .run { [userDefaultsClient] send in
              let hasSeen = userDefaultsClient.hasSeenLiveActivityInfo
              await send(.internal(.liveActivityInfoSeenLoaded(hasSeen)))
            }

          case .locationPickerTapped:
            state.locationPicker = LocationPicker.Feature.State()
            return .none

          case .setLocation(let location):
            state.promise.location = location
            if location == nil {
              state.weatherState = .idle
              return .cancel(id: CancelID.weatherFetchDebounce)
            }
            return .none

          case .toggleUseLocation:
            state.useLocation.toggle()
            if !state.useLocation {
              state.weatherState = .idle
              return .cancel(id: CancelID.weatherFetchDebounce)
            }
            return .none

          case .photosSelected(let items):
            return .run { send in
              var loadedData: [Data] = []
              for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                  loadedData.append(data)
                }
              }
              await send(.internal(.photosLoaded(loadedData)))
            }

          case .removeLocalImage(let index):
            guard index < state.localImageData.count else { return .none }
            state.localImageData.remove(at: index)
            return .none
          }
          
          // MARK: - Internal
        case .internal(let internalAction):
          switch internalAction {
            
          case .titleDebounced(let title):
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
            state.isEmojiLoading = true
            return .run { [emojiClient] send in
              do {
                let emoji = try await emojiClient.generate(title)
                await send(.internal(.emojiGenerationResponse(.success(emoji))))
              } catch {
                await send(.internal(.emojiGenerationResponse(.failure(error))))
              }
            }

          case .emojiGenerationResponse(.success(let emoji)):
            state.promise.emoji = emoji
            state.isEmojiLoading = false
            return .none

          case .emojiGenerationResponse(.failure):
            state.promise.emoji = "📅"
            state.isEmojiLoading = false
            return .none
            
          case .fetchGroupList:
            state.groupListState = .loading
            return .run { [groupClient, groupSummaries = state.groupSummaries] send in
              do {
                let groups: [GroupModel]
                if let groupSummaries, groupSummaries.isEmpty == false {
                  let ids = groupSummaries.map(\.id)
                  groups = try await groupClient.fetchGroupsByIds(ids)
                } else {
                  groups = try await groupClient.fetchGroups()
                }
                await send(.internal(.groupListResponse(.success(groups))))
              } catch {
                await send(.internal(.groupListResponse(.failure(error))))
              }
            }
            
          case .groupListResponse(.success(let groups)):
            state.groupListState = .loaded(groups)
            let groupIds = groups.map(\.id)
            return .send(.internal(.fetchPromiseCounts(groupIds)))
            
          case .groupListResponse(.failure(let error)):
            state.groupListState = .failed(error)
            return .none

          case .fetchPromiseCounts(let groupIds):
            return .run { [promiseClient] send in
              var counts: [String: Int] = [:]
              await withTaskGroup(of: (String, Int?).self) { group in
                for groupId in groupIds {
                  group.addTask {
                    let count = try? await promiseClient.getActivePromiseCount(groupId)
                    return (groupId, count)
                  }
                }
                for await (groupId, count) in group {
                  if let count {
                    counts[groupId] = count
                  }
                }
              }
              await send(.internal(.promiseCountsResponse(counts)))
            }

          case .promiseCountsResponse(let counts):
            state.groupPromiseCounts = counts
            return .none

          case .createPromiseResponse(.success(let id)):
            state.isCreatingPromise = false
            state.isUploadingImages = false
            analyticsClient.logEvent(
              AnalyticsClient.EventName.promiseCreated,
              [
                AnalyticsClient.ParameterKey.promiseID: id,
                AnalyticsClient.ParameterKey.promiseTitle: state.promise.title
              ]
            )
            return .send(.delegate(.promiseCreated(id: id)))

          case .createPromiseResponse(.failure(let e)):
            state.isCreatingPromise = false
            state.isUploadingImages = false
            state.creationError = e
            return .none

          case .liveActivityInfoSeenLoaded(let hasSeen):
            state.hasSeenLiveActivityInfo = hasSeen
            // 처음 보는 사용자에게 자동으로 팝오버 표시
            if !hasSeen {
              state.showLiveActivityInfo = true
            }
            return .none

          case .photosLoaded(let data):
            let remaining = 3 - state.localImageData.count
            let toAdd = Array(data.prefix(remaining))
            state.localImageData.append(contentsOf: toAdd)
            return .none

          case .imageUploadCompleted:
            return .none

          case .conflictsLoaded(let conflicts):
            AppLogger.group.info("[ConflictCheck] 약속 생성 - 충돌 결과 수신: \(conflicts.count)건")
            state.conflicts = conflicts
            state.isCheckingConflicts = false
            return .none

          case .settingsLoaded(let settings):
            state.conflictDetectionThreshold = settings.conflictDetectionThreshold
            return checkConflictsEffect(state: &state)

          case .weatherResponse(.success(let info)):
            state.weatherState = .loaded(info)
            return .none

          case .weatherResponse(.failure):
            state.weatherState = .idle
            return .none
          }
          
          // MARK: - Binding
        case .binding:
          return .none
          
          // MARK: - Delegate (여기선 부모가 처리하므로 기본은 .none)
        case .delegate:
          return .none

          // MARK: - LocationPicker
        case .locationPicker(.presented(.delegate(.locationSelected(let location)))):
          state.locationPicker = nil
          state.promise.location = location
          return fetchWeatherHintEffect(state: &state, debounce: false)

        case .locationPicker(.presented(.delegate(.dismissed))):
          state.locationPicker = nil
          return .none

        case .locationPicker:
          return .none
        }
      }
      .ifLet(\.$locationPicker, action: \.locationPicker) {
        LocationPicker.Feature()
      }
    }

    // MARK: - Weather Hint

    private enum Constants {
      static let weatherForecastMaxDays = 10
      static let weatherFetchDebounceMilliseconds = 500
    }

    private func fetchWeatherHintEffect(state: inout State, debounce: Bool = false) -> Effect<Action> {
      guard state.useLocation,
            let location = state.promise.location,
            let lat = location.latitude,
            let lng = location.longitude else {
        state.weatherState = .idle
        return .cancel(id: CancelID.weatherFetchDebounce)
      }

      let startAt = state.promise.startAt
      let maxForecastDate = Date().addingTimeInterval(TimeInterval(Constants.weatherForecastMaxDays) * 24 * 3600)
      guard startAt > Date(), startAt < maxForecastDate else {
        state.weatherState = .idle
        return .cancel(id: CancelID.weatherFetchDebounce)
      }

      state.weatherState = .loading
      return .run { [weatherClient, clock] send in
        if debounce {
          try await clock.sleep(for: .milliseconds(Constants.weatherFetchDebounceMilliseconds))
        }
        do {
          let info = try await weatherClient.getWeather(lat, lng, startAt)
          await send(.internal(.weatherResponse(.success(info))))
        } catch {
          await send(.internal(.weatherResponse(.failure(error))))
        }
      }
      .cancellable(id: CancelID.weatherFetchDebounce, cancelInFlight: true)
    }

    // MARK: - Schedule Conflict Check

    private func checkConflictsEffect(state: inout State) -> Effect<Action> {
      guard !state.currentUserId.isEmpty else { return .none }
      // Pro 미구독자는 충돌 감지 호출 안함
      guard state.isPro else {
        state.isCheckingConflicts = false
        state.conflicts = []
        return .none
      }
      // 충돌 감지 비활성화 (threshold == -1)
      guard state.conflictDetectionThreshold >= 0 else {
        state.isCheckingConflicts = false
        state.conflicts = []
        return .none
      }

      state.isCheckingConflicts = true

      let userId = state.currentUserId
      let startAt = state.promise.startAt
      let endAt = state.promise.endAt
      let minGapMinutes = state.conflictDetectionThreshold

      return .run { [scheduleConflictClient, clock] send in
        try await clock.sleep(for: .milliseconds(500))
        do {
          let conflicts = try await scheduleConflictClient.checkConflicts(userId, startAt, endAt, [], minGapMinutes)
          await send(.internal(.conflictsLoaded(conflicts)))
        } catch {
          await send(.internal(.conflictsLoaded([])))
        }
      }
      .cancellable(id: CancelID.conflictCheckDebounce, cancelInFlight: true)
    }
  }
}

extension CreatePromise {

  public struct RootView: View {
    private let store: StoreOf<CreatePromise.Feature>

    public init(store: StoreOf<CreatePromise.Feature>) {
      self.store = store
    }

    public var body: some View {
      StepSheetContainer(
        title: LocalizedStrings.CreatePromise.navigationTitle,
        currentStep: store.currentStep.rawValue,
        totalSteps: CreatePromiseStep.allCases.count,
        onDismiss: { store.send(.delegate(.dismiss)) }
      ) {
        store.currentStep.contentView(store: store)
      } floatingContent: {
        floatingBonusView
      } bottomContent: {
        bottomBar
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        LocalizedStrings.Error.promiseCreationFailed,
        isPresented: Binding(
          get: { store.creationError != nil },
          set: { if !$0 { store.send(.view(.clearCreationError)) } }
        )
      ) {
        Button(LocalizedStrings.Common.confirm, role: .cancel) {
          store.send(.view(.clearCreationError))
        }
      } message: {
        if let error = store.creationError {
          Text(error.localizedMessage)
        }
      }
    }

    @ViewBuilder
    private var floatingBonusView: some View {
      if store.currentStep == .second {
        ProBonusFloatingView(
          weatherForecast: weatherForecast,
          rangeForecasts: weatherRangeForecasts,
          forecastSource: weatherForecastSource,
          isLoadingWeather: store.weatherState.isLoading,
          weatherLocationName: store.useLocation ? store.promise.location?.name : nil,
          conflicts: store.conflicts.map {
            ConflictInfo(
              title: $0.title,
              overlapMinutes: $0.overlapMinutes,
              gapMinutes: $0.gapMinutes,
              startAt: $0.startAt,
              endAt: $0.endAt,
              emoji: $0.emoji,
              severity: $0.severity == .confirmed ? .confirmed : .pending
            )
          },
          isCheckingConflicts: store.isCheckingConflicts,
          newEventTitle: store.promise.title,
          newEventEmoji: store.promise.emoji,
          newEventStartAt: store.promise.startAt,
          newEventEndAt: store.promise.endAt
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.weatherState)
      }
    }

    private var weatherForecast: HourlyForecast? {
      guard let info = store.weatherState.value else { return nil }
      return WeatherHintHelper.forecast(from: info, startAt: store.promise.startAt, endAt: store.promise.endAt)
    }

    private var weatherRangeForecasts: [HourlyForecast] {
      guard let info = store.weatherState.value else { return [] }
      return WeatherHintHelper.rangeForecasts(from: info, startAt: store.promise.startAt, endAt: store.promise.endAt)
    }

    private var weatherForecastSource: ForecastSource {
      guard let info = store.weatherState.value else { return .shortTerm }
      return WeatherHintHelper.forecastSource(from: info, startAt: store.promise.startAt)
    }

    @ViewBuilder
    private var bottomBar: some View {
      switch store.currentStep {
      case .first:
        StepBottomBar(configuration: .navigation(
          showPrevious: false,
          previousAction: {},
          nextTitle: LocalizedStrings.Common.next,
          isNextDisabled: store.firstButtonDisabled,
          nextAction: { store.send(.view(.nextStep), animation: .easeInOut(duration: 0.25)) }
        ))
      case .second:
        StepBottomBar(configuration: .navigation(
          showPrevious: true,
          previousAction: { store.send(.view(.previousStep), animation: .default) },
          nextTitle: LocalizedStrings.Common.next,
          isNextDisabled: store.secondButtonDisabled,
          nextAction: { store.send(.view(.nextStep), animation: .easeInOut(duration: 0.25)) }
        ))
      case .third:
        StepBottomBar(configuration: .navigation(
          showPrevious: true,
          previousAction: { store.send(.view(.previousStep), animation: .default) },
          nextTitle: "약속 제안하기",
          nextSystemImage: "checkmark.circle.fill",
          isNextDisabled: store.thirdButtonDisabled,
          isNextLoading: store.isCreatingPromise,
          nextAction: { store.send(.view(.requestCreatingPromise), animation: .spring(response: 0.3, dampingFraction: 0.9)) }
        ))
      }
    }
  }
}

// MARK: - CreatePromiseStep Extension
extension CreatePromiseStep {
  @ViewBuilder
  func contentView(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      CreatePromiseStep1View(store: store)
    case .second:
      CreatePromiseStep2View(store: store)
    case .third:
      CreatePromiseStep3View(store: store)
    }
  }
}

// MARK: - PromiseClientError Localization

extension Clients.PromiseClientError {
  var localizedMessage: String {
    switch self {
    case .networkError: return LocalizedStrings.Error.networkError
    case .unauthorized: return LocalizedStrings.Error.userAuthRequired
    case .notFound: return LocalizedStrings.Error.notFoundError
    case .serverError: return LocalizedStrings.Error.serverError
    case .invalidData: return LocalizedStrings.Error.validationError
    case .groupNotFound: return LocalizedStrings.Error.notFoundError
    case .notGroupMember: return LocalizedStrings.Error.permissionError
    case .unknown: return LocalizedStrings.Error.unknownError
    }
  }
}
