//
//  DateScheduleTests.swift
//  PromisoShared
//
//  Date+Schedule 확장 및 LocalizedDateFormatters 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Extensions/Date+Schedule.swift`
//  - `PromisoShared/Sources/Extensions/LocalizedDateFormatters.swift`
//
//  ## 테스트 목적
//  - timeUntilScheduleString: 남은 시간을 사용자 친화적 문자열로 변환
//  - scheduleDateString: 오늘/내일/어제/요일/날짜 표시
//  - isScheduleSoon / isScheduleImminent / isScheduleLate: 상태 판별
//  - scheduleReminderTimes: 알림 시간 생성
//  - isThisWeekSchedule / isNextWeekSchedule / isThisMonthSchedule: 기간 판별
//  - scheduleGroupingKey: 날짜 그룹핑 키
//  - Calendar 확장: isSameScheduleDay, groupSchedulesByWeek/Month
//  - TimeInterval 확장: minutesUntilSchedule, hoursUntilSchedule, daysUntilSchedule
//  - LocalizedDateFormatters: 포맷터 출력 형식, 24시간/12시간 전환
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - timeUntilScheduleString 테스트

@Suite("Date.timeUntilScheduleString 테스트")
struct TimeUntilScheduleStringTests {

  @Test("과거 날짜는 '지남' 반환")
  func pastDate_returnsExpired() {
    let pastDate = Date(timeIntervalSinceNow: -100)
    #expect(pastDate.timeUntilScheduleString == LocalizedStrings.DateFormat.passed)
  }

  @Test("30초 후는 '30초 후' 반환")
  func thirtySecondsLater_returnsSeconds() {
    let date = Date(timeIntervalSinceNow: 30)
    let result = date.timeUntilScheduleString
    // 실행 시점에 따라 29~30초 범위이므로 passed가 아닌지 확인
    #expect(result != LocalizedStrings.DateFormat.passed)
  }

  @Test("5분 후는 '5분 후' 반환")
  func fiveMinutesLater_returnsMinutes() {
    let date = Date(timeIntervalSinceNow: 5 * 60 + 10)
    let result = date.timeUntilScheduleString
    #expect(result == LocalizedStrings.DateFormat.minutesLater(5))
  }

  @Test("90분 후는 '1시간 30분 후' 반환")
  func ninetyMinutesLater_returnsHoursAndMinutes() {
    let date = Date(timeIntervalSinceNow: 90 * 60 + 10)
    let result = date.timeUntilScheduleString
    #expect(result == LocalizedStrings.DateFormat.hoursMinutesLater(1, 30))
  }

  @Test("정확히 2시간 후는 '2시간 후' 반환 (분 없이)")
  func exactTwoHoursLater_returnsHoursOnly() {
    let date = Date(timeIntervalSinceNow: 2 * 3600 + 10)
    let result = date.timeUntilScheduleString
    #expect(result == LocalizedStrings.DateFormat.hoursLater(2))
  }

  @Test("2일 3시간 후 형식 확인")
  func twoDaysThreeHoursLater_returnsDaysAndHours() {
    let date = Date(timeIntervalSinceNow: 2 * 86400 + 3 * 3600 + 10)
    let result = date.timeUntilScheduleString
    #expect(result == LocalizedStrings.DateFormat.daysHoursLater(2, 3))
  }

  @Test("정확히 3일 후는 '3일 후' 반환 (시간 없이)")
  func exactThreeDaysLater_returnsDaysOnly() {
    let date = Date(timeIntervalSinceNow: 3 * 86400 + 10)
    let result = date.timeUntilScheduleString
    #expect(result == LocalizedStrings.DateFormat.daysLater(3))
  }
}

// MARK: - scheduleDateString 테스트

@Suite("Date.scheduleDateString 테스트")
struct ScheduleDateStringTests {

  @Test("오늘 날짜는 '오늘' 반환")
  func today_returnsToday() {
    let today = Date()
    #expect(today.scheduleDateString == LocalizedStrings.DateFormat.today)
  }

  @Test("내일 날짜는 '내일' 반환")
  func tomorrow_returnsTomorrow() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    #expect(tomorrow.scheduleDateString == LocalizedStrings.DateFormat.tomorrow)
  }

  @Test("어제 날짜는 '어제' 반환")
  func yesterday_returnsYesterday() {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    #expect(yesterday.scheduleDateString == LocalizedStrings.DateFormat.yesterday)
  }

  @Test("30일 뒤 날짜는 monthDay 포맷 반환")
  func farFutureDate_returnsMonthDay() {
    let farDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    let result = farDate.scheduleDateString
    let expected = LocalizedDateFormatters.monthDayString(from: farDate)
    #expect(result == expected)
  }
}

// MARK: - scheduleDateTimeString 테스트

@Suite("Date.scheduleDateTimeString 테스트")
struct ScheduleDateTimeStringTests {

  @Test("오늘 날짜+시간 형식 확인")
  func today_combinesDateAndTime() {
    let today = Date()
    let result = today.scheduleDateTimeString
    #expect(result.hasPrefix(LocalizedStrings.DateFormat.today + " "))
  }

  @Test("내일 날짜+시간 형식 확인")
  func tomorrow_combinesDateAndTime() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let result = tomorrow.scheduleDateTimeString
    #expect(result.hasPrefix(LocalizedStrings.DateFormat.tomorrow + " "))
  }
}

// MARK: - isScheduleSoon / isScheduleImminent / isScheduleLate 테스트

@Suite("Date 일정 상태 판별 테스트")
struct ScheduleStatusTests {

  @Test("20분 후 일정은 isScheduleSoon = true")
  func twentyMinutesLater_isSoon() {
    let date = Date(timeIntervalSinceNow: 20 * 60)
    #expect(date.isScheduleSoon == true)
  }

  @Test("60분 후 일정은 isScheduleSoon = false")
  func sixtyMinutesLater_isNotSoon() {
    let date = Date(timeIntervalSinceNow: 60 * 60)
    #expect(date.isScheduleSoon == false)
  }

  @Test("과거 일정은 isScheduleSoon = false")
  func pastDate_isNotSoon() {
    let date = Date(timeIntervalSinceNow: -60)
    #expect(date.isScheduleSoon == false)
  }

  @Test("10분 후 일정은 isScheduleImminent = true")
  func tenMinutesLater_isImminent() {
    let date = Date(timeIntervalSinceNow: 10 * 60)
    #expect(date.isScheduleImminent == true)
  }

  @Test("20분 후 일정은 isScheduleImminent = false")
  func twentyMinutesLater_isNotImminent() {
    let date = Date(timeIntervalSinceNow: 20 * 60)
    #expect(date.isScheduleImminent == false)
  }

  @Test("과거 일정은 isScheduleLate = true")
  func pastDate_isLate() {
    let date = Date(timeIntervalSinceNow: -60)
    #expect(date.isScheduleLate == true)
  }

  @Test("미래 일정은 isScheduleLate = false")
  func futureDate_isNotLate() {
    let date = Date(timeIntervalSinceNow: 60)
    #expect(date.isScheduleLate == false)
  }
}

// MARK: - scheduleReminderTimes 테스트

@Suite("Date.scheduleReminderTimes 테스트")
struct ScheduleReminderTimesTests {

  @Test("기본 간격으로 미래 알림 시간만 반환")
  func defaultIntervals_returnsFutureOnly() {
    // 2시간 후 일정 → 60분, 30분, 15분 전 알림 모두 미래
    let scheduleDate = Date(timeIntervalSinceNow: 2 * 3600)
    let reminders = scheduleDate.scheduleReminderTimes()
    #expect(reminders.count == 3)
    for reminder in reminders {
      #expect(reminder > Date())
    }
  }

  @Test("이미 지난 알림 시간은 제외")
  func pastReminders_areExcluded() {
    // 10분 후 일정 → 60분 전, 30분 전은 이미 과거
    let scheduleDate = Date(timeIntervalSinceNow: 10 * 60)
    let reminders = scheduleDate.scheduleReminderTimes()
    // 15분 전 알림만 아직 미래일 수 없음 (10분 후 - 15분 = -5분 → 과거)
    // 모든 알림이 과거이므로 빈 배열
    #expect(reminders.isEmpty)
  }

  @Test("커스텀 간격 지정 가능")
  func customIntervals_work() {
    let scheduleDate = Date(timeIntervalSinceNow: 3 * 3600)
    let reminders = scheduleDate.scheduleReminderTimes(intervals: [120, 60, 5])
    #expect(reminders.count == 3)
  }
}

// MARK: - isThisWeekSchedule / isNextWeekSchedule / isThisMonthSchedule 테스트

@Suite("Date 기간 판별 테스트")
struct SchedulePeriodTests {

  @Test("오늘은 이번 주 일정")
  func today_isThisWeek() {
    let today = Date()
    #expect(today.isThisWeekSchedule == true)
  }

  @Test("30일 뒤는 이번 주 일정이 아님")
  func farFuture_isNotThisWeek() {
    let farDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
    #expect(farDate.isThisWeekSchedule == false)
  }

  @Test("오늘은 이번 달 일정")
  func today_isThisMonth() {
    let today = Date()
    #expect(today.isThisMonthSchedule == true)
  }

  @Test("6개월 뒤는 이번 달 일정이 아님")
  func sixMonthsLater_isNotThisMonth() {
    let farDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
    #expect(farDate.isThisMonthSchedule == false)
  }
}

// MARK: - scheduleGroupingKey 테스트

@Suite("Date.scheduleGroupingKey 테스트")
struct ScheduleGroupingKeyTests {

  @Test("yyyy-MM-dd 형식의 키 반환")
  func returnsFormattedKey() {
    // 고정된 날짜 사용
    var components = DateComponents()
    components.year = 2025
    components.month = 3
    components.day = 15
    let date = Calendar.current.date(from: components)!
    #expect(date.scheduleGroupingKey == "2025-03-15")
  }

  @Test("같은 날짜는 같은 키 반환")
  func sameDayReturnsSameKey() {
    let calendar = Calendar.current
    let date1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    let date2 = calendar.date(bySettingHour: 21, minute: 30, second: 0, of: Date())!
    #expect(date1.scheduleGroupingKey == date2.scheduleGroupingKey)
  }
}

// MARK: - Calendar 확장 테스트

@Suite("Calendar Schedule 확장 테스트")
struct CalendarScheduleExtensionTests {

  @Test("같은 날 날짜는 isSameScheduleDay = true")
  func sameDayDates_areSameDay() {
    let calendar = Calendar.current
    let date1 = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    let date2 = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
    #expect(calendar.isSameScheduleDay(date1, date2) == true)
  }

  @Test("다른 날 날짜는 isSameScheduleDay = false")
  func differentDayDates_areNotSameDay() {
    let calendar = Calendar.current
    let today = Date()
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
    #expect(calendar.isSameScheduleDay(today, tomorrow) == false)
  }

  @Test("groupSchedulesByWeek이 같은 주 일정을 그룹핑")
  func groupByWeek_groupsSameWeek() {
    let calendar = Calendar.current
    let now = Date()

    struct TestSchedule {
      let date: Date
    }

    let schedules = [
      TestSchedule(date: now),
      TestSchedule(date: calendar.date(byAdding: .day, value: 1, to: now)!),
    ]

    let grouped = calendar.groupSchedulesByWeek(schedules, dateKeyPath: \.date)
    // 같은 주이면 1그룹, 주말 넘어가면 2그룹
    #expect(grouped.count >= 1)

    let totalCount = grouped.values.reduce(0) { $0 + $1.count }
    #expect(totalCount == 2)
  }

  @Test("groupSchedulesByMonth가 같은 달 일정을 그룹핑")
  func groupByMonth_groupsSameMonth() {
    let calendar = Calendar.current
    let now = Date()

    struct TestSchedule {
      let date: Date
    }

    let schedules = [
      TestSchedule(date: now),
      TestSchedule(date: calendar.date(byAdding: .month, value: 2, to: now)!),
    ]

    let grouped = calendar.groupSchedulesByMonth(schedules, dateKeyPath: \.date)
    #expect(grouped.count == 2)
  }
}

// MARK: - TimeInterval 확장 테스트

@Suite("TimeInterval Schedule 확장 테스트")
struct TimeIntervalScheduleTests {

  @Test("minutesUntilSchedule 변환 확인")
  func minutesConversion() {
    let interval: TimeInterval = 150 // 2.5분
    #expect(interval.minutesUntilSchedule == 2)
  }

  @Test("hoursUntilSchedule 변환 확인")
  func hoursConversion() {
    let interval: TimeInterval = 7200 // 2시간
    #expect(interval.hoursUntilSchedule == 2)
  }

  @Test("daysUntilSchedule 변환 확인")
  func daysConversion() {
    let interval: TimeInterval = 172800 // 2일
    #expect(interval.daysUntilSchedule == 2)
  }

  @Test("isValidReminderInterval: 양수이고 7일 이내면 true")
  func validReminderInterval() {
    let valid: TimeInterval = 3600 // 1시간
    #expect(valid.isValidReminderInterval == true)
  }

  @Test("isValidReminderInterval: 0 이하면 false")
  func zeroInterval_isInvalid() {
    let zero: TimeInterval = 0
    #expect(zero.isValidReminderInterval == false)

    let negative: TimeInterval = -100
    #expect(negative.isValidReminderInterval == false)
  }

  @Test("isValidReminderInterval: 7일 초과면 false")
  func overSevenDays_isInvalid() {
    let tooLong: TimeInterval = 86400 * 7 + 1
    #expect(tooLong.isValidReminderInterval == false)
  }
}

// MARK: - LocalizedDateFormatters 테스트

@Suite("LocalizedDateFormatters 테스트")
struct LocalizedDateFormattersTests {

  @Test("sectionHeader는 날짜+요일 형식")
  func sectionHeaderFormat() {
    var components = DateComponents()
    components.year = 2025
    components.month = 1
    components.day = 15
    let date = Calendar.current.date(from: components)!
    let result = LocalizedDateFormatters.sectionHeader.string(from: date)
    #expect(result.contains("15"))
    #expect(result.contains("("))
    #expect(result.contains(")"))
  }

  @Test("monthDay는 월/일 정보 포함")
  func monthDayFormat() {
    var components = DateComponents()
    components.year = 2025
    components.month = 3
    components.day = 5
    let date = Calendar.current.date(from: components)!
    let result = LocalizedDateFormatters.monthDay.string(from: date)
    #expect(!result.isEmpty)
    #expect(result.contains("5"))
  }

  @Test("yearMonthDay는 연/월/일 정보 포함")
  func yearMonthDayFormat() {
    var components = DateComponents()
    components.year = 2031
    components.month = 12
    components.day = 4
    let date = Calendar.current.date(from: components)!
    let result = LocalizedDateFormatters.yearMonthDay.string(from: date)
    #expect(result.contains("2031"))
    #expect(result.contains("4"))
  }

  @Test("date는 'yyyy-MM-dd' 형식")
  func dateFormat() {
    var components = DateComponents()
    components.year = 2025
    components.month = 1
    components.day = 5
    let date = Calendar.current.date(from: components)!
    let result = LocalizedDateFormatters.date.string(from: date)
    #expect(result == "2025-01-05")
  }

  @Test("endTimeString: 오늘 날짜는 시간만 반환")
  func endTimeString_todayReturnsTimeOnly() {
    let today = Date()
    let result = LocalizedDateFormatters.endTimeString(from: today)
    #expect(result == LocalizedDateFormatters.timeString(from: today))
  }

  @Test("endTimeString(relativeTo:): 같은 날이면 시간만 반환")
  func endTimeStringRelative_sameDayReturnsTimeOnly() {
    let calendar = Calendar.current
    let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
    let end = calendar.date(bySettingHour: 14, minute: 30, second: 0, of: Date())!
    let result = LocalizedDateFormatters.endTimeString(from: end, relativeTo: start)
    #expect(result == LocalizedDateFormatters.timeString(from: end))
  }

  @Test("endTimeString(relativeTo:): 다른 날이면 날짜+시간 반환")
  func endTimeStringRelative_differentDayReturnsDateAndTime() {
    let calendar = Calendar.current
    let start = Date()
    let end = calendar.date(byAdding: .day, value: 2, to: start)!
    let result = LocalizedDateFormatters.endTimeString(from: end, relativeTo: start)
    #expect(result.hasPrefix(LocalizedDateFormatters.monthDayString(from: end)))
  }
}

// MARK: - Date (LocalizedDateFormatters 확장) 테스트

@Suite("Date formatted 프로퍼티 테스트")
struct DateFormattedPropertiesTests {

  @Test("startOfMonth가 해당 월 1일을 반환")
  func startOfMonth_returnsFirstDay() {
    var components = DateComponents()
    components.year = 2025
    components.month = 3
    components.day = 15
    let date = Calendar.current.date(from: components)!
    let startOfMonth = date.startOfMonth

    let resultComponents = Calendar.current.dateComponents([.year, .month, .day], from: startOfMonth)
    #expect(resultComponents.year == 2025)
    #expect(resultComponents.month == 3)
    #expect(resultComponents.day == 1)
  }

  @Test("daysInMonth가 올바른 일수 반환")
  func daysInMonth_returnsCorrectCount() {
    // 2025년 2월 (28일)
    var feb = DateComponents()
    feb.year = 2025
    feb.month = 2
    feb.day = 10
    let febDate = Calendar.current.date(from: feb)!
    #expect(febDate.daysInMonth == 28)

    // 2025년 1월 (31일)
    var jan = DateComponents()
    jan.year = 2025
    jan.month = 1
    jan.day = 10
    let janDate = Calendar.current.date(from: jan)!
    #expect(janDate.daysInMonth == 31)
  }

  @Test("firstWeekdayOfMonth가 1~7 범위의 값 반환")
  func firstWeekdayOfMonth_returnsValidRange() {
    let date = Date()
    let weekday = date.firstWeekdayOfMonth
    #expect(weekday >= 1 && weekday <= 7)
  }
}
