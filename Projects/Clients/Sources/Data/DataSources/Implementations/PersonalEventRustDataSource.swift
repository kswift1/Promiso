import Foundation
import PromisoShared

// MARK: - Response DTOs

/// 일정 생성 응답
private struct RustCreateScheduleResponse: Decodable {
  let scheduleId: String
  let title: String
  let startAt: Date
}

/// 개인 일정 상세 응답
private struct RustPersonalScheduleResponse: Decodable {
  let id: String
  let scheduleType: String
  let userId: String?
  let title: String
  let emoji: String?
  let description: String?
  let descriptionBlocks: [RustDescriptionBlockDTO]?
  let startAt: Date
  let endAt: Date?
  let location: RustLocationResponse?
  let imageUrls: [String]?
  let reminderMinutesBefore: Int?
  let createdAt: Date
  let updatedAt: Date
}

private struct RustLocationResponse: Decodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct RustDescriptionBlockDTO: Decodable {
  let type: String
  let content: String?
  let items: [RustChecklistItemDTO]?
  let bulletItems: [String]?

  private enum CodingKeys: String, CodingKey {
    case type, content, items
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    content = try container.decodeIfPresent(String.self, forKey: .content)

    switch type {
    case "checklist":
      items = try container.decodeIfPresent([RustChecklistItemDTO].self, forKey: .items)
      bulletItems = nil
    case "bulletList":
      items = nil
      bulletItems = try container.decodeIfPresent([String].self, forKey: .items)
    default:
      items = nil
      bulletItems = nil
    }
  }
}

private struct RustChecklistItemDTO: Decodable {
  let id: String
  let text: String
  let isChecked: Bool
}

private struct RustSuccessResponse: Decodable {
  let success: Bool?
}

/// 캘린더 응답
private struct RustCalendarResponse: Decodable {
  let schedules: [RustPersonalScheduleResponse]
  let recurringInstances: [RustRecurringInstance]
}

private struct RustRecurringInstance: Decodable {
  let recurringScheduleId: String
  let title: String
  let emoji: String?
  let date: String
  let startTime: RustTimeComponents
  let endTime: RustTimeComponents?
  let location: RustLocationResponse?
}

private struct RustTimeComponents: Decodable {
  let hour: Int
  let minute: Int
}

// MARK: - Request Bodies

private struct CreatePersonalScheduleBody: Encodable {
  let scheduleType: String = "personal"
  let title: String
  let emoji: String?
  let description: String?
  let descriptionBlocks: [DescriptionBlock]?
  let startAt: Date
  let endAt: Date?
  let location: LocationBody?
  let imageUrls: [String]?
  let reminderMinutesBefore: Int?
}

private struct LocationBody: Encodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct UpdatePersonalScheduleBody: Encodable {
  let title: String?
  let emoji: String??
  let description: String??
  let descriptionBlocks: [DescriptionBlock]??
  let startAt: Date?
  let endAt: Date??
  let location: LocationBody??
  let imageUrls: [String]??
  let reminderMinutesBefore: Int??

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

    // descriptionBlocks: Option<Option<[DescriptionBlock]>>
    switch descriptionBlocks {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .descriptionBlocks)
    case .some(.some(let v)): try container.encode(v, forKey: .descriptionBlocks)
    }

    try container.encodeIfPresent(startAt, forKey: .startAt)

    // endAt: Option<Option<Date>>
    switch endAt {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .endAt)
    case .some(.some(let v)): try container.encode(v, forKey: .endAt)
    }

    // location: Option<Option<LocationBody>>
    switch location {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .location)
    case .some(.some(let v)): try container.encode(v, forKey: .location)
    }

    // imageUrls: Option<Option<[String]>>
    switch imageUrls {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .imageUrls)
    case .some(.some(let v)): try container.encode(v, forKey: .imageUrls)
    }

    // reminderMinutesBefore: Option<Option<Int>>
    switch reminderMinutesBefore {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .reminderMinutesBefore)
    case .some(.some(let v)): try container.encode(v, forKey: .reminderMinutesBefore)
    }
  }

  enum CodingKeys: String, CodingKey {
    case title, emoji, description, descriptionBlocks, startAt, endAt
    case location, imageUrls, reminderMinutesBefore
  }
}

// MARK: - PersonalEventRustDataSource

public actor PersonalEventRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Create

  public func createEvent(_ event: PersonalEventModel) async throws -> String {
    let locationBody: LocationBody? = event.location.flatMap { loc in
      guard !loc.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return LocationBody(
        name: loc.name,
        address: loc.address,
        latitude: loc.latitude,
        longitude: loc.longitude
      )
    }

    let body = CreatePersonalScheduleBody(
      title: event.title,
      emoji: event.emoji?.isEmpty == true ? nil : event.emoji,
      description: event.description?.isEmpty == true ? nil : event.description,
      descriptionBlocks: event.descriptionBlocks.isEmpty ? nil : event.descriptionBlocks,
      startAt: event.startAt,
      endAt: event.endAt,
      location: locationBody,
      imageUrls: event.imageUrls.isEmpty ? nil : event.imageUrls,
      reminderMinutesBefore: event.reminderMinutesBefore
    )

    let response: RustCreateScheduleResponse = try await api.post("/api/v1/schedules", body: body)
    return response.scheduleId
  }

  // MARK: - Read

  public func getEvent(id: String) async throws -> PersonalEventModel? {
    let response: RustPersonalScheduleResponse = try await api.get("/api/v1/schedules/\(id)")
    return response.toPersonalEventModel()
  }

  // MARK: - Update

  public func updateEvent(_ event: PersonalEventModel) async throws {
    let locationBody: LocationBody?? = {
      if let loc = event.location,
         !loc.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return .some(LocationBody(
          name: loc.name,
          address: loc.address,
          latitude: loc.latitude,
          longitude: loc.longitude
        ))
      } else {
        return .some(nil)
      }
    }()

    let body = UpdatePersonalScheduleBody(
      title: event.title,
      emoji: .some(event.emoji),
      description: .some(event.description),
      descriptionBlocks: event.descriptionBlocks.isEmpty ? .some(nil) : .some(event.descriptionBlocks),
      startAt: event.startAt,
      endAt: .some(event.endAt),
      location: locationBody,
      imageUrls: event.imageUrls.isEmpty ? .some(nil) : .some(event.imageUrls),
      reminderMinutesBefore: .some(event.reminderMinutesBefore)
    )

    let _: RustSuccessResponse = try await api.patch("/api/v1/schedules/\(event.id)", body: body)
  }

  // MARK: - Delete

  public func deleteEvent(id: String) async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/schedules/\(id)")
  }

  // MARK: - Active Events

  public func getActiveEvents(limit: Int) async throws -> [PersonalEventModel] {
    let response: [RustPersonalScheduleResponse] = try await api.get(
      "/api/v1/schedules/personal/active?limit=\(limit)"
    )
    return response.map { $0.toPersonalEventModel() }
  }

  // MARK: - Ongoing Events

  public func getOngoingEvents(limit: Int) async throws -> [PersonalEventModel] {
    let response: [RustPersonalScheduleResponse] = try await api.get(
      "/api/v1/schedules/personal/active?limit=100"
    )
    return response
      .map { $0.toPersonalEventModel() }
      .filter { $0.isOngoing }
      .prefix(limit)
      .map { $0 }
  }

  // MARK: - Past Events

  public func getPastEvents(limit: Int, lastStartAt: Date?) async throws -> [PersonalEventModel] {
    var path = "/api/v1/schedules/personal/past?limit=\(limit)"
    if let cursor = lastStartAt {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let cursorString = formatter.string(from: cursor)
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      path += "&cursor=\(cursorString)"
    }
    let response: [RustPersonalScheduleResponse] = try await api.get(path)
    return response.map { $0.toPersonalEventModel() }
  }

  // MARK: - Calendar

  public func getEventsByDateRange(startDate: Date, endDate: Date) async throws -> [PersonalEventModel] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let startString = formatter.string(from: startDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let endString = formatter.string(from: endDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

    let response: RustCalendarResponse = try await api.get(
      "/api/v1/schedules/calendar?start=\(startString)&end=\(endString)"
    )

    return response.schedules
      .filter { $0.scheduleType == "personal" }
      .map { $0.toPersonalEventModel() }
  }
}

// MARK: - DTO -> Model

extension RustPersonalScheduleResponse {
  fileprivate func toPersonalEventModel() -> PersonalEventModel {
    let locationModel: LocationInfoModel? = location.map {
      LocationInfoModel(
        name: $0.name,
        address: $0.address,
        latitude: $0.latitude,
        longitude: $0.longitude
      )
    }

    let descBlocks: [DescriptionBlock] = descriptionBlocks?.compactMap { dto in
      switch dto.type {
      case "text":
        guard let content = dto.content else { return nil }
        return DescriptionBlock(content: .text(content))
      case "checklist":
        guard let items = dto.items else { return nil }
        let checklistItems = items.map {
          ChecklistItem(id: $0.id, text: $0.text, isChecked: $0.isChecked)
        }
        return DescriptionBlock(content: .checklist(checklistItems))
      case "bulletList":
        guard let bulletItems = dto.bulletItems else { return nil }
        return DescriptionBlock(content: .bulletList(bulletItems))
      default:
        if let content = dto.content {
          return DescriptionBlock(content: .text(content))
        }
        return nil
      }
    } ?? (description.map { [DescriptionBlock(content: .text($0))] } ?? [])

    return PersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      descriptionBlocks: descBlocks,
      startAt: startAt,
      endAt: endAt,
      location: locationModel,
      imageUrls: imageUrls ?? [],
      reminderMinutesBefore: reminderMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
