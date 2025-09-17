import Foundation

/// 날짜를 기반으로 캘린더 키를 생성하는 유틸리티
public class CalendarKeyGenerator {
  public init() {}
  
  /// YYYYMM 형식의 키 생성 (예: "202401")
  public func generateYyyymmKey(for date: Date) -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    return String(format: "%04d%02d", year, month)
  }
  
  /// YYYYMMDD 형식의 키 생성 (예: "20240115")
  public func generateYyyymmddKey(for date: Date) -> String {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return String(format: "%04d%02d%02d", year, month, day)
  }
}
