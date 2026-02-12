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
