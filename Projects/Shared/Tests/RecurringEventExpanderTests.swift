//
//  RecurringEventExpanderTests.swift
//  PromisoShared
//
//  RecurringEventExpander 및 ExpandedEventInstance 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Helpers/RecurringEventExpander.swift`
//  - `PromisoShared/Sources/Models/RecurrenceRule.swift`
//  - `PromisoShared/Sources/Models/RecurringPersonalEventModel.swift`
//
//  ## 테스트 목적
//  - Daily: 매일 반복 인스턴스 생성
//  - Weekly: 매주 특정 요일 반복 인스턴스 생성
//  - Monthly: 매월 특정 일자 반복 인스턴스 생성
//  - excludedDates: 제외된 날짜 처리
//  - overrides: 개별 수정사항 적용
//  - seriesEndDate: 시리즈 종료일 처리
//  - 경계값 및 시간 계산
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - Helper Methods

private func makeDate(year: Int, month: Int, day: Int) -> Date {
  var components = DateComponents()
  components.year = year
  components.month = month
  components.day = day
  components.hour = 0
  components.minute = 0
  components.second = 0
  return Calendar.scheduleDisplay.date(from: components)!
}

private func makeDateWithTime(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
  var components = DateComponents()
  components.year = year
  components.month = month
  components.day = day
  components.hour = hour
  components.minute = minute
  components.second = 0
  return Calendar.scheduleDisplay.date(from: components)!
}

// MARK: - Daily 테스트

@Suite("RecurringEventExpander - Daily 반복")
struct DailyRecurrenceTests {

  @Test("매일 반복: 7일 범위에서 7개 인스턴스 생성")
  func daily_sevenDayRange_createsSeven() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 8) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 7)
    #expect(instances.first?.startAt == makeDateWithTime(year: 2025, month: 3, day: 1, hour: 10, minute: 0))
    #expect(instances.last?.startAt == makeDateWithTime(year: 2025, month: 3, day: 7, hour: 10, minute: 0))
  }

  @Test("매일 반복: seriesStartDate 이전은 제외")
  func daily_beforeSeriesStart_excludes() {
    let seriesStart = makeDate(year: 2025, month: 3, day: 5)
    let rangeStart = makeDate(year: 2025, month: 3, day: 1)
    let rangeEnd = makeDate(year: 2025, month: 3, day: 11) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: seriesStart
    )

    let instances = RecurringEventExpander.expand(event: event, from: rangeStart, to: rangeEnd)

    // seriesStart(3/5) ~ 3/10 = 6개
    #expect(instances.count == 6)
    #expect(instances.first?.startAt == makeDateWithTime(year: 2025, month: 3, day: 5, hour: 10, minute: 0))
  }
}

// MARK: - Weekly 테스트

@Suite("RecurringEventExpander - Weekly 반복")
struct WeeklyRecurrenceTests {

  @Test("매주 월수금: 2주 범위에서 6개 인스턴스 생성")
  func weekly_monWedFri_twoWeeks_createsSix() {
    // 2025-03-03은 월요일
    let startDate = makeDate(year: 2025, month: 3, day: 3)
    let endDate = makeDate(year: 2025, month: 3, day: 16)

    let event = RecurringPersonalEventModel(
      id: "weekly-test",
      title: "주간 회의",
      startTime: DateComponents(hour: 14, minute: 0),
      recurrence: .weekly([2, 4, 6]), // 월, 수, 금
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 첫째주: 월(3), 수(5), 금(7) = 3개
    // 둘째주: 월(10), 수(12), 금(14) = 3개
    // 총 6개
    #expect(instances.count == 6)
  }

  @Test("매주 토일: 해당 요일만 포함")
  func weekly_satSun_onlyWeekend() {
    // 2025-03-01은 토요일
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 10) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "weekly-test",
      title: "주말 활동",
      startTime: DateComponents(hour: 11, minute: 0),
      recurrence: .weekly([7, 1]), // 토, 일
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 3/1(토), 3/2(일), 3/8(토), 3/9(일) = 4개
    #expect(instances.count == 4)
    for instance in instances {
      let weekday = Calendar.current.component(.weekday, from: instance.startAt)
      #expect(weekday == 7 || weekday == 1)
    }
  }
}

// MARK: - Monthly 테스트

@Suite("RecurringEventExpander - Monthly 반복")
struct MonthlyRecurrenceTests {

  @Test("매월 15일: 3개월 범위에서 3개 인스턴스 생성")
  func monthly_15th_threeMonths_createsThree() {
    let startDate = makeDate(year: 2025, month: 1, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 31)

    let event = RecurringPersonalEventModel(
      id: "monthly-test",
      title: "월간 리뷰",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .monthly(day: 15),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 1/15, 2/15, 3/15 = 3개
    #expect(instances.count == 3)
    #expect(instances[0].startAt == makeDateWithTime(year: 2025, month: 1, day: 15, hour: 10, minute: 0))
    #expect(instances[1].startAt == makeDateWithTime(year: 2025, month: 2, day: 15, hour: 10, minute: 0))
    #expect(instances[2].startAt == makeDateWithTime(year: 2025, month: 3, day: 15, hour: 10, minute: 0))
  }

  @Test("매월 31일: 2월은 건너뜀")
  func monthly_31st_skipFebruary() {
    let startDate = makeDate(year: 2025, month: 1, day: 1)
    let endDate = makeDate(year: 2025, month: 4, day: 1) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "monthly-test",
      title: "월말 정산",
      startTime: DateComponents(hour: 17, minute: 0),
      recurrence: .monthly(day: 31),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 1/31과 3/31만 생성 (2월은 31일이 없음) = 2개
    #expect(instances.count == 2)
    #expect(instances[0].startAt == makeDateWithTime(year: 2025, month: 1, day: 31, hour: 17, minute: 0))
    #expect(instances[1].startAt == makeDateWithTime(year: 2025, month: 3, day: 31, hour: 17, minute: 0))
  }
}

// MARK: - excludedDates 테스트

@Suite("RecurringEventExpander - excludedDates")
struct ExcludedDatesTests {

  @Test("excludedDates에 포함된 날짜는 제외")
  func excludedDates_filtersOutSpecificDates() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 8) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate,
      excludedDates: ["2025-03-03", "2025-03-05"]
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 7일 중 2일 제외 = 5개
    #expect(instances.count == 5)

    let dateKeys = instances.map { $0.dateKey }
    #expect(!dateKeys.contains("2025-03-03"))
    #expect(!dateKeys.contains("2025-03-05"))
  }
}

// MARK: - overrides 테스트

@Suite("RecurringEventExpander - overrides")
struct OverridesTests {

  @Test("override로 시간 변경된 인스턴스")
  func overrides_changesStartTime() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 4) // exclusive upper bound

    let overrides: [String: EventOverride] = [
      "2025-03-02": EventOverride(startTime: DateComponents(hour: 14, minute: 30))
    ]

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate,
      overrides: overrides
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    let march2 = instances.first { $0.dateKey == "2025-03-02" }!
    #expect(march2.startAt == makeDateWithTime(year: 2025, month: 3, day: 2, hour: 14, minute: 30))
    #expect(march2.isOverridden == true)
  }

  @Test("override.isCancelled = true면 제외")
  func overrides_cancelled_excludesInstance() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 6) // exclusive upper bound

    let overrides: [String: EventOverride] = [
      "2025-03-03": EventOverride(isCancelled: true)
    ]

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate,
      overrides: overrides
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    // 5일 중 1일 취소 = 4개
    #expect(instances.count == 4)

    let dateKeys = instances.map { $0.dateKey }
    #expect(!dateKeys.contains("2025-03-03"))
  }

  @Test("override로 제목 변경된 인스턴스")
  func overrides_changesTitle() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 3) // exclusive upper bound

    let overrides: [String: EventOverride] = [
      "2025-03-02": EventOverride(title: "특별 미팅")
    ]

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate,
      overrides: overrides
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    let march1 = instances.first { $0.dateKey == "2025-03-01" }!
    let march2 = instances.first { $0.dateKey == "2025-03-02" }!

    #expect(march1.title == "일일 미팅")
    #expect(march2.title == "특별 미팅")
  }
}

// MARK: - seriesEndDate 테스트

@Suite("RecurringEventExpander - seriesEndDate")
struct SeriesEndDateTests {

  @Test("seriesEndDate 이후는 생성하지 않음")
  func seriesEndDate_stopsGeneration() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let seriesEndDate = makeDate(year: 2025, month: 3, day: 15)
    let rangeEnd = makeDate(year: 2025, month: 3, day: 31)

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(until: seriesEndDate),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: rangeEnd)

    // 3/1 ~ 3/15 = 15개
    #expect(instances.count == 15)
    #expect(instances.last?.startAt == makeDateWithTime(year: 2025, month: 3, day: 15, hour: 10, minute: 0))
  }
}

// MARK: - 경계값 테스트

@Suite("RecurringEventExpander - 경계값")
struct BoundaryTests {

  @Test("빈 범위면 빈 배열 반환")
  func emptyRange_returnsEmpty() {
    let startDate = makeDate(year: 2025, month: 3, day: 10)
    let endDate = makeDate(year: 2025, month: 3, day: 5) // start > end

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.isEmpty)
  }

  @Test("daysOfWeek가 nil이거나 empty면 빈 배열")
  func weeklyNilDaysOfWeek_returnsEmpty() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 31)

    let event = RecurringPersonalEventModel(
      id: "weekly-test",
      title: "주간 회의",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: RecurrenceRule(frequency: .weekly, daysOfWeek: nil),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.isEmpty)
  }

  @Test("monthlyWithoutDay_returnsEmpty")
  func monthlyNilDayOfMonth_returnsEmpty() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 31)

    let event = RecurringPersonalEventModel(
      id: "monthly-test",
      title: "월간 리뷰",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: RecurrenceRule(frequency: .monthly, dayOfMonth: nil),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.isEmpty)
  }
}

// MARK: - 시간 계산 테스트

@Suite("RecurringEventExpander - 시간 계산")
struct TimeCalculationTests {

  @Test("startTime이 올바르게 적용됨")
  func startTime_appliedCorrectly() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 14, minute: 30),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 1)
    let instance = instances.first!
    let components = Calendar.current.dateComponents([.hour, .minute], from: instance.startAt)
    #expect(components.hour == 14)
    #expect(components.minute == 30)
  }

  @Test("endTime으로 endAt 계산")
  func endTime_calculatesEndAt() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      endTime: DateComponents(hour: 11, minute: 30),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 1)
    let instance = instances.first!
    #expect(instance.endAt != nil)

    let expectedEnd = makeDateWithTime(year: 2025, month: 3, day: 1, hour: 11, minute: 30)
    #expect(instance.endAt == expectedEnd)
  }

  @Test("endTime이 nil이면 endAt도 nil")
  func noEndTime_endAtIsNil() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      endTime: nil,
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 1)
    let instance = instances.first!
    #expect(instance.endAt == nil)
  }

  @Test("endTime이 startTime보다 이전이면 다음 날로 계산")
  func endTime_beforeStartTime_nextDay() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "심야 미팅",
      startTime: DateComponents(hour: 23, minute: 0),
      endTime: DateComponents(hour: 1, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 1)
    let instance = instances.first!
    #expect(instance.endAt != nil)

    let expectedEnd = makeDateWithTime(year: 2025, month: 3, day: 2, hour: 1, minute: 0)
    #expect(instance.endAt == expectedEnd)
  }

  @Test("override의 endTime으로 endAt 변경")
  func overrideEndTime_changesEndAt() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 3) // exclusive upper bound

    let overrides: [String: EventOverride] = [
      "2025-03-02": EventOverride(endTime: DateComponents(hour: 12, minute: 0))
    ]

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      endTime: DateComponents(hour: 11, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate,
      overrides: overrides
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    let march1 = instances.first { $0.dateKey == "2025-03-01" }!
    let march2 = instances.first { $0.dateKey == "2025-03-02" }!

    let march1End = march1.endAt!
    let march2End = march2.endAt!

    let march1EndComponents = Calendar.current.dateComponents([.hour, .minute], from: march1End)
    let march2EndComponents = Calendar.current.dateComponents([.hour, .minute], from: march2End)

    #expect(march1EndComponents.hour == 11)
    #expect(march1EndComponents.minute == 0)
    #expect(march2EndComponents.hour == 12)
    #expect(march2EndComponents.minute == 0)
  }
}

// MARK: - 정렬 및 ID 테스트

@Suite("RecurringEventExpander - 정렬 및 ID")
struct SortingAndIdTests {

  @Test("인스턴스는 startAt 순서로 정렬됨")
  func instances_sortedByStartAt() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 8) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    for i in 0..<instances.count - 1 {
      #expect(instances[i].startAt <= instances[i + 1].startAt)
    }
  }

  @Test("expandedEventInstance id는 eventId + dateKey 조합")
  func expandedEventInstanceId_combines() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "test-event-123",
      title: "일일 미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.count == 1)
    let instance = instances.first!
    #expect(instance.id == "test-event-123_2025-03-01")
  }
}

// MARK: - KST 타임존 회귀 테스트

@Suite("RecurringEventExpander - KST 타임존")
struct KSTTimezoneTests {

  // KST 기준으로 "yyyy-MM-dd" 문자열을 Date로 파싱하는 헬퍼
  private func parseKSTDate(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
    return formatter.date(from: string)!
  }

  @Test("monthly dayOfMonth=1: 해당 월의 1일에만 인스턴스 생성")
  func monthly_dayOfMonth1_onlyFirstOfMonth() async {
    // 2026-03-01 ~ 2026-05-01 범위 (60일 근사)
    let rangeStart = makeDate(year: 2026, month: 3, day: 1)
    let rangeEnd = makeDate(year: 2026, month: 5, day: 2)

    let event = RecurringPersonalEventModel(
      id: "monthly-1st",
      title: "월초 미팅",
      startTime: DateComponents(hour: 9, minute: 0),
      recurrence: .monthly(day: 1),
      seriesStartDate: rangeStart
    )

    let instances = RecurringEventExpander.expand(event: event, from: rangeStart, to: rangeEnd)

    // 3/1, 4/1, 5/1 = 3개
    #expect(instances.count == 3)
    for instance in instances {
      let day = Calendar.scheduleDisplay.component(.day, from: instance.startAt)
      #expect(day == 1)
    }
  }

  @Test("monthly dayOfMonth=1: 1일 이외의 날에는 인스턴스 없음")
  func monthly_dayOfMonth1_noInstanceOnOtherDays() async {
    let rangeStart = makeDate(year: 2026, month: 3, day: 2)
    let rangeEnd = makeDate(year: 2026, month: 3, day: 31)

    let event = RecurringPersonalEventModel(
      id: "monthly-1st",
      title: "월초 미팅",
      startTime: DateComponents(hour: 9, minute: 0),
      recurrence: .monthly(day: 1),
      seriesStartDate: makeDate(year: 2026, month: 1, day: 1)
    )

    let instances = RecurringEventExpander.expand(event: event, from: rangeStart, to: rangeEnd)

    // 범위가 3/2 ~ 3/30이므로 3/1이 포함되지 않아 0개
    #expect(instances.isEmpty)
  }

  @Test("seriesStartDate를 '2026-03-19' 문자열에서 KST 파싱 후 expand 정상 동작")
  func seriesStartDate_kstParsedFromString_correctExpansion() async {
    // 실제 API 응답처럼 KST 기준 날짜 문자열로 파싱한 seriesStartDate 사용
    let seriesStart = parseKSTDate("2026-03-19")
    let rangeStart = makeDate(year: 2026, month: 3, day: 19)
    let rangeEnd = makeDate(year: 2026, month: 3, day: 23)

    let event = RecurringPersonalEventModel(
      id: "kst-parse-test",
      title: "KST 파싱 테스트",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: seriesStart
    )

    let instances = RecurringEventExpander.expand(event: event, from: rangeStart, to: rangeEnd)

    // 3/19 ~ 3/22 = 4개
    #expect(instances.count == 4)

    // 첫 인스턴스의 dateKey가 KST 기준 "2026-03-19"여야 함
    #expect(instances.first?.dateKey == "2026-03-19")
  }

  @Test("오늘~60일 후 범위에서 monthly 일정이 올바른 인스턴스만 생성")
  func monthly_today60DaysRange_correctInstances() async {
    // 기준: 2026-04-10 (오늘), 60일 후 = 2026-06-09
    let today = makeDate(year: 2026, month: 4, day: 10)
    let sixtyDaysLater = makeDate(year: 2026, month: 6, day: 10)

    let event = RecurringPersonalEventModel(
      id: "monthly-15th-range",
      title: "월간 보고",
      startTime: DateComponents(hour: 14, minute: 0),
      recurrence: .monthly(day: 15),
      seriesStartDate: makeDate(year: 2026, month: 1, day: 1)
    )

    let instances = RecurringEventExpander.expand(event: event, from: today, to: sixtyDaysLater)

    // 범위: 4/10 ~ 6/9 → 해당하는 15일: 4/15, 5/15, 6/15(제외, 6/10 미만 아님)
    // 6/10 < 6/15 이므로 6/15는 제외. 4/15, 5/15 = 2개
    #expect(instances.count == 2)

    let calendar = Calendar.scheduleDisplay
    let months = instances.map { calendar.component(.month, from: $0.startAt) }
    let days = instances.map { calendar.component(.day, from: $0.startAt) }

    #expect(months == [4, 5])
    #expect(days == [15, 15])
  }

  @Test("KST 기준 dateKey가 UTC 자정 전후에도 올바름")
  func dateKey_kstMidnight_correctDateKey() async {
    // KST 2026-04-10 00:00 = UTC 2026-04-09 15:00
    // Calendar.scheduleDisplay(KST)로 startOfDay 계산 시 4/10이어야 함
    let kst = Calendar.scheduleDisplay
    var kstMidnight = DateComponents()
    kstMidnight.year = 2026
    kstMidnight.month = 4
    kstMidnight.day = 10
    kstMidnight.hour = 0
    kstMidnight.minute = 0
    let date = kst.date(from: kstMidnight)!

    let event = RecurringPersonalEventModel(
      id: "kst-midnight",
      title: "자정 테스트",
      startTime: DateComponents(hour: 0, minute: 0),
      recurrence: .daily(),
      seriesStartDate: date
    )

    let rangeEnd = kst.date(byAdding: .day, value: 1, to: date)!
    let instances = RecurringEventExpander.expand(event: event, from: date, to: rangeEnd)

    #expect(instances.count == 1)
    #expect(instances.first?.dateKey == "2026-04-10")
  }
}

// MARK: - 메타데이터 전달 테스트

@Suite("RecurringEventExpander - 메타데이터")
struct MetadataTests {

  @Test("emoji는 원본 이벤트에서 가져옴")
  func emoji_preservedFromEvent() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "운동",
      emoji: "🏋️",
      startTime: DateComponents(hour: 10, minute: 0),
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.first?.emoji == "🏋️")
  }

  @Test("location은 override 또는 원본 사용")
  func location_overriddenOrPreserved() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 3) // exclusive upper bound

    let originalLocation = LocationInfoModel(name: "원래 장소", address: "주소1")
    let overrideLocation = LocationInfoModel(name: "변경된 장소", address: "주소2")

    let overrides: [String: EventOverride] = [
      "2025-03-02": EventOverride(location: overrideLocation)
    ]

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      location: originalLocation,
      recurrence: .daily(),
      seriesStartDate: startDate,
      overrides: overrides
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    let march1 = instances.first { $0.dateKey == "2025-03-01" }!
    let march2 = instances.first { $0.dateKey == "2025-03-02" }!

    #expect(march1.location?.name == "원래 장소")
    #expect(march2.location?.name == "변경된 장소")
  }

  @Test("reminderMinutesBefore는 원본 이벤트에서 가져옴")
  func reminderMinutesBefore_preservedFromEvent() {
    let startDate = makeDate(year: 2025, month: 3, day: 1)
    let endDate = makeDate(year: 2025, month: 3, day: 2) // exclusive upper bound

    let event = RecurringPersonalEventModel(
      id: "daily-test",
      title: "미팅",
      startTime: DateComponents(hour: 10, minute: 0),
      reminderMinutesBefore: 30,
      recurrence: .daily(),
      seriesStartDate: startDate
    )

    let instances = RecurringEventExpander.expand(event: event, from: startDate, to: endDate)

    #expect(instances.first?.reminderMinutesBefore == 30)
  }
}
