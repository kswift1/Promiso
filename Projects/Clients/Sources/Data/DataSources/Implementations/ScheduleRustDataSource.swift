import Foundation
import PromisoShared

// MARK: - Response DTOs

/// 일정 생성 응답
private struct RustCreateScheduleResponse: Decodable {
  let scheduleId: String
  let title: String
  let groupId: String?
  let startAt: Date
  let isConfirmed: Bool?
}

/// 일정 상세 응답
private struct RustScheduleResponse: Decodable {
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
  let createdAt: Date
  let updatedAt: Date
  // group fields
  let groupId: String?
  let hostId: String?
  let minimumParticipants: Int?
  let isConfirmed: Bool?
  let voteDeadline: Date?
  let trackingStartMinutesBefore: Int?
  let imageUrls: [String]?
  let votes: RustVotesResponse?
  // personal fields
  let reminderMinutesBefore: Int?
}

private struct RustLocationResponse: Decodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct RustVotesResponse: Decodable {
  let accepted: [String]
  let declined: [String]
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

/// 투표 응답
private struct RustRespondScheduleResponse: Decodable {
  let scheduleId: String
  let status: String
  let isConfirmed: Bool
  let confirmedSchedule: RustCalendarSyncSchedule?
}

private struct RustCalendarSyncSchedule: Decodable {
  let id: String
  let title: String
  let emoji: String?
  let startAt: Date
  let endAt: Date?
  let location: String?
  let groupId: String
}

/// 페이지네이션 응답 (그룹 일정 목록)
private struct RustPaginatedScheduleResponse: Decodable {
  let data: [RustScheduleResponse]
  let cursor: Date?
}

/// 캘린더 응답
private struct RustCalendarResponse: Decodable {
  let schedules: [RustScheduleResponse]
  let recurringInstances: [RustRecurringInstance]?
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

/// 캘린더 동기화 응답 (경량)
private struct RustCalendarSyncResponse: Decodable {
  let id: String
  let title: String
  let emoji: String?
  let startAt: Date
  let endAt: Date?
  let location: String?
  let groupId: String
}

/// 활성 일정 개수 응답
private struct RustActiveCountResponse: Decodable {
  let count: Int
}

private struct RustSuccessResponse: Decodable {
  let success: Bool?
}

// MARK: - Request Bodies

private struct CreateScheduleBody: Encodable {
  let scheduleType: String
  let groupId: String?
  let title: String
  let emoji: String?
  let description: String?
  let descriptionBlocks: [DescriptionBlock]?
  let startAt: Date
  let endAt: Date?
  let location: LocationBody?
  let minimumParticipants: Int?
  let trackingStartMinutesBefore: Int?
  let imageUrls: [String]?
  let reminderMinutesBefore: Int?
}

private struct LocationBody: Encodable {
  let name: String
  let address: String?
  let latitude: Double?
  let longitude: Double?
}

private struct UpdateScheduleBody: Encodable {
  let title: String?
  let emoji: String??
  let description: String??
  let descriptionBlocks: [DescriptionBlock]??
  let startAt: Date?
  let endAt: Date??
  let location: LocationBody??
  let minimumParticipants: Int?
  let trackingStartMinutesBefore: Int??
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

    try container.encodeIfPresent(minimumParticipants, forKey: .minimumParticipants)

    // trackingStartMinutesBefore: Option<Option<Int>>
    switch trackingStartMinutesBefore {
    case .none: break
    case .some(.none): try container.encodeNil(forKey: .trackingStartMinutesBefore)
    case .some(.some(let v)): try container.encode(v, forKey: .trackingStartMinutesBefore)
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
    case location, minimumParticipants, trackingStartMinutesBefore
    case imageUrls, reminderMinutesBefore
  }
}

private struct RespondScheduleBody: Encodable {
  let status: String
}

private struct UpdateScheduleLiveActivityBody: Encodable {
  let channelId: String
  let participants: [ParticipantState]
  let trackingDurationMinutes: Int
}

private struct EmptyBody: Encodable {}

// MARK: - ScheduleRustDataSource

public actor ScheduleRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Create

  public func createSchedule(_ schedule: ScheduleModel) async throws -> String {
    let locationBody: LocationBody? = schedule.location.flatMap { loc in
      guard !loc.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
      return LocationBody(
        name: loc.name,
        address: loc.address,
        latitude: loc.latitude,
        longitude: loc.longitude
      )
    }

    let body = CreateScheduleBody(
      scheduleType: schedule.groupId.isEmpty ? "personal" : "group",
      groupId: schedule.groupId.isEmpty ? nil : schedule.groupId,
      title: schedule.title,
      emoji: schedule.emoji?.isEmpty == true ? nil : schedule.emoji,
      description: schedule.description?.isEmpty == true ? nil : schedule.description,
      descriptionBlocks: schedule.descriptionBlocks.isEmpty ? nil : schedule.descriptionBlocks,
      startAt: schedule.startAt,
      endAt: schedule.endAt,
      location: locationBody,
      minimumParticipants: schedule.groupId.isEmpty ? nil : schedule.minimumParticipants,
      trackingStartMinutesBefore: schedule.trackingStartMinutesBefore,
      imageUrls: schedule.imageUrls.isEmpty ? nil : schedule.imageUrls,
      reminderMinutesBefore: nil
    )

    let response: RustCreateScheduleResponse = try await api.post("/api/v1/schedules", body: body)
    return response.scheduleId
  }

  // MARK: - Read

  public func getSchedule(id: String) async throws -> ScheduleModel? {
    let response: RustScheduleResponse = try await api.get("/api/v1/schedules/\(id)")
    return response.toScheduleModel()
  }

  // MARK: - Update

  public func updateSchedule(_ schedule: ScheduleModel) async throws {
    let locationBody: LocationBody?? = {
      if let loc = schedule.location,
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

    let body = UpdateScheduleBody(
      title: schedule.title,
      emoji: .some(schedule.emoji),
      description: .some(schedule.description),
      descriptionBlocks: schedule.descriptionBlocks.isEmpty ? .some(nil) : .some(schedule.descriptionBlocks),
      startAt: schedule.startAt,
      endAt: .some(schedule.endAt),
      location: locationBody,
      minimumParticipants: schedule.minimumParticipants,
      trackingStartMinutesBefore: .some(schedule.trackingStartMinutesBefore),
      imageUrls: schedule.imageUrls.isEmpty ? .some(nil) : .some(schedule.imageUrls),
      reminderMinutesBefore: nil
    )

    let _: RustSuccessResponse = try await api.patch("/api/v1/schedules/\(schedule.id)", body: body)
  }

  // MARK: - Delete

  public func deleteSchedule(id: String) async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/schedules/\(id)")
  }

  // MARK: - Respond

  public func respondToSchedule(scheduleId: String, status: String) async throws -> RespondScheduleResult {
    let body = RespondScheduleBody(status: status)
    let response: RustRespondScheduleResponse = try await api.post(
      "/api/v1/schedules/\(scheduleId)/respond",
      body: body
    )

    let confirmedSchedule: CalendarSyncSchedule? = response.confirmedSchedule.map { cs in
      CalendarSyncSchedule(
        id: cs.id,
        title: cs.title,
        emoji: cs.emoji ?? "",
        startAt: cs.startAt,
        endAt: cs.endAt,
        location: cs.location,
        groupId: cs.groupId
      )
    }

    return RespondScheduleResult(
      scheduleId: response.scheduleId,
      status: response.status,
      isConfirmed: response.isConfirmed,
      confirmedSchedule: confirmedSchedule
    )
  }

  // MARK: - Group Schedules

  public func getActiveSchedules(groupId: String, limit: Int) async throws -> [ScheduleModel] {
    let response: RustPaginatedScheduleResponse = try await api.get(
      "/api/v1/groups/\(groupId)/schedules?status=active&limit=\(limit)"
    )
    return response.data.map { $0.toScheduleModel() }
  }

  public func getPastSchedules(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [ScheduleModel] {
    var path = "/api/v1/groups/\(groupId)/schedules?status=past&limit=\(limit)"
    if let cursor = lastStartAt {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      let cursorString = formatter.string(from: cursor)
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      path += "&cursor=\(cursorString)"
    }
    let response: RustPaginatedScheduleResponse = try await api.get(path)
    return response.data.map { $0.toScheduleModel() }
  }

  public func getActiveScheduleCount(groupId: String) async throws -> Int {
    let response: RustPaginatedScheduleResponse = try await api.get(
      "/api/v1/groups/\(groupId)/schedules?status=active&limit=100"
    )
    return response.data.count
  }

  // MARK: - Home Schedules

  public func getHomeSchedules(groupIds: [String], limitPerChunk: Int) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty else { return [] }
    let limit = limitPerChunk * max(1, groupIds.count / 10 + 1)
    let response: [RustScheduleResponse] = try await api.get(
      "/api/v1/schedules/home?limit=\(limit)"
    )
    return response.map { $0.toScheduleModel() }
  }

  // MARK: - Calendar

  public func getSchedulesByDateRange(
    groupIds: [String],
    startDate: Date,
    endDate: Date
  ) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty else { return [] }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let startString = formatter.string(from: startDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let endString = formatter.string(from: endDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let response: RustCalendarResponse = try await api.get(
      "/api/v1/schedules/calendar?start=\(startString)&end=\(endString)"
    )
    return response.schedules.map { $0.toScheduleModel() }
  }

  public func getAcceptedSchedulesByDateRange(
    startDate: Date,
    endDate: Date
  ) async throws -> [ScheduleModel] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let startString = formatter.string(from: startDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let endString = formatter.string(from: endDate)
      .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let response: RustCalendarResponse = try await api.get(
      "/api/v1/schedules/calendar?start=\(startString)&end=\(endString)&accepted_only=true"
    )
    return response.schedules.map { $0.toScheduleModel() }
  }

  // MARK: - Calendar Sync

  public func getConfirmedSchedulesForCalendar() async throws -> [CalendarSyncSchedule] {
    let response: [RustCalendarSyncResponse] = try await api.get("/api/v1/schedules/calendar-sync")
    return response.map { item in
      CalendarSyncSchedule(
        id: item.id,
        title: item.title,
        emoji: item.emoji ?? "",
        startAt: item.startAt,
        endAt: item.endAt,
        location: item.location,
        groupId: item.groupId
      )
    }
  }

  // MARK: - Live Activity

  public func startLiveActivity(scheduleId: String) async throws {
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/schedules/\(scheduleId)/live-activity/start",
      body: EmptyBody()
    )
  }

  public func startVoteLiveActivity(scheduleId: String) async throws {
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/schedules/\(scheduleId)/vote-live-activity/start",
      body: EmptyBody()
    )
  }

  public func finalizeVote(scheduleId: String) async throws {
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/schedules/\(scheduleId)/vote-live-activity/finalize",
      body: EmptyBody()
    )
  }

  public func updateETA(
    scheduleId: String,
    channelId: String,
    participants: [ParticipantState],
    trackingDurationMinutes: Int
  ) async throws {
    let body = UpdateScheduleLiveActivityBody(
      channelId: channelId,
      participants: participants,
      trackingDurationMinutes: trackingDurationMinutes
    )
    let _: RustSuccessResponse = try await api.post(
      "/api/v1/schedules/\(scheduleId)/live-activity/eta",
      body: body
    )
  }
}

// MARK: - DTO -> Model

extension RustScheduleResponse {
  fileprivate func toScheduleModel() -> ScheduleModel {
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

    let votesModel: ScheduleVotesModel = {
      let accepted = votes?.accepted ?? []
      let declined = votes?.declined ?? []
      let until = voteDeadline ?? startAt
      return ScheduleVotesModel(accepted: accepted, declined: declined, until: until)
    }()

    return ScheduleModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      descriptionBlocks: descBlocks,
      hostId: hostId ?? userId ?? "",
      groupId: groupId ?? "",
      group: nil,
      minimumParticipants: minimumParticipants ?? 1,
      votes: votesModel,
      startAt: startAt,
      endAt: endAt,
      location: locationModel,
      imageUrls: imageUrls ?? [],
      trackingStartMinutesBefore: trackingStartMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
