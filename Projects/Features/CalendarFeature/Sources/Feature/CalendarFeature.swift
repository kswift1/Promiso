// MARK: - CalendarFeature.swift
// 캘린더 Feature - TCA Reducer

import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients
import SharedFeature
import CreatePromiseFeature
import ResourceKit

// MARK: - Feature Namespace

public enum CalendarFeature {}

// MARK: - Feature Implementation

extension CalendarFeature {

  // MARK: - Status Filter

  public enum StatusFilter: String, Equatable, CaseIterable, Sendable, Hashable {
    case all
    case needResponse
    case waitingConfirmation
    case confirmed
    case completed
    case failed

    /// all 제외한 개별 필터 Set
    public static let allIndividualFilters: Set<StatusFilter> = Set(allCases.filter { $0 != .all })
  }

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    /// 모드 전환 애니메이션 대기 시간 (나노초)
    private static let transitionAnimationDuration: UInt64 = 300_000_000

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 사용자 정보 (RootTab과 참조 공유)
      @Shared var currentUser: UserPrivateModel

      /// 그룹 멤버 캐시 (전역 공유, groupId → members)
      @Shared(.inMemory(AppConstants.SharedState.groupMembersCache))
      var groupMembersCache: [String: [UserPublicModel]] = [:]

      /// onAppear 최초 실행 여부
      var hasAppeared: Bool = false

      /// 표시 모드 (주간/월간/월간확장)
      public var displayMode: CalendarDisplayMode = .month

      /// 현재 주의 시작일
      var currentWeekStart: Date

      /// 현재 월
      var currentMonth: Date

      /// 선택된 날짜
      var selectedDate: Date

      /// 월별 약속 캐시 (키: 월 시작일)
      var cachedPromisesByMonth: [Date: [PromiseModel]] = [:]

      /// 이미 로드된 월 (중복 요청 방지)
      var loadedMonths: Set<Date> = []

      /// 약속 로딩 중인 월 목록
      var loadingMonths: Set<Date> = []

      /// 약속 로딩 중 여부 (computed)
      var isLoadingPromises: Bool { !loadingMonths.isEmpty }

      /// 주간 ↔ 월간 전환 애니메이션 진행 중
      var isTransitioning: Bool = false

      /// 스크롤 위치 (리스트에서 스크롤할 날짜)
      var scrolledID: Date?

      // MARK: - EventKit 관련 상태

      /// 월별 시스템 캘린더 이벤트 캐시 (키: 월 시작일)
      var cachedCalendarEventsByMonth: [Date: [CalendarEvent]] = [:]

      /// 이미 로드된 캘린더 이벤트 월 (중복 요청 방지)
      var loadedCalendarEventMonths: Set<Date> = []

      /// 캘린더 권한 상태
      var calendarPermissionStatus: CalendarAuthorizationStatus = .notDetermined

      /// 숨김 처리된 캘린더 배너 타입들
      var hiddenCalendarBannerTypes: Set<CalendarAuthorizationStatus> = []

      // MARK: - 날씨 관련

      /// 날씨 캐시 (HomeFeature와 공유)
      @Shared(.inMemory("weatherCache"))
      var weatherCache: [String: WeatherInfo] = [:]

      // MARK: - 공휴일 관련

      /// 공휴일 맵 (날짜 → 공휴일 이름)
      var holidaysByDate: [Date: String] = [:]
      /// 로드된 공휴일 연도
      var loadedHolidayYears: Set<Int> = []

      // MARK: - 개인 일정 관련

      /// 월별 개인 일정 캐시 (키: 월 시작일)
      var cachedPersonalEventsByMonth: [Date: [PersonalEventModel]] = [:]

      /// 이미 로드된 개인 일정 월 (중복 요청 방지)
      var loadedPersonalEventMonths: Set<Date> = []

      /// 개인 일정 로딩 중인 월 목록
      var loadingPersonalEventMonths: Set<Date> = []

      // MARK: - 반복 개인 일정 관련

      /// 반복 개인 일정 규칙 목록 (한 번만 로드)
      var recurringEvents: [RecurringPersonalEventModel] = []

      /// 반복 일정 로드 완료 여부
      var isRecurringEventsLoaded: Bool = false

      // MARK: - Filter

      /// 선택된 그룹 ID (빈 Set = 전체, 필터 해제)
      var selectedGroupIds: Set<String> = []

      /// 선택된 상태 필터 (전체 = allIndividualFilters)
      var selectedStatusFilters: Set<StatusFilter> = StatusFilter.allIndividualFilters

      /// 개인 일정 표시 여부
      var showPersonalEvents: Bool = true

      /// 시스템 캘린더 이벤트 표시 여부
      var showCalendarEvents: Bool = true

      /// 필터 시트 표시 여부
      var isFilterSheetPresented: Bool = false

      /// 그룹 정렬 옵션 (그룹 탭과 동일)
      var groupSortOption: GroupSortOption = .joinedRecent

      // MARK: - Group 관련

      /// 정렬된 그룹 목록 (필터 시트용)
      var sortedGroups: [UserGroupInfo] {
        switch groupSortOption {
        case .joinedRecent:
          return currentUser.groups.sorted { ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast) }
        case .joinedOldest:
          return currentUser.groups.sorted { ($0.joinedAt ?? .distantPast) < ($1.joinedAt ?? .distantPast) }
        case .nameAscending:
          return currentUser.groups.sorted { $0.name < $1.name }
        case .nameDescending:
          return currentUser.groups.sorted { $0.name > $1.name }
        case .custom(let order):
          if order.isEmpty { return currentUser.groups }
          let groupDict = Dictionary(uniqueKeysWithValues: currentUser.groups.map { ($0.id, $0) })
          let ordered = order.compactMap { groupDict[$0] }
          let remaining = currentUser.groups.filter { !Set(order).contains($0.id) }
          return ordered + remaining
        }
      }

      /// 사용자 그룹 정보 조회용 (키: groupId)
      var userGroupsMap: [String: UserGroupInfo] {
        Dictionary(uniqueKeysWithValues: currentUser.groups.map { ($0.id, $0) })
      }

      // MARK: - Navigation

      /// 네비게이션 경로 (약속 상세 등)
      var path = StackState<Path.State>()
      /// 삭제 확인 알럿
      @Presents var deleteAlert: AlertState<DeleteAlertAction>?
      /// 삭제 대상 일정 아이템
      var scheduleItemToDelete: CalendarFeature.ScheduleItem?
      /// 약속 수정 시트
      @Presents var editPromise: EditPromise.Feature.State?
      /// 개인 일정 수정 시트
      @Presents var editPersonalEvent: CreatePersonalEvent.Feature.State?
      /// 반복 개인 일정 수정 시트
      @Presents var editRecurringPersonalEvent: CreateRecurringPersonalEvent.Feature.State?
      /// 약속 생성 시트
      @Presents var createPromise: CreatePromise.Feature.State?
      /// 약속 공유 시트용
      var sharePromise: PromiseModel?
      var isKakaoPromiseSharing: Bool = false
      var systemShareText: String?
      /// 화면 토스트 메시지
      var toastMessage: ToastMessage?

      // MARK: - Computed Properties

      /// 현재 사용자 ID
      var currentUserId: String { currentUser.userId }

      /// 현재 사용자가 속한 그룹 ID 목록
      var userGroupIds: [String] { currentUser.groups.map { $0.id } }

      public init(
        currentUser: Shared<UserPrivateModel>,
        displayMode: CalendarDisplayMode = .month,
        selectedDate: Date = Date()
      ) {
        self._currentUser = currentUser
        self.displayMode = displayMode
        self.selectedDate = selectedDate
        self.currentWeekStart = selectedDate.startOfWeek
        self.currentMonth = selectedDate.startOfMonth
      }

      // MARK: - Computed Properties

      /// 현재 주의 날짜들 (일~토)
      var weekDates: [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
          calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)
        }
      }

      /// 날짜별로 그룹화된 약속 (현재 월 캐시에서 조회)
      var promisesByDate: [Date: [PromiseModel]] {
        let calendar = Calendar.current
        var grouped: [Date: [PromiseModel]] = [:]

        // 월간 모드: currentMonth 기준 / 주간 모드: selectedDate 기준
        let currentMonthKey = currentMonth.startOfMonth
        let allPromises = filteredPromises(for: currentMonthKey)

        // 날짜별 그룹화 — 시작일부터 종료일까지 모든 날짜에 포함
        for promise in allPromises {
          let startDay = calendar.startOfDay(for: promise.startAt)
          let endDay = calendar.startOfDay(for: promise.effectiveEndAt)

          var day = startDay
          var safetyCount = 0
          while day <= endDay, safetyCount < 31 {
            grouped[day, default: []].append(promise)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
            safetyCount += 1
          }
        }

        // 시간순 정렬
        for (date, promises) in grouped {
          grouped[date] = promises.sorted { $0.startAt < $1.startAt }
        }

        return grouped
      }

      /// 날짜별로 그룹화된 캘린더 이벤트
      var calendarEventsByDate: [Date: [CalendarEvent]] {
        guard showCalendarEvents else { return [:] }
        let calendar = Calendar.current
        let monthEvents = uniqueItemsAcrossMonths(from: cachedCalendarEventsByMonth)
        var grouped: [Date: [CalendarEvent]] = [:]

        for event in monthEvents {
          let startDay = calendar.startOfDay(for: event.startDate)
          let endDay = calendar.startOfDay(for: event.endDate)

          var day = startDay
          var safetyCount = 0
          while day <= endDay, safetyCount < 31 {
            grouped[day, default: []].append(event)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
            safetyCount += 1
          }
        }

        for (date, events) in grouped {
          grouped[date] = events.sorted { $0.startDate < $1.startDate }
        }

        return grouped
      }

      /// 날짜별로 그룹화된 개인 일정
      var personalEventsByDate: [Date: [PersonalEventModel]] {
        guard showPersonalEvents else { return [:] }
        let calendar = Calendar.current
        let currentMonthKey = currentMonth.startOfMonth
        let monthEvents = cachedPersonalEventsByMonth[currentMonthKey] ?? []
        var grouped: [Date: [PersonalEventModel]] = [:]

        for event in monthEvents {
          let startDay = calendar.startOfDay(for: event.startAt)
          let endDay = calendar.startOfDay(for: event.effectiveEndAt)

          var day = startDay
          var safetyCount = 0
          while day <= endDay, safetyCount < 31 {
            grouped[day, default: []].append(event)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = nextDay
            safetyCount += 1
          }
        }

        for (date, events) in grouped {
          grouped[date] = events.sorted { $0.startAt < $1.startAt }
        }

        return grouped
      }

      /// 표시할 섹션 날짜들
      var sectionDates: [Date] {
        if displayMode == .week {
          return weekDates.sorted()
        } else {
          let calendar = Calendar.current
          let monthStart = currentMonth.startOfMonth
          guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
          }

          var allDates = Set(promisesByDate.keys)
          allDates.formUnion(calendarEventsByDate.keys)
          allDates.formUnion(personalEventsByDate.keys)
          allDates.formUnion(holidaysByDate.keys)
          // 반복 일정 날짜 포함
          if showPersonalEvents {
            let cal = Calendar.current
            let instances = recurringEvents.flatMap {
              RecurringEventExpander.expand(event: $0, from: monthStart, to: monthEnd)
            }
            for instance in instances {
              allDates.insert(cal.startOfDay(for: instance.startAt))
            }
          }

          return allDates
            .filter { $0 >= monthStart && $0 < monthEnd }
            .sorted()
        }
      }

      /// 이벤트가 있는 날 수 (월간 헤더 표시용)
      var datesWithEvents: Int {
        let calendar = Calendar.current
        let monthStart = currentMonth.startOfMonth
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return 0 }

        var allDates = Set(promisesByDate.keys)
        allDates.formUnion(calendarEventsByDate.keys)
        allDates.formUnion(personalEventsByDate.keys)

        return allDates.filter { $0 >= monthStart && $0 < monthEnd }.count
      }

      /// 헤더 타이틀
      var headerTitle: String {
        if displayMode == .week {
          return LocalizedDateFormatters.monthWeek.string(from: currentWeekStart)
        } else {
          return LocalizedDateFormatters.yearMonth.string(from: currentMonth)
        }
      }

      /// 선택된 날짜가 오늘인지
      var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
      }

      /// 초기 로딩 중 (데이터가 없고 로딩 중일 때)
      var isInitialLoading: Bool {
        isLoadingPromises && loadedMonths.isEmpty
      }

      /// 필터 활성 여부 (헤더 뱃지용)
      var isFilterActive: Bool {
        selectedGroupIds != Set(currentUser.groups.map(\.id)) || !showPersonalEvents || selectedStatusFilters != StatusFilter.allIndividualFilters || !showCalendarEvents
      }

      // MARK: - Group Color Map

      /// 그룹별 컬러 맵 (groupId → Color)
      var groupColorMap: [String: Color] {
        Dictionary(
          uniqueKeysWithValues: currentUser.groups.compactMap { group in
            group.groupColor.map { (group.id, $0.color) }
          }
        )
      }

      // MARK: - Schedule Indicators

      /// 현재 월 ± 1개월의 캐시 데이터를 수집하고 ID 기준 중복 제거
      private func uniqueItemsAcrossMonths<T: Identifiable>(
        from cache: [Date: [T]]
      ) -> [T] {
        let calendar = Calendar.current
        let monthKey = currentMonth.startOfMonth
        let prevKey = calendar.date(byAdding: .month, value: -1, to: monthKey)?.startOfMonth
        let nextKey = calendar.date(byAdding: .month, value: 1, to: monthKey)?.startOfMonth
        let allItems = [prevKey, monthKey, nextKey]
          .compactMap { $0 }
          .flatMap { cache[$0] ?? [] }
        return Dictionary(grouping: allItems, by: \.id).compactMap(\.value.first)
      }

      /// 날짜별 일정 인디케이터 (월간 그리드 셀용)
      var scheduleIndicatorsByDate: [Date: [CalendarFeature.ScheduleIndicator]] {
        let calendar = Calendar.current
        let colorMap = groupColorMap
        let groupsMap = userGroupsMap
        var indicators: [Date: [CalendarFeature.ScheduleIndicator]] = [:]

        // 약속 — 3페이지 페이저를 위해 현재 월 ± 1개월 포함
        let currentMonthKey = currentMonth.startOfMonth
        let prevMonthKey = calendar.date(byAdding: .month, value: -1, to: currentMonthKey)?.startOfMonth
        let nextMonthKey = calendar.date(byAdding: .month, value: 1, to: currentMonthKey)?.startOfMonth
        let allPromises: [PromiseModel] = [prevMonthKey, currentMonthKey, nextMonthKey].compactMap { $0 }.flatMap { filteredPromises(for: $0) }
        // 중복 제거 (날짜 경계 약속이 여러 월에 걸칠 수 있음)
        let uniquePromises = Dictionary(grouping: allPromises, by: \.id).compactMap(\.value.first)
        for promise in uniquePromises {
          let color = colorMap[promise.groupId] ?? Color.pmindigo.n500
          let groupInfo = groupsMap[promise.groupId]
          spreadIndicators(
            startAt: promise.startAt, endAt: promise.effectiveEndAt, into: &indicators
          ) { day, position in
            .init(
              id: "\(promise.id)_\(day.timeIntervalSince1970)",
              color: color,
              title: promise.title,
              spanPosition: position,
              startAt: promise.startAt,
              endAt: promise.endAt,
              emoji: promise.emoji,
              sourceType: .promise(id: promise.id, groupId: promise.groupId),
              description: promise.description,
              locationName: promise.location?.name,
              imageUrls: promise.imageUrls,
              groupName: groupInfo?.name,
              groupImageUrl: groupInfo?.imageUrl
            )
          }
        }

        // 개인 일정
        if showPersonalEvents {
          let uniquePersonalEvents = uniqueItemsAcrossMonths(from: cachedPersonalEventsByMonth)
          for event in uniquePersonalEvents {
            spreadIndicators(
              startAt: event.startAt, endAt: event.effectiveEndAt, into: &indicators
            ) { day, position in
              .init(
                id: "\(event.id)_\(day.timeIntervalSince1970)",
                color: CalendarFeature.ScheduleIndicator.personalColor,
                title: event.title,
                spanPosition: position,
                startAt: event.startAt,
                endAt: event.endAt,
                emoji: event.emoji,
                sourceType: .personalEvent(id: event.id),
                description: event.description,
                locationName: event.location?.name,
                imageUrls: event.imageUrls
              )
            }
          }
        }

        // 시스템 캘린더 이벤트 (필터 OFF 시 제외)
        guard showCalendarEvents else { return indicators }
        let uniqueCalendarEvents = uniqueItemsAcrossMonths(from: cachedCalendarEventsByMonth)
        for event in uniqueCalendarEvents {
          spreadIndicators(
            startAt: event.startDate, endAt: event.endDate, into: &indicators
          ) { day, position in
            .init(
              id: "cal_\(event.id)_\(day.timeIntervalSince1970)",
              color: event.calendarColor,
              title: event.title,
              spanPosition: position,
              startAt: event.startDate,
              endAt: event.endDate,
              sourceType: .calendarEvent(id: event.id)
            )
          }
        }

        // 반복 개인 일정 (3페이지 범위로 확장)
        if showPersonalEvents {
          let indicatorRangeStart = prevMonthKey ?? currentMonthKey
          let indicatorRangeEnd: Date = {
            let base = nextMonthKey ?? currentMonthKey
            return calendar.date(byAdding: .month, value: 1, to: base) ?? base
          }()
          for event in recurringEvents {
            let instances = RecurringEventExpander.expand(
              event: event,
              from: indicatorRangeStart,
              to: indicatorRangeEnd
            )
            for instance in instances {
              let effectiveEnd = instance.endAt ?? instance.startAt
              spreadIndicators(
                startAt: instance.startAt, endAt: effectiveEnd, into: &indicators
              ) { day, position in
                .init(
                  id: "recurring_\(instance.id)_\(day.timeIntervalSince1970)",
                  color: CalendarFeature.ScheduleIndicator.personalColor,
                  title: "\(instance.emoji.map { $0 + " " } ?? "")\(instance.title)",
                  spanPosition: position,
                  startAt: instance.startAt,
                  endAt: instance.endAt,
                  sourceType: .recurringPersonalEvent(recurringEventId: instance.recurringEventId),
                  locationName: instance.location?.name
                )
              }
            }
          }
        }

        // startAt 순 정렬
        for (key, value) in indicators {
          indicators[key] = value.sorted { $0.startAt < $1.startAt }
        }

        return indicators
      }

      // MARK: - Schedule Items for Timeline

      /// 선택된 날짜의 타임라인 아이템
      var selectedDateScheduleItems: [CalendarFeature.ScheduleItem] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) else { return [] }
        return buildScheduleItems(from: selectedDay, to: nextDay)
      }

      /// 전일 타임라인 아이템
      var prevDayScheduleItems: [CalendarFeature.ScheduleItem] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let prevDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) else { return [] }
        return buildScheduleItems(from: prevDay, to: selectedDay)
      }

      /// 다음일 타임라인 아이템
      var nextDayScheduleItems: [CalendarFeature.ScheduleItem] {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: selectedDay),
              let dayAfter = calendar.date(byAdding: .day, value: 2, to: selectedDay) else { return [] }
        return buildScheduleItems(from: nextDay, to: dayAfter)
      }

      /// 캐시된 약속에서 ID로 약속을 검색합니다. O(N) 복잡도를 가집니다. (N: 총 캐시된 약속 수)
      func findCachedPromise(id: String) -> PromiseModel? {
        cachedPromisesByMonth.values.lazy.flatMap { $0 }.first { $0.id == id }
      }

      /// 필터가 적용된 약속 목록 (그룹 + 상태 필터)
      func filteredPromises(for monthKey: Date) -> [PromiseModel] {
        var promises = cachedPromisesByMonth[monthKey] ?? []

        // 그룹 필터
        promises = promises.filter { selectedGroupIds.contains($0.groupId) }

        // 상태 필터 (allIndividualFilters = 전체, 필터 안 함)
        if selectedStatusFilters != StatusFilter.allIndividualFilters {
          promises = promises.filter { promise in
            selectedStatusFilters.contains { filter in
              switch filter {
              case .all:
                return false
              case .needResponse:
                return promise.myVoteStatus(userId: currentUserId) == .pending && !promise.isVotingClosed
              case .waitingConfirmation:
                let totalMembers = groupMembersCache[promise.groupId]?.count
                let status = promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: totalMembers)
                return status == .responded
              case .confirmed:
                let hasResponded = promise.myVoteStatus(userId: currentUserId) != .pending || promise.isVotingClosed
                return promise.isConfirmed && !promise.isPast && hasResponded
              case .completed:
                return promise.isConfirmed && promise.isPast
              case .failed:
                let totalMembers = groupMembersCache[promise.groupId]?.count
                let status = promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: totalMembers)
                return status == .failed
              }
            }
          }
        }

        return promises
      }

      private func buildScheduleItems(from start: Date, to end: Date) -> [CalendarFeature.ScheduleItem] {
        // start/end가 속한 월을 모두 포함하여 월 경계 누락 방지
        let monthKeys = Set([start.startOfMonth, end.startOfMonth, selectedDate.startOfMonth])
        let allPromises = Dictionary(grouping: monthKeys.flatMap { filteredPromises(for: $0) }, by: \.id).compactMap(\.value.first)

        let promiseItems = allPromises
          .filter { $0.startAt < end && $0.effectiveEndAt >= start }
          .map { CalendarFeature.ScheduleItem.promise($0) }
        let personalItems: [CalendarFeature.ScheduleItem] = showPersonalEvents
          ? {
            let allPersonalEvents = monthKeys.flatMap { cachedPersonalEventsByMonth[$0] ?? [] }
            let relevantPersonalEvents = Dictionary(grouping: allPersonalEvents, by: \.id).compactMap(\.value.first)
            return relevantPersonalEvents
              .filter { $0.startAt < end && $0.effectiveEndAt >= start }
              .map { CalendarFeature.ScheduleItem.personalEvent($0) }
          }()
          : []
        let calendarItems: [CalendarFeature.ScheduleItem] = showCalendarEvents
          ? {
            let monthKeys = Set([start.startOfMonth, end.startOfMonth])
            let allCalendarEvents = monthKeys.flatMap { cachedCalendarEventsByMonth[$0] ?? [] }
            let relevantEvents = Dictionary(grouping: allCalendarEvents, by: \.id).compactMap(\.value.first)
            return relevantEvents
              .filter { $0.startDate < end && $0.endDate >= start }
              .map { CalendarFeature.ScheduleItem.calendarEvent($0) }
          }()
          : []
        let recurringItems: [CalendarFeature.ScheduleItem] = showPersonalEvents
          ? recurringEvents.flatMap { event in
            RecurringEventExpander.expand(event: event, from: start, to: end)
          }.map { .recurringPersonalEvent($0) }
          : []
        return (promiseItems + personalItems + calendarItems + recurringItems).sorted { $0.startAt < $1.startAt }
      }

      /// Preview용 필터 미적용 인디케이터 (특정 날짜 하나만 계산)
      func unfilteredIndicators(for date: Date) -> [CalendarFeature.ScheduleIndicator] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let colorMap = groupColorMap
        let groupsMap = userGroupsMap
        var indicators: [CalendarFeature.ScheduleIndicator] = []

        // 약속 (필터 미적용 — 전체 그룹)
        let monthKey = date.startOfMonth
        let allPromises = cachedPromisesByMonth[monthKey] ?? []
        for promise in allPromises where promise.startAt < dayEnd && promise.effectiveEndAt >= dayStart {
          let color = colorMap[promise.groupId] ?? Color.pmindigo.n500
          let groupInfo = groupsMap[promise.groupId]
          indicators.append(.init(
            id: "\(promise.id)_\(dayStart.timeIntervalSince1970)",
            color: color,
            title: promise.title,
            spanPosition: .single,
            startAt: promise.startAt,
            endAt: promise.endAt,
            emoji: promise.emoji,
            sourceType: .promise(id: promise.id, groupId: promise.groupId),
            description: promise.description,
            locationName: promise.location?.name,
            imageUrls: promise.imageUrls,
            groupName: groupInfo?.name,
            groupImageUrl: groupInfo?.imageUrl
          ))
        }

        // 개인 일정 (필터 미적용)
        let allPersonalEvents = cachedPersonalEventsByMonth[monthKey] ?? []
        for event in allPersonalEvents where event.startAt < dayEnd && event.effectiveEndAt >= dayStart {
          indicators.append(.init(
            id: "\(event.id)_\(dayStart.timeIntervalSince1970)",
            color: CalendarFeature.ScheduleIndicator.personalColor,
            title: event.title,
            spanPosition: .single,
            startAt: event.startAt,
            endAt: event.endAt,
            emoji: event.emoji,
            sourceType: .personalEvent(id: event.id),
            description: event.description,
            locationName: event.location?.name,
            imageUrls: event.imageUrls
          ))
        }

        // 시스템 캘린더 (필터 미적용)
        let calendarMonthKey = date.startOfMonth
        let allCalendarEvents = cachedCalendarEventsByMonth[calendarMonthKey] ?? []
        for event in allCalendarEvents where event.startDate < dayEnd && event.endDate >= dayStart {
          indicators.append(.init(
            id: "cal_\(event.id)_\(dayStart.timeIntervalSince1970)",
            color: event.calendarColor,
            title: event.title,
            spanPosition: .single,
            startAt: event.startDate,
            endAt: event.endDate,
            sourceType: .calendarEvent(id: event.id)
          ))
        }

        return indicators.sorted { $0.startAt < $1.startAt }
      }

      /// 일정을 날짜별로 펼쳐서 인디케이터 딕셔너리에 추가
      private func spreadIndicators(
        startAt: Date,
        endAt: Date,
        into indicators: inout [Date: [CalendarFeature.ScheduleIndicator]],
        makeIndicator: (Date, CalendarFeature.SpanPosition) -> CalendarFeature.ScheduleIndicator
      ) {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startAt)
        let endDay = calendar.startOfDay(for: endAt)
        let isMultiDay = startDay != endDay
        var day = startDay
        while day <= endDay {
          let position: CalendarFeature.SpanPosition = {
            if !isMultiDay { return .single }
            if day == startDay { return .start }
            if day == endDay { return .end }
            return .middle
          }()
          indicators[day, default: []].append(makeIndicator(day, position))
          guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
          day = next
        }
      }
    }

    // MARK: - Path (Navigation)

    @Reducer(state: .equatable)
    public enum Path {
      case promiseDetail(PromiseDetail.Feature)
      case personalEventDetail(PersonalEventDetail.Feature)
      case recurringPersonalEventDetail(RecurringPersonalEventDetail.Feature)
      case calendarEventDetail(CalendarEventDetailFeature)
    }

    /// 시스템 캘린더 이벤트 상세 (읽기 전용, 최소 Reducer)
    @Reducer
    public struct CalendarEventDetailFeature {
      @ObservableState
      public struct State: Equatable {
        let event: CalendarEvent
      }

      @CasePathable
      public enum Action: Sendable {
        case view(View)

        @CasePathable
        public enum View: Sendable {
          case noop
        }
      }

      public var body: some ReducerOf<Self> {
        EmptyReducer()
      }
    }

    // MARK: - Alert

    @CasePathable
    public enum DeleteAlertAction: Equatable {
      case confirmDelete
    }

    // MARK: - Action

    @CasePathable
    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case path(StackActionOf<Path>)
      case deleteAlert(PresentationAction<DeleteAlertAction>)
      case editPromise(PresentationAction<EditPromise.Feature.Action>)
      case editPersonalEvent(PresentationAction<CreatePersonalEvent.Feature.Action>)
      case editRecurringPersonalEvent(PresentationAction<CreateRecurringPersonalEvent.Feature.Action>)
      case createPromise(PresentationAction<CreatePromise.Feature.Action>)

      @CasePathable
      public enum ViewAction {
        case onAppear
        case toggleDisplayMode
        case selectDate(Date)
        case moveToToday
        case moveToPreviousPeriod
        case moveToNextPeriod
        case promiseTapped(PromiseModel)
        case promiseRespondTapped(PromiseModel)
        case collapseToWeek(Date)
        // TabView 페이징으로 변경된 날짜
        case weekPageChanged(Date)
        case monthPageChanged(Date)
        // 스크롤 관련
        case scrollTo(Date?)
        case resetScroll
        // EventKit 관련
        case requestCalendarPermission
        case openSettings
        case dismissCalendarBanner(CalendarAuthorizationStatus)
        // 개인 일정 탭
        case personalEventTapped(PersonalEventModel)
        // 탭 전환 시 데이터 새로고침
        case refresh
        // 과거 시간 슬롯 일정 생성 차단
        case pastTimeBlocked
        // 토스트 닫힘
        case toastDismissed
        // 타임라인 일정 아이템 탭
        case scheduleItemTapped(CalendarFeature.ScheduleItem)
        case editScheduleItem(CalendarFeature.ScheduleItem)
        case createPersonalEventFromTimeline(startDate: Date, endDate: Date)
        case createPromiseFromTimeline(startDate: Date, endDate: Date)
        case deleteScheduleItem(CalendarFeature.ScheduleItem)
        case shareScheduleItem(CalendarFeature.ScheduleItem)
        case dismissPromiseShareSheet
        case kakaoPromiseShareTapped
        case systemPromiseShareTapped
        case systemShareSheetDismissed
        case indicatorTapped(CalendarFeature.ScheduleIndicator)
        case dayLongPressCreatePersonalEvent(Date)
        case dayLongPressCreatePromise(Date)
        case setDisplayMode(CalendarDisplayMode)
        // 필터 관련
        case filterIconTapped
        case filterGroupToggled(String)
        case filterPersonalEventsToggled
        case filterStatusChanged(StatusFilter)
        case filterCalendarEventsToggled
        case filterReset
        case filterSheetDismissed
      }

      @CasePathable
      public enum InternalAction {
        case transitionCompleted
        // 초기화 관련
        case loadInitialData              // 캐시 초기화 + 약속 로드
        // 약속 데이터 관련 (월 단위 캐싱)
        case fetchPromisesForMonth(Date)  // 특정 월 데이터 로드
        case prefetchAdjacentMonths       // 인접 월 프리페치
        case promisesResponseForMonth(month: Date, Result<[PromiseModel], Error>)
        // EventKit 관련
        case checkCalendarPermission
        case calendarPermissionResponse(CalendarAuthorizationStatus)
        case fetchCalendarEventsForMonth(Date)
        case calendarEventsResponseForMonth(month: Date, Result<[CalendarEvent], Error>)
        // 개인 일정
        case fetchPersonalEventsForMonth(Date)
        case personalEventsResponseForMonth(month: Date, Result<[PersonalEventModel], Error>)
        // 공휴일
        case fetchHolidays(Int)  // 연도
        case holidaysResponse(year: Int, Result<[PublicHoliday], Error>)
        // 설정
        case fetchSettings
        case settingsResponse(Result<UserSettings, Error>)
        // 반복 개인 일정
        case fetchRecurringEvents
        case recurringEventsLoaded([RecurringPersonalEventModel])
        case recurringEventsFailed
        // 공유
        case kakaoPromiseShareResult(KakaoShareResult)
      }

    }

    // MARK: - Cancellation IDs

    private enum CancelID: Hashable {
      case fetchPromisesForMonth(Date)
      case fetchCalendarEventsForMonth(Date)
      case fetchPersonalEventsForMonth(Date)
      case fetchHolidays(Int)
    }

    // MARK: - Dependencies

    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.eventKitClient) var eventKitClient
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.recurringPersonalEventClient) var recurringPersonalEventClient
    @Dependency(\.kakaoShareClient) var kakaoShareClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.holidayClient) var holidayClient

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .path(.element(id: _, action: .promiseDetail(.delegate(.dismiss)))):
          _ = state.path.popLast()
          return .none
        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseDeleted)))):
          _ = state.path.popLast()
          // 데이터 새로고침
          let currentMonth = state.selectedDate.startOfMonth
          state.loadedMonths.remove(currentMonth)
          state.cachedPromisesByMonth.removeValue(forKey: currentMonth)
          return .send(.internal(.fetchPromisesForMonth(currentMonth)))
        case .path(.element(id: _, action: .promiseDetail(.delegate(.promiseUpdated(let promise))))):
          // 로컬 캐시 업데이트
          let monthKey = promise.startAt.startOfMonth
          if var monthPromises = state.cachedPromisesByMonth[monthKey] {
            if let index = monthPromises.firstIndex(where: { $0.id == promise.id }) {
              monthPromises[index] = promise
              state.cachedPromisesByMonth[monthKey] = monthPromises
            }
          }
          return .none
        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventDeleted)))):
          _ = state.path.popLast()
          let eventMonth = state.selectedDate.startOfMonth
          state.loadedPersonalEventMonths.remove(eventMonth)
          state.cachedPersonalEventsByMonth.removeValue(forKey: eventMonth)
          return .send(.internal(.fetchPersonalEventsForMonth(eventMonth)))
        case .path(.element(id: _, action: .personalEventDetail(.delegate(.eventUpdated)))):
          let eventMonth = state.selectedDate.startOfMonth
          state.loadedPersonalEventMonths.remove(eventMonth)
          state.cachedPersonalEventsByMonth.removeValue(forKey: eventMonth)
          return .send(.internal(.fetchPersonalEventsForMonth(eventMonth)))
        case .path(.element(id: _, action: .recurringPersonalEventDetail(.delegate(.eventDeleted(let id))))):
          _ = state.path.popLast()
          _ = id
          state.isRecurringEventsLoaded = false
          return .send(.internal(.fetchRecurringEvents))
        case .path(.element(id: _, action: .recurringPersonalEventDetail(.delegate(.eventUpdated(let updated))))):
          if let index = state.recurringEvents.firstIndex(where: { $0.id == updated.id }) {
            state.recurringEvents[index] = updated
          }
          _ = state.path.popLast()
          return .none
        case .path:
          return .none

        case .editPromise(.presented(.delegate(.cancelled))):
        state.editPromise = nil
        return .none

      case .editPromise(.presented(.delegate(.promiseUpdated(let promise)))):
        state.editPromise = nil
        let monthKey = promise.startAt.startOfMonth
        if var monthPromises = state.cachedPromisesByMonth[monthKey] {
          if let index = monthPromises.firstIndex(where: { $0.id == promise.id }) {
            monthPromises[index] = promise
            state.cachedPromisesByMonth[monthKey] = monthPromises
          }
        }
        return .none

      case .editPromise:
        return .none

      case .editPersonalEvent(.presented(.delegate(.eventCreated))):
        state.editPersonalEvent = nil
        let createdMonth = state.selectedDate.startOfMonth
        state.loadedPersonalEventMonths.remove(createdMonth)
        state.cachedPersonalEventsByMonth.removeValue(forKey: createdMonth)
        return .send(.internal(.fetchPersonalEventsForMonth(createdMonth)))

      case .editPersonalEvent(.presented(.delegate(.eventUpdated))):
        state.editPersonalEvent = nil
        let updatedMonth = state.selectedDate.startOfMonth
        state.loadedPersonalEventMonths.remove(updatedMonth)
        state.cachedPersonalEventsByMonth.removeValue(forKey: updatedMonth)
        return .send(.internal(.fetchPersonalEventsForMonth(updatedMonth)))

      case .editPersonalEvent(.presented(.delegate(.dismiss))):
        state.editPersonalEvent = nil
        return .none

      case .editPersonalEvent:
        return .none

      case .editRecurringPersonalEvent(.presented(.delegate(.eventCreated))),
           .editRecurringPersonalEvent(.presented(.delegate(.eventUpdated))):
        state.editRecurringPersonalEvent = nil
        state.isRecurringEventsLoaded = false
        return .send(.internal(.fetchRecurringEvents))

      case .editRecurringPersonalEvent(.presented(.delegate(.dismiss))):
        state.editRecurringPersonalEvent = nil
        return .none

      case .editRecurringPersonalEvent:
        return .none

      case .createPromise(.presented(.delegate(.promiseCreated))):
        state.createPromise = nil
        let currentMonth = state.selectedDate.startOfMonth
        return .send(.internal(.fetchPromisesForMonth(currentMonth)))

      case .createPromise(.presented(.delegate(.dismiss))):
        state.createPromise = nil
        return .none

      case .createPromise(.presented(.delegate(.createGroupRequested))):
        state.createPromise = nil
        return .none

      case .createPromise:
        return .none

      case .deleteAlert(.presented(.confirmDelete)):
          guard let item = state.scheduleItemToDelete else { return .none }
          state.scheduleItemToDelete = nil
          switch item {
          case .promise(let promise):
            let currentMonth = state.selectedDate.startOfMonth
            return .run { [promiseClient] send in
              try await promiseClient.deletePromise(promise.id)
              await send(.internal(.fetchPromisesForMonth(currentMonth)))
            }
          case .personalEvent(let event):
            let eventMonth = event.startAt.startOfMonth
            state.loadedPersonalEventMonths.remove(eventMonth)
            return .run { [personalEventClient] send in
              try await personalEventClient.deleteEvent(event.id)
              await send(.internal(.fetchPersonalEventsForMonth(eventMonth)))
            }
          case .calendarEvent:
            return .none
          case .recurringPersonalEvent:
            return .none
          }

        case .deleteAlert:
          state.scheduleItemToDelete = nil
          return .none
        }
      }
      .ifLet(\.$deleteAlert, action: \.deleteAlert)
      .ifLet(\.$editPromise, action: \.editPromise) {
        EditPromise.Feature()
      }
      .ifLet(\.$editPersonalEvent, action: \.editPersonalEvent) {
        CreatePersonalEvent.Feature()
      }
      .ifLet(\.$editRecurringPersonalEvent, action: \.editRecurringPersonalEvent) {
        CreateRecurringPersonalEvent.Feature()
      }
      .ifLet(\.$createPromise, action: \.createPromise) {
        CreatePromise.Feature()
      }
      .forEach(\.path, action: \.path)
    }

    // MARK: - View Action Handler

    private func handleViewAction(
      _ state: inout State,
      _ action: Action.ViewAction
    ) -> Effect<Action> {
      let calendar = Calendar.current

      switch action {
      case .onAppear:
        // 최초 1회만 실행 (탭 재진입 시 refresh가 담당)
        guard !state.hasAppeared else {
          AppLogger.calendar.debugLog("⏭️ onAppear 스킵 - 이미 초기화됨")
          return .none
        }
        state.hasAppeared = true
        AppLogger.calendar.debugLog("🚀 onAppear - 캘린더 탭 최초 진입")
        // 영속 저장된 배너 숨김 상태 복원
        if let saved = userDefaultsClient.stringForKey(AppConstants.UserDefaults.dismissedCalendarBannerTypes),
           !saved.isEmpty {
          let keys = saved.split(separator: ",").map(String.init)
          for key in keys {
            if let status = CalendarAuthorizationStatus(persistKey: key) {
              state.hiddenCalendarBannerTypes.insert(status)
            }
          }
        }
        // 그룹 필터 초기화 (전체 선택)
        if state.selectedGroupIds.isEmpty {
          state.selectedGroupIds = Set(state.currentUser.groups.map(\.id))
        }
        return .merge(
          .send(.internal(.checkCalendarPermission)),
          .send(.internal(.loadInitialData)),
          .send(.internal(.fetchSettings)),
          .send(.internal(.fetchRecurringEvents))
        )

      case .toggleDisplayMode:
        return applyDisplayModeChange(&state, to: state.displayMode.next)

      case .setDisplayMode(let mode):
        guard mode != state.displayMode else { return .none }
        return applyDisplayModeChange(&state, to: mode)

      case .selectDate(let date):
        let previousMonth = state.selectedDate.startOfMonth
        state.selectedDate = date
        let newMonth = date.startOfMonth

        // 주간 모드: 선택 날짜가 다른 주에 속하면 주간 스트립도 업데이트
        if state.displayMode == .week {
          let newWeekStart = date.startOfWeek
          if newWeekStart != state.currentWeekStart {
            state.currentWeekStart = newWeekStart
          }
          // 월 그리드 동기화
          if state.currentMonth.startOfMonth != newMonth {
            state.currentMonth = newMonth
          }
        }

        // 월이 바뀌면 데이터 로드
        if previousMonth != newMonth {
          return loadDataForMonthIfNeeded(newMonth, state: state)
        }
        return .none

      case .moveToToday:
        let today = Date()
        let previousMonth = state.selectedDate.startOfMonth
        state.selectedDate = today
        state.currentWeekStart = today.startOfWeek
        state.currentMonth = today.startOfMonth
        let newMonth = today.startOfMonth

        // 월이 바뀌면 데이터 로드
        if previousMonth != newMonth {
          return loadDataForMonthIfNeeded(newMonth, state: state)
        }
        return .none

      case .moveToPreviousPeriod:
        let previousMonth = state.currentMonth.startOfMonth
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            state.selectedDate = newWeekStart
            state.currentMonth = newWeekStart.startOfMonth
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: -1, to: state.currentMonth) {
            state.currentMonth = newMonth
          }
        }
        let newMonth = state.currentMonth.startOfMonth
        if previousMonth != newMonth {
          AppLogger.calendar.debugLog("⏪ moveToPreviousPeriod - 월 변경: \(LocalizedDateFormatters.yearMonth.string(from: previousMonth)) → \(LocalizedDateFormatters.yearMonth.string(from: newMonth))")
          return .merge(
            loadDataForMonthIfNeeded(newMonth, state: state),
            .send(.internal(.prefetchAdjacentMonths))
          )
        }
        // 주 모드에서 같은 월 내 이동 시에도 인접 월 프리페치
        return .send(.internal(.prefetchAdjacentMonths))

      case .moveToNextPeriod:
        let previousMonth = state.currentMonth.startOfMonth
        if state.displayMode == .week {
          if let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: state.currentWeekStart) {
            state.currentWeekStart = newWeekStart
            state.selectedDate = newWeekStart
            state.currentMonth = newWeekStart.startOfMonth
          }
        } else {
          if let newMonth = calendar.date(byAdding: .month, value: 1, to: state.currentMonth) {
            state.currentMonth = newMonth
          }
        }
        let newMonth = state.currentMonth.startOfMonth
        if previousMonth != newMonth {
          AppLogger.calendar.debugLog("⏩ moveToNextPeriod - 월 변경: \(LocalizedDateFormatters.yearMonth.string(from: previousMonth)) → \(LocalizedDateFormatters.yearMonth.string(from: newMonth))")
          return .merge(
            loadDataForMonthIfNeeded(newMonth, state: state),
            .send(.internal(.prefetchAdjacentMonths))
          )
        }
        // 주 모드에서 같은 월 내 이동 시에도 인접 월 프리페치
        return .send(.internal(.prefetchAdjacentMonths))

      case .promiseTapped(let promise):
        // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
        let groupMembers = state.groupMembersCache[promise.groupId]
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId,
          groupMembers: groupMembers
        )))
        return .none

      case .promiseRespondTapped(let promise):
        // 즉시 이동 (캐시 hit면 전달, miss면 nil로 전달 → Detail에서 로드)
        let groupMembers = state.groupMembersCache[promise.groupId]
        state.path.append(.promiseDetail(.init(
          promise: promise,
          currentUserId: state.currentUserId,
          groupMembers: groupMembers
        )))
        return .none

      case .collapseToWeek(let date):
        guard state.displayMode.isMonthMode else { return .none }
        state.selectedDate = date
        state.currentWeekStart = date.startOfWeek
        state.displayMode = .week
        state.isTransitioning = true

        // 전환 전에 미리 스크롤 위치 설정 (애니메이션 없이 바로 해당 위치에 표시)
        let targetDate = calendar.startOfDay(for: date)
        state.scrolledID = targetDate

        return .merge(
          .run { send in
            try await Task.sleep(nanoseconds: Self.transitionAnimationDuration)
            await send(.internal(.transitionCompleted))
          },
          .send(.internal(.prefetchAdjacentMonths))
        )

      case .weekPageChanged(let newWeekStart):
        // TabView 페이징으로 주가 변경됨
        state.currentWeekStart = newWeekStart

        // selectedDate가 이미 해당 주 내에 있으면 유지, 아니면 주의 첫날로 동기화
        let selectedWeekStart = state.selectedDate.startOfWeek
        if !calendar.isDate(selectedWeekStart, inSameDayAs: newWeekStart) {
          state.selectedDate = newWeekStart
        }
        AppLogger.calendar.debugLog("📆 weekPageChanged - 주 시작: \(LocalizedDateFormatters.date.string(from: newWeekStart)), 선택된 날짜: \(LocalizedDateFormatters.date.string(from: state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        let monthStart = newWeekStart.startOfMonth
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          AppLogger.calendar.debugLog("🔄 캐시 MISS - 로드 필요: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          AppLogger.calendar.debugLog("✅ 캐시 HIT - 이미 로드됨: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
        }

        // 캘린더 이벤트 로드 (캐시되지 않은 경우만)
        if state.calendarPermissionStatus.canReadEvents && !state.loadedCalendarEventMonths.contains(monthStart) {
          effects.append(.send(.internal(.fetchCalendarEventsForMonth(monthStart))))
        }

        // 개인 일정 로드 (캐시되지 않은 경우만)
        if !state.loadedPersonalEventMonths.contains(monthStart) {
          effects.append(.send(.internal(.fetchPersonalEventsForMonth(monthStart))))
        }

        // 공휴일 로드 (해당 연도가 아직 로드되지 않은 경우)
        let weekYear = calendar.component(.year, from: monthStart)
        if !state.loadedHolidayYears.contains(weekYear) {
          effects.append(.send(.internal(.fetchHolidays(weekYear))))
        }

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return effects.isEmpty ? .none : .merge(effects)

      case .monthPageChanged(let newMonth):
        // TabView 페이징으로 월이 변경됨
        let monthStart = newMonth.startOfMonth
        state.currentMonth = monthStart

        // selectedDate는 변경하지 않음 — 다른 월이면 셀에서 선택 표시 안 됨
        AppLogger.calendar.debugLog("📆 monthPageChanged - 월: \(LocalizedDateFormatters.yearMonth.string(from: newMonth)), 선택된 날짜: \(LocalizedDateFormatters.date.string(from: state.selectedDate))")

        // 해당 월 로드 (캐시되지 않은 경우만)
        var effects: [Effect<Action>] = []

        if !state.loadedMonths.contains(monthStart) {
          AppLogger.calendar.debugLog("🔄 캐시 MISS - 로드 필요: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
          effects.append(.send(.internal(.fetchPromisesForMonth(monthStart))))
        } else {
          AppLogger.calendar.debugLog("✅ 캐시 HIT - 이미 로드됨: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
        }

        // 캘린더 이벤트 로드 (캐시되지 않은 경우만)
        if state.calendarPermissionStatus.canReadEvents && !state.loadedCalendarEventMonths.contains(monthStart) {
          effects.append(.send(.internal(.fetchCalendarEventsForMonth(monthStart))))
        }

        // 개인 일정 로드 (캐시되지 않은 경우만)
        if !state.loadedPersonalEventMonths.contains(monthStart) {
          effects.append(.send(.internal(.fetchPersonalEventsForMonth(monthStart))))
        }

        // 공휴일 로드 (해당 연도가 아직 로드되지 않은 경우)
        let year = calendar.component(.year, from: monthStart)
        if !state.loadedHolidayYears.contains(year) {
          effects.append(.send(.internal(.fetchHolidays(year))))
        }

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return effects.isEmpty ? .none : .merge(effects)

      case .scrollTo(let date):
        // 특정 날짜로 스크롤
        guard let date = date else {
          state.scrolledID = nil
          return .none
        }
        if let targetDate = state.sectionDates.first(where: { calendar.isDate($0, inSameDayAs: date) }) {
          state.scrolledID = targetDate
        }
        return .none

      case .resetScroll:
        state.scrolledID = nil
        return .none

      case .requestCalendarPermission:
        let currentMonth = state.currentMonth.startOfMonth
        return .run { [eventKitClient, currentMonth] send in
          do {
            let granted = try await eventKitClient.requestAccess()
            let status = eventKitClient.authorizationStatus()
            await send(.internal(.calendarPermissionResponse(status)))
            if granted {
              await send(.internal(.fetchCalendarEventsForMonth(currentMonth)))
            }
          } catch {
            // 에러 무시 - 권한 거부로 처리
          }
        }

      case .openSettings:
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        return .none

      case .dismissCalendarBanner(let status):
        state.hiddenCalendarBannerTypes.insert(status)
        // UserDefaults에 영속 저장
        let rawValues = state.hiddenCalendarBannerTypes.map { $0.persistKey }
        userDefaultsClient.setString(rawValues.joined(separator: ","), AppConstants.UserDefaults.dismissedCalendarBannerTypes)
        return .none

      case .personalEventTapped(let event):
        state.path.append(.personalEventDetail(.init(event: event)))
        return .none

      case .refresh:
        // 탭 전환 시 최신 데이터 로드
        AppLogger.calendar.debugLog("🔄 refresh - 캘린더 탭 진입 (데이터 새로고침)")
        return .merge(
          .send(.internal(.checkCalendarPermission)),
          .send(.internal(.loadInitialData))
        )

      case .pastTimeBlocked:
        state.toastMessage = ToastMessage(
          type: .warning,
          title: LocalizedStrings.Calendar.cannotCreatePastSchedule
        )
        return .none

      case .toastDismissed:
        state.toastMessage = nil
        return .none

      case .scheduleItemTapped(let item):
        switch item {
        case .promise(let promise):
          let groupMembers = state.groupMembersCache[promise.groupId]
          state.path.append(.promiseDetail(.init(
            promise: promise,
            currentUserId: state.currentUserId,
            groupMembers: groupMembers
          )))
        case .personalEvent(let event):
          state.path.append(.personalEventDetail(.init(event: event)))
        case .calendarEvent(let event):
          state.path.append(.calendarEventDetail(.init(event: event)))
        case .recurringPersonalEvent(let instance):
          if let recurring = state.recurringEvents.first(where: { $0.id == instance.recurringEventId }) {
            state.path.append(.recurringPersonalEventDetail(.init(
              recurringEvent: recurring,
              selectedInstance: instance
            )))
          }
        }
        return .none

      case .editScheduleItem(let item):
        switch item {
        case .promise(let promise):
          let maxMembers = state.groupMembersCache[promise.groupId]?.count ?? promise.minimumParticipants
          state.editPromise = EditPromise.Feature.State(promise: promise, maxMembers: maxMembers, currentUserId: state.currentUserId)
        case .personalEvent(let event):
          state.editPersonalEvent = CreatePersonalEvent.Feature.State(event: event, mode: .edit)
        case .calendarEvent:
          break
        case .recurringPersonalEvent(let instance):
          if let event = state.recurringEvents.first(where: { $0.id == instance.recurringEventId }) {
            state.editRecurringPersonalEvent = CreateRecurringPersonalEvent.Feature.State(event: event, mode: .edit)
          }
        }
        return .none

      case let .createPersonalEventFromTimeline(startDate, endDate):
        let newEvent = PersonalEventModel(startAt: startDate, endAt: endDate)
        state.editPersonalEvent = CreatePersonalEvent.Feature.State(event: newEvent, mode: .create)
        return .none

      case let .createPromiseFromTimeline(startDate, endDate):
        var promise = PromiseModel.empty
        promise.startAt = startDate
        promise.endAt = endDate
        state.createPromise = CreatePromise.Feature.State(
          promise: promise,
          groupSummaries: state.currentUser.groups.isEmpty ? nil : Array(state.currentUser.groups),
          currentUserId: state.currentUserId
        )
        return .none

      case .deleteScheduleItem(let item):
        state.scheduleItemToDelete = item
        switch item {
        case .promise(let promise):
          state.deleteAlert = AlertState {
            TextState(LocalizedStrings.GroupMain.deletePromiseTitle)
          } actions: {
            ButtonState(role: .cancel) {
              TextState(LocalizedStrings.Common.cancel)
            }
            ButtonState(role: .destructive, action: .confirmDelete) {
              TextState(LocalizedStrings.Common.delete)
            }
          } message: {
            TextState(LocalizedStrings.GroupMain.deletePromiseConfirm(promise.title))
          }
        case .personalEvent(let event):
          state.deleteAlert = AlertState {
            TextState(LocalizedStrings.Shared.deleteEvent)
          } actions: {
            ButtonState(role: .cancel) {
              TextState(LocalizedStrings.Common.cancel)
            }
            ButtonState(role: .destructive, action: .confirmDelete) {
              TextState(LocalizedStrings.Common.delete)
            }
          } message: {
            TextState(LocalizedStrings.Shared.deleteEventConfirm(event.title))
          }
        case .calendarEvent:
          break
        case .recurringPersonalEvent:
          break
        }
        return .none

      case .shareScheduleItem(let item):
        switch item {
        case .promise(let promise):
          state.sharePromise = promise
        case .personalEvent, .calendarEvent, .recurringPersonalEvent:
          break
        }
        return .none

      case .dismissPromiseShareSheet:
        state.sharePromise = nil
        state.isKakaoPromiseSharing = false
        return .none

      case .kakaoPromiseShareTapped:
        guard let promise = state.sharePromise else { return .none }
        state.isKakaoPromiseSharing = true
        return .run { [kakaoShareClient] send in
          let result = await kakaoShareClient.sharePromise(
            promise.title,
            promise.displayEmoji,
            promise.dateText,
            promise.timeText,
            promise.location?.name,
            promise.location?.address,
            promise.id,
            promise.groupId,
            promise.description,
            promise.imageUrls.first
          )
          await send(.internal(.kakaoPromiseShareResult(result)))
        }

      case .systemPromiseShareTapped:
        guard let promise = state.sharePromise else { return .none }
        state.systemShareText = promise.shareText
        state.sharePromise = nil
        return .none

      case .systemShareSheetDismissed:
        state.systemShareText = nil
        return .none

      case .indicatorTapped(let indicator):
        switch indicator.sourceType {
        case .promise(let promiseId, let groupId):
          guard let promise = state.findCachedPromise(id: promiseId) else {
            return .none
          }
          let groupMembers = state.groupMembersCache[groupId]
          state.path.append(.promiseDetail(.init(
            promise: promise,
            currentUserId: state.currentUserId,
            groupMembers: groupMembers
          )))
        case .personalEvent(let eventId):
          guard let event = state.cachedPersonalEventsByMonth.values.lazy.flatMap({ $0 }).first(where: { $0.id == eventId }) else {
            return .none
          }
          state.path.append(.personalEventDetail(.init(event: event)))
        case .recurringPersonalEvent(let recurringEventId):
          guard let recurring = state.recurringEvents.first(where: { $0.id == recurringEventId }) else {
            return .none
          }
          state.path.append(.recurringPersonalEventDetail(.init(recurringEvent: recurring)))
        case .calendarEvent(let eventId):
          guard let event = state.cachedCalendarEventsByMonth.values.lazy.flatMap({ $0 }).first(where: { $0.id == eventId }) else {
            return .none
          }
          state.path.append(.calendarEventDetail(.init(event: event)))
        case .unknown:
          break
        }
        return .none

      case .dayLongPressCreatePersonalEvent(let date):
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(86400)
        guard endOfDay > Date() else {
          return .send(.view(.pastTimeBlocked))
        }
        // 오늘이면 현재시간+1분, 미래면 해당일 10시
        let startDate = calendar.isDateInToday(date)
          ? Date().addingTimeInterval(60)
          : calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date
        let endDate = startDate.addingTimeInterval(3600)
        return .send(.view(.createPersonalEventFromTimeline(startDate: startDate, endDate: endDate)))

      case let .dayLongPressCreatePromise(date):
        let calendar = Calendar.current
        let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(86400)
        guard endOfDay > Date() else {
          return .send(.view(.pastTimeBlocked))
        }
        let startDate = calendar.isDateInToday(date)
          ? Date().addingTimeInterval(60)
          : calendar.date(bySettingHour: 10, minute: 0, second: 0, of: date) ?? date
        let endDate = startDate.addingTimeInterval(3600)
        return .send(.view(.createPromiseFromTimeline(startDate: startDate, endDate: endDate)))

      case .filterIconTapped:
        state.isFilterSheetPresented = true
        return .none

      case .filterGroupToggled(let groupId):
        if state.selectedGroupIds.contains(groupId) {
          state.selectedGroupIds.remove(groupId)
        } else {
          state.selectedGroupIds.insert(groupId)
        }
        return .none

      case .filterPersonalEventsToggled:
        state.showPersonalEvents.toggle()
        return .none

      case .filterStatusChanged(let filter):
        if filter == .all {
          if state.selectedStatusFilters == StatusFilter.allIndividualFilters {
            state.selectedStatusFilters = []
          } else {
            state.selectedStatusFilters = StatusFilter.allIndividualFilters
          }
        } else if state.selectedStatusFilters.contains(filter) {
          state.selectedStatusFilters.remove(filter)
        } else {
          state.selectedStatusFilters.insert(filter)
        }
        return .none

      case .filterCalendarEventsToggled:
        state.showCalendarEvents.toggle()
        return .none

      case .filterReset:
        state.selectedGroupIds = Set(state.currentUser.groups.map(\.id))
        state.showPersonalEvents = true
        state.showCalendarEvents = true
        state.selectedStatusFilters = StatusFilter.allIndividualFilters
        return .none

      case .filterSheetDismissed:
        state.isFilterSheetPresented = false
        return .none

      }
    }

    // MARK: - Internal Action Handler

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.InternalAction
    ) -> Effect<Action> {
      switch action {
      case .transitionCompleted:
        state.isTransitioning = false
        return .none

      case .loadInitialData:
        // 현재 보고 있는 월 + 인접 월만 선택적 무효화 (전체 캐시 삭제 X)
        let monthsToLoad = getMonthsToLoad(state: state)
        for month in monthsToLoad {
          state.loadedMonths.remove(month)
          state.loadedPersonalEventMonths.remove(month)
          state.loadedCalendarEventMonths.remove(month)
        }
        AppLogger.calendar.debugLog("📦 데이터 로드 (선택적 무효화: \(monthsToLoad.count)개 월, 그룹: \(state.userGroupIds.count)개)")

        // 개인 일정은 월별로 로드
        var effects: [Effect<Action>] = monthsToLoad.map { month in
          Effect<Action>.send(.internal(.fetchPersonalEventsForMonth(month)))
        }

        // 그룹이 있으면 약속 로드
        if !state.userGroupIds.isEmpty {
          effects.append(contentsOf: monthsToLoad.map { month in
            Effect<Action>.send(.internal(.fetchPromisesForMonth(month)))
          })
        }

        // 캘린더 권한이 있으면 캘린더 이벤트 로드
        if state.calendarPermissionStatus.canReadEvents {
          effects.append(contentsOf: monthsToLoad.map { month in
            Effect<Action>.send(.internal(.fetchCalendarEventsForMonth(month)))
          })
        }

        // 공휴일 로드 (현재 연도 + 인접 연도)
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: state.selectedDate)
        let prevYear = currentYear - 1
        let nextYear = currentYear + 1
        for year in [prevYear, currentYear, nextYear] {
          if !state.loadedHolidayYears.contains(year) {
            effects.append(.send(.internal(.fetchHolidays(year))))
          }
        }

        // 인접 월 프리페치
        effects.append(.send(.internal(.prefetchAdjacentMonths)))

        return .merge(effects)

      case .fetchPromisesForMonth(let month):
        let monthStart = month.startOfMonth

        // 이미 로드된 월이면 스킵
        guard !state.loadedMonths.contains(monthStart) else {
          AppLogger.calendar.debugLog("⏭️ fetchPromisesForMonth 스킵 - 이미 로드됨: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
          return .none
        }

        // 그룹이 없으면 스킵
        guard !state.userGroupIds.isEmpty else {
          AppLogger.calendar.debugLog("⏭️ fetchPromisesForMonth 스킵 - 그룹 없음")
          return .none
        }

        state.loadingMonths.insert(monthStart)
        AppLogger.calendar.debugLog("🌐 API 요청 시작 - \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")

        // 월의 시작과 끝 계산
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let groupIds = state.userGroupIds

        return .run { [promiseClient] send in
          let startTime = Date()
          do {
            let promises = try await promiseClient.getPromisesByDateRange(groupIds, monthStart, endDate)
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.calendar.debugLog("✅ API 응답 성공 - \(LocalizedDateFormatters.yearMonth.string(from: monthStart)): \(promises.count)개 약속, \(String(format: "%.2f", elapsed))초")
            await send(.internal(.promisesResponseForMonth(month: monthStart, .success(promises))))
          } catch {
            let elapsed = Date().timeIntervalSince(startTime)
            AppLogger.calendar.debugLog("❌ API 응답 실패 - \(LocalizedDateFormatters.yearMonth.string(from: monthStart)): \(error.localizedDescription), \(String(format: "%.2f", elapsed))초", type: .error)
            await send(.internal(.promisesResponseForMonth(month: monthStart, .failure(error))))
          }
        }
        .cancellable(id: CancelID.fetchPromisesForMonth(monthStart), cancelInFlight: true)

      case .prefetchAdjacentMonths:
        // 현재 보고 있는 월 기준 전/후 월 프리페치
        let calendar = Calendar.current
        let currentMonth = state.currentMonth.startOfMonth

        let prevMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)?.startOfMonth
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)?.startOfMonth

        AppLogger.calendar.debugLog("🔮 프리페치 체크 - 현재: \(LocalizedDateFormatters.yearMonth.string(from: currentMonth)), 이전: \(prevMonth.map { LocalizedDateFormatters.yearMonth.string(from: $0) } ?? "nil"), 다음: \(nextMonth.map { LocalizedDateFormatters.yearMonth.string(from: $0) } ?? "nil")")
        AppLogger.calendar.debugLog("🔮 캐시 현황 - loadedMonths: \(state.loadedMonths.map { LocalizedDateFormatters.yearMonth.string(from: $0) }.sorted()), loadedPersonalEventMonths: \(state.loadedPersonalEventMonths.map { LocalizedDateFormatters.yearMonth.string(from: $0) }.sorted())")

        var promiseMonthsToFetch: [Date] = []
        if let prevMonth = prevMonth, !state.loadedMonths.contains(prevMonth) {
          promiseMonthsToFetch.append(prevMonth)
        }
        if let nextMonth = nextMonth, !state.loadedMonths.contains(nextMonth) {
          promiseMonthsToFetch.append(nextMonth)
        }

        // 개인 일정 프리페치
        let personalMonthsToFetch = [prevMonth, nextMonth].compactMap { $0 }.filter { !state.loadedPersonalEventMonths.contains($0) }

        // 캘린더 이벤트 프리페치
        let calendarMonthsToFetch: [Date]
        if state.calendarPermissionStatus.canReadEvents {
          calendarMonthsToFetch = [prevMonth, nextMonth].compactMap { $0 }.filter { !state.loadedCalendarEventMonths.contains($0) }
        } else {
          calendarMonthsToFetch = []
        }

        if promiseMonthsToFetch.isEmpty && personalMonthsToFetch.isEmpty && calendarMonthsToFetch.isEmpty {
          AppLogger.calendar.debugLog("⏭️ 프리페치 스킵 - 인접 월 모두 캐시됨 (이전: \(prevMonth.map { state.loadedMonths.contains($0) ? "✅" : "❌" } ?? "-"), 다음: \(nextMonth.map { state.loadedMonths.contains($0) ? "✅" : "❌" } ?? "-"))")
          return .none
        }

        AppLogger.calendar.debugLog("🔮 프리페치 시작 - 약속: \(promiseMonthsToFetch.map { LocalizedDateFormatters.yearMonth.string(from: $0) }), 개인일정: \(personalMonthsToFetch.map { LocalizedDateFormatters.yearMonth.string(from: $0) }), 캘린더: \(calendarMonthsToFetch.map { LocalizedDateFormatters.yearMonth.string(from: $0) })")

        // 프리페치는 백그라운드에서 조용히 실행 (로딩 표시 없음)
        var effects: [Effect<Action>] = promiseMonthsToFetch.map { month in
          .send(.internal(.fetchPromisesForMonth(month)))
        }
        effects.append(contentsOf: personalMonthsToFetch.map { month in
          .send(.internal(.fetchPersonalEventsForMonth(month)))
        })
        effects.append(contentsOf: calendarMonthsToFetch.map { month in
          .send(.internal(.fetchCalendarEventsForMonth(month)))
        })
        return .merge(effects)

      case .promisesResponseForMonth(let month, let result):
        state.loadingMonths.remove(month)

        switch result {
        case .success(let promises):
          // 그룹 정보 매핑 (UserGroupInfo + groupMembersCache → GroupModel 변환)
          let groupsDict = Dictionary(
            uniqueKeysWithValues: state.currentUser.groups.map { ($0.id, $0) }
          )
          let membersCache = state.groupMembersCache
          let promisesWithGroup = promises.map { promise in
            var mutablePromise = promise
            if let groupInfo = groupsDict[promise.groupId] {
              let memberIds = membersCache[promise.groupId]?.map(\.id) ?? []
              mutablePromise.group = GroupModel(
                id: groupInfo.id,
                name: groupInfo.name,
                imageUrl: groupInfo.imageUrl,
                memberIds: memberIds,
                maxMembers: memberIds.count,
                inviteCode: "",
                createdBy: ""
              )
            }
            return mutablePromise
          }
          state.cachedPromisesByMonth[month] = promisesWithGroup
          state.loadedMonths.insert(month)
          AppLogger.calendar.debugLog("💾 캐시 저장 완료 - \(LocalizedDateFormatters.yearMonth.string(from: month)): \(promises.count)개 약속")

        case .failure(let error):
          // 실패해도 재시도 가능하도록 loadedMonths에 추가하지 않음
          AppLogger.calendar.debugLog("⚠️ 캐시 저장 실패 - \(LocalizedDateFormatters.yearMonth.string(from: month)): \(error.localizedDescription)", type: .error)
          state.toastMessage = ToastMessage(
            type: .error,
            title: LocalizedStrings.Error.promiseFetchFailed
          )
        }
        return .none

      case .checkCalendarPermission:
        let status = eventKitClient.authorizationStatus()
        state.calendarPermissionStatus = status

        if status.canReadEvents {
          return .send(.internal(.fetchCalendarEventsForMonth(state.currentMonth.startOfMonth)))
        }
        return .none

      case .calendarPermissionResponse(let status):
        state.calendarPermissionStatus = status
        return .none

      case .fetchCalendarEventsForMonth(let month):
        let monthStart = month.startOfMonth
        guard state.calendarPermissionStatus.canReadEvents else { return .none }
        guard !state.loadedCalendarEventMonths.contains(monthStart) else {
          AppLogger.calendar.debugLog("⏭️ fetchCalendarEventsForMonth 스킵 - 이미 로드됨: \(LocalizedDateFormatters.yearMonth.string(from: monthStart))")
          return .none
        }

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

        return .run { [eventKitClient] send in
          do {
            let events = try await eventKitClient.fetchEvents(monthStart, endDate)
            await send(.internal(.calendarEventsResponseForMonth(month: monthStart, .success(events))))
          } catch {
            await send(.internal(.calendarEventsResponseForMonth(month: monthStart, .failure(error))))
          }
        }
        .cancellable(id: CancelID.fetchCalendarEventsForMonth(monthStart), cancelInFlight: true)

      case .calendarEventsResponseForMonth(let month, let result):
        switch result {
        case .success(let events):
          state.cachedCalendarEventsByMonth[month] = events
          state.loadedCalendarEventMonths.insert(month)
          AppLogger.calendar.debugLog("📅 캘린더 이벤트 캐시 저장 - \(LocalizedDateFormatters.yearMonth.string(from: month)): \(events.count)개")
        case .failure:
          // 실패 시 loadedCalendarEventMonths에 추가하지 않아 재시도 가능
          AppLogger.calendar.debugLog("⚠️ 캘린더 이벤트 로드 실패 - \(LocalizedDateFormatters.yearMonth.string(from: month))", type: .error)
        }
        return .none

      case .fetchPersonalEventsForMonth(let month):
        let monthStart = month.startOfMonth
        guard !state.loadedPersonalEventMonths.contains(monthStart) else { return .none }

        state.loadingPersonalEventMonths.insert(monthStart)

        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart

        return .run { [personalEventClient] send in
          do {
            let events = try await personalEventClient.getEventsByDateRange(monthStart, endDate)
            await send(.internal(.personalEventsResponseForMonth(month: monthStart, .success(events))))
          } catch {
            await send(.internal(.personalEventsResponseForMonth(month: monthStart, .failure(error))))
          }
        }
        .cancellable(id: CancelID.fetchPersonalEventsForMonth(monthStart), cancelInFlight: true)

      case .personalEventsResponseForMonth(let month, let result):
        state.loadingPersonalEventMonths.remove(month)
        switch result {
        case .success(let events):
          state.cachedPersonalEventsByMonth[month] = events
          state.loadedPersonalEventMonths.insert(month)
        case .failure:
          // 에러 시 재시도 가능하도록 loadedPersonalEventMonths에 추가하지 않음
          break
        }
        return .none

      case .fetchSettings:
        let userId = state.currentUserId
        return .run { [userSettingsClient] send in
          do {
            let settings = try await userSettingsClient.fetchSettings(userId)
            await send(.internal(.settingsResponse(.success(settings))))
          } catch {
            await send(.internal(.settingsResponse(.failure(error))))
          }
        }

      case .settingsResponse(let result):
        if case .success(let settings) = result {
          state.groupSortOption = settings.groupSortOption
        }
        return .none

      case .fetchHolidays(let year):
        guard !state.loadedHolidayYears.contains(year) else { return .none }
        return .run { [holidayClient] send in
          do {
            let holidays = try await holidayClient.fetchHolidays(year)
            await send(.internal(.holidaysResponse(year: year, .success(holidays))))
          } catch {
            await send(.internal(.holidaysResponse(year: year, .failure(error))))
          }
        }
        .cancellable(id: CancelID.fetchHolidays(year), cancelInFlight: true)

      case .holidaysResponse(let year, let result):
        switch result {
        case .success(let holidays):
          state.loadedHolidayYears.insert(year)
          for holiday in holidays {
            state.holidaysByDate[holiday.date] = holiday.localName
          }
        case .failure(let error):
          // 공휴일 로드 실패 시 로그 출력 (재시도 가능하도록 loadedHolidayYears에 추가 안 함)
          AppLogger.calendar.debugLog("❌ 공휴일 로드 실패 (year: \(year)): \(error.localizedDescription)", type: .error)
        }
        return .none

      case .fetchRecurringEvents:
        guard !state.isRecurringEventsLoaded else { return .none }
        return .run { [recurringPersonalEventClient] send in
          do {
            let events = try await recurringPersonalEventClient.getAllEvents()
            await send(.internal(.recurringEventsLoaded(events)))
          } catch {
            await send(.internal(.recurringEventsFailed))
          }
        }

      case .recurringEventsLoaded(let events):
        state.recurringEvents = events
        state.isRecurringEventsLoaded = true
        return .none

      case .recurringEventsFailed:
        state.isRecurringEventsLoaded = true
        return .none

      case .kakaoPromiseShareResult(let result):
        state.isKakaoPromiseSharing = false
        switch result {
        case .shared, .webShared:
          state.sharePromise = nil
          state.toastMessage = ToastMessage(
            type: .success,
            title: LocalizedStrings.KakaoShare.promiseShared,
            position: .top
          )
        case .fallbackToSystem:
          break
        }
        return .none
      }
    }

    // MARK: - Display Mode Change

    /// 디스플레이 모드 변경 공통 로직
    private func applyDisplayModeChange(_ state: inout State, to newMode: CalendarDisplayMode) -> Effect<Action> {
      state.isTransitioning = true
      state.displayMode = newMode

      // 모드 전환 시 현재 선택된 날짜 기준으로 양방향 동기화
      state.currentWeekStart = state.selectedDate.startOfWeek
      state.currentMonth = state.selectedDate.startOfMonth

      // 월간 모드로 전환 시 해당 월 데이터 로드
      let allMonths = getMonthsToLoad(state: state)
      let promiseMonthsToLoad = allMonths.filter { !state.loadedMonths.contains($0) }
      let personalMonthsToLoad = allMonths.filter { !state.loadedPersonalEventMonths.contains($0) }
      AppLogger.calendar.debugLog("🔄 모드 전환(\(newMode)) - 로드 필요 월: \(promiseMonthsToLoad.map { LocalizedDateFormatters.yearMonth.string(from: $0) })")

      var effects: [Effect<Action>] = promiseMonthsToLoad.map { month in
        .send(.internal(.fetchPromisesForMonth(month)))
      }
      effects.append(contentsOf: personalMonthsToLoad.map { month in
        .send(.internal(.fetchPersonalEventsForMonth(month)))
      })

      effects.append(.run { send in
        try await Task.sleep(nanoseconds: Self.transitionAnimationDuration)
        await send(.internal(.transitionCompleted))
      })

      return .merge(effects)
    }

    // MARK: - Helper Functions

    /// 월이 변경될 때 미로드 약속/개인일정/캘린더 이벤트를 로드하는 Effect 반환
    private func loadDataForMonthIfNeeded(_ month: Date, state: State) -> Effect<Action> {
      var effects: [Effect<Action>] = []
      let needsPromises = !state.loadedMonths.contains(month)
      let needsPersonal = !state.loadedPersonalEventMonths.contains(month)
      let needsCalendar = state.calendarPermissionStatus.canReadEvents && !state.loadedCalendarEventMonths.contains(month)

      if needsPromises {
        effects.append(.send(.internal(.fetchPromisesForMonth(month))))
      }
      if needsPersonal {
        effects.append(.send(.internal(.fetchPersonalEventsForMonth(month))))
      }
      if needsCalendar {
        effects.append(.send(.internal(.fetchCalendarEventsForMonth(month))))
      }

      AppLogger.calendar.debugLog("📅 loadDataForMonthIfNeeded - \(LocalizedDateFormatters.yearMonth.string(from: month)): 약속=\(needsPromises ? "로드" : "캐시"), 개인=\(needsPersonal ? "로드" : "캐시"), 캘린더=\(needsCalendar ? "로드" : "캐시")")
      return effects.isEmpty ? .none : .merge(effects)
    }

    /// 현재 표시 범위에 필요한 월 목록 반환 (항상 월 단위로 관리)
    private func getMonthsToLoad(state: State) -> [Date] {
      // 선택된 날짜 + 현재 보고 있는 월 모두 포함
      var months = Set<Date>()
      months.insert(state.selectedDate.startOfMonth)
      months.insert(state.currentMonth.startOfMonth)
      return Array(months)
    }
  }
}
