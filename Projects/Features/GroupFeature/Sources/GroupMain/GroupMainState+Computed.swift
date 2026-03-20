import Clients
import PromisoShared
import SwiftUI

extension GroupMain.Feature.State {
  // MARK: - Computed Properties for New UI

  /// 그룹 로딩 중 여부
  var isGroupsLoading: Bool {
    allGroupSummaries == nil
  }

  /// 그룹 가로 바용 아이템 목록
  var groupBarItems: [GroupBarItem] {
    guard let groups = allGroupSummaries, !groups.isEmpty else { return [] }

    let sortedGroups = sortedGroupsForSelection(groups)

    return sortedGroups.map { group in
      GroupBarItem(
        id: group.id,
        name: group.name,
        imageUrl: group.imageUrl,
        hasNewActivity: group.hasNewActivity,
        isSelected: group.id == currentGroup?.id,
        joinedAt: group.joinedAt
      )
    }
  }

  /// 응답 필요 일정 목록 (마감 임박순)
  var needResponseSchedules: [ScheduleModel] {
    guard case .loaded(let schedules) = schedulesState else { return [] }
    return schedules
      .filter { $0.responseStatus(currentUserId: currentUser.userId, totalGroupMembers: currentGroupMembers?.count) == .needResponse }
      .sorted { $0.votes.until < $1.votes.until }  // 마감 임박순
  }

  /// 확정된 일정 목록 (시작 시간순, 내가 응답한 것만)
  var confirmedSchedules: [ScheduleModel] {
    guard case .loaded(let schedules) = schedulesState else { return [] }
    return schedules
      .filter {
        $0.isConfirmed && $0.startAt > Date()
        && $0.myVoteStatus(userId: currentUser.userId) != .pending
      }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 모든 일정 (시간순)
  var allSchedules: [ScheduleModel] {
    guard case .loaded(let schedules) = schedulesState else { return [] }
    return schedules.sorted { $0.startAt < $1.startAt }
  }

  /// 응답 완료 일정 목록 (시작 시간순)
  var respondedSchedules: [ScheduleModel] {
    guard case .loaded(let schedules) = schedulesState else { return [] }
    return schedules
      .filter {
        let status = $0.responseStatus(
          currentUserId: currentUser.userId,
          totalGroupMembers: currentGroupMembers?.count
        )
        return status == .responded && !$0.isConfirmed
      }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 과거 일정 목록 (최신순, 별도 fetch된 데이터)
  var pastSchedules: [ScheduleModel] {
    guard case .loaded(let schedules) = pastSchedulesState else { return [] }
    return schedules.sorted { $0.startAt > $1.startAt }  // 최신순
  }

  /// 현재 필터에 따른 일정 목록
  var filteredSchedules: [ScheduleModel] {
    switch selectedFilter {
    case .needResponse:
      return needResponseSchedules
    case .responded:
      return respondedSchedules
    case .confirmed:
      return confirmedSchedules
    case .all:
      return allSchedules
    case .past:
      return pastSchedules
    }
  }

  /// 과거 필터 로딩 중 여부
  var isPastFilterLoading: Bool {
    selectedFilter == .past && pastSchedulesState == .loading
  }

  /// 날짜별로 그룹화된 필터된 일정 목록
  var groupedFilteredSchedules: [(day: Date, title: String, schedules: [ScheduleModel])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredSchedules) { schedule in
      calendar.startOfDay(for: schedule.startAt)
    }

    let isDescending = selectedFilter == .past
    return grouped
      .sorted { isDescending ? $0.key > $1.key : $0.key < $1.key }
      .map { day, schedules in
        let title: String
        if calendar.isDateInToday(day) {
          title = LocalizedStrings.DateFormat.today
        } else if calendar.isDateInTomorrow(day) {
          title = LocalizedStrings.DateFormat.tomorrow
        } else {
          title = LocalizedDateFormatters.monthDayString(from: day)
        }

        return (day: day, title: title, schedules: schedules)
      }
  }

  /// 필터별 일정 개수 (과거 필터 제외)
  var filterCounts: [GroupMain.ScheduleFilter: Int] {
    guard case .loaded(let schedules) = schedulesState else {
      return [
        .needResponse: 0,
        .responded: 0,
        .confirmed: 0,
        .all: 0
      ]
    }

    let currentUserId = currentUser.userId
    let totalGroupMembers = currentGroupMembers?.count
    let now = Date()

    var needResponseCount = 0
    var respondedCount = 0
    var confirmedCount = 0

    for schedule in schedules {
      let responseStatus = schedule.responseStatus(
        currentUserId: currentUserId,
        totalGroupMembers: totalGroupMembers
      )

      if responseStatus == .needResponse {
        needResponseCount += 1
      } else if responseStatus == .responded, !schedule.isConfirmed {
        respondedCount += 1
      }

      if schedule.isConfirmed,
         schedule.startAt > now,
         schedule.myVoteStatus(userId: currentUserId) != .pending {
        confirmedCount += 1
      }
    }

    return [
      .needResponse: needResponseCount,
      .responded: respondedCount,
      .confirmed: confirmedCount,
      .all: schedules.count
      // .past는 제외 (별도 fetch이므로)
    ]
  }

  func sortedGroupsForSelection(_ groups: [UserGroupInfo]) -> [UserGroupInfo] {
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
      if order.isEmpty {
        return groups
      }
      let orderSet = Set(order)
      let groupDict = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
      let ordered = order.compactMap { groupDict[$0] }
      let remaining = groups.filter { group in !orderSet.contains(group.id) }
      return ordered + remaining
    }
  }
}
