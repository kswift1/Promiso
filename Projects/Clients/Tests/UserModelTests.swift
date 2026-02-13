//
//  UserModelTests.swift
//  Clients
//
//  UserModel 관련 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/UserModel.swift`
//
//  ## 테스트 목적
//  - UserPublicModel.validateNickname 닉네임 유효성 검증 로직
//  - UserPrivateModel.toPublic 변환, sortedGroups 정렬 검증
//  - displayName, profileImageUrl 등 computed property 검증
//  - NicknameValidationError 메시지 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - 닉네임 유효성 검증 테스트

@Suite("UserPublicModel 닉네임 유효성 검증 테스트")
struct NicknameValidationTests {

  @Test("[U1,U2] 유효한 닉네임 (2~12자)이면 nil 반환")
  func validateNickname_validNickname_returnsNil() {
    let result = UserPublicModel.validateNickname("테스트유저")
    #expect(result == nil)
  }

  @Test("[U1] 2자 닉네임이면 유효")
  func validateNickname_twoCharacters_returnsNil() {
    let result = UserPublicModel.validateNickname("AB")
    #expect(result == nil)
  }

  @Test("[U2] 12자 닉네임이면 유효")
  func validateNickname_twelveCharacters_returnsNil() {
    let result = UserPublicModel.validateNickname("123456789012")
    #expect(result == nil)
  }

  @Test("[U1] 1자 닉네임이면 tooShort 에러")
  func validateNickname_oneCharacter_returnsTooShort() {
    let result = UserPublicModel.validateNickname("A")
    #expect(result == .tooShort(minimum: 2))
  }

  @Test("[U1] 빈 문자열이면 tooShort 에러")
  func validateNickname_empty_returnsTooShort() {
    let result = UserPublicModel.validateNickname("")
    #expect(result == .tooShort(minimum: 2))
  }

  @Test("[U2] 13자 이상이면 tooLong 에러")
  func validateNickname_thirteenCharacters_returnsTooLong() {
    let result = UserPublicModel.validateNickname("1234567890123")
    #expect(result == .tooLong(maximum: 12))
  }

  @Test("[U3] 중간에 공백이 있으면 containsWhitespace 에러")
  func validateNickname_withMiddleWhitespace_returnsContainsWhitespace() {
    let result = UserPublicModel.validateNickname("테스트 유저")
    #expect(result == .containsWhitespace)
  }

  @Test("[U4] 앞에 공백이 있으면 hasLeadingOrTrailingWhitespace 에러")
  func validateNickname_withLeadingWhitespace_returnsHasLeadingOrTrailing() {
    let result = UserPublicModel.validateNickname(" 테스트유저")
    #expect(result == .hasLeadingOrTrailingWhitespace)
  }

  @Test("[U4] 뒤에 공백이 있으면 hasLeadingOrTrailingWhitespace 에러")
  func validateNickname_withTrailingWhitespace_returnsHasLeadingOrTrailing() {
    let result = UserPublicModel.validateNickname("테스트유저 ")
    #expect(result == .hasLeadingOrTrailingWhitespace)
  }
}

// MARK: - NicknameValidationError 메시지 테스트

@Suite("NicknameValidationError 메시지 테스트")
struct NicknameValidationErrorMessageTests {

  @Test("tooShort 에러 메시지 확인")
  func tooShort_message() {
    let error = UserPublicModel.NicknameValidationError.tooShort(minimum: 2)
    #expect(error.message == "2자 이상 입력해주세요")
  }

  @Test("tooLong 에러 메시지 확인")
  func tooLong_message() {
    let error = UserPublicModel.NicknameValidationError.tooLong(maximum: 12)
    #expect(error.message == "12자 이하로 입력해주세요")
  }

  @Test("containsWhitespace 에러 메시지 확인")
  func containsWhitespace_message() {
    let error = UserPublicModel.NicknameValidationError.containsWhitespace
    #expect(error.message == "닉네임엔 공백을 넣을 수 없어요")
  }

  @Test("hasLeadingOrTrailingWhitespace 에러 메시지 확인")
  func hasLeadingOrTrailingWhitespace_message() {
    let error = UserPublicModel.NicknameValidationError.hasLeadingOrTrailingWhitespace
    #expect(error.message == "앞뒤 공백 없이 입력해주세요")
  }
}

// MARK: - UserPublicModel / UserPrivateModel 테스트

@Suite("UserModel 속성 및 변환 테스트")
struct UserModelPropertyTests {

  // MARK: - displayName 테스트

  @Test("[U14] displayName은 닉네임을 반환")
  func displayName_returnsNickname() {
    let user = TestFactories.makePublicUser(nickname: "마이닉네임")
    #expect(user.displayName == "마이닉네임")
  }

  // MARK: - profileImageUrl 테스트

  @Test("[U12] 프로필 이미지가 있고 썸네일 URL이 있으면 썸네일 반환")
  func profileImageUrl_withThumbUrl_returnsThumbUrl() {
    let profile = ProfileImage(url: "https://example.com/full.jpg", thumbUrl: "https://example.com/thumb.jpg")
    let user = TestFactories.makePublicUser(profile: profile)
    #expect(user.profileImageUrl == "https://example.com/thumb.jpg")
  }

  @Test("[U12] 프로필 이미지가 있고 썸네일 없으면 원본 URL 반환")
  func profileImageUrl_withoutThumbUrl_returnsOriginalUrl() {
    let profile = ProfileImage(url: "https://example.com/full.jpg", thumbUrl: nil)
    let user = TestFactories.makePublicUser(profile: profile)
    #expect(user.profileImageUrl == "https://example.com/full.jpg")
  }

  @Test("[U12] 프로필 이미지가 nil이면 nil 반환")
  func profileImageUrl_withNoProfile_returnsNil() {
    let user = TestFactories.makePublicUser(profile: nil)
    #expect(user.profileImageUrl == nil)
  }

  // MARK: - UserPublicModel id 테스트

  @Test("UserPublicModel의 id는 userId와 동일")
  func publicModel_id_equalsUserId() {
    let user = TestFactories.makePublicUser(userId: "test-user-123")
    #expect(user.id == "test-user-123")
  }

  // MARK: - UserPrivateModel toPublic 테스트

  @Test("toPublic 변환 시 기본 정보 유지")
  func toPublic_preservesBasicInfo() {
    let profile = ProfileImage(url: "https://example.com/img.jpg")
    let metadata = Metadata()
    let user = TestFactories.makeCurrentUser(
      userId: "user-1",
      name: "김테스트",
      nickname: "테스트닉",
      profile: profile,
      metadata: metadata
    )
    let publicUser = user.toPublic()

    #expect(publicUser.userId == "user-1")
    #expect(publicUser.name == "김테스트")
    #expect(publicUser.nickname == "테스트닉")
    #expect(publicUser.profile?.url == "https://example.com/img.jpg")
  }

  // MARK: - UserPrivateModel sortedGroups 테스트

  @Test("sortedGroups는 joinedAt 내림차순 정렬")
  func sortedGroups_sortsByJoinedAtDescending() {
    let now = Date()
    let groups = [
      TestFactories.makeUserGroupInfo(id: "g1", joinedAt: now.addingTimeInterval(-7200)),
      TestFactories.makeUserGroupInfo(id: "g2", joinedAt: now.addingTimeInterval(-3600)),
      TestFactories.makeUserGroupInfo(id: "g3", joinedAt: now),
    ]
    let user = TestFactories.makeCurrentUser(groups: groups)
    let sorted = user.sortedGroups

    #expect(sorted[0].id == "g3")
    #expect(sorted[1].id == "g2")
    #expect(sorted[2].id == "g1")
  }

  @Test("sortedGroups에서 joinedAt이 nil이면 가장 뒤로")
  func sortedGroups_nilJoinedAtGoesLast() {
    let now = Date()
    let groups = [
      TestFactories.makeUserGroupInfo(id: "g1", joinedAt: nil),
      TestFactories.makeUserGroupInfo(id: "g2", joinedAt: now),
    ]
    let user = TestFactories.makeCurrentUser(groups: groups)
    let sorted = user.sortedGroups

    #expect(sorted[0].id == "g2")
    #expect(sorted[1].id == "g1")
  }

  // MARK: - UserPrivateModel id 테스트

  @Test("UserPrivateModel의 id는 userId와 동일")
  func privateModel_id_equalsUserId() {
    let user = TestFactories.makeCurrentUser(userId: "private-user-123")
    #expect(user.id == "private-user-123")
  }

  // MARK: - exampleUser 테스트

  @Test("exampleUser 정적 속성이 올바른 기본값을 가짐")
  func exampleUser_hasCorrectDefaults() {
    let example = UserPrivateModel.exampleUser
    #expect(example.userId == "example_user")
    #expect(example.nickname == "예시유저")
    #expect(example.email == "example@example.com")
    #expect(example.provider == "google")
  }
}
