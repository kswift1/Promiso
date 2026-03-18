import ComposableArchitecture
import Clients
import PromisoShared
import Foundation

public enum GroupScheduleList {}

extension GroupScheduleList {
  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable {
      let group: GroupModel
      var schedules: [ScheduleModel]
      let currentUserId: String
      let groupMembers: [UserPublicModel]?
      var selectedFilter: StatusFilter
      var respondingStates: [String: GroupMain.RespondingState] = [:]

      /// 그룹 캘린더 동기화 설정 캐시 (전역 공유)
      @Shared(.inMemory(AppConstants.SharedState.groupCalendarSyncCache))
      var groupCalendarSyncCache: [String: Bool] = [:]

      /// 날씨 결과 (scheduleId → WeatherInfo)
      var weatherByScheduleId: [String: WeatherInfo] = [:]

      public init(
        group: GroupModel,
        schedules: [ScheduleModel],
        currentUserId: String,
        groupMembers: [UserPublicModel]?,
        initialFilter: StatusFilter = .all
      ) {
        self.group = group
        self.schedules = schedules
        self.currentUserId = currentUserId
        self.groupMembers = groupMembers
        self.selectedFilter = initialFilter
      }

      /// 필터링된 일정 목록
      var filteredSchedules: [ScheduleModel] {
        switch selectedFilter {
        case .needResponse:
          return schedules
            .filter { $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count) == .needResponse }
            .sorted { $0.votes.until < $1.votes.until }
        case .responded:
          return schedules
            .filter { $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count) == .responded }
            .sorted { $0.startAt < $1.startAt }
        case .confirmed:
          return schedules
            .filter {
              $0.isConfirmed
              && $0.myVoteStatus(userId: currentUserId) != .pending
            }
            .sorted { $0.startAt < $1.startAt }
        case .all:
          return schedules.sorted { $0.startAt < $1.startAt }
        }
      }
    }

    public enum Action: Sendable {
      case view(ViewAction)
      case delegate(Delegate)

      public enum ViewAction: Sendable {
        case filterChanged(StatusFilter)
        case scheduleTapped(ScheduleModel)
        case acceptTapped(ScheduleModel)
        case rejectTapped(ScheduleModel)
        case responseChanged(ScheduleModel, ScheduleAttendanceStatus)
      }

      public enum Delegate: Sendable {
        case scheduleSelected(ScheduleModel)
      }
    }

    @Dependency(\.scheduleClient) var scheduleClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.filterChanged(let filter)):
          state.selectedFilter = filter
          return .none

        case .view(.scheduleTapped(let schedule)):
          return .send(.delegate(.scheduleSelected(schedule)))

        case .view(.acceptTapped(let schedule)):
          guard state.respondingStates[schedule.id] == nil else { return .none }
          state.respondingStates[schedule.id] = .accepting
          let calendarSyncCache = state.groupCalendarSyncCache
          return .run { [calendarSyncClient] send in
            let result = try await scheduleClient.respondSchedule(schedule.id, .accepted)
            await send(.view(.responseChanged(schedule, .accepted)))

            // 캘린더 동기화: 수락 + 확정 시 추가
            if result.isConfirmed, let confirmedSchedule = result.confirmedSchedule {
              let groupCalendarSync = calendarSyncCache[confirmedSchedule.groupId] ?? true
              try? await calendarSyncClient.addSchedule(confirmedSchedule, groupCalendarSync)
            }
          } catch: { _, send in
            await send(.view(.responseChanged(schedule, .pending)))
          }

        case .view(.rejectTapped(let schedule)):
          guard state.respondingStates[schedule.id] == nil else { return .none }
          state.respondingStates[schedule.id] = .rejecting
          return .run { [calendarSyncClient] send in
            _ = try await scheduleClient.respondSchedule(schedule.id, .declined)
            await send(.view(.responseChanged(schedule, .declined)))

            // 캘린더 동기화: 거절 시 제거
            try? await calendarSyncClient.removeSchedule(schedule.id)
          } catch: { _, send in
            await send(.view(.responseChanged(schedule, .pending)))
          }

        case .view(.responseChanged(let schedule, let status)):
          state.respondingStates[schedule.id] = nil
          // 로컬 상태 업데이트 - immutable ScheduleVotesModel 새로 생성
          if let index = state.schedules.firstIndex(where: { $0.id == schedule.id }) {
            var updated = state.schedules[index]
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

            updated.votes = ScheduleVotesModel(
              accepted: newAccepted,
              declined: newDeclined,
              until: updated.votes.until
            )
            state.schedules[index] = updated
          }
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}
