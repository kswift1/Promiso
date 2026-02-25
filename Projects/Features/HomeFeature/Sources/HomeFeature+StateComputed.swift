import Clients
import PromisoShared
import SwiftUI

// MARK: - State Computed Properties

extension Home.Feature.State {
  /// 전체 약속 (nil이면 빈 배열)
  var allPromises: [PromiseModel] {
    promisesState.value ?? []
  }

  /// 전체 개인 일정 (nil이면 빈 배열)
  private var allPersonalEvents: [PersonalEventModel] {
    personalEventsState.value ?? []
  }

  /// 오늘 날짜 범위 (KST 기준)
  private var todayRange: (start: Date, end: Date) {
    let calendar = Calendar.promiseDisplay
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    return (startOfDay, endOfDay)
  }

  /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷 갱신
  mutating func refreshHomeContentSnapshot() {
    homeContentSnapshot = buildHomeContentSnapshot()
  }

  /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷 생성
  private func buildHomeContentSnapshot() -> HomeContentSnapshot {
    let (startOfDay, endOfDay) = todayRange
    let userId = currentUser.userId

    var todayPromises: [PromiseModel] = []
    var todayScheduleItems: [HomeModels.ScheduleItem] = []
    var pendingPromises: [PromiseModel] = []
    var upcomingPromises: [PromiseModel] = []
    var upcomingScheduleItems: [HomeModels.ScheduleItem] = []

    for promise in allPromises {
      if promise.startAt >= startOfDay, promise.startAt < endOfDay, promise.isConfirmed {
        todayPromises.append(promise)
        todayScheduleItems.append(.promise(promise))
      }

      if promise.myVoteStatus(userId: userId) == .pending, !promise.isVotingClosed {
        pendingPromises.append(promise)
      }

      if promise.startAt >= endOfDay,
         promise.isConfirmed,
         promise.myVoteStatus(userId: userId) == .accepted {
        upcomingPromises.append(promise)
        upcomingScheduleItems.append(.promise(promise))
      }
    }

    for event in allPersonalEvents {
      if event.startAt >= startOfDay, event.startAt < endOfDay {
        todayScheduleItems.append(.personalEvent(event))
      } else if event.startAt >= endOfDay {
        upcomingScheduleItems.append(.personalEvent(event))
      }
    }

    pendingPromises.sort { lhs, rhs in
      lhs.votes.until < rhs.votes.until
    }
    pendingPromises = Array(pendingPromises.prefix(5))
    upcomingPromises = Array(upcomingPromises.prefix(10))

    todayScheduleItems.sort { $0.startAt < $1.startAt }
    upcomingScheduleItems.sort { $0.startAt < $1.startAt }
    upcomingScheduleItems = Array(upcomingScheduleItems.prefix(10))

    return HomeContentSnapshot(
      todayPromises: todayPromises,
      todayScheduleItems: todayScheduleItems,
      pendingPromises: pendingPromises,
      upcomingPromises: upcomingPromises,
      upcomingScheduleItems: upcomingScheduleItems
    )
  }

  /// 필터링된 약속 (id 기반 안전)
  var filteredPromises: [PromiseModel] {
    var promises = allPromises

    // 그룹 필터 적용
    if let groupId = selectedGroupId {
      promises = promises.filter { $0.groupId == groupId }
    }

    // 상태 필터 적용
    switch selectedStatusFilter {
    case .needResponse:
      promises = promises.filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed
      }
    case .confirmed:
      promises = promises.filter { $0.isConfirmed && !$0.isPast }
    case .inProgress:
      promises = promises.filter {
        !$0.isConfirmed && !$0.isVotingClosed
      }
    case .all:
      promises = promises.filter { !$0.isPast }
    }

    return promises
  }

  /// Overview 데이터
  var overviewData: HomeModels.OverviewData {
    let snapshot = homeContentSnapshot
    let nextPromise = snapshot.todayPromises
      .filter { $0.startAt > Date() }
      .first

    return HomeModels.OverviewData(
      todayCount: snapshot.todayScheduleItems.count,
      nextPromise: nextPromise,
      needResponseCount: snapshot.pendingPromises.count
    )
  }

  /// Critical Zone 데이터 (실시간 계산 필요)
  var criticalZoneData: HomeModels.CriticalZoneData? {
    let now = Date()
    let todayPromises = homeContentSnapshot.todayPromises

    // todayPromises에서 실시간 상태 계산
    if let livePromise = todayPromises.first(where: { $0.isRealtimeShareable }) {
      return HomeModels.CriticalZoneData(reason: .liveActivity, promise: livePromise)
    }

    if let ongoingPromise = todayPromises.first(where: { $0.isOngoing }) {
      return HomeModels.CriticalZoneData(reason: .inProgress, promise: ongoingPromise)
    }

    if let soonPromise = todayPromises.first(where: {
      let interval = $0.startAt.timeIntervalSince(now)
      return interval > 0 && interval <= 1800
    }) {
      return HomeModels.CriticalZoneData(reason: .departureSoon, promise: soonPromise)
    }

    return nil
  }

  /// Timeline 데이터 (날짜별 그룹화)
  var timelineData: [HomeModels.TimelineSection] {
    let grouped = Dictionary(grouping: filteredPromises) { promise in
      Calendar.promiseDisplay.startOfDay(for: promise.startAt)
    }

    return grouped
      .sorted { $0.key < $1.key }
      .map { day, promises in
        HomeModels.TimelineSection(
          day: day,
          promises: promises.sorted { $0.startAt < $1.startAt }
        )
      }
  }

  /// 사용 가능한 그룹 목록
  var availableGroups: [HomeModels.GroupInfo] {
    currentUser.groups.map { HomeModels.GroupInfo(id: $0.id, name: $0.name) }
  }

  /// 로딩 중 여부
  var isLoading: Bool {
    promisesState.isLoading
  }

  /// 응답 필요 개수 (배지용)
  var pendingResponseCount: Int {
    homeContentSnapshot.pendingPromises.count
  }

  // MARK: - Calendar Overlay Computed

  /// 오버레이 캘린더에 표시할 날짜 셀 배열
  var overlayCalendarDays: [OverlayCalendarModels.DayItem] {
    OverlayCalendarModels.generateMonthDays(
      for: overlayCalendarMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate
    )
  }

  /// 이전 월 캘린더 날짜 셀 배열
  var overlayPrevMonthDays: [OverlayCalendarModels.DayItem] {
    guard let prevMonth = Calendar.promiseDisplay.date(byAdding: .month, value: -1, to: overlayCalendarMonth)
    else { return [] }
    return OverlayCalendarModels.generateMonthDays(
      for: prevMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate
    )
  }

  /// 다음 월 캘린더 날짜 셀 배열
  var overlayNextMonthDays: [OverlayCalendarModels.DayItem] {
    guard let nextMonth = Calendar.promiseDisplay.date(byAdding: .month, value: 1, to: overlayCalendarMonth)
    else { return [] }
    return OverlayCalendarModels.generateMonthDays(
      for: nextMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate
    )
  }

  /// 선택된 날짜의 실제 일정 아이템 (약속 + 개인 일정)
  var overlaySelectedDateScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.promiseDisplay
    let selectedDay = calendar.startOfDay(for: overlaySelectedDate)
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) else { return [] }

    let promiseItems = allPromises
      .filter { $0.startAt >= selectedDay && $0.startAt < nextDay }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = (personalEventsState.value ?? [])
      .filter { $0.startAt >= selectedDay && $0.startAt < nextDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems).sorted { $0.startAt < $1.startAt }
  }

  /// 선택된 날짜의 전일 일정 아이템
  var overlayPrevDayScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.promiseDisplay
    guard let prevDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: overlaySelectedDate)),
          let nextDay = calendar.date(byAdding: .day, value: 1, to: prevDay) else { return [] }
    let promiseItems = allPromises
      .filter { $0.startAt >= prevDay && $0.startAt < nextDay }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = (personalEventsState.value ?? [])
      .filter { $0.startAt >= prevDay && $0.startAt < nextDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems).sorted { $0.startAt < $1.startAt }
  }

  /// 선택된 날짜의 다음일 일정 아이템
  var overlayNextDayScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.promiseDisplay
    let selectedDay = calendar.startOfDay(for: overlaySelectedDate)
    guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: selectedDay),
          let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: nextDayStart) else { return [] }
    let promiseItems = allPromises
      .filter { $0.startAt >= nextDayStart && $0.startAt < nextDayEnd }
      .map { HomeModels.ScheduleItem.promise($0) }
    let eventItems = (personalEventsState.value ?? [])
      .filter { $0.startAt >= nextDayStart && $0.startAt < nextDayEnd }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (promiseItems + eventItems).sorted { $0.startAt < $1.startAt }
  }

  /// 선택된 날짜가 속한 주의 7일 (주간 스트립용)
  var overlaySelectedWeekDays: [OverlayCalendarModels.DayItem] {
    OverlayCalendarModels.extractWeekDays(
      from: overlayCalendarDays,
      selectedDate: overlaySelectedDate
    )
  }

  /// 오버레이에서 사용하는 그룹 ID → GroupColor.color 매핑
  var overlayGroupColorMap: [String: Color] {
    Dictionary(
      uniqueKeysWithValues: currentUser.groups.compactMap { group in
        group.groupColor.map { (group.id, $0.color) }
      }
    )
  }

  /// 날짜별 일정 인디케이터 (그룹 컬러 + 제목)
  private var overlayScheduleIndicatorsByDate: [Date: [OverlayCalendarModels.ScheduleIndicator]] {
    let calendar = Calendar.promiseDisplay
    let colorMap = overlayGroupColorMap
    var indicators: [Date: [OverlayCalendarModels.ScheduleIndicator]] = [:]

    for promise in allPromises {
      let dateKey = calendar.startOfDay(for: promise.startAt)
      let color = colorMap[promise.groupId] ?? Color.pmindigo.n500
      indicators[dateKey, default: []].append(
        .init(id: promise.id, color: color, title: promise.title)
      )
    }

    for event in (personalEventsState.value ?? []) {
      let dateKey = calendar.startOfDay(for: event.startAt)
      indicators[dateKey, default: []].append(
        .init(id: event.id, color: OverlayCalendarModels.ScheduleIndicator.personalColor, title: event.title)
      )
    }

    // startAt 순 정렬
    for (key, value) in indicators {
      indicators[key] = value.sorted { lhs, rhs in
        let lhsPromise = allPromises.first { $0.id == lhs.id }
        let rhsPromise = allPromises.first { $0.id == rhs.id }
        let lhsDate = lhsPromise?.startAt ?? (personalEventsState.value ?? []).first { $0.id == lhs.id }?.startAt ?? .distantFuture
        let rhsDate = rhsPromise?.startAt ?? (personalEventsState.value ?? []).first { $0.id == rhs.id }?.startAt ?? .distantFuture
        return lhsDate < rhsDate
      }
    }

    return indicators
  }

  /// 날짜별 일정 개수 (약속 + 개인 일정)
  private var overlayScheduleCountsByDate: [Date: Int] {
    let calendar = Calendar.promiseDisplay
    var counts: [Date: Int] = [:]

    // 약속
    for promise in allPromises {
      let dateKey = calendar.startOfDay(for: promise.startAt)
      counts[dateKey, default: 0] += 1
    }

    // 개인 일정
    for event in (personalEventsState.value ?? []) {
      let dateKey = calendar.startOfDay(for: event.startAt)
      counts[dateKey, default: 0] += 1
    }

    return counts
  }
}
