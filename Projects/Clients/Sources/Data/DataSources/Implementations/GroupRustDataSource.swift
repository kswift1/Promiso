import Foundation
import PromisoShared

// MARK: - Response DTOs

private struct RustCreateGroupResponse: Decodable {
  let groupId: String
  let inviteCode: String
  let createdAt: Date
}

private struct RustGroupResponse: Decodable {
  let groupId: String
  let name: String
  let description: String?
  let imageUrl: String?
  let maxMembers: Int
  let inviteCode: String
  let createdBy: String
  let memberCount: Int
  let role: String
  let groupColor: String
  let notificationSettings: RustNotificationSettingsResponse
  let lastReadAt: Date
  let createdAt: Date
  let updatedAt: Date
}

private struct RustGroupSummaryResponse: Decodable {
  let groupId: String
  let name: String
  let description: String?
  let imageUrl: String?
  let maxMembers: Int
  let memberCount: Int
  let role: String
  let groupColor: String
  let hasNewActivity: Bool
  let joinedAt: Date
}

private struct RustGroupPreviewResponse: Decodable {
  let groupId: String
  let name: String
  let description: String?
  let imageUrl: String?
  let memberCount: Int
  let maxMembers: Int
  let previewMembers: [RustGroupMemberPreview]
}

private struct RustGroupMemberPreview: Decodable {
  let userId: String
  let nickname: String
  let profileUrl: String?
}

private struct RustGroupMemberResponse: Decodable {
  let userId: String
  let nickname: String
  let profileUrl: String?
  let role: String
  let groupColor: String
  let joinedAt: Date
}

private struct RustNotificationSettingsResponse: Decodable {
  let enabled: Bool
  let schedule: RustScheduleNotificationSettings
  let group: RustGroupNotificationSettings
  let calendarSync: Bool
}

private struct RustScheduleNotificationSettings: Decodable {
  let invitation: Bool
  let reminder: Bool
  let confirmed: Bool
  let cancelled: Bool
  let updated: Bool
  let attendanceResponse: Bool
}

private struct RustGroupNotificationSettings: Decodable {
  let update: Bool
}

private struct RustSuccessResponse: Decodable {
  let success: Bool?
}

// MARK: - Request Bodies

private struct CreateGroupBody: Encodable {
  let name: String
  let description: String?
  let maxMembers: Int?
}

private struct JoinGroupBody: Encodable {
  let inviteCode: String
}

private struct UpdateGroupBody: Encodable {
  let description: String??
  let maxMembers: Int?
  let imageUrl: String??

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    // description: nil → omit, .some(nil) → null, .some(.some(v)) → value
    switch description {
    case .none:
      break
    case .some(.none):
      try container.encodeNil(forKey: .description)
    case .some(.some(let v)):
      try container.encode(v, forKey: .description)
    }
    try container.encodeIfPresent(maxMembers, forKey: .maxMembers)
    // imageUrl: nil → omit, .some(nil) → null, .some(.some(v)) → value
    switch imageUrl {
    case .none:
      break
    case .some(.none):
      try container.encodeNil(forKey: .imageUrl)
    case .some(.some(let v)):
      try container.encode(v, forKey: .imageUrl)
    }
  }

  enum CodingKeys: String, CodingKey {
    case description
    case maxMembers
    case imageUrl
  }
}

private struct TransferHostBody: Encodable {
  let newHostUid: String
}

private struct ExpelMemberBody: Encodable {
  let targetUid: String
}

private struct NotificationSettingsBody: Encodable {
  let enabled: Bool
  let schedule: ScheduleNotificationBody
  let group: GroupNotificationBody
  let calendarSync: Bool
}

private struct ScheduleNotificationBody: Encodable {
  let invitation: Bool
  let reminder: Bool
  let confirmed: Bool
  let cancelled: Bool
  let updated: Bool
  let attendanceResponse: Bool
}

private struct GroupNotificationBody: Encodable {
  let update: Bool
}

private struct UpdateGroupColorBody: Encodable {
  let color: String
}

// MARK: - GroupRustDataSource

public actor GroupRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  // MARK: - Create

  public func createGroup(
    name: String,
    maxMembers: Int,
    description: String?
  ) async throws -> GroupCreationResultModel {
    let body = CreateGroupBody(
      name: name,
      description: description,
      maxMembers: maxMembers
    )
    let response: RustCreateGroupResponse = try await api.post("/api/v1/groups", body: body)
    return GroupCreationResultModel(
      id: response.groupId,
      name: name,
      inviteCode: response.inviteCode
    )
  }

  // MARK: - Preview

  public func previewGroup(inviteCode: String) async throws -> GroupPreviewModel {
    // previewGroup 엔드포인트는 서버에서 인증 불필요이지만,
    // RustAPIClient가 Firebase 토큰을 붙여도 서버가 이를 무시하므로 동일 클라이언트 사용
    let encoded = inviteCode.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? inviteCode
    let response: RustGroupPreviewResponse = try await api.get("/api/v1/groups/preview?code=\(encoded)")
    return response.toModel()
  }

  // MARK: - Join / Leave

  public func joinGroup(inviteCode: String) async throws -> GroupModel {
    let body = JoinGroupBody(inviteCode: inviteCode)
    let response: RustGroupResponse = try await api.post("/api/v1/groups/join", body: body)
    return response.toModel()
  }

  public func leaveGroup(groupId: String) async throws {
    let _: RustSuccessResponse = try await api.post("/api/v1/groups/\(groupId)/leave", body: EmptyBody())
  }

  // MARK: - Fetch

  public func fetchMyGroups() async throws -> [GroupModel] {
    let response: [RustGroupSummaryResponse] = try await api.get("/api/v1/groups/me")
    return response.map { $0.toModel() }
  }

  public func fetchGroupSummaries() async throws -> [UserGroupInfo] {
    let response: [RustGroupSummaryResponse] = try await api.get("/api/v1/groups/me")
    return response.map { $0.toUserGroupInfo() }
  }

  public func fetchGroup(groupId: String) async throws -> GroupModel {
    let response: RustGroupResponse = try await api.get("/api/v1/groups/\(groupId)")
    return response.toModel()
  }

  public func fetchGroupMembers(groupId: String) async throws -> [UserPublicModel] {
    let response: [RustGroupMemberResponse] = try await api.get("/api/v1/groups/\(groupId)/members")
    return response.map { $0.toModel() }
  }

  // MARK: - Update

  public func updateGroup(
    groupId: String,
    description: String?,
    maxMembers: Int?,
    imageUrl: String??
  ) async throws -> GroupModel {
    let body = UpdateGroupBody(description: description, maxMembers: maxMembers, imageUrl: imageUrl)
    let _: RustSuccessResponse = try await api.patch("/api/v1/groups/\(groupId)", body: body)
    return try await fetchGroup(groupId: groupId)
  }

  public func deleteGroup(groupId: String) async throws {
    let _: RustSuccessResponse = try await api.delete("/api/v1/groups/\(groupId)")
  }

  public func transferHost(groupId: String, newHostUid: String) async throws {
    let body = TransferHostBody(newHostUid: newHostUid)
    let _: RustSuccessResponse = try await api.post("/api/v1/groups/\(groupId)/transfer-host", body: body)
  }

  public func expelMember(groupId: String, targetUid: String) async throws {
    let body = ExpelMemberBody(targetUid: targetUid)
    let _: RustSuccessResponse = try await api.post("/api/v1/groups/\(groupId)/expel", body: body)
  }

  public func markGroupRead(groupId: String) async throws {
    let _: RustSuccessResponse = try await api.post("/api/v1/groups/\(groupId)/mark-read", body: EmptyBody())
  }

  public func updateNotificationSettings(
    groupId: String,
    settings: GroupNotificationSettings
  ) async throws {
    let body = settings.toRequestBody()
    let _: RustSuccessResponse = try await api.patch(
      "/api/v1/groups/\(groupId)/notification-settings",
      body: body
    )
  }

  public func updateGroupColor(groupId: String, color: GroupColor?) async throws {
    let colorValue = color?.rawValue ?? ""
    let body = UpdateGroupColorBody(color: colorValue)
    let _: RustSuccessResponse = try await api.patch("/api/v1/groups/\(groupId)/color", body: body)
  }
}

// MARK: - Helper

private struct EmptyBody: Encodable {}

// MARK: - DTO → Model 변환

extension RustGroupResponse {
  func toModel() -> GroupModel {
    GroupModel(
      id: groupId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      memberIds: [],
      memberCount: memberCount,
      maxMembers: maxMembers,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

extension RustGroupSummaryResponse {
  func toModel() -> GroupModel {
    GroupModel(
      id: groupId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      memberIds: [],
      memberCount: memberCount,
      maxMembers: maxMembers,
      inviteCode: "",
      createdBy: "",
      createdAt: joinedAt,
      updatedAt: joinedAt
    )
  }

  func toUserGroupInfo() -> UserGroupInfo {
    UserGroupInfo(
      id: groupId,
      name: name,
      role: GroupRole(rawValue: role),
      joinedAt: joinedAt,
      notifications: nil,
      hasNewActivity: hasNewActivity,
      imageUrl: imageUrl,
      groupColor: GroupColor(rawValue: groupColor)
    )
  }
}

extension RustGroupPreviewResponse {
  func toModel() -> GroupPreviewModel {
    let groupModel = GroupModel(
      id: groupId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      memberIds: [],
      memberCount: memberCount,
      maxMembers: maxMembers,
      inviteCode: "",
      createdBy: "",
      createdAt: Date(),
      updatedAt: Date()
    )
    let members = previewMembers.map { preview in
      UserPublicModel(
        userId: preview.userId,
        name: preview.nickname,
        nickname: preview.nickname,
        profile: preview.profileUrl.map { url in
          ProfileImage(url: url, thumbUrl: nil, updatedAt: Date())
        },
        metadata: Metadata(createdAt: Date(), updatedAt: Date())
      )
    }
    return GroupPreviewModel(
      group: groupModel,
      members: members,
      memberCount: Int(memberCount)
    )
  }
}

extension RustGroupMemberResponse {
  func toModel() -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: nickname,
      nickname: nickname,
      profile: profileUrl.map { url in
        ProfileImage(url: url, thumbUrl: nil, updatedAt: joinedAt)
      },
      metadata: Metadata(createdAt: joinedAt, updatedAt: joinedAt)
    )
  }
}

// MARK: - GroupNotificationSettings → Request Body 변환

extension GroupNotificationSettings {
  fileprivate func toRequestBody() -> NotificationSettingsBody {
    NotificationSettingsBody(
      enabled: enabled,
      schedule: ScheduleNotificationBody(
        invitation: schedule["invitation"] ?? true,
        reminder: schedule["reminder"] ?? true,
        confirmed: schedule["confirmed"] ?? true,
        cancelled: schedule["cancelled"] ?? true,
        updated: schedule["updated"] ?? true,
        attendanceResponse: schedule["attendanceResponse"] ?? true
      ),
      group: GroupNotificationBody(
        update: group["update"] ?? true
      ),
      calendarSync: calendarSync
    )
  }
}
