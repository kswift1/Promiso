//
//  MockGroupRemoteDataSource.swift
//  Clients
//
//  GroupRemoteDataSourceProtocol Mock 구현
//
//  ## 사용법
//  ```swift
//  let mock = MockGroupRemoteDataSource()
//  mock.fetchGroupHandler = { groupId in
//    return TestFactories.makeGroup(id: groupId)
//  }
//  let group = try await mock.fetchGroup(groupId: "group-1")
//  #expect(mock.fetchGroupCallCount == 1)
//  ```
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockGroupRemoteDataSource

final class MockGroupRemoteDataSource: GroupRemoteDataSourceProtocol {

  // MARK: - Call Counts

  private(set) var createGroupCallCount = 0
  private(set) var fetchGroupCallCount = 0
  private(set) var leaveGroupCallCount = 0
  private(set) var deleteGroupCallCount = 0
  private(set) var updateGroupCallCount = 0
  private(set) var updateGroupNotificationSettingsCallCount = 0
  private(set) var fetchGroupsCallCount = 0
  private(set) var fetchGroupsByIdsCallCount = 0
  private(set) var fetchGroupSummariesCallCount = 0
  private(set) var previewGroupCallCount = 0
  private(set) var joinGroupCallCount = 0
  private(set) var clearGroupBadgeCallCount = 0
  private(set) var updateGroupColorCallCount = 0

  // MARK: - Captured Arguments

  private(set) var fetchGroupArguments: [String] = []
  private(set) var leaveGroupArguments: [String] = []
  private(set) var deleteGroupArguments: [String] = []
  private(set) var fetchGroupsArguments: [String] = []
  private(set) var fetchGroupsByIdsArguments: [[String]] = []
  private(set) var fetchGroupSummariesArguments: [String] = []
  private(set) var previewGroupArguments: [String] = []
  private(set) var joinGroupArguments: [(inviteCode: String, userId: String)] = []
  private(set) var clearGroupBadgeArguments: [String] = []

  // MARK: - Handlers

  var createGroupHandler: ((String, Int, String?, String, Data?) async throws -> GroupCreationResultModel)?
  var fetchGroupHandler: ((String) async throws -> GroupModel)?
  var leaveGroupHandler: ((String) async throws -> Void)?
  var deleteGroupHandler: ((String) async throws -> Void)?
  var updateGroupHandler: ((String, String?, Int?, Data?) async throws -> GroupModel)?
  var updateGroupNotificationSettingsHandler: ((String, String, GroupNotificationSettings) async throws -> Void)?
  var fetchGroupsHandler: ((String) async throws -> [GroupModel])?
  var fetchGroupsByIdsHandler: (([String]) async throws -> [GroupModel])?
  var fetchGroupSummariesHandler: ((String) async throws -> [UserGroupInfo])?
  var previewGroupHandler: ((String) async throws -> GroupPreviewModel)?
  var joinGroupHandler: ((String, String) async throws -> GroupModel)?
  var clearGroupBadgeHandler: ((String) async -> Void)?
  var updateGroupColorHandler: ((String, String, GroupColor?) async throws -> Void)?

  // MARK: - Reset

  /// 모든 호출 카운트와 캡처된 인자 초기화
  func reset() {
    createGroupCallCount = 0
    fetchGroupCallCount = 0
    leaveGroupCallCount = 0
    deleteGroupCallCount = 0
    updateGroupCallCount = 0
    updateGroupNotificationSettingsCallCount = 0
    fetchGroupsCallCount = 0
    fetchGroupsByIdsCallCount = 0
    fetchGroupSummariesCallCount = 0
    previewGroupCallCount = 0
    joinGroupCallCount = 0
    clearGroupBadgeCallCount = 0
    updateGroupColorCallCount = 0

    fetchGroupArguments = []
    leaveGroupArguments = []
    deleteGroupArguments = []
    fetchGroupsArguments = []
    fetchGroupsByIdsArguments = []
    fetchGroupSummariesArguments = []
    previewGroupArguments = []
    joinGroupArguments = []
    clearGroupBadgeArguments = []
  }

  // MARK: - CRUD Operations

  func createGroup(
    name: String,
    maxMembers: Int,
    description: String?,
    creatorId: String,
    photoData: Data?
  ) async throws -> GroupCreationResultModel {
    createGroupCallCount += 1
    if let handler = createGroupHandler {
      return try await handler(name, maxMembers, description, creatorId, photoData)
    }
    return GroupCreationResultModel(
      id: "created-group-id",
      name: name,
      inviteCode: "NEW123"
    )
  }

  func fetchGroup(groupId: String) async throws -> GroupModel {
    fetchGroupCallCount += 1
    fetchGroupArguments.append(groupId)
    if let handler = fetchGroupHandler {
      return try await handler(groupId)
    }
    return TestFactories.makeGroup(id: groupId)
  }

  func leaveGroup(groupId: String) async throws {
    leaveGroupCallCount += 1
    leaveGroupArguments.append(groupId)
    if let handler = leaveGroupHandler {
      try await handler(groupId)
    }
  }

  func deleteGroup(groupId: String) async throws {
    deleteGroupCallCount += 1
    deleteGroupArguments.append(groupId)
    if let handler = deleteGroupHandler {
      try await handler(groupId)
    }
  }

  func updateGroup(
    groupId: String,
    description: String?,
    maxMembers: Int?,
    photoData: Data?
  ) async throws -> GroupModel {
    updateGroupCallCount += 1
    if let handler = updateGroupHandler {
      return try await handler(groupId, description, maxMembers, photoData)
    }
    return TestFactories.makeGroup(id: groupId)
  }

  func updateGroupNotificationSettings(
    groupId: String,
    userId: String,
    settings: GroupNotificationSettings
  ) async throws {
    updateGroupNotificationSettingsCallCount += 1
    if let handler = updateGroupNotificationSettingsHandler {
      try await handler(groupId, userId, settings)
    }
  }

  // MARK: - Query Operations

  func fetchGroups(userId: String) async throws -> [GroupModel] {
    fetchGroupsCallCount += 1
    fetchGroupsArguments.append(userId)
    if let handler = fetchGroupsHandler {
      return try await handler(userId)
    }
    return []
  }

  func fetchGroupsByIds(ids: [String]) async throws -> [GroupModel] {
    fetchGroupsByIdsCallCount += 1
    fetchGroupsByIdsArguments.append(ids)
    if let handler = fetchGroupsByIdsHandler {
      return try await handler(ids)
    }
    return []
  }

  func fetchGroupSummaries(userId: String) async throws -> [UserGroupInfo] {
    fetchGroupSummariesCallCount += 1
    fetchGroupSummariesArguments.append(userId)
    if let handler = fetchGroupSummariesHandler {
      return try await handler(userId)
    }
    return []
  }

  // MARK: - Invite Operations

  func previewGroup(inviteCode: String) async throws -> GroupPreviewModel {
    previewGroupCallCount += 1
    previewGroupArguments.append(inviteCode)
    if let handler = previewGroupHandler {
      return try await handler(inviteCode)
    }
    let group = TestFactories.makeGroup()
    return GroupPreviewModel(group: group, members: [])
  }

  func joinGroup(inviteCode: String, userId: String) async throws -> GroupModel {
    joinGroupCallCount += 1
    joinGroupArguments.append((inviteCode, userId))
    if let handler = joinGroupHandler {
      return try await handler(inviteCode, userId)
    }
    return TestFactories.makeGroup()
  }

  // MARK: - Badge Operations

  func clearGroupBadge(groupId: String) async {
    clearGroupBadgeCallCount += 1
    clearGroupBadgeArguments.append(groupId)
    if let handler = clearGroupBadgeHandler {
      await handler(groupId)
    }
  }

  // MARK: - Color Operations

  func updateGroupColor(
    groupId: String,
    userId: String,
    color: GroupColor?
  ) async throws {
    updateGroupColorCallCount += 1
    if let handler = updateGroupColorHandler {
      try await handler(groupId, userId, color)
    }
  }
}
