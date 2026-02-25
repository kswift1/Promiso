import Foundation

// MARK: - Korean Date Parser

/// 한국어 날짜/시간 표현을 Date로 변환하는 파서
/// NSDataDetector(절대 날짜) + 정규표현식(상대 날짜) 계층 구조
public enum KoreanDateParser {

  // MARK: - Public API

  /// 텍스트에서 날짜/시간 추출
  /// - Parameter text: 입력 텍스트
  /// - Returns: 추출된 Date (없으면 nil)
  public static func parse(_ text: String) -> Date? {
    // 1순위: NSDataDetector (절대 날짜: "2026년 3월 1일", "3/1" 등)
    if let date = parseWithDataDetector(text) {
      return date
    }

    // 2순위: 커스텀 파서 (한국어 상대 표현)
    if let date = parseKoreanRelative(text) {
      return date
    }

    return nil
  }

  // MARK: - NSDataDetector

  private static func parseWithDataDetector(_ text: String) -> Date? {
    guard let detector = try? NSDataDetector(
      types: NSTextCheckingResult.CheckingType.date.rawValue
    ) else { return nil }

    let range = NSRange(text.startIndex..., in: text)
    let matches = detector.matches(in: text, range: range)

    // 가장 가까운 미래 날짜 반환
    let now = Date()
    return matches
      .compactMap(\.date)
      .filter { $0 > now.addingTimeInterval(-3600) } // 1시간 전까지 허용
      .min(by: { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) })
  }

  // MARK: - Korean Relative Date Parser

  private static func parseKoreanRelative(_ text: String) -> Date? {
    let calendar = Calendar.current
    let now = Date()

    var targetDate: Date?
    var hour: Int?
    var minute: Int = 0

    // 시간 추출 (오전/오후 N시 N분)
    let timeResult = extractTime(from: text)
    hour = timeResult.hour
    minute = timeResult.minute

    // 날짜 추출
    if let relativeDay = extractRelativeDay(from: text) {
      targetDate = calendar.date(byAdding: .day, value: relativeDay, to: now)
    } else if let weekdayResult = extractWeekday(from: text) {
      targetDate = nextDate(for: weekdayResult.weekday, isNextWeek: weekdayResult.isNextWeek)
    }

    // 날짜+시간 조합
    if let date = targetDate, let h = hour {
      return calendar.date(bySettingHour: h, minute: minute, second: 0, of: date)
    }

    // 시간만 있는 경우 (오늘 또는 내일)
    if let h = hour {
      var candidate = calendar.date(bySettingHour: h, minute: minute, second: 0, of: now) ?? now
      if candidate <= now {
        candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
      }
      return candidate
    }

    // 날짜만 있는 경우
    return targetDate
  }

  // MARK: - Time Extraction

  private static func extractTime(from text: String) -> (hour: Int?, minute: Int) {
    // "오후 3시 30분", "오전 10시", "저녁 7시", "밤 11시", "새벽 2시"
    let pattern = #"(오전|오후|저녁|밤|새벽)?\s*(\d{1,2})\s*시\s*(?:(\d{1,2})\s*분)?"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return (nil, 0) }

    let ampmRange = Range(match.range(at: 1), in: text)
    let ampm = ampmRange.map { String(text[$0]) }

    guard let hourRange = Range(match.range(at: 2), in: text),
          var h = Int(text[hourRange])
    else { return (nil, 0) }

    let minuteRange = Range(match.range(at: 3), in: text)
    let m = minuteRange.flatMap { Int(text[$0]) } ?? 0

    // AM/PM 변환
    switch ampm {
    case "오후", "저녁", "밤":
      if h < 12 { h += 12 }
    case "오전", "새벽":
      if h == 12 { h = 0 }
    default:
      // 지정 없으면 12시간 기준 추측 (1~6 → 오후, 7~11 → 오전 가능성)
      if h >= 1 && h <= 6 { h += 12 }
    }

    return (h, m)
  }

  // MARK: - Relative Day Extraction

  /// "오늘" → 0, "내일" → 1, "모레" → 2
  private static func extractRelativeDay(from text: String) -> Int? {
    if text.contains("모레") { return 2 }
    if text.contains("내일") { return 1 }
    if text.contains("오늘") { return 0 }
    return nil
  }

  // MARK: - Weekday Extraction

  private struct WeekdayResult {
    let weekday: Int // 1=일, 2=월, ..., 7=토
    let isNextWeek: Bool
  }

  private static let weekdayMap: [String: Int] = [
    "일": 1, "월": 2, "화": 3, "수": 4, "목": 5, "금": 6, "토": 7,
  ]

  private static func extractWeekday(from text: String) -> WeekdayResult? {
    let pattern = #"(이번\s*주|다음\s*주|이번주|다음주)?\s*(월|화|수|목|금|토|일)\s*요일"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    else { return nil }

    guard let dayRange = Range(match.range(at: 2), in: text),
          let weekday = weekdayMap[String(text[dayRange])]
    else { return nil }

    let prefixRange = Range(match.range(at: 1), in: text)
    let prefix = prefixRange.map { String(text[$0]) } ?? ""
    let isNextWeek = prefix.contains("다음")

    return WeekdayResult(weekday: weekday, isNextWeek: isNextWeek)
  }

  /// 다음 특정 요일 날짜 계산
  private static func nextDate(for weekday: Int, isNextWeek: Bool) -> Date {
    let calendar = Calendar.current
    let today = calendar.component(.weekday, from: Date())
    var daysAhead = weekday - today
    if daysAhead <= 0 { daysAhead += 7 }
    if isNextWeek { daysAhead += 7 }
    return calendar.date(byAdding: .day, value: daysAhead, to: Date()) ?? Date()
  }
}
