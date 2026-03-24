import ComposableArchitecture
import PromisoShared
import Clients
import CreateScheduleFeature
import CreateGroupFeature
import Foundation

extension GroupMain {
  private enum CancelID: Hashable {
    case respond(String)
    case scheduleSubscription
    case needResponseShake
    case conflictCheck
    case weatherFetch
    case showGuide
  }

  /// ShakeEffect 타이밍 상수
  private enum ShakeConstants {
    /// ShakeEffect delay(0.5s) + animation(0.3s × 3) + buffer(0.1s)
    static let needResponseShakeDuration: TimeInterval = 0.5 + (0.3 * 3) + 0.1
  }

  enum RespondingState: Equatable {
    case idle, accepting, rejecting, resetting
  }

  // MARK: - Feature Reducer
  @Reducer
  public struct Feature {

    @Dependency(\.groupClient) var groupClient
    @Dependency(\.scheduleClient) var scheduleClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.mapClient) var mapClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.kakaoShareClient) var kakaoShareClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.analyticsClient) var analyticsClient
    @Dependency(\.scheduleConflictClient) var scheduleConflictClient
    @Dependency(\.weatherClient) var weatherClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var isInitialized: Bool = false
      /// 현재 사용자 정보 (RootTab과 참조 공유)
      @Shared var currentUser: UserPrivateModel

      var schedulesState: LoadingState<[ScheduleModel]> = .idle
      var proposalResponding: [String: RespondingState] = [:]
      var path = StackState<Path.State>()

      public var allGroupSummaries: [UserGroupInfo]?
      var currentGroup: GroupModel?

      /// 그룹 멤버 캐시 (전역 공유, groupId → members)
      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      public var groupMembersCache: [String: [UserPublicModel]] = [:]

      /// 그룹 캘린더 동기화 설정 캐시 (전역 공유, groupId → calendarSync)
      @Shared(.inMemory(AppConstants.SharedState.groupCalendarSyncCache))
      public var groupCalendarSyncCache: [String: Bool] = [:]

      /// 날씨 결과 (scheduleId → WeatherInfo)
      var weatherByScheduleId: [String: WeatherInfo] = [:]

      /// 현재 그룹 멤버 (캐시에서 조회)
      var currentGroupMembers: [UserPublicModel]? {
        guard let groupId = currentGroup?.id else { return nil }
        return groupMembersCache[groupId]
      }

      /// 현재 fetch 중인 그룹 ID (중복 fetch 방지)
      var pendingGroupId: String?

      /// 현재 선택된 필터
      var selectedFilter: GroupMain.ScheduleFilter = .all

      /// 그룹 정렬 옵션 (커스텀의 경우 순서 포함)
      var groupSortOption: GroupSortOption = .joinedRecent

      /// Pro 구독 여부
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      /// 일정 탭 기본 모드 (Settings에서 설정)
      @Shared(.appStorage(AppConstants.UserDefaults.defaultScheduleTabMode)) var defaultScheduleTabMode: String = "group"

      /// 과거 일정 상태 (별도 fetch)
      var pastSchedulesState: LoadingState<[ScheduleModel]> = .idle

      // 일정 공유 시트용
      var shareSchedule: ScheduleModel?
      var isKakaoScheduleSharing: Bool = false
      var systemShareText: String?
      /// 화면 토스트 메시지
      var toastMessage: ToastMessage?

      /// 그룹 초대 시트 표시 여부
      var showGroupInviteSheet: Bool = false
      /// 카카오 초대 공유 진행 중
      var isKakaoInviteSharing: Bool = false
      /// context menu에서 그룹 전환 후 실행할 액션
      enum PendingContextAction: Equatable, Sendable {
        case invite
        case settings
        case createSchedule
      }
      var pendingContextAction: PendingContextAction?
      /// 그룹 생성 후 일정 생성 화면으로 이동하기 위한 pending 그룹 ID
      var pendingCreateScheduleGroupId: String?

      @Presents var createSchedule: CreateSchedule.Feature.State?
      @Presents var createGroup: CreateGroup.Feature.State?
      @Presents var joinGroup: JoinGroup.Feature.State?
      @Presents var editSchedule: EditSchedule.Feature.State?
      @Presents var deleteAlert: AlertState<DeleteAlertAction>?
      @Presents var groupActionSheet: ConfirmationDialogState<GroupActionSheetAction>?
      var sortSettings: GroupSortSettings.Feature.State?

      /// 삭제 대상 일정 ID (알럿 확인 시 사용)
      var scheduleToDelete: String?

      /// 딥링크로 열려는 목적지 (그룹/일정 로드 후 처리)
      var pendingDeeplink: GroupMain.Deeplink?

      /// 하이라이트할 일정 ID (목록에서 스크롤 및 강조 표시)
      var highlightedScheduleId: String?

      /// 응답 필요 탭 진입 시 전체 흔들기 애니메이션 활성화
      var isNeedResponseShaking: Bool = false

      /// 현재 실시간 공유 중인 일정 ID (nil이면 비활성)
      public var liveActivityScheduleId: String?

      /// LiveActivity 활성화 여부 (FAB 위치 조정용)
      public var hasLiveActivity: Bool { liveActivityScheduleId != nil }

      /// 일정별 충돌 결과 캐시 (scheduleId → conflicts)
      var conflictsByScheduleId: [String: [ScheduleConflict]] = [:]
      /// 현재 충돌 확인 중인 일정 ID 집합
      var conflictCheckingIds: Set<String> = []
      /// 충돌 감지 임계값 (분). -1이면 비활성화
      var conflictDetectionThreshold: Int = 0

      var isShowingGuide: Bool = false

      public init(currentUser: Shared<UserPrivateModel>) {
        self._currentUser = currentUser
      }
    }

    @Reducer(state: .equatable)
    public enum Path {
      case groupSettings(GroupSettings.Feature)
      case groupScheduleList(GroupScheduleList.Feature)
      case scheduleDetail(ScheduleDetail.Feature)
      case pastSchedules(PastSchedules.Feature)
      case groupOverview(GroupOverview.Feature)
    }

    @CasePathable
    public enum DeleteAlertAction: Sendable {
      case confirmDelete
    }

    @CasePathable
    public enum GroupActionSheetAction: Sendable {
      case createGroup
      case joinGroup
    }

    public enum Action {
      case view(ViewAction)
      case binding(BindingAction<State>)
      case `internal`(Internal)

      case createSchedule(PresentationAction<CreateSchedule.Feature.Action>)
      case createGroup(PresentationAction<CreateGroup.Feature.Action>)
      case joinGroup(PresentationAction<JoinGroup.Feature.Action>)
      case editSchedule(PresentationAction<EditSchedule.Feature.Action>)
      case deleteAlert(PresentationAction<DeleteAlertAction>)
      case groupActionSheet(PresentationAction<GroupActionSheetAction>)
      case sortSettingsDismissed
      case sortOptionChanged(GroupSortOption)

      case path(StackActionOf<Path>)

      @CasePathable
      public enum ViewAction {
        case onAppear
        case refreshTriggered
        case groupChanged(UserGroupInfo)
        case proposalAccepted(String)
        case proposalRejected(String)
        case scheduleDeleteRequested(String)
        case scheduleEditTapped(ScheduleModel)
        case responseChanged(String, ScheduleAttendanceStatus)
        case scheduleTapped(ScheduleModel)
        case scheduleShared(String)
        case createNewSchedule
        case createGroup
        case joinGroup
        case joinGroupWithCode(String) // 딥링크로 초대 코드와 함께 열기
        case handleDeeplink(GroupMain.Deeplink) // 딥링크 처리

        // MARK: - New UI Actions
        case groupTapped(String)  // 가로 바에서 그룹 선택
        case filterChanged(GroupMain.ScheduleFilter)  // 필터 변경
        case clearHighlightedSchedule  // 하이라이트 클리어
        case needResponseShakeCompleted  // 응답 필요 흔들기 완료
        case moreNeedResponseTapped  // "N개 더 보기" - 응답 필요
        case moreConfirmedTapped  // "N개 더 보기" - 확정
        case allSchedulesTapped  // "모든 일정 보기"
        case groupSettingsTapped  // "그룹 설정"
        case groupOverviewTapped  // "그룹 개요" (모든 그룹 설정)
        case sortSettingsTapped  // "그룹 정렬"
        case directionsTapped(String)  // 길찾기 (scheduleId)
        case openCreateScheduleIfPossible  // Widget 딥링크: 그룹 있으면 일정 생성
        case switchToPersonalMode  // 개인 모드로 전환 요청
        case showGuide
        case dismissGuide
        case toastDismissed
        case tabReturned
        // Context Menu Actions
        case groupInviteTapped(String)  // 그룹 초대 (groupId)
        case groupContextSettingsTapped(String)  // 그룹 설정 (groupId)
        case contextCreateScheduleTapped(String)  // 일정 만들기 (groupId)
        case dismissGroupInviteSheet
        case kakaoInviteShareTapped
        case systemInviteShareTapped
        case kakaoScheduleShareTapped
        case systemScheduleShareTapped
        case dismissScheduleShareSheet
        case systemShareSheetDismissed
      }

      @CasePathable
      public enum Internal {
        case fetchGroupList
        case groupListResponse(Result<[UserGroupInfo], AppError>)
        case setDefaultGroup(groups: [UserGroupInfo])
        case fetchCurrentGroup(id: String)
        case currentGroupResponse(Result<GroupModel, AppError>)
        case fetchGroupMembers(groupId: String)
        case groupMembersResponse(Result<[UserPublicModel], AppError>)
        case subscribeToSchedules(groupId: String)
        case cancelSubscription
        case schedulesUpdated([ScheduleModel])
        case proposalRespondDone(scheduleId: String, status: ScheduleAttendanceStatus)
        case proposalRespondFailed(scheduleId: String, error: AppError)
        case respondSchedule(scheduleId: String, status: ScheduleAttendanceStatus)
        case deleteSchedule(scheduleId: String)
        case deleteScheduleDone(scheduleId: String)
        case deleteScheduleFailed(scheduleId: String, error: AppError)
        case toggleGroupNotifications
        case clearBadge(groupId: String)
        case liveActivityChanged(scheduleId: String?)
        case fetchPastSchedules(groupId: String)
        case pastSchedulesResponse(Result<[ScheduleModel], AppError>)
        case fetchGroupForSettings(groupInfo: UserGroupInfo)
        case groupForSettingsResponse(Result<GroupModel, AppError>, summary: UserGroupInfo)
        case fetchSettings
        case settingsResponse(Result<UserSettings, AppError>)
        case kakaoInviteShareResult(KakaoShareResult)
        case kakaoScheduleShareResult(KakaoShareResult)
        case refreshProFeatures([ScheduleModel])
        case checkConflicts([ScheduleModel])
        case conflictsLoaded(scheduleId: String, [ScheduleConflict])
        case conflictCheckFailed(scheduleId: String)
        case conflictSettingsLoaded(Int)
        case fetchWeather([ScheduleModel])
        case weatherBatchResponse([String: WeatherInfo])
      }
    }

    // MARK: - Reducer Body
    public var body: some ReducerOf<Self> {
      Reduce<State, Action> { state, action in
        switch action {
        // MARK: - View Actions
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard !state.isInitialized else { return .none }
            state.isInitialized = true
            // 최초 진입 시 가이드 표시 (1초 딜레이)
            let shouldShowGuide = !userDefaultsClient.hasSeenScheduleGuide
            return .merge(
              .send(.internal(.fetchSettings)),
              shouldShowGuide
                ? .run { send in
                    try await Task.sleep(for: .seconds(1))
                    await send(.view(.showGuide))
                  }
                  .cancellable(id: CancelID.showGuide, cancelInFlight: true)
                : .none
            )

          case .tabReturned:
            // 탭 복귀 시 그룹 목록만 갱신 (일정은 실시간 리스너로 처리)
            guard state.isInitialized else { return .none }
            return .send(.internal(.fetchGroupList))

          case .refreshTriggered:
            if !state.schedulesState.isLoaded {
              state.schedulesState = .loading
            }
            // 현재 그룹 멤버 캐시 무효화 후 다시 로드
            if let groupId = state.currentGroup?.id {
              state.$groupMembersCache.withLock { _ = $0.removeValue(forKey: groupId) }
              return .merge(
                .send(.internal(.fetchGroupList)),
                .send(.internal(.fetchGroupMembers(groupId: groupId)))
              )
            }
            return .send(.internal(.fetchGroupList))

          case .groupChanged(let group):
            // 이미 선택된 그룹이거나 fetch 중인 그룹이면 무시
            guard group.id != state.currentGroup?.id,
                  group.id != state.pendingGroupId else { return .none }
            state.currentGroup = nil
            state.pendingGroupId = group.id
            state.schedulesState = .loading
            state.pastSchedulesState = .idle  // 그룹 변경 시 과거 일정 초기화
            return .send(.internal(.fetchCurrentGroup(id: group.id)))

          case .proposalAccepted(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .accepting
            return .send(.internal(.respondSchedule(scheduleId: id, status: .accepted)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .proposalRejected(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .rejecting
            return .send(.internal(.respondSchedule(scheduleId: id, status: .declined)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .scheduleDeleteRequested(let id):
            guard let schedule = state.schedulesState.value?.first(where: { $0.id == id }) else {
              return .none
            }
            state.scheduleToDelete = id
            state.deleteAlert = AlertState {
              TextState(LocalizedStrings.GroupMain.deleteScheduleTitle)
            } actions: {
              ButtonState(role: .cancel) {
                TextState(LocalizedStrings.Common.cancel)
              }
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState(LocalizedStrings.Common.delete)
              }
            } message: {
              TextState(LocalizedStrings.GroupMain.deleteScheduleConfirm(schedule.title))
            }
            return .none

          case .scheduleEditTapped(let schedule):
            let maxMembers = state.currentGroupMembers?.count ?? schedule.minimumParticipants
            state.editSchedule = EditSchedule.Feature.State(
              schedule: schedule,
              maxMembers: maxMembers,
              currentUserId: state.currentUser.userId
            )
            return .none

          case .responseChanged(let id, let status):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            switch status {
            case .accepted:
              state.proposalResponding[id] = .accepting
            case .declined:
              state.proposalResponding[id] = .rejecting
            case .pending:
              state.proposalResponding[id] = .resetting
            }
            return .send(.internal(.respondSchedule(scheduleId: id, status: status)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .scheduleTapped(let schedule):
            state.path.append(.scheduleDetail(.init(
              schedule: schedule,
              currentUserId: state.currentUser.userId,
              groupMembers: state.currentGroupMembers
            )))
            return .none

          case .scheduleShared(let scheduleId):
            guard let schedule = state.schedulesState.value?.first(where: { $0.id == scheduleId }) else {
              return .none
            }
            state.shareSchedule = schedule
            analyticsClient.log(
              .scheduleShareSheetOpened(
                scheduleID: schedule.id,
                scheduleTitle: schedule.title
              )
            )
            return .none

          case .directionsTapped(let scheduleId):
            guard let schedule = state.schedulesState.value?.first(where: { $0.id == scheduleId }),
                  let location = schedule.location,
                  let latitude = location.latitude,
                  let longitude = location.longitude else {
              return .none
            }
            let coordinate = Coordinate(latitude: latitude, longitude: longitude)
            mapClient.openDirections(nil, coordinate, location.name, .car)
            return .none

          case .createNewSchedule:
            var schedule = ScheduleModel.empty
            // 현재 보고 있는 그룹을 기본 선택
            if let currentGroup = state.currentGroup {
              schedule.group = currentGroup
              schedule.groupId = currentGroup.id
            }
            state.createSchedule = CreateSchedule.Feature.State(
              schedule: schedule,
              groupSummaries: state.allGroupSummaries,
              currentUserId: state.currentUser.userId,
              currentUser: state.currentUser
            )
            return .none

          case .createGroup:
            state.createGroup = CreateGroup.Feature.State(
              currentUser: state.currentUser
            )
            return .none

          case .joinGroup:
            state.joinGroup = JoinGroup.Feature.State(
              currentUser: state.currentUser
            )
            return .none

          case .joinGroupWithCode(let inviteCode):
            var joinState = JoinGroup.Feature.State(
              currentUser: state.currentUser
            )
            joinState.inviteCode = inviteCode
            state.joinGroup = joinState
            return .send(.joinGroup(.presented(.view(.nextTapped))))

          case .handleDeeplink(let deeplink):
            AppLogger.deeplink.debug("[GroupMain] handleDeeplink: \(String(describing: deeplink))")

            // groupId 추출
            let groupId: String
            switch deeplink {
            case .group(let gid): groupId = gid
            case .schedule(_, let gid): groupId = gid
            case .scheduleInList(_, let gid, _): groupId = gid
            }

            // 현재 그룹이고 일정이 이미 로드된 경우 바로 적용
            if state.currentGroup?.id == groupId,
               let schedules = state.schedulesState.value {
              switch deeplink {
              case .schedule(let scheduleId, _):
                if let schedule = schedules.first(where: { $0.id == scheduleId }) {
                  AppLogger.deeplink.debug("[GroupMain] Schedule already loaded, navigating to detail immediately")
                  state.path.append(.scheduleDetail(.init(
                    schedule: schedule,
                    currentUserId: state.currentUser.userId,
                    groupMembers: state.currentGroupMembers
                  )))
                  return .none
                }
              case .scheduleInList(let scheduleId, _, let filter):
                if schedules.contains(where: { $0.id == scheduleId }) {
                  AppLogger.deeplink.debug("[GroupMain] Schedule already loaded, applying highlight immediately")
                  state.selectedFilter = filter
                  state.highlightedScheduleId = scheduleId
                  return .none
                }
              case .group:
                break
              }
            }

            // 그 외의 경우 pending으로 설정
            state.pendingDeeplink = deeplink

            // 다른 그룹으로 이동하는 경우에만 path 초기화
            state.clearPathIfGroupChanged(targetGroupId: groupId)

            // 해당 그룹으로 이동
            let summaryIds = state.allGroupSummaries?.map { $0.id } ?? []
            AppLogger.deeplink.debug("[GroupMain] allGroupSummaries: \(summaryIds)")
            if let groupInfo = state.allGroupSummaries?.first(where: { $0.id == groupId }) {
              AppLogger.deeplink.debug("[GroupMain] Group found, switching to: \(groupInfo.name)")
              return .send(.view(.groupChanged(groupInfo)))
            } else {
              AppLogger.deeplink.warning("[GroupMain] Group not found, fetching list...")
              return .send(.internal(.fetchGroupList))
            }

          // MARK: - New UI Actions

          case .groupTapped(let groupId):
            // 이미 선택된 그룹이거나 fetch 중인 그룹이면 무시
            guard groupId != state.currentGroup?.id,
                  groupId != state.pendingGroupId else { return .none }

            guard let groupInfo = state.allGroupSummaries?.first(where: { $0.id == groupId }) else {
              return .none
            }

            return .merge(
              .send(.internal(.clearBadge(groupId: groupId))),
              .send(.view(.groupChanged(groupInfo)))
            )

          case .filterChanged(let filter):
            state.selectedFilter = filter
            state.isNeedResponseShaking = false

            if filter == .needResponse {
              state.isNeedResponseShaking = true
              let shakeEffect: Effect<Action> = .run { send in
                try await Task.sleep(for: .seconds(ShakeConstants.needResponseShakeDuration))
                await send(.view(.needResponseShakeCompleted))
              }
              .cancellable(id: CancelID.needResponseShake, cancelInFlight: true)
              return shakeEffect
            }

            // 과거 필터 선택 시 별도 fetch
            if filter == .past, let groupId = state.currentGroup?.id {
              // 이미 로드된 경우 재요청 안 함
              guard !state.pastSchedulesState.isLoaded else {
                return .cancel(id: CancelID.needResponseShake)
              }
              return .merge(
                .cancel(id: CancelID.needResponseShake),
                .send(.internal(.fetchPastSchedules(groupId: groupId)))
              )
            }
            return .cancel(id: CancelID.needResponseShake)

          case .clearHighlightedSchedule:
            state.highlightedScheduleId = nil
            return .none

          case .needResponseShakeCompleted:
            state.isNeedResponseShaking = false
            return .none

          case .moreNeedResponseTapped:
            return handleMoreNeedResponseTapped(&state)

          case .moreConfirmedTapped:
            return handleMoreConfirmedTapped(&state)

          case .allSchedulesTapped:
            return handleAllSchedulesTapped(&state)

          case .groupSettingsTapped:
            return handleGroupSettingsTapped(&state)

          case .groupOverviewTapped:
            let groups = state.allGroupSummaries ?? []
            state.path.append(.groupOverview(.init(
              groups: groups,
              currentUser: state.$currentUser
            )))
            return .none

          case .sortSettingsTapped:
            // 커스텀 정렬 순서에 따라 그룹 정렬
            let customOrder = state.groupSortOption.customOrder
            let customOrdered: [GroupBarItem] = {
              if customOrder.isEmpty {
                return state.groupBarItems
              }
              let groupDict = Dictionary(uniqueKeysWithValues: state.groupBarItems.map { ($0.id, $0) })
              return customOrder.compactMap { groupDict[$0] }
            }()

            state.sortSettings = GroupSortSettings.Feature.State(
              selectedOption: state.groupSortOption,
              previewGroups: state.groupBarItems,
              customOrderedGroups: customOrdered
            )
            return .none

          case .openCreateScheduleIfPossible:
            // onAppear 전이면 currentUser.groups에서 fallback 로드
            if state.allGroupSummaries == nil {
              let summaries = state.sortedGroupsForSelection(state.currentUser.groups)
              state.allGroupSummaries = summaries
            }
            guard let groups = state.allGroupSummaries, !groups.isEmpty else {
              // 그룹 없음 → 그룹 탭 화면 유지 (온보딩 모드)
              return .none
            }
            // 그룹 있음 → 일정 생성 화면 열기
            return .send(.view(.createNewSchedule))

          case .switchToPersonalMode:
            // RootTabFeature에서 처리
            return .none

          case .showGuide:
            state.isShowingGuide = true
            return .none

          case .dismissGuide:
            state.isShowingGuide = false
            let isFirstTime = !userDefaultsClient.hasSeenScheduleGuide
            if isFirstTime {
              state.toastMessage = ToastMessage(
                type: .info,
                title: LocalizedStrings.Schedule.guideToastMessage,
                position: .top
              )
            }
            return .run { _ in
              userDefaultsClient.markScheduleGuideSeen()
            }

          case .toastDismissed:
            state.toastMessage = nil
            return .none

          // MARK: - Context Menu Actions

          case .groupInviteTapped(let groupId):
            if groupId == state.currentGroup?.id {
              state.showGroupInviteSheet = true
              if let group = state.currentGroup {
                analyticsClient.log(
                  .groupInviteSheetOpened(
                    groupID: group.id,
                    groupName: group.name
                  )
                )
              }
              return .none
            } else {
              state.pendingContextAction = .invite
              return .send(.view(.groupTapped(groupId)))
            }

          case .groupContextSettingsTapped(let groupId):
            if groupId == state.currentGroup?.id {
              return handleGroupSettingsTapped(&state)
            } else {
              state.pendingContextAction = .settings
              return .send(.view(.groupTapped(groupId)))
            }

          case .contextCreateScheduleTapped(let groupId):
            if groupId == state.currentGroup?.id {
              return .send(.view(.createNewSchedule))
            } else {
              state.pendingContextAction = .createSchedule
              return .send(.view(.groupTapped(groupId)))
            }

          case .dismissGroupInviteSheet:
            state.showGroupInviteSheet = false
            return .none

          case .kakaoInviteShareTapped:
            guard let group = state.currentGroup else { return .none }
            state.isKakaoInviteSharing = true
            let groupID = group.id
            let groupName = group.name
            let inviteCode = group.inviteCode
            let memberCount = group.memberIds.count
            let maxMembers = group.maxMembers
            let groupImageUrl = group.imageUrl
            let inviterName = state.currentGroupMembers?
              .first { $0.userId == state.currentUser.userId }?.displayName ?? state.currentUser.nickname
            let scheduleInfos = state.allSchedules
              .filter { $0.isUpcoming }
              .sorted { $0.startAt < $1.startAt }
              .prefix(3)
              .map { schedule in
                ScheduleShareInfo(
                  title: schedule.title,
                  emoji: schedule.displayEmoji,
                  dateText: schedule.dateText,
                  timeText: schedule.timeText,
                  locationName: schedule.location?.name,
                  imageUrl: schedule.imageUrls.first
                )
              }
            return .run { [kakaoShareClient, hapticFeedback, analyticsClient] send in
              await hapticFeedback.buttonTap()
              analyticsClient.log(
                .groupInviteLinkShared(
                  groupID: groupID,
                  groupName: groupName,
                  shareMethod: .kakao,
                  scheduleCount: scheduleInfos.count
                )
              )
              let result = await kakaoShareClient.shareGroupInvite(
                groupName,
                inviteCode,
                memberCount,
                maxMembers,
                groupImageUrl,
                inviterName,
                scheduleInfos
              )
              await send(.internal(.kakaoInviteShareResult(result)))
            }

          case .systemInviteShareTapped:
            guard let group = state.currentGroup else { return .none }
            analyticsClient.log(
              .groupInviteLinkShared(
                groupID: group.id,
                groupName: group.name,
                shareMethod: .system
              )
            )
            return .none

          case .kakaoScheduleShareTapped:
            guard let schedule = state.shareSchedule else { return .none }
            state.isKakaoScheduleSharing = true
            return .run { [kakaoShareClient, hapticFeedback, analyticsClient] send in
              await hapticFeedback.buttonTap()
              analyticsClient.log(
                .scheduleLinkShared(
                  scheduleID: schedule.id,
                  scheduleTitle: schedule.title,
                  shareMethod: .kakao
                )
              )
              let result = await kakaoShareClient.shareSchedule(
                schedule.title,
                schedule.displayEmoji,
                schedule.dateText,
                schedule.timeText,
                schedule.location?.name,
                schedule.location?.address,
                schedule.id,
                schedule.groupId,
                schedule.description,
                schedule.imageUrls.first
              )
              await send(.internal(.kakaoScheduleShareResult(result)))
            }

          case .systemScheduleShareTapped:
            guard let schedule = state.shareSchedule else { return .none }
            state.systemShareText = schedule.shareText
            state.shareSchedule = nil
            analyticsClient.log(
              .scheduleLinkShared(
                scheduleID: schedule.id,
                scheduleTitle: schedule.title,
                shareMethod: .system
              )
            )
            return .none

          case .dismissScheduleShareSheet:
            state.shareSchedule = nil
            state.isKakaoScheduleSharing = false
            return .none

          case .systemShareSheetDismissed:
            state.systemShareText = nil
            return .none
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .fetchGroupList:
            return .run { [groupClient] send in
              do {
                let summaries = try await groupClient.fetchGroupSummaries()
                await send(.internal(.groupListResponse(.success(summaries))))
              } catch {
                await send(.internal(.groupListResponse(.failure(AppError(error)))))
              }
            }

          case .groupListResponse(.success(let groupSummaries)):
            state.allGroupSummaries = groupSummaries

            // Shared currentUser.groups를 서버 기준으로 동기화
            var latestGroupsById: [String: UserGroupInfo] = [:]
            for summary in groupSummaries {
              latestGroupsById[summary.id] = summary
            }
            let normalizedGroups = latestGroupsById.values.sorted {
              ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast)
            }
            state.$currentUser.withLock { user in
              user = UserPrivateModel(
                userId: user.userId,
                name: user.name,
                nickname: user.nickname,
                email: user.email,
                provider: user.provider,
                profile: user.profile,
                metadata: user.metadata,
                groups: normalizedGroups
              )
            }

            // 그룹 캘린더 동기화 설정 캐시 업데이트
            state.$groupCalendarSyncCache.withLock { cache in
              for group in groupSummaries {
                cache[group.id] = group.notifications?.calendarSync ?? true
              }
            }
            analyticsClient.setGroupMembershipProperties(groupSummaries)
            analyticsClient.setCalendarSyncEnabled(
              personalEnabled: UserDefaults.standard.bool(
                forKey: AppConstants.UserDefaults.personalCalendarSync
              ),
              groups: groupSummaries
            )

            // 딥링크로 열려는 그룹이 있으면 해당 그룹으로 이동
            if let deeplink = state.pendingDeeplink {
              let groupId: String
              switch deeplink {
              case .schedule(_, let gid): groupId = gid
              case .group(let gid): groupId = gid
              case .scheduleInList(_, let gid, _): groupId = gid
              }
              if let groupInfo = groupSummaries.first(where: { $0.id == groupId }) {
                AppLogger.deeplink.debug("[GroupMain] Deeplink group found after fetch: \(groupInfo.name)")
                return .send(.view(.groupChanged(groupInfo)))
              } else {
                AppLogger.deeplink.warning("[GroupMain] Deeplink group not found - user may not be a member: \(groupId)")
                state.pendingDeeplink = nil
                state.toastMessage = ToastMessage(
                  type: .info,
                  title: LocalizedStrings.GroupMain.joinGroupRequiredForDeeplinkTitle,
                  subtitle: LocalizedStrings.GroupMain.joinGroupRequiredForDeeplinkSubtitle
                )
              }
            }

            // 그룹 생성 후 일정 생성으로 이동
            if let pendingGroupId = state.pendingCreateScheduleGroupId {
              state.pendingCreateScheduleGroupId = nil
              if let groupInfo = groupSummaries.first(where: { $0.id == pendingGroupId }) {
                return .merge(
                  .send(.view(.groupChanged(groupInfo))),
                  .run { send in
                    // 그룹 전환 애니메이션 완료를 기다린 후 일정 생성 화면 열기
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.view(.createNewSchedule))
                  }
                )
              }
            }

            if let currentGroupId = state.currentGroup?.id,
               groupSummaries.contains(where: { $0.id == currentGroupId }) {
              return .send(.internal(.fetchCurrentGroup(id: currentGroupId)))
            }
            return .send(.internal(.setDefaultGroup(groups: groupSummaries)))

          case .groupListResponse(.failure(let error)):
            state.schedulesState = .failed(error)
            return .none

          case .setDefaultGroup(let groups):
            let sortedGroups = state.sortedGroupsForSelection(groups)
            guard let firstGroup = sortedGroups.first else { return .none }
            state.pendingGroupId = firstGroup.id
            return .merge(
              .send(.internal(.clearBadge(groupId: firstGroup.id))),
              .send(.internal(.fetchCurrentGroup(id: firstGroup.id)))
            )

          case .fetchCurrentGroup(let id):
            return .run { [groupClient] send in
              do {
                let group = try await groupClient.fetchGroup(id)
                await send(.internal(.currentGroupResponse(.success(group))))
              } catch {
                await send(.internal(.currentGroupResponse(.failure(AppError(error)))))
              }
            }

          case .currentGroupResponse(.success(let group)):
            state.currentGroup = group
            state.pendingGroupId = nil

            // context menu에서 그룹 전환 후 대기 중인 액션 실행
            var effects: [Effect<Action>] = [
              .send(.internal(.clearBadge(groupId: group.id))),
              .send(.internal(.fetchGroupMembers(groupId: group.id)))
            ]
            if let pendingAction = state.pendingContextAction {
              state.pendingContextAction = nil
              switch pendingAction {
              case .invite:
                state.showGroupInviteSheet = true
                analyticsClient.log(
                  .groupInviteSheetOpened(
                    groupID: group.id,
                    groupName: group.name
                  )
                )
              case .settings:
                effects.append(handleGroupSettingsTapped(&state))
              case .createSchedule:
                effects.append(.send(.view(.createNewSchedule)))
              }
            }
            return .merge(effects)

          case .currentGroupResponse(.failure(let error)):
            state.pendingGroupId = nil
            state.schedulesState = .failed(error)
            return .none

          case .fetchGroupMembers(let groupId):
            return .run { [groupClient] send in
              do {
                let members = try await groupClient.fetchGroupMembers(groupId)
                await send(.internal(.groupMembersResponse(.success(members))))
              } catch {
                await send(.internal(.groupMembersResponse(.failure(AppError(error)))))
              }
            }

          case .groupMembersResponse(.success(let members)):
            guard let groupId = state.currentGroup?.id else { return .none }
            state.$groupMembersCache.withLock { $0[groupId] = members }

            // LiveActivity 프로필 이미지 사전 캐싱 (APNs 원격 시작 대응)
            // 상세: cacheProfileImagesForLiveActivity 함수 주석 참고
            return .merge(
              .send(.internal(.subscribeToSchedules(groupId: groupId))),
              .run(priority: .utility) { _ in
                await cacheProfileImagesForLiveActivity(members: members)
              }
            )

          case .groupMembersResponse(.failure):
            // 멤버 조회 실패해도 schedules는 subscribe (캐시에 없으면 computed property가 nil 반환)
            guard let groupId = state.currentGroup?.id else { return .none }
            return .send(.internal(.subscribeToSchedules(groupId: groupId)))

          case .subscribeToSchedules(let groupId):
            if !state.schedulesState.isLoaded {
              state.schedulesState = .loading
            }
            AppLogger.group.debug("[GroupMain] subscribeToSchedules 시작: groupId=\(groupId)")
            return .run { [scheduleClient] send in
              AppLogger.group.debug("[GroupMain] 리스너 연결 시작...")
              for await schedules in scheduleClient.subscribeToSchedules(groupId, 20) {
                AppLogger.group.debug("[GroupMain] schedules 수신: \(schedules.count)개")
                await send(.internal(.schedulesUpdated(schedules)))
              }
              AppLogger.group.warning("[GroupMain] 리스너 스트림 종료됨")
            }
            .cancellable(id: CancelID.scheduleSubscription, cancelInFlight: true)

          case .cancelSubscription:
            AppLogger.group.debug("[GroupMain] 백그라운드 진입 - 구독 취소")
            return .cancel(id: CancelID.scheduleSubscription)

          case .schedulesUpdated(let schedules):
            AppLogger.group.debug("[GroupMain] schedulesUpdated: \(schedules.count)개 로드됨")
            state.schedulesState = .loaded(schedules)

            // 딥링크 처리
            switch state.pendingDeeplink {
            case .schedule(let scheduleId, _):
              // 일정 상세 화면으로 바로 이동
              if let schedule = schedules.first(where: { $0.id == scheduleId }) {
                AppLogger.deeplink.debug("[GroupMain] Schedule found, navigating to detail: \(schedule.title)")
                state.path.append(.scheduleDetail(.init(
                  schedule: schedule,
                  currentUserId: state.currentUser.userId,
                  groupMembers: state.currentGroupMembers
                )))
              } else {
                AppLogger.deeplink.warning("[GroupMain] Schedule not found in loaded list: \(scheduleId)")
              }
              state.pendingDeeplink = nil

            case .scheduleInList(let scheduleId, _, let filter):
              // 필터 적용 후 목록에서 해당 일정으로 스크롤
              if schedules.contains(where: { $0.id == scheduleId }) {
                AppLogger.deeplink.debug("[GroupMain] Schedule found in list, setting filter: \(filter.rawValue)")
                state.selectedFilter = filter
                state.highlightedScheduleId = scheduleId
              } else {
                AppLogger.deeplink.warning("[GroupMain] Schedule not found in list: \(scheduleId)")
              }
              state.pendingDeeplink = nil

            case .group, .none:
              state.pendingDeeplink = nil
            }
            return .send(.internal(.refreshProFeatures(schedules)))

          case .proposalRespondDone(let id, _):
            state.proposalResponding[id] = nil
            // 응답 후 그룹 배지(hasNewActivity) 갱신
            return .send(.internal(.fetchGroupList))

          case .proposalRespondFailed(let id, let error):
            state.proposalResponding[id] = nil
            state.schedulesState = .failed(error)
            return .none

          case .respondSchedule(let scheduleId, let status):
            // 캘린더 동기화 설정 캐시에서 조회
            let calendarSyncCache = state.groupCalendarSyncCache
            AppLogger.calendar.debug("📱 [GroupMain] respondSchedule 시작 - scheduleId: \(scheduleId), status: \(String(describing: status))")
            AppLogger.calendar.debug("📱 [GroupMain] calendarSyncCache: \(calendarSyncCache)")
            return .run { [scheduleClient, calendarSyncClient] send in
              do {
                let result = try await scheduleClient.respondSchedule(scheduleId, status)
                AppLogger.calendar.debug("📱 [GroupMain] respondSchedule 결과 - isConfirmed: \(result.isConfirmed)")
                await send(.internal(.proposalRespondDone(scheduleId: scheduleId, status: status)))

                // 캘린더 동기화: 수락 + 확정 시 추가
                if status == .accepted,
                   result.isConfirmed,
                   let confirmedSchedule = result.confirmedSchedule {
                  let groupCalendarSync = calendarSyncCache[confirmedSchedule.groupId] ?? true
                  AppLogger.calendar.debug("📱 [GroupMain] 캘린더 추가 시도 - groupCalendarSync: \(groupCalendarSync)")
                  try? await calendarSyncClient.addSchedule(confirmedSchedule, groupCalendarSync)
                } else {
                  AppLogger.calendar.debug("📱 [GroupMain] 캘린더 추가 조건 불충족 - status: \(String(describing: status)), isConfirmed: \(result.isConfirmed)")
                }

                // 캘린더 동기화: 거절 시 제거
                if status == .declined {
                  AppLogger.calendar.debug("📱 [GroupMain] 캘린더 제거 시도")
                  try? await calendarSyncClient.removeSchedule(scheduleId)
                }
              } catch {
                AppLogger.calendar.error("📱 [GroupMain] respondSchedule 에러: \(error.localizedDescription)")
                await send(.internal(.proposalRespondFailed(scheduleId: scheduleId, error: AppError(error))))
              }
            }

          case .deleteSchedule(let scheduleId):
            return .run { [scheduleClient] send in
              do {
                try await scheduleClient.deleteSchedule(scheduleId)
                await send(.internal(.deleteScheduleDone(scheduleId: scheduleId)))
              } catch {
                await send(.internal(.deleteScheduleFailed(scheduleId: scheduleId, error: AppError(error))))
              }
            }

          case .deleteScheduleDone:
            return .none

          case .deleteScheduleFailed(_, let error):
            state.schedulesState = .failed(error)
            return .none

          case .toggleGroupNotifications:
            return .none

          case .clearBadge(let groupId):
            // hasNewActivity가 true인 경우에만 클리어
            guard let index = state.allGroupSummaries?.firstIndex(where: { $0.id == groupId }),
                  state.allGroupSummaries?[index].hasNewActivity == true else {
              return .none
            }

            // 로컬 상태 즉시 업데이트
            state.allGroupSummaries?[index].hasNewActivity = false

            // 서버에 배지 클리어 요청 (Fire & Forget)
            return .run { [groupClient] _ in
              await groupClient.clearGroupBadge(groupId)
            }

          case .liveActivityChanged(let scheduleId):
            state.liveActivityScheduleId = scheduleId
            return .none

          case .fetchPastSchedules(let groupId):
            state.pastSchedulesState = .loading
            return .run { [scheduleClient] send in
              do {
                let schedules = try await scheduleClient.getPastSchedules(groupId, 20, nil)
                await send(.internal(.pastSchedulesResponse(.success(schedules))))
              } catch {
                await send(.internal(.pastSchedulesResponse(.failure(AppError(error)))))
              }
            }

          case .pastSchedulesResponse(.success(let schedules)):
            state.pastSchedulesState = .loaded(schedules)
            return .none

          case .pastSchedulesResponse(.failure(let error)):
            state.pastSchedulesState = .failed(error)
            return .none

          case .fetchGroupForSettings(let groupInfo):
            return .run { [groupClient] send in
              do {
                let group = try await groupClient.fetchGroup(groupInfo.id)
                await send(.internal(.groupForSettingsResponse(.success(group), summary: groupInfo)))
              } catch {
                await send(.internal(.groupForSettingsResponse(.failure(AppError(error)), summary: groupInfo)))
              }
            }

          case .groupForSettingsResponse(.success(let group), let summary):
            let upcomingSchedules: [ScheduleModel] = {
              if let groupId = state.currentGroup?.id, groupId == group.id {
                return state.allSchedules.filter { $0.isUpcoming }
              }
              return []
            }()
            let preloadedMembers = state.groupMembersCache[group.id]
            state.path.append(.groupSettings(.init(
              group: group,
              summary: summary,
              currentUserId: state.currentUser.userId,
              isPro: state.isPro,
              preloadedMembers: preloadedMembers,
              upcomingSchedules: upcomingSchedules
            )))
            return .none

          case .groupForSettingsResponse(.failure, _):
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.unknownError,
              position: .top
            )
            return .none

          case .fetchSettings:
            return .merge(
              .run { [userSettingsClient, currentUser = state.currentUser] send in
                do {
                  let settings = try await userSettingsClient.fetchSettings(currentUser.userId)
                  await send(.internal(.settingsResponse(.success(settings))))
                } catch {
                  await send(.internal(.settingsResponse(.failure(AppError(error)))))
                }
              }
            )

          case .settingsResponse(.success(let settings)):
            state.groupSortOption = settings.groupSortOption
            state.conflictDetectionThreshold = settings.conflictDetectionThreshold
            // 설정 로드 후 그룹 리스트 표시
            let summaries = state.sortedGroupsForSelection(state.currentUser.groups)
            state.allGroupSummaries = summaries

            // 그룹 캘린더 동기화 설정 캐시 업데이트
            state.$groupCalendarSyncCache.withLock { cache in
              for group in summaries {
                cache[group.id] = group.notifications?.calendarSync ?? true
              }
            }
            analyticsClient.setGroupMembershipProperties(summaries)
            analyticsClient.setCalendarSyncEnabled(
              personalEnabled: UserDefaults.standard.bool(
                forKey: AppConstants.UserDefaults.personalCalendarSync
              ),
              groups: summaries
            )

            return .merge(
              .send(.internal(.setDefaultGroup(groups: summaries))),
              .send(.internal(.fetchGroupList))
            )

          case .settingsResponse(.failure):
            // 설정 로드 실패해도 기본값으로 그룹 리스트 표시
            let summaries = state.sortedGroupsForSelection(state.currentUser.groups)
            state.allGroupSummaries = summaries

            // 그룹 캘린더 동기화 설정 캐시 업데이트
            state.$groupCalendarSyncCache.withLock { cache in
              for group in summaries {
                cache[group.id] = group.notifications?.calendarSync ?? true
              }
            }
            analyticsClient.setGroupMembershipProperties(summaries)
            analyticsClient.setCalendarSyncEnabled(
              personalEnabled: UserDefaults.standard.bool(
                forKey: AppConstants.UserDefaults.personalCalendarSync
              ),
              groups: summaries
            )

            return .merge(
              .send(.internal(.setDefaultGroup(groups: summaries))),
              .send(.internal(.fetchGroupList))
            )

          case .kakaoInviteShareResult(let result):
            state.isKakaoInviteSharing = false
            switch result {
            case .shared, .webShared:
              state.showGroupInviteSheet = false
              state.toastMessage = ToastMessage(
                type: .success,
                title: LocalizedStrings.KakaoShare.inviteLinkShared,
                position: .top
              )
              return .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            case .fallbackToSystem:
              return .none
            }

          case .kakaoScheduleShareResult(let result):
            state.isKakaoScheduleSharing = false
            switch result {
            case .shared, .webShared:
              state.shareSchedule = nil
              state.toastMessage = ToastMessage(
                type: .success,
                title: LocalizedStrings.KakaoShare.scheduleShared,
                position: .top
              )
              return .run { [hapticFeedback] _ in
                await hapticFeedback.success()
              }
            case .fallbackToSystem:
              return .none
            }

          case .refreshProFeatures(let schedules):
            guard state.isPro else { return .none }
            return .merge(
              .send(.internal(.checkConflicts(schedules))),
              .send(.internal(.fetchWeather(schedules)))
            )

          case .checkConflicts(let schedules):
            let userId = state.currentUser.userId
            let threshold = state.conflictDetectionThreshold
            guard threshold >= 0 else {
              AppLogger.group.debug("[ConflictCheck] threshold=\(threshold), 충돌 체크 스킵")
              return .none
            }
            let futureSchedules = schedules.filter { $0.startAt > Date() }
            AppLogger.group.debug("[ConflictCheck] 전체 \(schedules.count)건 중 미래 \(futureSchedules.count)건")
            guard !futureSchedules.isEmpty else { return .none }
            for schedule in futureSchedules {
              state.conflictCheckingIds.insert(schedule.id)
            }
            return .merge(futureSchedules.map { schedule in
              .run { [scheduleConflictClient] send in
                do {
                  let conflicts = try await scheduleConflictClient.checkConflicts(
                    userId, schedule.startAt, schedule.endAt, Set([schedule.id]), threshold
                  )
                  await send(.internal(.conflictsLoaded(scheduleId: schedule.id, conflicts)))
                } catch {
                  AppLogger.group.error("[ConflictCheck] CF 실패 scheduleId=\(schedule.id): \(error)")
                  await send(.internal(.conflictCheckFailed(scheduleId: schedule.id)))
                }
              }
            })
            .cancellable(id: CancelID.conflictCheck, cancelInFlight: true)

          case .conflictsLoaded(let scheduleId, let conflicts):
            state.conflictCheckingIds.remove(scheduleId)
            state.conflictsByScheduleId[scheduleId] = conflicts
            return .none

          case .conflictCheckFailed(let scheduleId):
            state.conflictCheckingIds.remove(scheduleId)
            return .none

          case .conflictSettingsLoaded(let threshold):
            state.conflictDetectionThreshold = threshold
            return .none

          case .fetchWeather(let schedules):
            let existing = state.weatherByScheduleId
            let maxDate = Date().addingTimeInterval(10 * 24 * 3600)
            let targets = schedules.filter { schedule in
              schedule.location?.latitude != nil &&
              schedule.location?.longitude != nil &&
              !schedule.isPast &&
              schedule.startAt < maxDate &&
              existing[schedule.id] == nil
            }
            guard !targets.isEmpty else { return .none }
            return .run { [weatherClient] send in
              var updates: [String: WeatherInfo] = [:]
              await withTaskGroup(of: (String, WeatherInfo?).self) { group in
                for schedule in targets {
                  group.addTask {
                    guard let lat = schedule.location?.latitude,
                          let lng = schedule.location?.longitude else { return (schedule.id, nil) }
                    let info = try? await weatherClient.getWeather(lat, lng, schedule.startAt)
                    return (schedule.id, info)
                  }
                }
                for await (id, info) in group {
                  guard let info else { continue }
                  updates[id] = info
                }
              }
              guard !updates.isEmpty else { return }
              await send(.internal(.weatherBatchResponse(updates)))
            }
            .cancellable(id: CancelID.weatherFetch, cancelInFlight: true)

          case .weatherBatchResponse(let updates):
            for (id, info) in updates {
              state.weatherByScheduleId[id] = info
            }
            return .none


          }

        // MARK: - Child Feature Actions
        case .createSchedule(.presented(.delegate(.dismiss))):
          state.createSchedule = nil
          return .none

        case .createSchedule(.presented(.delegate(.scheduleCreated))):
          state.createSchedule = nil
          return .send(.internal(.fetchGroupList))

        case .createSchedule(.presented(.delegate(.groupCreated))):
          return .send(.internal(.fetchGroupList))

        case .createSchedule:
          return .none

        case .createGroup(.presented(.delegate(.dismiss))):
          state.createGroup = nil
          return .none

        case .createGroup(.presented(.delegate(.groupCreated))):
          state.createGroup = nil
          return .send(.internal(.fetchGroupList))

        case .createGroup(.presented(.delegate(.groupCreatedAndCreateSchedule(let groupId)))):
          state.createGroup = nil
          state.pendingCreateScheduleGroupId = groupId
          return .send(.internal(.fetchGroupList))

        case .createGroup:
          return .none

        case .joinGroup(.presented(.delegate(.dismiss))):
          state.joinGroup = nil
          return .none

        case .joinGroup(.presented(.delegate(.groupJoined))):
          state.joinGroup = nil
          return .send(.internal(.fetchGroupList))

        case .joinGroup:
          return .none

        case .editSchedule(.presented(.delegate(.cancelled))):
          state.editSchedule = nil
          return .none

        case .editSchedule(.presented(.delegate(.scheduleUpdated))):
          state.editSchedule = nil
          return .none

        case .editSchedule:
          return .none

        case .sortSettingsDismissed:
          state.sortSettings = nil
          return .none

        case .sortOptionChanged(let option):
          state.sortSettings = nil
          state.groupSortOption = option
          return .run { [userSettingsClient, currentUser = state.currentUser] _ in
            do {
              try await userSettingsClient.updateGroupSortOption(currentUser.userId, option)
            } catch {
              // 저장 실패해도 로컬 상태는 유지 (다음 앱 실행 시 서버에서 다시 로드)
              AppLogger.general.error("Failed to save sort option: \(error.localizedDescription)")
            }
          }

        case .deleteAlert(.presented(.confirmDelete)):
          guard let scheduleId = state.scheduleToDelete else { return .none }
          state.scheduleToDelete = nil
          return .send(.internal(.deleteSchedule(scheduleId: scheduleId)))

        case .deleteAlert:
          state.scheduleToDelete = nil
          return .none

        // MARK: - Group Action Sheet
        case .groupActionSheet(.presented(.createGroup)):
          state.createGroup = CreateGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .groupActionSheet(.presented(.joinGroup)):
          state.joinGroup = JoinGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .groupActionSheet:
          return .none

        // MARK: - Path Actions

        // GroupSettings delegate actions
        case .path(.element(id: _, action: .groupSettings(.delegate(.groupLeft)))):
          if let groupId = state.currentGroup?.id {
            state.$groupMembersCache.withLock { _ = $0.removeValue(forKey: groupId) }
            state.$currentUser.withLock { user in
              let updatedGroups = user.groups.filter { $0.id != groupId }
              user = UserPrivateModel(
                userId: user.userId,
                name: user.name,
                nickname: user.nickname,
                email: user.email,
                provider: user.provider,
                profile: user.profile,
                metadata: user.metadata,
                groups: updatedGroups
              )
            }
          }
          state.path.removeAll()
          state.currentGroup = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .groupSettings(.delegate(.groupDeleted)))):
          if let groupId = state.currentGroup?.id {
            state.$groupMembersCache.withLock { _ = $0.removeValue(forKey: groupId) }
            state.$currentUser.withLock { user in
              let updatedGroups = user.groups.filter { $0.id != groupId }
              user = UserPrivateModel(
                userId: user.userId,
                name: user.name,
                nickname: user.nickname,
                email: user.email,
                provider: user.provider,
                profile: user.profile,
                metadata: user.metadata,
                groups: updatedGroups
              )
            }
          }
          state.path.removeAll()
          state.currentGroup = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .groupSettings(.delegate(.pastSchedulesTapped)))):
          guard let groupId = state.currentGroup?.id else { return .none }
          state.path.append(.pastSchedules(.init(
            groupId: groupId,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .groupSettings(.delegate(.hostTransferred)))):
          // 호스트 양도 후 설정 화면을 닫고 그룹 데이터 새로고침
          if let groupId = state.currentGroup?.id {
            state.$groupMembersCache.withLock { _ = $0.removeValue(forKey: groupId) }
          }
          state.path.removeAll()
          return .send(.internal(.fetchGroupList))

        // GroupScheduleList delegate actions
        case .path(.element(id: _, action: .groupScheduleList(.delegate(.scheduleSelected(let schedule))))):
          state.path.append(.scheduleDetail(.init(
            schedule: schedule,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .pastSchedules(.delegate(.scheduleSelected(let schedule))))):
          state.path.append(.scheduleDetail(.init(
            schedule: schedule,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.scheduleDeleted)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .scheduleDetail(.delegate(.scheduleUpdated)))):
          return .none

        // GroupOverview delegate actions
        case .path(.element(id: _, action: .groupOverview(.delegate(.groupSelected(let groupInfo))))):
          return .send(.internal(.fetchGroupForSettings(groupInfo: groupInfo)))

        case .path(.element(id: _, action: .groupOverview(.delegate(.createGroup)))):
          state.path.removeAll()
          state.createGroup = CreateGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .path(.element(id: _, action: .groupOverview(.delegate(.joinGroup)))):
          state.path.removeAll()
          state.joinGroup = JoinGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .path:
          return .none

        case .binding:
          return .none
        }
      }
      .ifLet(\.$createSchedule, action: \.createSchedule) { CreateSchedule.Feature() }
      .ifLet(\.$createGroup, action: \.createGroup) { CreateGroup.Feature() }
      .ifLet(\.$joinGroup, action: \.joinGroup) { JoinGroup.Feature() }
      .ifLet(\.$editSchedule, action: \.editSchedule) { EditSchedule.Feature() }
      .ifLet(\.$deleteAlert, action: \.deleteAlert)
      .ifLet(\.$groupActionSheet, action: \.groupActionSheet)
      .forEach(\.path, action: \.path)
    }
  }
}
