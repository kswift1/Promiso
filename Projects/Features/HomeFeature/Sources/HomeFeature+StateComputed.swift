import Clients
import PromisoShared
import SwiftUI

// MARK: - State Computed Properties

extension Home.Feature.State {
  /// 전체 일정 (nil이면 빈 배열)
  var allSchedules: [ScheduleModel] {
    schedulesState.value ?? []
  }

  /// 전체 개인 일정 (nil이면 빈 배열)
  private var allPersonalEvents: [PersonalEventModel] {
    personalEventsState.value ?? []
  }

  /// 전체 반복 개인 일정 (nil이면 빈 배열)
  private var allRecurringEvents: [RecurringPersonalEventModel] {
    recurringEventsState.value ?? []
  }

  /// 오늘 날짜 범위 (KST 기준)
  private var todayRange: (start: Date, end: Date) {
    let calendar = Calendar.scheduleDisplay
    let startOfDay = calendar.startOfDay(for: Date())
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    return (startOfDay, endOfDay)
  }

  /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷 갱신
  /// 초기 로딩이 방금 완료되었으면 `true` 반환
  @discardableResult
  mutating func refreshHomeContentSnapshot() -> Bool {
    homeContentSnapshot = buildHomeContentSnapshot()
    // 3개 데이터 소스가 모두 로드/실패 완료되면 초기 로딩 완료로 표시
    let didCompleteInitialLoad = !hasLoadedOnce && !isLoading
    if didCompleteInitialLoad {
      hasLoadedOnce = true
    }
    return didCompleteInitialLoad
  }

  /// 홈 본문에서 공통으로 사용하는 파생 데이터 스냅샷 생성
  private func buildHomeContentSnapshot() -> HomeContentSnapshot {
    let (startOfDay, endOfDay) = todayRange
    let userId = currentUser.userId

    // 반복 일정 expand 범위: 오늘 ~ 30일 후
    let calendar = Calendar.scheduleDisplay
    let rangeEnd = calendar.date(byAdding: .day, value: 60, to: startOfDay) ?? startOfDay
    let expandedRecurringItems: [HomeModels.ScheduleItem] = allRecurringEvents.flatMap { event in
      RecurringEventExpander.expand(event: event, from: startOfDay, to: rangeEnd)
        .map { HomeModels.ScheduleItem.recurringPersonalEvent($0) }
    }

    var todaySchedules: [ScheduleModel] = []
    var todayScheduleItems: [HomeModels.ScheduleItem] = []
    var pendingSchedules: [ScheduleModel] = []
    var upcomingSchedules: [ScheduleModel] = []
    var upcomingScheduleItems: [HomeModels.ScheduleItem] = []

    for schedule in allSchedules {
      let isMySchedule = schedule.hostId == userId || schedule.myVoteStatus(userId: userId) == .accepted
      if schedule.startAt < endOfDay, schedule.effectiveEndAt >= startOfDay, isMySchedule {
        todaySchedules.append(schedule)
        todayScheduleItems.append(.schedule(schedule))
      }

      if schedule.myVoteStatus(userId: userId) == .pending, !schedule.isVotingClosed {
        pendingSchedules.append(schedule)
      }

      if schedule.startAt >= endOfDay,
         schedule.isConfirmed,
         schedule.myVoteStatus(userId: userId) == .accepted {
        upcomingSchedules.append(schedule)
        upcomingScheduleItems.append(.schedule(schedule))
      }
    }

    for event in allPersonalEvents {
      if event.startAt < endOfDay, event.effectiveEndAt >= startOfDay {
        todayScheduleItems.append(.personalEvent(event))
      } else if event.startAt >= endOfDay {
        upcomingScheduleItems.append(.personalEvent(event))
      }
    }

    // 반복 규칙 텍스트 매핑 (원본 모델에서 가져옴)
    let recurrenceTextMap: [String: String] = Dictionary(
      uniqueKeysWithValues: allRecurringEvents.map { ($0.id, $0.recurrence.displayText) }
    )

    var upcomingRecurringGroups: [String: (title: String, emoji: String, recurrenceText: String, nextDate: Date)] = [:]
    for item in expandedRecurringItems {
      if item.startAt < endOfDay, item.effectiveEndAt >= startOfDay {
        todayScheduleItems.append(item)
      } else if item.startAt >= endOfDay {
        if case .recurringPersonalEvent(let instance) = item {
          let id = instance.recurringEventId
          if upcomingRecurringGroups[id] == nil {
            upcomingRecurringGroups[id] = (
              title: instance.title,
              emoji: instance.emoji ?? "🔄",
              recurrenceText: recurrenceTextMap[id] ?? LocalizedStrings.Personal.filterRecurring,
              nextDate: item.startAt
            )
          } else if let existingGroup = upcomingRecurringGroups[id] {
            upcomingRecurringGroups[id]?.nextDate = min(existingGroup.nextDate, item.startAt)
          }
        }
      }
    }

    let upcomingRecurringSummaries = upcomingRecurringGroups
      .map { HomeModels.RecurringEventSummary(
        recurringEventId: $0.key,
        title: $0.value.title,
        emoji: $0.value.emoji,
        recurrenceText: $0.value.recurrenceText,
        nextInstanceDate: $0.value.nextDate
      )}
      .sorted { $0.nextInstanceDate < $1.nextInstanceDate }

    pendingSchedules.sort { lhs, rhs in
      lhs.votes.until < rhs.votes.until
    }
    pendingSchedules = Array(pendingSchedules.prefix(5))
    upcomingSchedules = Array(upcomingSchedules.prefix(10))

    todayScheduleItems.sort { $0.startAt < $1.startAt }
    upcomingScheduleItems.sort { $0.startAt < $1.startAt }
    upcomingScheduleItems = Array(upcomingScheduleItems.prefix(10))

    return HomeContentSnapshot(
      todaySchedules: todaySchedules,
      todayScheduleItems: todayScheduleItems,
      pendingSchedules: pendingSchedules,
      upcomingSchedules: upcomingSchedules,
      upcomingScheduleItems: upcomingScheduleItems,
      upcomingRecurringSummaries: upcomingRecurringSummaries
    )
  }

  /// 필터링된 일정 (id 기반 안전)
  var filteredSchedules: [ScheduleModel] {
    var schedules = allSchedules

    // 그룹 필터 적용
    if let groupId = selectedGroupId {
      schedules = schedules.filter { $0.groupId == groupId }
    }

    // 상태 필터 적용
    switch selectedStatusFilter {
    case .needResponse:
      schedules = schedules.filter {
        $0.myVoteStatus(userId: currentUser.userId) == .pending && !$0.isVotingClosed
      }
    case .confirmed:
      schedules = schedules.filter { $0.isConfirmed && !$0.isPast }
    case .inProgress:
      schedules = schedules.filter {
        !$0.isConfirmed && !$0.isVotingClosed
      }
    case .all:
      schedules = schedules.filter { !$0.isPast }
    }

    return schedules
  }

  /// Overview 데이터
  var overviewData: HomeModels.OverviewData {
    let snapshot = homeContentSnapshot
    let nextSchedule = snapshot.todaySchedules
      .filter { $0.startAt > Date() }
      .first

    return HomeModels.OverviewData(
      todayCount: snapshot.todayScheduleItems.count,
      nextSchedule: nextSchedule,
      needResponseCount: snapshot.pendingSchedules.count
    )
  }

  /// Critical Zone 데이터 (실시간 계산 필요)
  var criticalZoneData: HomeModels.CriticalZoneData? {
    let now = Date()
    let todaySchedules = homeContentSnapshot.todaySchedules

    // todaySchedules에서 실시간 상태 계산
    if let liveSchedule = todaySchedules.first(where: { $0.isRealtimeShareable }) {
      return HomeModels.CriticalZoneData(reason: .liveActivity, schedule: liveSchedule)
    }

    if let ongoingSchedule = todaySchedules.first(where: { $0.isOngoing }) {
      return HomeModels.CriticalZoneData(reason: .inProgress, schedule: ongoingSchedule)
    }

    if let soonSchedule = todaySchedules.first(where: {
      let interval = $0.startAt.timeIntervalSince(now)
      return interval > 0 && interval <= 1800
    }) {
      return HomeModels.CriticalZoneData(reason: .departureSoon, schedule: soonSchedule)
    }

    return nil
  }

  /// Timeline 데이터 (날짜별 그룹화, multi-day 일정 포함)
  var timelineData: [HomeModels.TimelineSection] {
    var grouped: [Date: [ScheduleModel]] = [:]
    let calendar = Calendar.scheduleDisplay
    for schedule in filteredSchedules {
      let startDay = calendar.startOfDay(for: schedule.startAt)
      let endDay = calendar.startOfDay(for: schedule.effectiveEndAt)
      var day = startDay
      while day <= endDay {
        grouped[day, default: []].append(schedule)
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
      }
    }

    return grouped
      .sorted { $0.key < $1.key }
      .map { day, schedules in
        HomeModels.TimelineSection(
          day: day,
          schedules: schedules.sorted { $0.startAt < $1.startAt }
        )
      }
  }

  /// 사용 가능한 그룹 목록
  var availableGroups: [HomeModels.GroupInfo] {
    currentUser.groups.map { HomeModels.GroupInfo(id: $0.id, name: $0.name) }
  }

  /// 로딩 중 여부
  var isLoading: Bool {
    // idle은 아직 로딩을 시작하지 않은 초기 상태 — 하나라도 idle이면 초기 로딩 중으로 간주
    let schedulesIdle = !schedulesState.isLoaded && !schedulesState.isFailed && !schedulesState.isLoading
    let personalEventsIdle = !personalEventsState.isLoaded && !personalEventsState.isFailed && !personalEventsState.isLoading
    let recurringEventsIdle = !recurringEventsState.isLoaded && !recurringEventsState.isFailed && !recurringEventsState.isLoading
    if schedulesIdle || personalEventsIdle || recurringEventsIdle {
      return true
    }
    // 하나라도 loading이면 로딩 중
    return schedulesState.isLoading || personalEventsState.isLoading || recurringEventsState.isLoading
  }

  /// 응답 필요 개수 (배지용)
  var pendingResponseCount: Int {
    homeContentSnapshot.pendingSchedules.count
  }

  // MARK: - Calendar Overlay Computed

  /// 오버레이용 전체 일정 (로드된 모든 월에서 합산, 중복 제거)
  private var overlayAllSchedules: [ScheduleModel] {
    var seen = Set<String>()
    return overlaySchedulesByMonth.values.flatMap { $0 }.filter { seen.insert($0.id).inserted }
  }

  /// 오버레이용 전체 개인 일정 (로드된 모든 월에서 합산, 중복 제거)
  private var overlayAllPersonalEvents: [PersonalEventModel] {
    var seen = Set<String>()
    return overlayPersonalEventsByMonth.values.flatMap { $0 }.filter { seen.insert($0.id).inserted }
  }

  /// 공휴일 날짜 Set
  var overlayHolidayDateSet: Set<Date> {
    Set(overlayHolidaysByDate.keys)
  }

  /// 오버레이 캘린더에 표시할 날짜 셀 배열
  var overlayCalendarDays: [OverlayCalendarModels.DayItem] {
    OverlayCalendarModels.generateMonthDays(
      for: overlayCalendarMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate,
      holidayDates: overlayHolidayDateSet
    )
  }

  /// 이전 월 캘린더 날짜 셀 배열
  var overlayPrevMonthDays: [OverlayCalendarModels.DayItem] {
    guard let prevMonth = Calendar.scheduleDisplay.date(byAdding: .month, value: -1, to: overlayCalendarMonth)
    else { return [] }
    return OverlayCalendarModels.generateMonthDays(
      for: prevMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate,
      holidayDates: overlayHolidayDateSet
    )
  }

  /// 다음 월 캘린더 날짜 셀 배열
  var overlayNextMonthDays: [OverlayCalendarModels.DayItem] {
    guard let nextMonth = Calendar.scheduleDisplay.date(byAdding: .month, value: 1, to: overlayCalendarMonth)
    else { return [] }
    return OverlayCalendarModels.generateMonthDays(
      for: nextMonth,
      selectedDate: overlaySelectedDate,
      scheduleCountsByDate: overlayScheduleCountsByDate,
      scheduleIndicatorsByDate: overlayScheduleIndicatorsByDate,
      holidayDates: overlayHolidayDateSet
    )
  }

  /// 선택된 날짜의 실제 일정 아이템 (일정 + 개인 일정)
  var overlaySelectedDateScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.scheduleDisplay
    let selectedDay = calendar.startOfDay(for: overlaySelectedDate)
    guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) else { return [] }

    let scheduleItems = overlayAllSchedules
      .filter { $0.startAt < nextDay && $0.effectiveEndAt >= selectedDay }
      .map { HomeModels.ScheduleItem.schedule($0) }
    let eventItems = overlayAllPersonalEvents
      .filter { $0.startAt < nextDay && $0.effectiveEndAt >= selectedDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (scheduleItems + eventItems).sorted { $0.startAt < $1.startAt }
  }

  /// 선택된 날짜의 전일 일정 아이템
  var overlayPrevDayScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.scheduleDisplay
    guard let prevDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: overlaySelectedDate)),
          let nextDay = calendar.date(byAdding: .day, value: 1, to: prevDay) else { return [] }
    let scheduleItems = overlayAllSchedules
      .filter { $0.startAt < nextDay && $0.effectiveEndAt >= prevDay }
      .map { HomeModels.ScheduleItem.schedule($0) }
    let eventItems = overlayAllPersonalEvents
      .filter { $0.startAt < nextDay && $0.effectiveEndAt >= prevDay }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (scheduleItems + eventItems).sorted { $0.startAt < $1.startAt }
  }

  /// 선택된 날짜의 다음일 일정 아이템
  var overlayNextDayScheduleItems: [HomeModels.ScheduleItem] {
    let calendar = Calendar.scheduleDisplay
    let selectedDay = calendar.startOfDay(for: overlaySelectedDate)
    guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: selectedDay),
          let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: nextDayStart) else { return [] }
    let scheduleItems = overlayAllSchedules
      .filter { $0.startAt < nextDayEnd && $0.effectiveEndAt >= nextDayStart }
      .map { HomeModels.ScheduleItem.schedule($0) }
    let eventItems = overlayAllPersonalEvents
      .filter { $0.startAt < nextDayEnd && $0.effectiveEndAt >= nextDayStart }
      .map { HomeModels.ScheduleItem.personalEvent($0) }
    return (scheduleItems + eventItems).sorted { $0.startAt < $1.startAt }
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
    let calendar = Calendar.scheduleDisplay
    let colorMap = overlayGroupColorMap
    var indicators: [Date: [OverlayCalendarModels.ScheduleIndicator]] = [:]

    for schedule in overlayAllSchedules {
      let color = colorMap[schedule.groupId] ?? Color.pmindigo.n500
      let startDay = calendar.startOfDay(for: schedule.startAt)
      let endDay = calendar.startOfDay(for: schedule.effectiveEndAt)
      let isMultiDay = startDay != endDay
      var day = startDay
      while day <= endDay {
        let position: OverlayCalendarModels.SpanPosition = {
          if !isMultiDay { return .single }
          if day == startDay { return .start }
          if day == endDay { return .end }
          return .middle
        }()
        indicators[day, default: []].append(
          .init(id: "\(schedule.id)_\(day.timeIntervalSince1970)", color: color, title: schedule.title, spanPosition: position,
                startAt: schedule.startAt, endAt: schedule.endAt, emoji: schedule.emoji)
        )
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
      }
    }

    for event in overlayAllPersonalEvents {
      let startDay = calendar.startOfDay(for: event.startAt)
      let endDay = calendar.startOfDay(for: event.effectiveEndAt)
      let isMultiDay = startDay != endDay
      var day = startDay
      while day <= endDay {
        let position: OverlayCalendarModels.SpanPosition = {
          if !isMultiDay { return .single }
          if day == startDay { return .start }
          if day == endDay { return .end }
          return .middle
        }()
        indicators[day, default: []].append(
          .init(id: "\(event.id)_\(day.timeIntervalSince1970)", color: OverlayCalendarModels.ScheduleIndicator.personalColor, title: event.title, spanPosition: position,
                startAt: event.startAt, endAt: event.endAt, emoji: event.emoji)
        )
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
      }
    }

    // startAt 순 정렬
    for (key, value) in indicators {
      indicators[key] = value.sorted { lhs, rhs in
        let lhsId = lhs.id.components(separatedBy: "_").first ?? lhs.id
        let rhsId = rhs.id.components(separatedBy: "_").first ?? rhs.id
        let lhsSchedule = overlayAllSchedules.first { $0.id == lhsId }
        let rhsSchedule = overlayAllSchedules.first { $0.id == rhsId }
        let lhsDate = lhsSchedule?.startAt ?? overlayAllPersonalEvents.first { $0.id == lhsId }?.startAt ?? .distantFuture
        let rhsDate = rhsSchedule?.startAt ?? overlayAllPersonalEvents.first { $0.id == rhsId }?.startAt ?? .distantFuture
        return lhsDate < rhsDate
      }
    }

    return indicators
  }

  /// 날짜별 일정 개수 (일정 + 개인 일정)
  private var overlayScheduleCountsByDate: [Date: Int] {
    let calendar = Calendar.scheduleDisplay
    var counts: [Date: Int] = [:]

    // 일정 (multi-day 포함)
    for schedule in overlayAllSchedules {
      let startDay = calendar.startOfDay(for: schedule.startAt)
      let endDay = calendar.startOfDay(for: schedule.effectiveEndAt)
      var day = startDay
      while day <= endDay {
        counts[day, default: 0] += 1
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
      }
    }

    // 개인 일정 (multi-day 포함)
    for event in overlayAllPersonalEvents {
      let startDay = calendar.startOfDay(for: event.startAt)
      let endDay = calendar.startOfDay(for: event.effectiveEndAt)
      var day = startDay
      while day <= endDay {
        counts[day, default: 0] += 1
        guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
        day = next
      }
    }

    return counts
  }
}
