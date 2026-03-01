import Clients
import PromisoShared
import ResourceKit
import SwiftUI

extension GroupMain.Feature.State {
  // MARK: - Computed Properties for New UI

  /// 그룹 로딩 중 여부
  var isGroupsLoading: Bool {
    allGroupSummaries == nil
  }

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
          name: LocalizedStrings.GroupMain.onboardingGroupName,
          localImage: ResourceKitAsset.notificationLogo.swiftUIImage,
          hasNewActivity: false,
          isSelected: true
        )
      ]
    }

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

  /// 응답 필요 약속 목록 (마감 임박순)
  var needResponsePromises: [PromiseModel] {
    guard case .loaded(let promises) = promisesState else { return [] }
    return promises
      .filter { $0.responseStatus(currentUserId: currentUser.userId, totalGroupMembers: currentGroupMembers?.count) == .needResponse }
      .sorted { $0.votes.until < $1.votes.until }  // 마감 임박순
  }

  /// 확정된 약속 목록 (시작 시간순, 내가 응답한 것만)
  var confirmedPromises: [PromiseModel] {
    guard case .loaded(let promises) = promisesState else { return [] }
    return promises
      .filter {
        $0.isConfirmed && $0.startAt > Date()
        && $0.myVoteStatus(userId: currentUser.userId) != .pending
      }
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
  var groupedFilteredPromises: [(day: Date, title: String, promises: [PromiseModel])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredPromises) { promise in
      calendar.startOfDay(for: promise.startAt)
    }

    return grouped
      .sorted { $0.key < $1.key }
      .map { day, promises in
        let title: String
        if calendar.isDateInToday(day) {
          title = LocalizedStrings.DateFormat.today
        } else if calendar.isDateInTomorrow(day) {
          title = LocalizedStrings.DateFormat.tomorrow
        } else {
          title = LocalizedDateFormatters.monthDayString(from: day)
        }

        return (day: day, title: title, promises: promises)
      }
  }

  /// 필터별 약속 개수 (과거 필터 제외)
  var filterCounts: [GroupMain.PromiseFilter: Int] {
    guard case .loaded(let promises) = promisesState else {
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

    for promise in promises {
      let responseStatus = promise.responseStatus(
        currentUserId: currentUserId,
        totalGroupMembers: totalGroupMembers
      )

      if responseStatus == .needResponse {
        needResponseCount += 1
      } else if responseStatus == .responded, !promise.isConfirmed {
        respondedCount += 1
      }

      if promise.isConfirmed,
         promise.startAt > now,
         promise.myVoteStatus(userId: currentUserId) != .pending {
        confirmedCount += 1
      }
    }

    return [
      .needResponse: needResponseCount,
      .responded: respondedCount,
      .confirmed: confirmedCount,
      .all: promises.count
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
