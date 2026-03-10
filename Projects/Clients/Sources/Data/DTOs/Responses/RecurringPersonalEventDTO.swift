import Foundation
import FirebaseFirestore
import PromisoShared

// MARK: - Recurring Personal Event DTO

/// Firestore users/{userId}/recurringEvents/{eventId} 문서 DTO
public struct RecurringPersonalEventDTO: Codable {
  public let title: String
  public let emoji: String?
  public let description: String?

  // 시간 (Map: {hour: Int, minute: Int})
  public let startTime: TimeComponentsDTO
  public let durationMinutes: Int?

  // 위치
  public let location: LocationDTO?

  // 알림
  public let reminderMinutesBefore: Int?

  // 반복 규칙
  public let recurrence: RecurrenceRuleDTO
  public let seriesStartDate: Timestamp

  // 예외 처리
  public let excludedDates: [String]?
  public let overrides: [String: EventOverrideDTO]?

  // 메타데이터
  public let createdAt: Timestamp
  public let updatedAt: Timestamp

  public init(
    title: String,
    emoji: String?,
    description: String?,
    startTime: TimeComponentsDTO,
    durationMinutes: Int?,
    location: LocationDTO?,
    reminderMinutesBefore: Int?,
    recurrence: RecurrenceRuleDTO,
    seriesStartDate: Timestamp,
    excludedDates: [String]?,
    overrides: [String: EventOverrideDTO]?,
    createdAt: Timestamp,
    updatedAt: Timestamp
  ) {
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

// MARK: - TimeComponents DTO

public struct TimeComponentsDTO: Codable {
  public let hour: Int
  public let minute: Int

  public init(hour: Int, minute: Int) {
    self.hour = hour
    self.minute = minute
  }

  public init(from components: DateComponents) {
    self.hour = components.hour ?? 0
    self.minute = components.minute ?? 0
  }

  public var toDateComponents: DateComponents {
    DateComponents(hour: hour, minute: minute)
  }
}

// MARK: - RecurrenceRule DTO

public struct RecurrenceRuleDTO: Codable {
  public let frequency: String
  public let daysOfWeek: [Int]?
  public let dayOfMonth: Int?
  public let seriesEndDate: Timestamp?

  public init(from rule: RecurrenceRule) {
    self.frequency = rule.frequency.rawValue
    self.daysOfWeek = rule.daysOfWeek
    self.dayOfMonth = rule.dayOfMonth
    self.seriesEndDate = rule.seriesEndDate.map { Timestamp(date: $0) }
  }

  public func toModel() -> RecurrenceRule {
    RecurrenceRule(
      frequency: RecurrenceRule.Frequency(rawValue: frequency) ?? .weekly,
      daysOfWeek: daysOfWeek,
      dayOfMonth: dayOfMonth,
      seriesEndDate: seriesEndDate?.dateValue()
    )
  }
}

// MARK: - EventOverride DTO

public struct EventOverrideDTO: Codable {
  public let title: String?
  public let startTime: TimeComponentsDTO?
  public let durationMinutes: Int?
  public let location: LocationDTO?
  public let isCancelled: Bool?

  public init(from override: EventOverride) {
    self.title = override.title
    self.startTime = override.startTime.map { TimeComponentsDTO(from: $0) }
    self.durationMinutes = override.durationMinutes
    self.location = override.location.map { LocationDTO(model: $0) }
    self.isCancelled = override.isCancelled
  }

  public func toModel() -> EventOverride {
    EventOverride(
      title: title,
      startTime: startTime?.toDateComponents,
      durationMinutes: durationMinutes,
      location: location.map { LocationInfoModel(dto: $0) },
      isCancelled: isCancelled ?? false
    )
  }
}

// MARK: - Model -> DTO 변환

extension RecurringPersonalEventDTO {
  public init(model: RecurringPersonalEventModel) {
    self.init(
      title: model.title,
      emoji: model.emoji,
      description: model.description,
      startTime: TimeComponentsDTO(from: model.startTime),
      durationMinutes: model.durationMinutes,
      location: model.location.map { LocationDTO(model: $0) },
      reminderMinutesBefore: model.reminderMinutesBefore,
      recurrence: RecurrenceRuleDTO(from: model.recurrence),
      seriesStartDate: Timestamp(date: model.seriesStartDate),
      excludedDates: model.excludedDates.isEmpty ? nil : Array(model.excludedDates),
      overrides: model.overrides.isEmpty ? nil : model.overrides.mapValues { EventOverrideDTO(from: $0) },
      createdAt: Timestamp(date: model.createdAt),
      updatedAt: Timestamp(date: model.updatedAt)
    )
  }
}

// MARK: - DTO -> Model 변환

extension RecurringPersonalEventModel {
  public init(dto: RecurringPersonalEventDTO, id: String) {
    self.init(
      id: id,
      title: dto.title,
      emoji: dto.emoji,
      description: dto.description,
      startTime: dto.startTime.toDateComponents,
      durationMinutes: dto.durationMinutes,
      location: dto.location.map { LocationInfoModel(dto: $0) },
      reminderMinutesBefore: dto.reminderMinutesBefore,
      recurrence: dto.recurrence.toModel(),
      seriesStartDate: dto.seriesStartDate.dateValue(),
      excludedDates: Set(dto.excludedDates ?? []),
      overrides: (dto.overrides ?? [:]).mapValues { $0.toModel() },
      createdAt: dto.createdAt.dateValue(),
      updatedAt: dto.updatedAt.dateValue()
    )
  }
}
