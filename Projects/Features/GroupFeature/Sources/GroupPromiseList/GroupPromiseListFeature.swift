import ComposableArchitecture
import Clients
import PromisoShared
import Foundation

public enum GroupPromiseList {}

extension GroupPromiseList {
  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      let group: GroupModel
      var promises: [PromiseModel]
      let currentUserId: String
      let groupMembers: [UserPublicModel]?
      var selectedFilter: StatusFilter
      var respondingStates: [String: GroupMain.RespondingState] = [:]

      /// 그룹 캘린더 동기화 설정 캐시 (전역 공유)
      @Shared(.inMemory(AppConstants.SharedState.groupCalendarSyncCache))
      var groupCalendarSyncCache: [String: Bool] = [:]

      public init(
        group: GroupModel,
        promises: [PromiseModel],
        currentUserId: String,
        groupMembers: [UserPublicModel]?,
        initialFilter: StatusFilter = .all
      ) {
        self.group = group
        self.promises = promises
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
        self.selectedFilter = initialFilter
      }

      /// 필터링된 약속 목록
      var filteredPromises: [PromiseModel] {
        switch selectedFilter {
        case .needResponse:
          return promises
            .filter { $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count) == .needResponse }
            .sorted { $0.votes.until < $1.votes.until }
        case .responded:
          return promises
            .filter { $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count) == .responded }
            .sorted { $0.startAt < $1.startAt }
        case .confirmed:
          return promises
            .filter { $0.isConfirmed }
            .sorted { $0.startAt < $1.startAt }
        case .all:
          return promises.sorted { $0.startAt < $1.startAt }
        }
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case filterChanged(StatusFilter)
        case promiseTapped(PromiseModel)
        case acceptTapped(PromiseModel)
        case rejectTapped(PromiseModel)
        case responseChanged(PromiseModel, PromiseAttendanceStatus)
      }

      public enum Delegate: Sendable {
        case promiseSelected(PromiseModel)
      }
    }

    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.filterChanged(let filter)):
          state.selectedFilter = filter
          return .none

        case .view(.promiseTapped(let promise)):
          return .send(.delegate(.promiseSelected(promise)))

        case .view(.acceptTapped(let promise)):
          guard state.respondingStates[promise.id] == nil else { return .none }
          state.respondingStates[promise.id] = .accepting
          let calendarSyncCache = state.groupCalendarSyncCache
          return .run { [calendarSyncClient] send in
            let result = try await promiseClient.respondPromise(promise.id, .accepted)
            await send(.view(.responseChanged(promise, .accepted)))

            // 캘린더 동기화: 수락 + 확정 시 추가
            if result.isConfirmed, let confirmedPromise = result.confirmedPromise {
              let groupCalendarSync = calendarSyncCache[confirmedPromise.groupId] ?? true
              try? await calendarSyncClient.addPromise(confirmedPromise, groupCalendarSync)
            }
          } catch: { _, send in
            await send(.view(.responseChanged(promise, .pending)))
          }

        case .view(.rejectTapped(let promise)):
          guard state.respondingStates[promise.id] == nil else { return .none }
          state.respondingStates[promise.id] = .rejecting
          return .run { [calendarSyncClient] send in
            _ = try await promiseClient.respondPromise(promise.id, .declined)
            await send(.view(.responseChanged(promise, .declined)))

            // 캘린더 동기화: 거절 시 제거
            try? await calendarSyncClient.removePromise(promise.id)
          } catch: { _, send in
            await send(.view(.responseChanged(promise, .pending)))
          }

        case .view(.responseChanged(let promise, let status)):
          state.respondingStates[promise.id] = nil
          // 로컬 상태 업데이트 - immutable PromiseVotesModel 새로 생성
          if let index = state.promises.firstIndex(where: { $0.id == promise.id }) {
            var updated = state.promises[index]
            var newAccepted = updated.votes.accepted.filter { $0 != state.currentUserId }
            var newDeclined = updated.votes.declined.filter { $0 != state.currentUserId }

            switch status {
            case .accepted:
              newAccepted.append(state.currentUserId)
            case .declined:
              newDeclined.append(state.currentUserId)
            case .pending:
              break  // 이미 위에서 제거됨
            }

            updated.votes = PromiseVotesModel(
              accepted: newAccepted,
              declined: newDeclined,
              until: updated.votes.until
            )
            state.promises[index] = updated
          }
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - Equatable

extension GroupPromiseList.Feature.State: Sendable {}
