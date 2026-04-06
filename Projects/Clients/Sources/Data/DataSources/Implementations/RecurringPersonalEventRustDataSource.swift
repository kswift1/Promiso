import Foundation
import PromisoShared

// MARK: - Response DTOs

/// 반복 일정 생성 응답
private struct RustCreateRecurringResponse: Decodable {
  let id: String
  let createdAt: Date
}

/// 반복 일정 응답
private struct RustRecurringScheduleResponse: Decodable {
  let id: String
  let userId: String?
  let title: String
  let emoji: String?
  let description: String?
  let startTimeHour: Int
  let startTimeMinute: Int
  let endTimeHour: Int?
  let endTimeMinute: Int?
  let location: RustRecurringLocationResponse?
  let reminderMinutesBefore: Int?
  let frequency: String
  let daysOfWeek: [Int]?
  let dayOfMonth: Int?
  let seriesStartDate: String
  let seriesEndDate: String?
  let excludedDates: [String]?
  let overrides: OverridesJSON?
  let createdAt: Date
  let updatedAt: Date
}

private struct RustRecurringLocationResponse: Decodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct RustRecurringSuccessResponse: Decodable {
  let success: Bool?
}

// overrides: 서버에서 JSON object로 전달
private typealias OverridesJSON = [String: RustEventOverrideDTO]

private struct RustEventOverrideDTO: Decodable {
  let title: String?
  let startTime: RustRecurringTimeComponents?
  let endTime: RustRecurringTimeComponents?
  let location: RustRecurringLocationResponse?
  let isCancelled: Bool?
}

private struct RustRecurringTimeComponents: Decodable {
  let hour: Int
  let minute: Int
}

// MARK: - Request Bodies

private struct CreateRecurringScheduleBody: Encodable {
  let title: String
  let emoji: String?
  let description: String?
  let startTime: RecurringTimeBody
  let endTime: RecurringTimeBody?
  let location: RecurringLocationBody?
  let reminderMinutesBefore: Int?
  let frequency: String
  let daysOfWeek: [Int]?
  let dayOfMonth: Int?
  let seriesStartDate: String
  let seriesEndDate: String?
}

private struct RecurringTimeBody: Encodable {
  let hour: Int
  let minute: Int
}

private struct RecurringLocationBody: Encodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct UpdateRecurringScheduleBody: Encodable {
  let title: String?
  let emoji: String??
  let description: String??
  let startTime: RecurringTimeBody?
  let endTime: RecurringTimeBody??
  let location: RecurringLocationBody??
  let reminderMinutesBefore: Int??
  let frequency: String?
  let daysOfWeek: [Int]??
  let dayOfMonth: Int??
  let seriesStartDate: String?
  let seriesEndDate: String??
  let excludedDates: [String]?
  let overrides: [String: EventOverrideBody]??

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(title, forKey: .title)

    // emoji: Option<Option<String>>
    switch emoji {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .emoji)
    case .some(.some(let v)): try container.encode(v, forKey: .emoji)
    }

    // description: Option<Option<String>>
    switch description {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .description)
    case .some(.some(let v)): try container.encode(v, forKey: .description)
    }

    try container.encodeIfPresent(startTime, forKey: .startTime)

    // endTime: Option<Option<RecurringTimeBody>>
    switch endTime {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .endTime)
    case .some(.some(let v)): try container.encode(v, forKey: .endTime)
    }

    // location: Option<Option<RecurringLocationBody>>
    switch location {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .location)
    case .some(.some(let v)): try container.encode(v, forKey: .location)
    }

    // reminderMinutesBefore: Option<Option<Int>>
    switch reminderMinutesBefore {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .reminderMinutesBefore)
    case .some(.some(let v)): try container.encode(v, forKey: .reminderMinutesBefore)
    }

    try container.encodeIfPresent(frequency, forKey: .frequency)

    // daysOfWeek: Option<Option<[Int]>>
    switch daysOfWeek {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .daysOfWeek)
    case .some(.some(let v)): try container.encode(v, forKey: .daysOfWeek)
    }

    // dayOfMonth: Option<Option<Int>>
    switch dayOfMonth {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .dayOfMonth)
    case .some(.some(let v)): try container.encode(v, forKey: .dayOfMonth)
    }

    try container.encodeIfPresent(seriesStartDate, forKey: .seriesStartDate)

    // seriesEndDate: Option<Option<String>>
    switch seriesEndDate {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .seriesEndDate)
    case .some(.some(let v)): try container.encode(v, forKey: .seriesEndDate)
    }

    try container.encodeIfPresent(excludedDates, forKey: .excludedDates)

    // overrides: Option<Option<[String: EventOverrideBody]>>
    switch overrides {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .overrides)
    case .some(.some(let v)): try container.encode(v, forKey: .overrides)
    }
  }

  enum CodingKeys: String, CodingKey {
    case title, emoji, description, startTime, endTime
    case location, reminderMinutesBefore, frequency
    case daysOfWeek, dayOfMonth, seriesStartDate, seriesEndDate
    case excludedDates, overrides
  }
}

private struct EventOverrideBody: Encodable {
  let title: String?
  let startTime: RecurringTimeBody?
  let endTime: RecurringTimeBody?
  let location: RecurringLocationBody?
  let isCancelled: Bool
}

// MARK: - RecurringPersonalEventRustDataSource

public actor RecurringPersonalEventRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Create

  public func createEvent(_ event: RecurringPersonalEventModel) async throws -> String {
    let locationBody: RecurringLocationBody? = event.location.flatMap { loc in
      guard !loc.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return RecurringLocationBody(
        name: loc.name,
        address: loc.address,
        latitude: loc.latitude,
        longitude: loc.longitude
      )
    }

    // Swift daysOfWeek (1=Sun~7=Sat) → Rust (0=Sun~6=Sat)
    let rustDaysOfWeek = event.recurrence.daysOfWeek?.map { $0 - 1 }

    let body = CreateRecurringScheduleBody(
      title: event.title,
      emoji: event.emoji?.isEmpty == true ? nil : event.emoji,
      description: event.description?.isEmpty == true ? nil : event.description,
      startTime: RecurringTimeBody(hour: event.startTime.hour ?? 0, minute: event.startTime.minute ?? 0),
      endTime: event.endTime.map { RecurringTimeBody(hour: $0.hour ?? 0, minute: $0.minute ?? 0) },
      location: locationBody,
      reminderMinutesBefore: event.reminderMinutesBefore,
      frequency: event.recurrence.frequency.rawValue,
      daysOfWeek: rustDaysOfWeek,
      dayOfMonth: event.recurrence.dayOfMonth,
      seriesStartDate: RecurringPersonalEventModel.dateKey(from: event.seriesStartDate),
      seriesEndDate: event.recurrence.seriesEndDate.map { RecurringPersonalEventModel.dateKey(from: $0) }
    )

    let response: RustCreateRecurringResponse = try await api.post("/api/v1/recurring-schedules", body: body)
    return response.id
  }

  // MARK: - Read

  public func getEvent(id: String) async throws -> RecurringPersonalEventModel? {
    do {
      let response: RustRecurringScheduleResponse = try await api.get("/api/v1/recurring-schedules/\(id)")
      return response.toModel()
    } catch RustAPIError.httpError(let statusCode) where statusCode == 404 {
      return nil
    }
  }

  // MARK: - Update

  public func updateEvent(_ event: RecurringPersonalEventModel) async throws {
    let locationBody: RecurringLocationBody?? = {
      if let loc = event.location,
         !loc.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .some(RecurringLocationBody(
          name: loc.name,
          address: loc.address,
          latitude: loc.latitude,
          longitude: loc.longitude
        ))
      } else {
        return .some(nil)
      }
    }()

    // Swift daysOfWeek (1=Sun~7=Sat) → Rust (0=Sun~6=Sat)
    let rustDaysOfWeek: [Int]?? = {
      guard let days = event.recurrence.daysOfWeek else {
        return .none
      }
      return .some(days.map { $0 - 1 })
    }()

    // overrides → EventOverrideBody (비어있으면 생략, 있으면 전송)
    let overrideBodies: [String: EventOverrideBody]?? = {
      if event.overrides.isEmpty {
        return .none
      } else {
        let mapped = event.overrides.mapValues { override in
          EventOverrideBody(
            title: override.title,
            startTime: override.startTime.map { RecurringTimeBody(hour: $0.hour ?? 0, minute: $0.minute ?? 0) },
            endTime: override.endTime.map { RecurringTimeBody(hour: $0.hour ?? 0, minute: $0.minute ?? 0) },
            location: override.location.map {
              RecurringLocationBody(name: $0.name, address: $0.address, latitude: $0.latitude, longitude: $0.longitude)
            },
            isCancelled: override.isCancelled
          )
        }
        return .some(mapped)
      }
    }()

    let body = UpdateRecurringScheduleBody(
      title: event.title,
      emoji: .some(event.emoji),
      description: .some(event.description),
      startTime: RecurringTimeBody(hour: event.startTime.hour ?? 0, minute: event.startTime.minute ?? 0),
      endTime: .some(event.endTime.map { RecurringTimeBody(hour: $0.hour ?? 0, minute: $0.minute ?? 0) }),
      location: locationBody,
      reminderMinutesBefore: .some(event.reminderMinutesBefore),
      frequency: event.recurrence.frequency.rawValue,
      daysOfWeek: rustDaysOfWeek,
      dayOfMonth: .some(event.recurrence.dayOfMonth),
      seriesStartDate: RecurringPersonalEventModel.dateKey(from: event.seriesStartDate),
      seriesEndDate: .some(event.recurrence.seriesEndDate.map { RecurringPersonalEventModel.dateKey(from: $0) }),
      excludedDates: event.excludedDates.isEmpty ? nil : Array(event.excludedDates),
      overrides: overrideBodies
    )

    let _: RustRecurringSuccessResponse = try await api.patch("/api/v1/recurring-schedules/\(event.id)", body: body)
  }

  // MARK: - Delete

  public func deleteEvent(id: String) async throws {
    let _: RustRecurringSuccessResponse = try await api.delete("/api/v1/recurring-schedules/\(id)")
  }

  // MARK: - List

  public func getAllEvents() async throws -> [RecurringPersonalEventModel] {
    let response: [RustRecurringScheduleResponse] = try await api.get("/api/v1/recurring-schedules")
    return response.map { $0.toModel() }
  }
}

// MARK: - DTO -> Model

extension RustRecurringScheduleResponse {
  fileprivate func toModel() -> RecurringPersonalEventModel {
    let locationModel: LocationInfoModel? = location.map {
      LocationInfoModel(
        name: $0.name,
        address: $0.address,
        latitude: $0.latitude,
        longitude: $0.longitude
      )
    }

    // frequency → RecurrenceRule
    let freq = RecurrenceRule.Frequency(rawValue: frequency) ?? .daily

    // Rust daysOfWeek (0=Sun~6=Sat) → Swift (1=Sun~7=Sat)
    let swiftDaysOfWeek = daysOfWeek?.map { $0 + 1 }

    let recurrenceRule = RecurrenceRule(
      frequency: freq,
      daysOfWeek: swiftDaysOfWeek,
      dayOfMonth: dayOfMonth,
      seriesEndDate: Self.parseDate(seriesEndDate)
    )

    // excludedDates → Set<String>
    let excluded = Set(excludedDates ?? [])

    // overrides → [String: EventOverride]
    let eventOverrides: [String: EventOverride] = (overrides ?? [:]).mapValues { dto in
      EventOverride(
        title: dto.title,
        startTime: dto.startTime.map { DateComponents(hour: $0.hour, minute: $0.minute) },
        endTime: dto.endTime.map { DateComponents(hour: $0.hour, minute: $0.minute) },
        location: dto.location.map {
          LocationInfoModel(name: $0.name, address: $0.address, latitude: $0.latitude, longitude: $0.longitude)
        },
        isCancelled: dto.isCancelled ?? false
      )
    }

    return RecurringPersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      startTime: DateComponents(hour: startTimeHour, minute: startTimeMinute),
      endTime: endTimeHour.map { DateComponents(hour: $0, minute: endTimeMinute ?? 0) },
      location: locationModel,
      reminderMinutesBefore: reminderMinutesBefore,
      recurrence: recurrenceRule,
      seriesStartDate: Self.parseDate(seriesStartDate) ?? Date(),
      excludedDates: excluded,
      overrides: eventOverrides,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  private static func parseDate(_ string: String?) -> Date? {
    guard let string = string else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: string)
  }
}
