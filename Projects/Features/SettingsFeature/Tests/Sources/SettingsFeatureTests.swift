//
//  SettingsFeatureTests.swift
//  SettingsFeature
//
//  Settings.Feature reducer 테스트 (Swift Testing + TCA TestStore)
//
//  ## 테스트 대상
//  - `SettingsFeature/Sources/SettingsFeature.swift`
//  - Reducer의 action 처리 및 state 변화 검증
//

import Foundation
import Testing
import ComposableArchitecture
import Clients
import Sharing
@testable import SettingsFeature

// MARK: - SettingsFeature Tests

@Suite("Settings.Feature reducer 테스트")
struct SettingsFeatureTests {

  // MARK: - Test Helpers

  /// 테스트용 현재 사용자 생성
  private func makeCurrentUser(
    nickname: String = "테스트유저"
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: "test-user-123",
      name: "테스트",
      nickname: nickname,
      email: "test@example.com",
      provider: "apple",
      metadata: .init(),
      groups: []
    )
  }

  // MARK: - logoutTapped 테스트

  @Test("logoutTapped 시 로그아웃 확인 Alert 표시")
  func logoutTapped_showsLogoutAlert() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-logout-alert")) var currentUser = user

    let store = TestStore(
      initialState: Settings.Feature.State(currentUser: $currentUser)
    ) {
      Settings.Feature()
    } withDependencies: {
      $0.hapticFeedback.medium = {}
    }

    await store.send(.view(.logoutTapped)) {
      $0.showLogoutAlert = true
    }
  }

  @Test("logoutCancelled 시 Alert 닫기")
  func logoutCancelled_dismissesAlert() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-logout-cancel")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.showLogoutAlert = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.logoutCancelled)) {
      $0.showLogoutAlert = false
    }
  }

  // MARK: - Profile Edit 테스트

  @Test("editProfileTapped 시 프로필 편집 모드 진입")
  func editProfileTapped_entersEditMode() async {
    let user = makeCurrentUser(nickname: "원래닉네임")
    @Shared(.inMemory("test-edit-profile")) var currentUser = user

    let store = TestStore(
      initialState: Settings.Feature.State(currentUser: $currentUser)
    ) {
      Settings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }

    await store.send(.view(.editProfileTapped)) {
      $0.isEditingProfile = true
      $0.editedNickname = "원래닉네임"
      $0.editedProfileImageData = nil
      $0.nicknameValidation = .idle
    }
  }

  @Test("cancelEditTapped 시 편집 모드 해제")
  func cancelEditTapped_exitsEditMode() async {
    let user = makeCurrentUser(nickname: "원래닉네임")
    @Shared(.inMemory("test-cancel-edit")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true
    state.editedNickname = "변경된닉네임"

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.cancelEditTapped)) {
      $0.isEditingProfile = false
      $0.editedNickname = "원래닉네임"
      $0.editedProfileImageData = nil
      $0.nicknameValidation = .idle
    }
  }

  @Test("nicknameChanged - 빈 문자열 시 invalid 상태")
  func nicknameChanged_emptyString_setsInvalid() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-empty")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.nicknameChanged(""))) {
      $0.editedNickname = ""
      $0.nicknameValidation = .invalid("닉네임을 입력해주세요")
    }
  }

  @Test("nicknameChanged - 1자 미만 시 invalid 상태")
  func nicknameChanged_tooShort_setsInvalid() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-short")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.nicknameChanged("A"))) {
      $0.editedNickname = "A"
      $0.nicknameValidation = .invalid("닉네임은 2자 이상이어야 합니다")
    }
  }

  @Test("dismissError 시 에러 메시지 초기화")
  func dismissError_clearsErrorMessage() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-dismiss-error")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.errorMessage = "테스트 에러"

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.dismissError)) {
      $0.errorMessage = nil
    }
  }

  // MARK: - Internal Actions 테스트

  @Test("nicknameCheckResult - available 시 상태 업데이트")
  func nicknameCheckResult_available_setsAvailable() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-available")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.nicknameValidation = .checking

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.internal(.nicknameCheckResult(true))) {
      $0.nicknameValidation = .available
    }
  }

  @Test("nicknameCheckResult - unavailable 시 상태 업데이트")
  func nicknameCheckResult_unavailable_setsUnavailable() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-unavailable")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.nicknameValidation = .checking

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.internal(.nicknameCheckResult(false))) {
      $0.nicknameValidation = .unavailable
    }
  }
}
