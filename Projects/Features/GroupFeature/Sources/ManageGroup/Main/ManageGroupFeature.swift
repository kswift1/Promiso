import Clients
import ComposableArchitecture
import PromisoShared

public enum ManageGroup {}

extension ManageGroup {
  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient
    @Dependency(\.userProfileClient) var userProfileClient

    @ObservableState
    public struct State: Equatable {
      public let group: GroupModel
      public let summary: UserGroupInfo?
      public let currentUserId: String
      public let promises: [PromiseModel]

      // Members
      var membersState: LoadingState<[UserPublicModel]> = .idle
      var members: [UserPublicModel] = []

      // Leave/Delete
      var isLeavingGroup: Bool = false
      var isDeletingGroup: Bool = false
      var leaveError: String?
      var deleteError: String?

      // Image Detail
      var selectedMemberForImage: UserPublicModel?
      var showGroupImageDetail: Bool = false

      // Transfer Host
      var isShowingTransferSheet: Bool = false
      var selectedNewHost: UserPublicModel?
      var isTransferringHost: Bool = false
      var transferError: String?

      public init(
        group: GroupModel,
        summary: UserGroupInfo?,
        currentUserId: String,
        preloadedMembers: [UserPublicModel]? = nil,
        promises: [PromiseModel] = []
      ) {
        self.group = group
        self.summary = summary
        self.currentUserId = currentUserId
        self.promises = promises

        // preloadedMembers가 있으면 초기 표시용으로 사용 (onAppear에서 새로 fetch함)
        if let preloadedMembers = preloadedMembers {
          self.members = preloadedMembers
        }
      }

      var isHost: Bool {
        group.createdBy == currentUserId
      }

      /// 진행중인 약속 수 (과거 제외)
      var activePromiseCount: Int {
        promises.filter { !$0.isPast }.count
      }

      /// 호스트 양도 가능 여부 (호스트이고 다른 멤버가 있을 때)
      var canTransferHost: Bool {
        isHost && members.count > 1
      }

      /// 호스트 양도 대상 목록 (본인 제외)
      var transferCandidates: [UserPublicModel] {
        members.filter { $0.userId != currentUserId }
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case onAppear
        case pastPromisesTapped
        case leaveGroupTapped
        case deleteGroupTapped
        case confirmLeave
        case confirmDelete
        case cancelLeave
        case cancelDelete
        case dismissError
        // Image Detail
        case memberImageTapped(UserPublicModel)
        case groupImageTapped
        case imageDetailDismissed
        // Transfer Host
        case transferHostTapped
        case transferSheetDismissed
        case newHostSelected(UserPublicModel)
        case confirmTransferHost
        case cancelTransferHost
      }

      public enum Internal: Sendable {
        case fetchMembers
        case membersResponse(Result<[UserPublicModel], Error>)
        case leaveGroupResponse(Result<Void, Error>)
        case deleteGroupResponse(Result<Void, Error>)
        case transferHostResponse(Result<Void, Error>)
      }

      public enum Delegate: Sendable {
        case groupLeft
        case groupDeleted
        case pastPromisesTapped
        case hostTransferred(newHostId: String)
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 항상 최신 멤버 데이터를 fetch (호스트 양도 등 정확한 멤버 수 필요)
            return .send(.internal(.fetchMembers))

          case .pastPromisesTapped:
            return .send(.delegate(.pastPromisesTapped))

          case .leaveGroupTapped:
            // 리브 확인 alert는 View에서 처리
            return .none

          case .deleteGroupTapped:
            // 삭제 확인 alert는 View에서 처리
            return .none

          case .confirmLeave:
            state.isLeavingGroup = true
            state.leaveError = nil
            return .run { [groupId = state.group.id] send in
              do {
                try await groupClient.leaveGroup(groupId)
                await send(.internal(.leaveGroupResponse(.success(()))))
              } catch {
                await send(.internal(.leaveGroupResponse(.failure(error))))
              }
            }

          case .confirmDelete:
            state.isDeletingGroup = true
            state.deleteError = nil
            return .run { [groupId = state.group.id] send in
              do {
                try await groupClient.deleteGroup(groupId)
                await send(.internal(.deleteGroupResponse(.success(()))))
              } catch {
                await send(.internal(.deleteGroupResponse(.failure(error))))
              }
            }

          case .cancelLeave, .cancelDelete:
            return .none

          case .dismissError:
            state.leaveError = nil
            state.deleteError = nil
            state.transferError = nil
            return .none

          case .memberImageTapped(let member):
            state.selectedMemberForImage = member
            return .none

          case .groupImageTapped:
            state.showGroupImageDetail = true
            return .none

          case .imageDetailDismissed:
            state.selectedMemberForImage = nil
            state.showGroupImageDetail = false
            return .none

          case .transferHostTapped:
            state.isShowingTransferSheet = true
            state.selectedNewHost = nil
            state.transferError = nil
            return .none

          case .transferSheetDismissed:
            state.isShowingTransferSheet = false
            state.selectedNewHost = nil
            return .none

          case .newHostSelected(let member):
            state.selectedNewHost = member
            return .none

          case .confirmTransferHost:
            guard let newHost = state.selectedNewHost else { return .none }
            state.isTransferringHost = true
            state.transferError = nil
            return .run { [groupId = state.group.id, newHostId = newHost.userId] send in
              do {
                try await groupClient.transferHost(groupId, newHostId)
                await send(.internal(.transferHostResponse(.success(()))))
              } catch {
                await send(.internal(.transferHostResponse(.failure(error))))
              }
            }

          case .cancelTransferHost:
            state.selectedNewHost = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .fetchMembers:
            // 기존 멤버가 없을 때만 로딩 표시 (있으면 백그라운드에서 갱신)
            if state.members.isEmpty {
              state.membersState = .loading
            }
            return .run { [groupId = state.group.id] send in
              do {
                let members = try await groupClient.fetchGroupMembers(groupId)
                await send(.internal(.membersResponse(.success(members))))
              } catch {
                await send(.internal(.membersResponse(.failure(error))))
              }
            }

          case .membersResponse(.success(let members)):
            state.membersState = .loaded(members)
            state.members = members
            return .none

          case .membersResponse(.failure(let error)):
            state.membersState = .failed(error)
            return .none

          case .leaveGroupResponse(.success):
            state.isLeavingGroup = false
            return .send(.delegate(.groupLeft))

          case .leaveGroupResponse(.failure(let error)):
            state.isLeavingGroup = false
            state.leaveError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            return .none

          case .deleteGroupResponse(.success):
            state.isDeletingGroup = false
            return .send(.delegate(.groupDeleted))

          case .deleteGroupResponse(.failure(let error)):
            state.isDeletingGroup = false
            state.deleteError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            return .none

          case .transferHostResponse(.success):
            guard let newHostId = state.selectedNewHost?.userId else {
              state.isTransferringHost = false
              state.isShowingTransferSheet = false
              state.selectedNewHost = nil
              return .none
            }
            state.isTransferringHost = false
            state.isShowingTransferSheet = false
            state.selectedNewHost = nil
            return .send(.delegate(.hostTransferred(newHostId: newHostId)))

          case .transferHostResponse(.failure(let error)):
            state.isTransferringHost = false
            state.transferError = (error as? AuthClientError)?.localizedMessage ?? (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - AuthClientError Localization

extension AuthClientError {
  var localizedMessage: String {
    switch self {
    case .invalidCredentials: return LocalizedStrings.Error.authInvalidCredentials
    case .alreadyExists: return LocalizedStrings.Error.authAlreadyExists
    case .network: return LocalizedStrings.Error.authNetwork
    case .invalidAppleCredential: return LocalizedStrings.Error.authInvalidAppleCredential
    case .missingIdentityToken: return LocalizedStrings.Error.authMissingIdentityToken
    case .providerUnavailable: return LocalizedStrings.Error.authProviderUnavailable
    case .isGroupHost: return LocalizedStrings.Error.authIsGroupHost
    case .unknown: return LocalizedStrings.Error.unknownError
    }
  }
}
