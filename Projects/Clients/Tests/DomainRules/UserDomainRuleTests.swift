//
//  UserDomainRuleTests.swift
//  Clients
//
//  Layer 1: 도메인 규칙 안전망 테스트
//
//  ## 목적
//  - 도메인 규칙(.ai/domain-rules/user.md)이 코드에 올바르게 반영되었는지 검증
//  - 규칙 위반 코드가 들어오면 테스트가 실패하여 자동으로 차단
//

import Foundation
import Testing
@testable import Clients

// MARK: - 제약 조건 (U1~U4)

@Suite("User 제약 조건 도메인 규칙")
struct UserConstraintRuleTests {

  // MARK: - [U1] 닉네임 최소 2자

  @Test("[U1] 1자 닉네임은 tooShort")
  func u1_oneChar_tooShort() {
    let result = UserPublicModel.validateNickname("A")
    #expect(result == .tooShort(minimum: 2))
  }

  @Test("[U1] 빈 문자열은 tooShort")
  func u1_empty_tooShort() {
    let result = UserPublicModel.validateNickname("")
    #expect(result == .tooShort(minimum: 2))
  }

  @Test("[U1] 2자 닉네임은 유효")
  func u1_twoChars_valid() {
    let result = UserPublicModel.validateNickname("AB")
    #expect(result == nil)
  }

  // MARK: - [U2] 닉네임 최대 12자 (회원가입)

  @Test("[U2] 12자 닉네임은 유효")
  func u2_twelveChars_valid() {
    let result = UserPublicModel.validateNickname("123456789012")
    #expect(result == nil)
  }

  @Test("[U2] 13자 닉네임은 tooLong")
  func u2_thirteenChars_tooLong() {
    let result = UserPublicModel.validateNickname("1234567890123")
    #expect(result == .tooLong(maximum: 12))
  }

  // MARK: - [U3] 닉네임 중간 공백 불가

  @Test("[U3] 중간 공백이 있으면 containsWhitespace")
  func u3_middleSpace_invalid() {
    let result = UserPublicModel.validateNickname("테스트 유저")
    #expect(result == .containsWhitespace)
  }

  // MARK: - [U4] 닉네임 앞뒤 공백 불가

  @Test("[U4] 앞 공백이 있으면 hasLeadingOrTrailingWhitespace")
  func u4_leadingSpace_invalid() {
    let result = UserPublicModel.validateNickname(" 테스트유저")
    #expect(result == .hasLeadingOrTrailingWhitespace)
  }

  @Test("[U4] 뒤 공백이 있으면 hasLeadingOrTrailingWhitespace")
  func u4_trailingSpace_invalid() {
    let result = UserPublicModel.validateNickname("테스트유저 ")
    #expect(result == .hasLeadingOrTrailingWhitespace)
  }
}

// MARK: - 표시 규칙 (U12, U14)

@Suite("User 표시 도메인 규칙")
struct UserDisplayRuleTests {

  // MARK: - [U12] 프로필 이미지 URL 우선순위: thumbUrl > url

  @Test("[U12] thumbUrl 있으면 thumbUrl 반환")
  func u12_withThumbUrl_returnsThumb() {
    let profile = ProfileImage(url: "https://full.jpg", thumbUrl: "https://thumb.jpg")
    let user = TestFactories.makePublicUser(profile: profile)
    #expect(user.profileImageUrl == "https://thumb.jpg")
  }

  @Test("[U12] thumbUrl 없으면 url 반환")
  func u12_withoutThumbUrl_returnsOriginal() {
    let profile = ProfileImage(url: "https://full.jpg", thumbUrl: nil)
    let user = TestFactories.makePublicUser(profile: profile)
    #expect(user.profileImageUrl == "https://full.jpg")
  }

  @Test("[U12] profile nil이면 nil 반환")
  func u12_noProfile_returnsNil() {
    let user = TestFactories.makePublicUser(profile: nil)
    #expect(user.profileImageUrl == nil)
  }

  // MARK: - [U14] displayName = nickname

  @Test("[U14] displayName은 nickname 반환")
  func u14_displayName_returnsNickname() {
    let user = TestFactories.makePublicUser(nickname: "마이닉네임")
    #expect(user.displayName == "마이닉네임")
  }
}
