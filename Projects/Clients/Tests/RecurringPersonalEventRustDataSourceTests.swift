import Testing
@testable import Clients

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
