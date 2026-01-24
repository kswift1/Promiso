import ComposableArchitecture
import PromisoShared
import Clients
import SwiftUI
import UIKit
import Nuke
import ResourceKit

public enum GroupMain {}

// MARK: - Promise Filter

extension GroupMain {
  /// 약속 목록 필터 (Apple Mail 스타일)
  public enum PromiseFilter: String, CaseIterable, Sendable, CategoryFilterItem {
    case needResponse = "응답 필요"
    case responded = "응답 완료"
    case confirmed = "확정"
    case all = "전체"
    case past = "과거"

    public var title: String { rawValue }

    public var icon: String {
      switch self {
      case .needResponse: return "envelope.badge"
      case .responded: return "clock.badge.checkmark"
      case .confirmed: return "checkmark.circle.fill"
      case .all: return "tray.fill"
      case .past: return "clock.arrow.circlepath"
      }
    }

    public var selectedColor: Color {
      switch self {
      case .needResponse: return .orange
      case .responded: return .blue
      case .confirmed: return .green
      case .all: return .pmindigo.n500
      case .past: return Color(UIColor.systemGray)
      }
    }

    public var hasSeparatorBefore: Bool {
      self == .past
    }
  }
}

// MARK: - Deeplink

extension GroupMain {
  /// 그룹 탭에서 처리할 딥링크 목적지
  public enum Deeplink: Equatable, Sendable {
    /// 그룹 상세 화면
    case group(groupId: String)
    /// 약속 상세 화면
    case promise(promiseId: String, groupId: String)
  }
}

// MARK: - Onboarding
// TODO: onboarding - 추후 고도화 필요 (튜토리얼, 샘플 데이터 등)

extension GroupMain {
  /// 온보딩용 Mock 그룹 ID
  static let onboardingGroupId = "__onboarding__"

  /// 온보딩 카드 타입
  public enum OnboardingCard: CaseIterable, Identifiable {
    case createGroup
    case joinGroup
    case howToUse

    public var id: Self { self }

    var title: String {
      switch self {
      case .createGroup: return "그룹 만들기"
      case .joinGroup: return "친구 초대 코드로 참여"
      case .howToUse: return "Promiso 사용법"
      }
    }

    var subtitle: String {
      switch self {
      case .createGroup: return "친구들과 함께할 그룹을 만들어보세요"
      case .joinGroup: return "초대 코드를 입력해서 그룹에 참여하세요"
      case .howToUse: return "약속 생성부터 확정까지 알아보기"
      }
    }

    var icon: String {
      switch self {
      case .createGroup: return "person.3.fill"
      case .joinGroup: return "link.circle.fill"
      case .howToUse: return "questionmark.circle.fill"
      }
    }

    var color: Color {
      switch self {
      case .createGroup: return .blue
      case .joinGroup: return .green
      case .howToUse: return .orange
      }
    }
  }
}

extension GroupMain {
  private enum CancelID: Hashable {
    case respond(String)
    case promiseSubscription
  }

  enum RespondingState: Equatable {
    case idle, accepting, rejecting, resetting
  }

  // MARK: - Feature Reducer
  @Reducer
  public struct Feature {

    @Dependency(\.groupClient) var groupClient
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.userSettingsClient) var userSettingsClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var isInitialized: Bool = false
      let currentUser: UserPrivateModel

      var promisesState: LoadingState<[PromiseModel]> = .idle
      var proposalResponding: [String: RespondingState] = [:]
      var path = StackState<Path.State>()

      public var allGroupSummaries: [UserGroupInfo]?
      var currentGroup: GroupModel?
      var currentGroupMembers: [UserPublicModel]?

      /// 현재 fetch 중인 그룹 ID (중복 fetch 방지)
      var pendingGroupId: String?

      /// 현재 선택된 필터
      var selectedFilter: GroupMain.PromiseFilter = .needResponse

      /// 그룹 정렬 옵션 (커스텀의 경우 순서 포함)
      var groupSortOption: GroupSortOption = .joinedRecent

      /// 과거 약속 상태 (별도 fetch)
      var pastPromisesState: LoadingState<[PromiseModel]> = .idle

      // 공유 시트용
      var sharePromise: PromiseModel?

      @Presents var createPromise: CreatePromise.Feature.State?
      @Presents var createGroup: CreateGroup.Feature.State?
      @Presents var joinGroup: JoinGroup.Feature.State?
      @Presents var editPromise: EditPromise.Feature.State?
      @Presents var deleteAlert: AlertState<DeleteAlertAction>?
      @Presents var groupActionSheet: ConfirmationDialogState<GroupActionSheetAction>?
      @Presents var sortSettings: GroupSortSettings.Feature.State?

      /// 삭제 대상 약속 ID (알럿 확인 시 사용)
      var promiseToDelete: String?

      /// 딥링크로 열려는 목적지 (그룹/약속 로드 후 처리)
      var pendingDeeplink: GroupMain.Deeplink?

      /// 현재 실시간 공유 중인 약속 ID (nil이면 비활성)
      public var liveActivityPromiseId: String?

      /// LiveActivity 활성화 여부 (FAB 위치 조정용)
      public var hasLiveActivity: Bool { liveActivityPromiseId != nil }

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // MARK: - Computed Properties for New UI

      /// 온보딩 모드 여부 (그룹이 없을 때)
      var isOnboardingMode: Bool {
        allGroupSummaries?.isEmpty == true
      }

      /// 그룹 가로 바용 아이템 목록
      var groupBarItems: [GroupBarItem] {
        guard let groups = allGroupSummaries else { return [] }

        // 그룹이 없으면 온보딩 Mock 그룹 표시
        if groups.isEmpty {
          return [
            GroupBarItem(
              id: GroupMain.onboardingGroupId,
              name: "Promiso 시작하기",
              localImageName: "notificationLogo",
              hasNewActivity: false,
              isSelected: true
            )
          ]
        }

        // 정렬 적용
        let sortedGroups: [UserGroupInfo] = {
          switch groupSortOption {
          case .joinedRecent:
            return groups.sorted { ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast) }
          case .joinedOldest:
            return groups.sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
          case .nameAscending:
            return groups.sorted { $0.name < $1.name }
          case .nameDescending:
            return groups.sorted { $0.name > $1.name }
          case .custom(let order):
            // 커스텀 정렬 순서 적용
            if order.isEmpty {
              return groups
            }
            let groupDict = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
            let ordered = order.compactMap { groupDict[$0] }
            let remaining = groups.filter { group in !order.contains(group.id) }
            return ordered + remaining
          }
        }()

        return sortedGroups.map { group in
          GroupBarItem(
            id: group.id,
            name: group.name,
            imageUrl: group.imageUrl,
            hasNewActivity: group.hasNewActivity,
            isSelected: group.id == currentGroup?.id
          )
        }
      }

      /// 응답 필요 약속 목록 (마감 임박순)
      var needResponsePromises: [PromiseModel] {
        guard case .loaded(let promises) = promisesState else { return [] }
        return promises
          .filter { $0.responseStatus(currentUserId: currentUser.userId, totalGroupMembers: currentGroupMembers?.count) == .needResponse }
          .sorted { $0.votes.until < $1.votes.until }  // 마감 임박순
      }

      /// 확정된 약속 목록 (시작 시간순)
      var confirmedPromises: [PromiseModel] {
        guard case .loaded(let promises) = promisesState else { return [] }
        return promises
          .filter { $0.isConfirmed && $0.startAt > Date() }  // 확정 + 미래 약속만
          .sorted { $0.startAt < $1.startAt }
      }

      /// 모든 약속 (시간순)
      var allPromises: [PromiseModel] {
        guard case .loaded(let promises) = promisesState else { return [] }
        return promises.sorted { $0.startAt < $1.startAt }
      }

      /// 응답 완료 약속 목록 (시작 시간순)
      var respondedPromises: [PromiseModel] {
        guard case .loaded(let promises) = promisesState else { return [] }
        return promises
          .filter {
            let status = $0.responseStatus(
              currentUserId: currentUser.userId,
              totalGroupMembers: currentGroupMembers?.count
            )
            return status == .responded && !$0.isConfirmed
          }
          .sorted { $0.startAt < $1.startAt }
      }

      /// 과거 약속 목록 (최신순, 별도 fetch된 데이터)
      var pastPromises: [PromiseModel] {
        guard case .loaded(let promises) = pastPromisesState else { return [] }
        return promises.sorted { $0.startAt > $1.startAt }  // 최신순
      }

      /// 현재 필터에 따른 약속 목록
      var filteredPromises: [PromiseModel] {
        switch selectedFilter {
        case .needResponse:
          return needResponsePromises
        case .responded:
          return respondedPromises
        case .confirmed:
          return confirmedPromises
        case .all:
          return allPromises
        case .past:
          return pastPromises
        }
      }

      /// 과거 필터 로딩 중 여부
      var isPastFilterLoading: Bool {
        selectedFilter == .past && pastPromisesState == .loading
      }

      /// 날짜별로 그룹화된 필터된 약속 목록
      var groupedFilteredPromises: [(date: String, promises: [PromiseModel])] {
        let grouped = Dictionary(grouping: filteredPromises, by: { $0.dateText })

        return grouped.sorted { lhs, rhs in
          // 오늘 > 내일 > 나머지 (날짜순)
          let priorityOrder = ["오늘": 0, "내일": 1]
          let lhsPriority = priorityOrder[lhs.key] ?? 2
          let rhsPriority = priorityOrder[rhs.key] ?? 2

          if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
          }
          return lhs.key < rhs.key
        }.map { (date: $0.key, promises: $0.value) }
      }

      /// 리스트 애니메이션 키 (DiffableDataSource 스타일)
      var promiseListAnimationKey: [String] {
        groupedFilteredPromises.flatMap { section in
          [section.date] + section.promises.map(\.id)
        }
      }

      /// 필터별 약속 개수 (과거 필터 제외)
      var filterCounts: [GroupMain.PromiseFilter: Int] {
        [
          .needResponse: needResponsePromises.count,
          .responded: respondedPromises.count,
          .confirmed: confirmedPromises.count,
          .all: allPromises.count
          // .past는 제외 (별도 fetch이므로)
        ]
      }
    }

    @Reducer
    public enum Path {
      case manageGroupFeature(ManageGroup.Feature)
      case groupSettings(GroupSettings.Feature)
      case groupPromiseList(GroupPromiseList.Feature)
      case promiseDetail(PromiseDetail.Feature)
      case pastPromises(PastPromises.Feature)
      case pastPromiseDetail(PastPromiseDetail.Feature)
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

    public enum Action: Sendable {
      case view(ViewAction)
      case binding(BindingAction<State>)
      case `internal`(Internal)

      case createPromise(PresentationAction<CreatePromise.Feature.Action>)
      case createGroup(PresentationAction<CreateGroup.Feature.Action>)
      case joinGroup(PresentationAction<JoinGroup.Feature.Action>)
      case editPromise(PresentationAction<EditPromise.Feature.Action>)
      case deleteAlert(PresentationAction<DeleteAlertAction>)
      case groupActionSheet(PresentationAction<GroupActionSheetAction>)
      case sortSettings(PresentationAction<GroupSortSettings.Feature.Action>)

      case path(StackActionOf<Path>)

      public enum ViewAction: Sendable {
        case onAppear
        case refreshTriggered
        case groupChanged(UserGroupInfo)
        case proposalAccepted(String)
        case proposalRejected(String)
        case promiseDeleteRequested(String)
        case promiseEditTapped(PromiseModel)
        case responseChanged(String, PromiseAttendanceStatus)
        case promiseTapped(PromiseModel)
        case promiseShared(String)
        case sharePromiseDismissed
        case groupManageTapped
        case createNewPromise
        case createGroup
        case joinGroup
        case joinGroupWithCode(String) // 딥링크로 초대 코드와 함께 열기
        case handleDeeplink(GroupMain.Deeplink) // 딥링크 처리

        // MARK: - New UI Actions
        case groupTapped(String)  // 가로 바에서 그룹 선택
        case filterChanged(GroupMain.PromiseFilter)  // 필터 변경
        case moreNeedResponseTapped  // "N개 더 보기" - 응답 필요
        case moreConfirmedTapped  // "N개 더 보기" - 확정
        case allPromisesTapped  // "모든 약속 보기"
        case groupSettingsTapped  // "그룹 설정"
        case sortSettingsTapped  // "그룹 정렬"
      }

      public enum Internal: Sendable {
        case fetchGroupList
        case groupListResponse(Result<[UserGroupInfo], AppError>)
        case setDefaultGroup(groups: [UserGroupInfo])
        case fetchCurrentGroup(id: String)
        case currentGroupResponse(Result<GroupModel, AppError>)
        case fetchGroupMembers(groupId: String)
        case groupMembersResponse(Result<[UserPublicModel], AppError>)
        case subscribeToPromises(groupId: String)
        case cancelSubscription
        case promisesUpdated([PromiseModel])
        case proposalRespondDone(promiseId: String, status: PromiseAttendanceStatus)
        case proposalRespondFailed(promiseId: String, error: AppError)
        case respondPromise(promiseId: String, status: PromiseAttendanceStatus)
        case deletePromise(promiseId: String)
        case deletePromiseDone(promiseId: String)
        case deletePromiseFailed(promiseId: String, error: AppError)
        case toggleGroupNotifications
        case clearBadge(groupId: String)
        case liveActivityChanged(promiseId: String?)
        case fetchPastPromises(groupId: String)
        case pastPromisesResponse(Result<[PromiseModel], AppError>)
        case fetchSettings
        case settingsResponse(Result<UserSettings, AppError>)
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
            // 캐시된 데이터로 먼저 UI 표시 (빠른 로딩)
            let summaries = state.currentUser.sortedGroups
            state.allGroupSummaries = summaries
            // 최신 데이터 fetch (imageUrl 등 갱신) + 설정 로드
            return .merge(
              .send(.internal(.setDefaultGroup(groups: summaries))),
              .send(.internal(.fetchGroupList)),
              .send(.internal(.fetchSettings))
            )

          case .refreshTriggered:
            if !state.promisesState.isLoaded {
              state.promisesState = .loading
            }
            return .send(.internal(.fetchGroupList))

          case .groupChanged(let group):
            // 이미 선택된 그룹이거나 fetch 중인 그룹이면 무시
            guard group.id != state.currentGroup?.id,
                  group.id != state.pendingGroupId else { return .none }
            state.currentGroup = nil
            state.currentGroupMembers = nil
            state.pendingGroupId = group.id
            state.promisesState = .loading
            state.pastPromisesState = .idle  // 그룹 변경 시 과거 약속 초기화
            return .send(.internal(.fetchCurrentGroup(id: group.id)))

          case .proposalAccepted(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .accepting
            return .send(.internal(.respondPromise(promiseId: id, status: .accepted)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .proposalRejected(let id):
            guard state.proposalResponding[id] ?? .idle == .idle else { return .none }
            state.proposalResponding[id] = .rejecting
            return .send(.internal(.respondPromise(promiseId: id, status: .declined)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .promiseDeleteRequested(let id):
            guard let promise = state.promisesState.value?.first(where: { $0.id == id }) else {
              return .none
            }
            state.promiseToDelete = id
            state.deleteAlert = AlertState {
              TextState("약속 삭제")
            } actions: {
              ButtonState(role: .cancel) {
                TextState("취소")
              }
              ButtonState(role: .destructive, action: .confirmDelete) {
                TextState("삭제")
              }
            } message: {
              TextState("'\(promise.title)' 약속을 삭제하시겠습니까?\n삭제된 약속은 복구할 수 없습니다.")
            }
            return .none

          case .promiseEditTapped(let promise):
            let maxMembers = state.currentGroupMembers?.count ?? promise.minimumParticipants
            state.editPromise = EditPromise.Feature.State(
              promise: promise,
              maxMembers: maxMembers
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
            return .send(.internal(.respondPromise(promiseId: id, status: status)))
              .cancellable(id: CancelID.respond(id), cancelInFlight: true)

          case .promiseTapped(let promise):
            state.path.append(.promiseDetail(.init(
              promise: promise,
              currentUserId: state.currentUser.userId,
              groupMembers: state.currentGroupMembers
            )))
            return .none

          case .promiseShared(let promiseId):
            guard let promise = state.promisesState.value?.first(where: { $0.id == promiseId }) else {
              return .none
            }
            state.sharePromise = promise
            return .none

          case .sharePromiseDismissed:
            state.sharePromise = nil
            return .none

          case .groupManageTapped:
            guard let currentGroup = state.currentGroup else { return .none }
            let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
            state.path.append(.manageGroupFeature(.init(
              group: currentGroup,
              summary: summary,
              currentUserId: state.currentUser.userId,
              preloadedMembers: state.currentGroupMembers,
              promises: state.promisesState.value ?? []
            )))
            return .none

          case .createNewPromise:
            var promise = PromiseModel.empty
            // 현재 보고 있는 그룹을 기본 선택
            if let currentGroup = state.currentGroup {
              promise.group = currentGroup
              promise.groupId = currentGroup.id
            }
            state.createPromise = CreatePromise.Feature.State(
              promise: promise,
              groupSummaries: state.allGroupSummaries
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
            state.pendingDeeplink = deeplink

            // groupId 추출
            let groupId: String
            switch deeplink {
            case .group(let gid): groupId = gid
            case .promise(_, let gid): groupId = gid
            }

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

            // 과거 필터 선택 시 별도 fetch
            if filter == .past, let groupId = state.currentGroup?.id {
              // 이미 로드된 경우 재요청 안 함
              guard !state.pastPromisesState.isLoaded else { return .none }
              return .send(.internal(.fetchPastPromises(groupId: groupId)))
            }
            return .none

          case .moreNeedResponseTapped:
            return handleMoreNeedResponseTapped(&state)

          case .moreConfirmedTapped:
            return handleMoreConfirmedTapped(&state)

          case .allPromisesTapped:
            return handleAllPromisesTapped(&state)

          case .groupSettingsTapped:
            return handleGroupSettingsTapped(&state)

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

            // 딥링크로 열려는 그룹이 있으면 해당 그룹으로 이동
            if let deeplink = state.pendingDeeplink {
              let groupId: String
              switch deeplink {
              case .promise(_, let gid): groupId = gid
              case .group(let gid): groupId = gid
              }
              if let groupInfo = groupSummaries.first(where: { $0.id == groupId }) {
                AppLogger.deeplink.debug("[GroupMain] Deeplink group found after fetch: \(groupInfo.name)")
                return .send(.view(.groupChanged(groupInfo)))
              }
            }

            if let currentGroupId = state.currentGroup?.id,
               groupSummaries.contains(where: { $0.id == currentGroupId }) {
              return .send(.internal(.fetchCurrentGroup(id: currentGroupId)))
            }
            return .send(.internal(.setDefaultGroup(groups: groupSummaries)))

          case .groupListResponse(.failure(let error)):
            state.promisesState = .failed(error)
            return .none

          case .setDefaultGroup(let groups):
            guard let firstGroup = groups.first else { return .none }
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
            // 멤버 정보 먼저 fetch 후 promises subscribe
            return .send(.internal(.fetchGroupMembers(groupId: group.id)))

          case .currentGroupResponse(.failure(let error)):
            state.pendingGroupId = nil
            state.promisesState = .failed(error)
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
            state.currentGroupMembers = members
            guard let groupId = state.currentGroup?.id else { return .none }

            // LiveActivity 프로필 이미지 사전 캐싱 (APNs 원격 시작 대응)
            // 상세: cacheProfileImagesForLiveActivity 함수 주석 참고
            return .merge(
              .send(.internal(.subscribeToPromises(groupId: groupId))),
              .run(priority: .utility) { _ in
                await cacheProfileImagesForLiveActivity(members: members)
              }
            )

          case .groupMembersResponse(.failure):
            state.currentGroupMembers = nil
            // 멤버 조회 실패해도 promises는 subscribe
            guard let groupId = state.currentGroup?.id else { return .none }
            return .send(.internal(.subscribeToPromises(groupId: groupId)))

          case .subscribeToPromises(let groupId):
            if !state.promisesState.isLoaded {
              state.promisesState = .loading
            }
            AppLogger.group.debug("[GroupMain] subscribeToPromises 시작: groupId=\(groupId)")
            return .run { [promiseClient] send in
              AppLogger.group.debug("[GroupMain] 리스너 연결 시작...")
              for await promises in promiseClient.subscribeToPromises(groupId, 20) {
                AppLogger.group.debug("[GroupMain] promises 수신: \(promises.count)개")
                await send(.internal(.promisesUpdated(promises)))
              }
              AppLogger.group.warning("[GroupMain] 리스너 스트림 종료됨")
            }
            .cancellable(id: CancelID.promiseSubscription, cancelInFlight: true)

          case .cancelSubscription:
            AppLogger.group.debug("[GroupMain] 백그라운드 진입 - 구독 취소")
            return .cancel(id: CancelID.promiseSubscription)

          case .promisesUpdated(let promises):
            AppLogger.group.debug("[GroupMain] promisesUpdated: \(promises.count)개 로드됨")
            state.promisesState = .loaded(promises)

            // 딥링크로 열려는 약속이 있으면 상세 화면으로 이동
            if case .promise(let promiseId, _) = state.pendingDeeplink,
               let promise = promises.first(where: { $0.id == promiseId }) {
              AppLogger.deeplink.debug("[GroupMain] Promise found, navigating to detail: \(promise.title)")
              state.pendingDeeplink = nil
              // TODO: currentGroupMembers가 nil일 수 있음 - PromiseDetail에서 nil 처리 필요
              state.path.append(.promiseDetail(.init(
                promise: promise,
                currentUserId: state.currentUser.userId,
                groupMembers: state.currentGroupMembers
              )))
            } else if state.pendingDeeplink != nil {
              // 그룹만 열려는 경우 (promise 없음) - pending 클리어
              state.pendingDeeplink = nil
            }
            return .none

          case .proposalRespondDone(let id, _):
            state.proposalResponding[id] = nil
            // 응답 후 그룹 배지(hasNewActivity) 갱신
            return .send(.internal(.fetchGroupList))

          case .proposalRespondFailed(let id, let error):
            state.proposalResponding[id] = nil
            state.promisesState = .failed(error)
            return .none

          case .respondPromise(let promiseId, let status):
            return .run { [promiseClient] send in
              do {
                try await promiseClient.respondPromise(promiseId, status)
                await send(.internal(.proposalRespondDone(promiseId: promiseId, status: status)))
              } catch {
                await send(.internal(.proposalRespondFailed(promiseId: promiseId, error: AppError(error))))
              }
            }

          case .deletePromise(let promiseId):
            return .run { [promiseClient] send in
              do {
                try await promiseClient.deletePromise(promiseId)
                await send(.internal(.deletePromiseDone(promiseId: promiseId)))
              } catch {
                await send(.internal(.deletePromiseFailed(promiseId: promiseId, error: AppError(error))))
              }
            }

          case .deletePromiseDone:
            return .none

          case .deletePromiseFailed(_, let error):
            state.promisesState = .failed(error)
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

          case .liveActivityChanged(let promiseId):
            state.liveActivityPromiseId = promiseId
            return .none

          case .fetchPastPromises(let groupId):
            state.pastPromisesState = .loading
            return .run { [promiseClient] send in
              do {
                let promises = try await promiseClient.getPastPromises(groupId, 20, nil)
                await send(.internal(.pastPromisesResponse(.success(promises))))
              } catch {
                await send(.internal(.pastPromisesResponse(.failure(AppError(error)))))
              }
            }

          case .pastPromisesResponse(.success(let promises)):
            state.pastPromisesState = .loaded(promises)
            return .none

          case .pastPromisesResponse(.failure(let error)):
            state.pastPromisesState = .failed(error)
            return .none

          case .fetchSettings:
            return .run { [userSettingsClient, currentUser = state.currentUser] send in
              do {
                let settings = try await userSettingsClient.fetchSettings(currentUser.userId)
                await send(.internal(.settingsResponse(.success(settings))))
              } catch {
                await send(.internal(.settingsResponse(.failure(AppError(error)))))
              }
            }

          case .settingsResponse(.success(let settings)):
            state.groupSortOption = settings.groupSortOption
            return .none

          case .settingsResponse(.failure):
            // 설정 로드 실패 시 기본값 유지
            return .none
          }

        // MARK: - Child Feature Actions
        case .createPromise(.presented(.delegate(.dismiss))):
          state.createPromise = nil
          return .none

        case .createPromise(.presented(.delegate(.promiseCreated))):
          state.createPromise = nil
          return .none

        case .createPromise(.presented(.delegate(.createGroupRequested))):
          state.createPromise = nil
          state.createGroup = CreateGroup.Feature.State(
            currentUser: state.currentUser
          )
          return .none

        case .createPromise:
          return .none

        case .createGroup(.presented(.delegate(.dismiss))):
          state.createGroup = nil
          return .none

        case .createGroup(.presented(.delegate(.groupCreated))):
          state.createGroup = nil
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

        case .editPromise(.presented(.delegate(.cancelled))):
          state.editPromise = nil
          return .none

        case .editPromise(.presented(.delegate(.promiseUpdated))):
          state.editPromise = nil
          return .none

        case .editPromise:
          return .none

        case .sortSettings(.presented(.delegate(.sortOptionChanged(let option)))):
          state.groupSortOption = option
          state.sortSettings = nil
          // 정렬 옵션 Firestore에 저장 (커스텀 순서 포함)
          return .run { [userSettingsClient, currentUser = state.currentUser] _ in
            try await userSettingsClient.updateGroupSortOption(currentUser.userId, option)
          }

        case .sortSettings(.presented(.delegate(.cancelled))):
          state.sortSettings = nil
          return .none

        case .sortSettings:
          return .none

        case .deleteAlert(.presented(.confirmDelete)):
          guard let promiseId = state.promiseToDelete else { return .none }
          state.promiseToDelete = nil
          return .send(.internal(.deletePromise(promiseId: promiseId)))

        case .deleteAlert:
          state.promiseToDelete = nil
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
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .groupSettings(.delegate(.groupDeleted)))):
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .groupSettings(.delegate(.pastPromisesTapped)))):
          guard let groupId = state.currentGroup?.id else { return .none }
          state.path.append(.pastPromises(.init(
            groupId: groupId,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        // GroupPromiseList delegate actions
        case .path(.element(id: _, action: .groupPromiseList(.delegate(.promiseSelected(let promise))))):
          state.path.append(.promiseDetail(.init(
            promise: promise,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        // ManageGroup delegate actions (legacy)
        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupLeft)))):
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.groupDeleted)))):
          state.path.removeAll()
          state.currentGroup = nil
          state.currentGroupMembers = nil
          return .send(.internal(.fetchGroupList))

        case .path(.element(id: _, action: .manageGroupFeature(.delegate(.pastPromisesTapped)))):
          guard let groupId = state.currentGroup?.id else { return .none }
          state.path.append(.pastPromises(.init(
            groupId: groupId,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .pastPromises(.delegate(.promiseSelected(let promise))))):
          state.path.append(.pastPromiseDetail(.init(
            promise: promise,
            currentUserId: state.currentUser.userId,
            groupMembers: state.currentGroupMembers
          )))
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          return .none

        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated)))):
          return .none

        case .path:
          return .none

        case .binding:
          return .none
        }
      }
      .ifLet(\.$createPromise, action: \.createPromise) { CreatePromise.Feature() }
      .ifLet(\.$createGroup, action: \.createGroup) { CreateGroup.Feature() }
      .ifLet(\.$joinGroup, action: \.joinGroup) { JoinGroup.Feature() }
      .ifLet(\.$editPromise, action: \.editPromise) { EditPromise.Feature() }
      .ifLet(\.$deleteAlert, action: \.deleteAlert)
      .ifLet(\.$groupActionSheet, action: \.groupActionSheet)
      .ifLet(\.$sortSettings, action: \.sortSettings) { GroupSortSettings.Feature() }
      .forEach(\.path, action: \.path)
    }
  }
}

// MARK: - Path Conformances

extension GroupMain.Feature.Path.State: Equatable, Sendable {}
extension GroupMain.Feature.Path.Action: Sendable {}

// MARK: - New UI Action Helpers

private func handleMoreNeedResponseTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .needResponse
  )))
  return .none
}

private func handleMoreConfirmedTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .confirmed
  )))
  return .none
}

private func handleAllPromisesTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  state.path.append(.groupPromiseList(.init(
    group: currentGroup,
    promises: state.allPromises,
    currentUserId: state.currentUser.userId,
    groupMembers: state.currentGroupMembers,
    initialFilter: .all
  )))
  return .none
}

private func handleGroupSettingsTapped(
  _ state: inout GroupMain.Feature.State
) -> Effect<GroupMain.Feature.Action> {
  guard let currentGroup = state.currentGroup else { return .none }
  let summary = state.allGroupSummaries?.first { $0.id == currentGroup.id }
  state.path.append(.groupSettings(.init(
    group: currentGroup,
    summary: summary,
    currentUserId: state.currentUser.userId,
    preloadedMembers: state.currentGroupMembers
  )))
  return .none
}

// MARK: - Deeplink Helpers

extension GroupMain.Feature.State {
  /// 딥링크 처리 시 다른 그룹으로 이동하는 경우에만 path 초기화
  mutating func clearPathIfGroupChanged(targetGroupId: String) {
    if currentGroup?.id != targetGroupId {
      path.removeAll()
    }
  }
}

// MARK: - LiveActivity Profile Image Caching

/// LiveActivity용 프로필 이미지 사전 캐싱
///
/// APNs 원격 LiveActivity 시작 시 앱 코드가 실행되지 않으므로,
/// 멤버 로드 시점에 미리 App Group에 캐싱합니다.
/// - 이미 캐시된 이미지는 스킵
/// - 다운로드 실패 시 Widget에서 이모지로 fallback
private func cacheProfileImagesForLiveActivity(members: [UserPublicModel]) async {
  AppLogger.liveActivity.debug("프로필 이미지 캐싱 시작: \(members.count)명")

  await withTaskGroup(of: Void.self) { group in
    for member in members {
      group.addTask {
        guard let urlString = member.profileImageUrl,
              let url = URL(string: urlString) else {
          AppLogger.liveActivity.debug("프로필 URL 없음: \(member.userId)")
          return
        }

        // 매번 저장 (덮어쓰기) - 프로필 변경 즉시 반영
        // Nuke 캐시로 네트워크 비용 없음, TaskGroup이 병렬 처리
        do {
          let image = try await ImagePipeline.shared.image(for: url)
          LiveActivityImageStore.saveImage(image, userId: member.userId)
        } catch {
          AppLogger.liveActivity.error("다운로드 실패: \(member.userId), \(error)")
        }
      }
    }
  }
}
