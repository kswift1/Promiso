import Foundation

// MARK: - Recurring Personal Event Model

/// 반복 개인 일정 도메인 모델
/// 규칙 기반으로 저장되며, 화면에 표시할 때 RecurringEventExpander로 인스턴스 생성
public struct RecurringPersonalEventModel: Identifiable, Equatable, Hashable, Sendable {
  // MARK: - 기본 정보
  public var id: String
  public var title: String
  public var emoji: String?
  public var description: String?

  // MARK: - 시간 (시/분만 저장, 날짜는 반복 규칙으로 결정)
  /// 시작 시각 (hour, minute)
  public var startTime: DateComponents
  /// 소요 시간 (분 단위, nil = 종료 시간 없음)
  public var durationMinutes: Int?

  // MARK: - 위치
  public var location: LocationInfoModel?

  // MARK: - 알림
  public var reminderMinutesBefore: Int?

  // MARK: - 반복 규칙
  public var recurrence: RecurrenceRule
  /// 반복 시작일 (이 날짜부터 반복)
  public var seriesStartDate: Date

  // MARK: - 예외 처리
  /// 취소된 날짜 목록 ("yyyy-MM-dd" 형식)
  public var excludedDates: Set<String>
  /// 날짜별 개별 수정 ("yyyy-MM-dd" → Override)
  public var overrides: [String: EventOverride]

  // MARK: - 메타데이터
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    title: String = "",
    emoji: String? = nil,
    description: String? = nil,
    startTime: DateComponents = DateComponents(hour: 9, minute: 0),
    durationMinutes: Int? = nil,
    location: LocationInfoModel? = nil,
    reminderMinutesBefore: Int? = nil,
    recurrence: RecurrenceRule = .daily(),
    seriesStartDate: Date = Date(),
    excludedDates: Set<String> = [],
    overrides: [String: EventOverride] = [:],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.description = description
    self.startTime = startTime
    self.durationMinutes = durationMinutes
    self.location = location
    self.reminderMinutesBefore = reminderMinutesBefore
    self.recurrence = recurrence
    self.seriesStartDate = seriesStartDate
    self.excludedDates = excludedDates
    self.overrides = overrides
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

// MARK: - Event Override

/// 특정 날짜의 개별 수정사항
public struct EventOverride: Codable, Equatable, Hashable, Sendable {
  /// 변경된 제목 (nil이면 원본 유지)
  public var title: String?
  /// 변경된 시작 시각 (nil이면 원본 유지)
  public var startTime: DateComponents?
  /// 변경된 소요 시간 (nil이면 원본 유지)
  public var durationMinutes: Int?
  /// 변경된 장소 (nil이면 원본 유지)
  public var location: LocationInfoModel?
  /// 이 날 취소 여부
  public var isCancelled: Bool

  public init(
    title: String? = nil,
    startTime: DateComponents? = nil,
    durationMinutes: Int? = nil,
    location: LocationInfoModel? = nil,
    isCancelled: Bool = false
  ) {
    self.title = title
    self.startTime = startTime
    self.durationMinutes = durationMinutes
    self.location = location
    self.isCancelled = isCancelled
  }
}

// MARK: - Codable Conformance

extension RecurringPersonalEventModel: Codable {}

// MARK: - Empty & Mock

extension RecurringPersonalEventModel {
  /// 빈 반복 일정 (생성 폼용)
  public static var empty: RecurringPersonalEventModel {
    RecurringPersonalEventModel()
  }

  /// Preview/테스트용 Mock
  public static func mock(
    id: String = "mock-recurring-id",
    title: String = "매주 헬스장",
    emoji: String? = "🏋️",
    startTime: DateComponents = DateComponents(hour: 19, minute: 0),
    durationMinutes: Int? = 60,
    recurrence: RecurrenceRule = .weekly([2, 4, 6])
  ) -> RecurringPersonalEventModel {
    RecurringPersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      startTime: startTime,
      durationMinutes: durationMinutes,
      recurrence: recurrence,
      seriesStartDate: Date()
    )
  }
}

// MARK: - UI Display

extension RecurringPersonalEventModel {
  /// 표시용 이모지
  public var displayEmoji: String {
    guard let emoji = emoji, !emoji.isEmpty else { return "🔄" }
    return emoji
  }

  /// 시간 텍스트 (예: "19:00")
  public var timeText: String {
    let hour = startTime.hour ?? 0
    let minute = startTime.minute ?? 0
    return String(format: "%02d:%02d", hour, minute)
  }

  /// 소요 시간 텍스트
  public var durationText: String? {
    guard let minutes = durationMinutes else { return nil }
    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      if remainingMinutes == 0 {
        return "\(hours)시간"
      }
      return "\(hours)시간 \(remainingMinutes)분"
    }
    return "\(minutes)분"
  }

  /// 반복 규칙 + 시간 요약 (예: "매주 월, 수, 금 19:00")
  public var summaryText: String {
    "\(recurrence.displayText) \(timeText)"
  }
}

// MARK: - Validation

extension RecurringPersonalEventModel {
  /// 제목 유효성
  public var isTitleValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 생성 가능 여부
  public var canCreate: Bool {
    isTitleValid && isRecurrenceValid
  }

  /// 반복 규칙 유효성
  public var isRecurrenceValid: Bool {
    switch recurrence.frequency {
    case .daily:
      return true
    case .weekly, .biweekly:
      guard let days = recurrence.daysOfWeek else { return false }
      return !days.isEmpty && days.allSatisfy { (1...7).contains($0) }
    case .monthly:
      guard let day = recurrence.dayOfMonth else { return false }
      return (1...31).contains(day)
    }
  }
}

// MARK: - Date Key Helper

extension RecurringPersonalEventModel {
  /// Date를 "yyyy-MM-dd" 문자열로 변환
  public static func dateKey(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
  }
}
