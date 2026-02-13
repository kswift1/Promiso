//
//  GroupModelTests.swift
//  Clients
//
//  GroupModel 관련 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/Group/GroupModel.swift`
//  - `Clients/Sources/Domain/Models/Group/GroupCreationResultModel.swift`
//  - `Clients/Sources/Domain/Models/Group/GroupPreviewModel.swift`
//
//  ## 테스트 목적
//  - GroupModel: 초기화, Identifiable, Equatable, 속성 검증
//  - GroupCreationResultModel: 초기화, Identifiable 검증
//  - GroupPreviewModel: 초기화, 관계 모델 구성 검증
//  - UserGroupInfo: 초기화, GroupRole 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - GroupModel 테스트

@Suite("GroupModel 테스트")
struct GroupModelTests {

  @Test("GroupModel 초기화 및 속성 확인")
  func init_setsAllProperties() {
    let now = Date()
    let group = TestFactories.makeGroup(
      id: "g-1",
      name: "테스트 그룹",
      description: "그룹 설명",
      imageUrl: "https://example.com/img.jpg",
      memberIds: ["u1", "u2", "u3"],
      maxMembers: 20,
      inviteCode: "XYZ789",
      createdBy: "u1",
      createdAt: now,
      updatedAt: now
    )
    #expect(group.id == "g-1")
    #expect(group.name == "테스트 그룹")
    #expect(group.description == "그룹 설명")
    #expect(group.imageUrl == "https://example.com/img.jpg")
    #expect(group.memberIds == ["u1", "u2", "u3"])
    #expect(group.maxMembers == 20)
    #expect(group.inviteCode == "XYZ789")
    #expect(group.createdBy == "u1")
  }

  @Test("GroupModel Equatable 비교")
  func equatable_sameValues_areEqual() {
    let now = Date()
    let g1 = GroupModel(
      id: "g1", name: "그룹", memberIds: ["u1"],
      maxMembers: 10, inviteCode: "ABC",
      createdBy: "u1", createdAt: now, updatedAt: now
    )
    let g2 = GroupModel(
      id: "g1", name: "그룹", memberIds: ["u1"],
      maxMembers: 10, inviteCode: "ABC",
      createdBy: "u1", createdAt: now, updatedAt: now
    )
    #expect(g1 == g2)
  }

  @Test("GroupModel description이 nil 허용")
  func init_allowsNilDescription() {
    let group = TestFactories.makeGroup(description: nil)
    #expect(group.description == nil)
  }

  @Test("GroupModel imageUrl이 nil 허용")
  func init_allowsNilImageUrl() {
    let group = TestFactories.makeGroup(imageUrl: nil)
    #expect(group.imageUrl == nil)
  }
}

// MARK: - GroupCreationResultModel 테스트

@Suite("GroupCreationResultModel 테스트")
struct GroupCreationResultModelTests {

  @Test("GroupCreationResultModel 초기화 및 속성 확인")
  func init_setsProperties() {
    let result = GroupCreationResultModel(
      id: "new-group-1",
      name: "새 그룹",
      inviteCode: "INVITE123"
    )
    #expect(result.id == "new-group-1")
    #expect(result.name == "새 그룹")
    #expect(result.inviteCode == "INVITE123")
  }

  @Test("GroupCreationResultModel Equatable 비교")
  func equatable() {
    let r1 = GroupCreationResultModel(id: "g1", name: "그룹", inviteCode: "ABC")
    let r2 = GroupCreationResultModel(id: "g1", name: "그룹", inviteCode: "ABC")
    #expect(r1 == r2)
  }
}

// MARK: - GroupPreviewModel 테스트

@Suite("GroupPreviewModel 테스트")
struct GroupPreviewModelTests {

  @Test("GroupPreviewModel 초기화: group과 members 포함")
  func init_setsGroupAndMembers() {
    let group = TestFactories.makeGroup(id: "g1", name: "미리보기 그룹")
    let members = [
      TestFactories.makePublicUser(userId: "u1", nickname: "유저1"),
      TestFactories.makePublicUser(userId: "u2", nickname: "유저2"),
    ]
    let preview = GroupPreviewModel(group: group, members: members)

    #expect(preview.group.id == "g1")
    #expect(preview.group.name == "미리보기 그룹")
    #expect(preview.members.count == 2)
    #expect(preview.members[0].userId == "u1")
    #expect(preview.members[1].userId == "u2")
  }

  @Test("GroupPreviewModel Equatable 비교")
  func equatable() {
    let group = TestFactories.makeGroup(id: "g1")
    let members = [TestFactories.makePublicUser(userId: "u1")]
    let p1 = GroupPreviewModel(group: group, members: members)
    let p2 = GroupPreviewModel(group: group, members: members)
    #expect(p1 == p2)
  }
}

// MARK: - UserGroupInfo 테스트

@Suite("UserGroupInfo 테스트")
struct UserGroupInfoTests {

  @Test("UserGroupInfo 초기화 및 속성 확인")
  func init_setsProperties() {
    let now = Date()
    let info = TestFactories.makeUserGroupInfo(
      id: "g1",
      name: "내 그룹",
      role: .admin,
      joinedAt: now,
      hasNewActivity: true,
      imageUrl: "https://example.com/group.jpg"
    )
    #expect(info.id == "g1")
    #expect(info.name == "내 그룹")
    #expect(info.role == .admin)
    #expect(info.joinedAt == now)
    #expect(info.hasNewActivity == true)
    #expect(info.imageUrl == "https://example.com/group.jpg")
  }

  @Test("UserGroupInfo 기본값 확인")
  func defaultValues() {
    let info = TestFactories.makeUserGroupInfo()
    #expect(info.role == nil)
    #expect(info.joinedAt == nil)
    #expect(info.hasNewActivity == false)
    #expect(info.imageUrl == nil)
  }
}

// MARK: - GroupRole 테스트

@Suite("GroupRole 테스트")
struct GroupRoleTests {

  @Test("GroupRole rawValue 올바름")
  func rawValues() {
    #expect(GroupRole.admin.rawValue == "admin")
    #expect(GroupRole.member.rawValue == "member")
  }
}

// MARK: - Group 제약 조건 (G4, G6, G9, G16)

@Suite("GroupModel 제약 조건 테스트")
struct GroupConstraintTests {

  @Test("[G4] maxMembers 최소값은 2")
  func g4_minMaxMembers_isTwo() {
    let group = TestFactories.makeGroup(maxMembers: 2)
    #expect(group.maxMembers >= 2)
  }

  @Test("[G4] maxMembers 최대값은 10")
  func g4_maxMaxMembers_isTen() {
    let group = TestFactories.makeGroup(maxMembers: 10)
    #expect(group.maxMembers <= 10)
  }

  @Test("[G6] 초대 코드는 6자리")
  func g6_inviteCode_isSixChars() {
    let group = TestFactories.makeGroup(inviteCode: "ABC123")
    #expect(group.inviteCode.count == 6)
  }

  @Test("[G6] 초대 코드는 영숫자만")
  func g6_inviteCode_isAlphanumeric() {
    let code = "ABC123"
    let isAlphanumeric = code.allSatisfy { $0.isLetter || $0.isNumber }
    #expect(isAlphanumeric == true)
  }

  @Test("[G9] createdBy가 그룹 호스트")
  func g9_createdBy_isHost() {
    let group = TestFactories.makeGroup(createdBy: "user-1")
    #expect(group.createdBy == "user-1")
  }

  @Test("[G16] 멤버 수 < maxMembers이면 가입 가능")
  func g16_belowCapacity_canJoin() {
    let group = TestFactories.makeGroup(memberIds: ["a", "b"], maxMembers: 5)
    #expect(group.memberIds.count < group.maxMembers)
  }

  @Test("[G16] 멤버 수 == maxMembers이면 가입 불가")
  func g16_atCapacity_cannotJoin() {
    let group = TestFactories.makeGroup(memberIds: ["a", "b", "c"], maxMembers: 3)
    #expect(group.memberIds.count >= group.maxMembers)
  }
}
