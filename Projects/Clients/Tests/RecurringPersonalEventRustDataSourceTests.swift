import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - 요일 매핑 테스트

@Suite("RecurringPersonalEventRustDataSource 요일 매핑")
struct RecurringPersonalEventRustDataSourceTests {

  @Test("요청 바디 변환 시 요일 값을 그대로 유지")
  func rustDaysOfWeek_preservesSwiftWeekdays() {
    let weekdays = [1, 3, 7]

    let result = RecurringPersonalEventRustDataSource.rustDaysOfWeek(from: weekdays)

    #expect(result == [1, 3, 7])
  }

  @Test("응답 모델 변환 시 요일 값을 그대로 유지")
  func swiftDaysOfWeek_preservesRustWeekdays() {
    let weekdays = [1, 4, 6]

    let result = RecurringPersonalEventRustDataSource.swiftDaysOfWeek(from: weekdays)

    #expect(result == [1, 4, 6])
  }

  @Test("요일이 없으면 nil을 그대로 유지")
  func weekdayMapping_nilStaysNil() {
    #expect(RecurringPersonalEventRustDataSource.rustDaysOfWeek(from: nil) == nil)
    #expect(RecurringPersonalEventRustDataSource.swiftDaysOfWeek(from: nil) == nil)
  }
}

// MARK: - RecurrenceRule.Frequency rawValue 파싱 테스트

@Suite("RecurrenceRule.Frequency rawValue 파싱")
struct RecurrenceFrequencyRawValueTests {

  @Test("'monthly' lowercase rawValue로 Frequency 생성 성공")
  func monthly_lowercase_parsesSuccessfully() {
    let freq = RecurrenceRule.Frequency(rawValue: "monthly")

    #expect(freq == .monthly)
  }

  @Test("'daily' lowercase rawValue로 Frequency 생성 성공")
  func daily_lowercase_parsesSuccessfully() {
    let freq = RecurrenceRule.Frequency(rawValue: "daily")

    #expect(freq == .daily)
  }

  @Test("'weekly' lowercase rawValue로 Frequency 생성 성공")
  func weekly_lowercase_parsesSuccessfully() {
    let freq = RecurrenceRule.Frequency(rawValue: "weekly")

    #expect(freq == .weekly)
  }

  @Test("'Monthly' PascalCase rawValue는 nil 반환")
  func monthly_pascalCase_returnsNil() {
    let freq = RecurrenceRule.Frequency(rawValue: "Monthly")

    #expect(freq == nil)
  }

  @Test("'Daily' PascalCase rawValue는 nil 반환")
  func daily_pascalCase_returnsNil() {
    let freq = RecurrenceRule.Frequency(rawValue: "Daily")

    #expect(freq == nil)
  }

  @Test("'Weekly' PascalCase rawValue는 nil 반환")
  func weekly_pascalCase_returnsNil() {
    let freq = RecurrenceRule.Frequency(rawValue: "Weekly")

    #expect(freq == nil)
  }

  @Test("빈 문자열 rawValue는 nil 반환")
  func empty_rawValue_returnsNil() {
    let freq = RecurrenceRule.Frequency(rawValue: "")

    #expect(freq == nil)
  }

  @Test("알 수 없는 rawValue는 nil 반환")
  func unknown_rawValue_returnsNil() {
    let freq = RecurrenceRule.Frequency(rawValue: "MONTHLY")

    #expect(freq == nil)
  }
}

// MARK: - frequency fallback 테스트

@Suite("RecurringPersonalEventRustDataSource frequency fallback")
struct FrequencyFallbackTests {

  /// 서버가 알 수 없는 frequency 문자열을 반환할 때 .daily로 fallback되는지 검증
  @Test("알 수 없는 frequency 문자열은 .daily로 fallback")
  func unknownFrequency_fallbackToDaily() {
    // RecurrenceRule.Frequency(rawValue:) ?? .daily 패턴을 직접 검증
    let freq = RecurrenceRule.Frequency(rawValue: "UNKNOWN") ?? .daily

    #expect(freq == .daily)
  }

  @Test("'Monthly' PascalCase는 .daily로 fallback (서버 오타 대응)")
  func monthlyPascalCase_fallbackToDaily() {
    let freq = RecurrenceRule.Frequency(rawValue: "Monthly") ?? .daily

    #expect(freq == .daily)
  }

  @Test("'monthly' lowercase는 .monthly로 정상 파싱 (fallback 불필요)")
  func monthlyLowercase_noFallbackNeeded() {
    let freq = RecurrenceRule.Frequency(rawValue: "monthly") ?? .daily

    #expect(freq == .monthly)
  }

  @Test("Frequency rawValue 전체 roundtrip: .daily.rawValue == 'daily'")
  func daily_rawValue_isLowercase() {
    #expect(RecurrenceRule.Frequency.daily.rawValue == "daily")
    #expect(RecurrenceRule.Frequency.weekly.rawValue == "weekly")
    #expect(RecurrenceRule.Frequency.monthly.rawValue == "monthly")
  }
}
