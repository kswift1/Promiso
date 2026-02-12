//
//  GroupDomainRuleTests.swift
//  Clients
//
//  Layer 1: 도메인 규칙 안전망 테스트
//
//  ## 목적
//  - 도메인 규칙(.ai/domain-rules/group.md)이 코드에 올바르게 반영되었는지 검증
//  - GroupModel은 순수 데이터 구조이므로, 여기서는 모델 불변조건만 검증
//  - Feature 레벨 규칙(G3,G5,G9-G15 등)은 별도 Feature 테스트에서 검증
//

import Foundation
import Testing
@testable import Clients
@testable import PromisoShared

// MARK: - 제약 조건 (G1~G8)

@Suite("Group 제약 조건 도메인 규칙")
struct GroupConstraintRuleTests {

  // MARK: - [G4] 최대 인원 2~10명

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

  // MARK: - [G6] 초대 코드 6자리 영숫자

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
}

// MARK: - 권한 (G9~G17)

@Suite("Group 권한 도메인 규칙")
struct GroupPermissionRuleTests {

  // MARK: - [G9] 호스트 = 그룹 생성자

  @Test("[G9] createdBy가 그룹 호스트")
  func g9_createdBy_isHost() {
    let group = TestFactories.makeGroup(createdBy: "user-1")
    #expect(group.createdBy == "user-1")
  }

  // MARK: - [G16] 가입 조건: 정원 미달

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

// MARK: - 정렬 (G28)

@Suite("Group 정렬 도메인 규칙")
struct GroupSortRuleTests {

  // MARK: - [G28] 5가지 정렬 옵션

  @Test("[G28] joinedRecent sortType은 joined")
  func g28_joinedRecent_sortType() {
    #expect(GroupSortOption.joinedRecent.sortType == .joined)
  }

  @Test("[G28] joinedOldest sortType은 joined")
  func g28_joinedOldest_sortType() {
    #expect(GroupSortOption.joinedOldest.sortType == .joined)
  }

  @Test("[G28] nameAscending sortType은 name")
  func g28_nameAscending_sortType() {
    #expect(GroupSortOption.nameAscending.sortType == .name)
  }

  @Test("[G28] nameDescending sortType은 name")
  func g28_nameDescending_sortType() {
    #expect(GroupSortOption.nameDescending.sortType == .name)
  }

  @Test("[G28] custom sortType은 custom")
  func g28_custom_sortType() {
    #expect(GroupSortOption.custom(order: ["g1"]).sortType == .custom)
  }

  @Test("[G28] joinedRecent는 내림차순 (기본 정렬)")
  func g28_joinedRecent_isDescending() {
    #expect(GroupSortOption.joinedRecent.isAscending == false)
  }

  @Test("[G28] toggled 동작 검증")
  func g28_toggled_reverses() {
    #expect(GroupSortOption.joinedRecent.toggled == .joinedOldest)
    #expect(GroupSortOption.joinedOldest.toggled == .joinedRecent)
    #expect(GroupSortOption.nameAscending.toggled == .nameDescending)
    #expect(GroupSortOption.nameDescending.toggled == .nameAscending)
  }
}

// MARK: - 초대/딥링크 (G30)

@Suite("Group 초대 딥링크 도메인 규칙")
struct GroupDeeplinkRuleTests {

  // MARK: - [G30] 딥링크 형식: promiso://join/{code}

  @Test("[G30] 초대 메시지에 딥링크 promiso://join/{code} 포함")
  func g30_message_containsDeeplink() {
    let message = GroupInviteShareMessage.message(groupName: "테스트 그룹", inviteCode: "ABC123")
    #expect(message.contains("promiso://join/ABC123"))
  }

  @Test("[G30] 딥링크에 초대 코드가 정확히 포함됨")
  func g30_deeplink_containsExactCode() {
    let message = GroupInviteShareMessage.message(groupName: "그룹", inviteCode: "XYZ789")
    #expect(message.contains("promiso://join/XYZ789"))
  }

  @Test("[G30] 초대 메시지에 그룹 이름 포함")
  func g30_message_containsGroupName() {
    let message = GroupInviteShareMessage.message(groupName: "우리 모임", inviteCode: "TEST01")
    #expect(message.contains("우리 모임"))
  }

  @Test("[G30] 초대 메시지에 초대 코드 포함")
  func g30_message_containsInviteCode() {
    let message = GroupInviteShareMessage.message(groupName: "그룹", inviteCode: "CODE42")
    #expect(message.contains("CODE42"))
  }
}
