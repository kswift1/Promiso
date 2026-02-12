//
//  GroupRemoteDataSourceTests.swift
//  Clients
//
//  Mock 기반 GroupRemoteDataSource 로직 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Data/DataSources/Protocols/GroupRemoteDataSourceProtocol.swift`
//  - `Clients/Tests/Mocks/MockGroupRemoteDataSource.swift`
//
//  ## 테스트 목적
//  - Mock DataSource의 CRUD 호출 카운트 및 인자 캡처 검증
//  - 초대 코드 관련 메서드 검증
//  - 커스텀 핸들러 동작 검증
//  - reset 기능 검증
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockGroupRemoteDataSource 동작 테스트

@Suite("GroupRemoteDataSource Mock 기반 테스트")
struct GroupRemoteDataSourceTests {

  // MARK: - fetchGroup 테스트

  @Test("fetchGroup 호출 시 callCount 증가 및 인자 캡처, 기본 반환값 검증")
  func fetchGroup_incrementsCallCountAndReturnsDefault() async throws {
    let mock = MockGroupRemoteDataSource()

    let group = try await mock.fetchGroup(groupId: "group-1")

    #expect(mock.fetchGroupCallCount == 1)
    #expect(mock.fetchGroupArguments == ["group-1"])
    #expect(group.id == "group-1")
    #expect(group.name == "테스트 그룹")
  }

  @Test("fetchGroup 커스텀 핸들러 설정 시 오버라이드된 그룹 반환")
  func fetchGroup_customHandler_returnsCustomGroup() async throws {
    let mock = MockGroupRemoteDataSource()
    mock.fetchGroupHandler = { groupId in
      TestFactories.makeGroup(
        id: groupId,
        name: "커스텀 그룹",
        memberIds: ["user-a", "user-b", "user-c"],
        maxMembers: 20
      )
    }

    let group = try await mock.fetchGroup(groupId: "custom-group")

    #expect(group.id == "custom-group")
    #expect(group.name == "커스텀 그룹")
    #expect(group.memberIds.count == 3)
    #expect(group.maxMembers == 20)
  }

  // MARK: - joinGroup 및 previewGroup 테스트

  @Test("joinGroup 호출 시 초대 코드와 userId가 정확히 캡처")
  func joinGroup_capturesInviteCodeAndUserId() async throws {
    let mock = MockGroupRemoteDataSource()

    let group = try await mock.joinGroup(inviteCode: "XYZ789", userId: "user-1")

    #expect(mock.joinGroupCallCount == 1)
    #expect(mock.joinGroupArguments.count == 1)
    #expect(mock.joinGroupArguments.first?.inviteCode == "XYZ789")
    #expect(mock.joinGroupArguments.first?.userId == "user-1")
    #expect(group.id == "group-id") // 기본 TestFactories.makeGroup() 반환
  }

  // MARK: - reset 테스트

  @Test("reset 호출 시 모든 카운트와 캡처 인자 초기화")
  func reset_clearsAllCountsAndArguments() async throws {
    let mock = MockGroupRemoteDataSource()

    // 여러 호출 수행
    _ = try await mock.fetchGroup(groupId: "g1")
    _ = try await mock.fetchGroup(groupId: "g2")
    try await mock.leaveGroup(groupId: "g3")
    try await mock.deleteGroup(groupId: "g4")
    _ = try await mock.joinGroup(inviteCode: "ABC", userId: "u1")
    await mock.clearGroupBadge(groupId: "g5")

    #expect(mock.fetchGroupCallCount == 2)
    #expect(mock.leaveGroupCallCount == 1)
    #expect(mock.deleteGroupCallCount == 1)
    #expect(mock.joinGroupCallCount == 1)
    #expect(mock.clearGroupBadgeCallCount == 1)

    // reset
    mock.reset()

    #expect(mock.fetchGroupCallCount == 0)
    #expect(mock.leaveGroupCallCount == 0)
    #expect(mock.deleteGroupCallCount == 0)
    #expect(mock.joinGroupCallCount == 0)
    #expect(mock.clearGroupBadgeCallCount == 0)
    #expect(mock.fetchGroupArguments.isEmpty)
    #expect(mock.leaveGroupArguments.isEmpty)
    #expect(mock.deleteGroupArguments.isEmpty)
    #expect(mock.joinGroupArguments.isEmpty)
    #expect(mock.clearGroupBadgeArguments.isEmpty)
  }
}
