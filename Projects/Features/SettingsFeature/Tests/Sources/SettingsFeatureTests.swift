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

  // MARK: - logoutConfirmed 테스트

  @Test("logoutConfirmed 성공 시 로그아웃 완료")
  func logoutConfirmed_success_completesLogout() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-logout-confirmed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.showLogoutAlert = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    } withDependencies: {
      $0.authClient.logout = {}
      $0.hapticFeedback.heavy = {}
      $0.hapticFeedback.success = {}
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.logoutConfirmed)) {
      $0.showLogoutAlert = false
      $0.isLoading = true
    }
    await store.receive(\.internal.logoutCompleted) {
      $0.isLoading = false
    }
  }

  @Test("logoutConfirmed 실패 시 에러 메시지 표시")
  func logoutConfirmed_failure_showsError() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-logout-failed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.showLogoutAlert = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    } withDependencies: {
      $0.authClient.logout = { throw AuthClientError.unknown }
      $0.hapticFeedback.heavy = {}
      $0.hapticFeedback.error = {}
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.logoutConfirmed)) {
      $0.showLogoutAlert = false
      $0.isLoading = true
    }
    await store.receive(\.internal.logoutFailed) {
      $0.isLoading = false
      $0.errorMessage = AuthClientError.unknown.localizedDescription
    }
  }

  // MARK: - nicknameChanged 추가 테스트

  @Test("nicknameChanged - 20자 초과 시 invalid 상태")
  func nicknameChanged_tooLong_setsInvalid() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-long")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    let longName = String(repeating: "가", count: 21)
    await store.send(.view(.nicknameChanged(longName))) {
      $0.editedNickname = longName
      $0.nicknameValidation = .invalid("닉네임은 20자 이하여야 합니다")
    }
  }

  @Test("nicknameChanged - 현재 닉네임과 동일 시 idle 상태")
  func nicknameChanged_sameAsCurrent_setsIdle() async {
    let user = makeCurrentUser(nickname: "테스트유저")
    @Shared(.inMemory("test-nickname-same")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.nicknameChanged("테스트유저")))
  }

  // MARK: - nicknameCheckFailed 테스트

  @Test("nicknameCheckFailed 시 error 상태")
  func nicknameCheckFailed_setsError() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-nickname-check-failed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.nicknameValidation = .checking

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.internal(.nicknameCheckFailed("네트워크 에러"))) {
      $0.nicknameValidation = .error("네트워크 에러")
    }
  }

  // MARK: - profileImageSelected 테스트

  @Test("profileImageSelected 시 이미지 데이터 설정")
  func profileImageSelected_setsImageData() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-image-selected")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true

    let imageData = Data([0x01, 0x02, 0x03])
    let store = TestStore(initialState: state) {
      Settings.Feature()
    } withDependencies: {
      $0.hapticFeedback.selection = {}
    }

    await store.send(.view(.profileImageSelected(imageData))) {
      $0.editedProfileImageData = imageData
    }
  }

  // MARK: - saveProfileTapped 테스트

  @Test("saveProfileTapped - validation 미통과 시 무시")
  func saveProfileTapped_invalidValidation_ignored() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-save-guard")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true
    state.editedNickname = "새닉네임"
    state.nicknameValidation = .checking

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.saveProfileTapped))
  }

  // MARK: - profileSaveCompleted 테스트

  @Test("profileSaveCompleted 시 편집 모드 해제 및 사용자 업데이트")
  func profileSaveCompleted_updatesUserAndExitsEditMode() async {
    let user = makeCurrentUser(nickname: "원래닉네임")
    @Shared(.inMemory("test-save-completed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true
    state.isSavingProfile = true
    state.editedNickname = "새닉네임"

    let updatedUser = makeCurrentUser(nickname: "새닉네임")

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }
    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileSaveCompleted(updatedUser))) {
      $0.$currentUser.withLock { $0 = updatedUser }
      $0.isSavingProfile = false
      $0.isEditingProfile = false
      $0.editedProfileImageData = nil
      $0.nicknameValidation = .idle
    }

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .success)
    #expect(store.state.toastMessage?.title == "프로필이 저장되었어요")
    #expect(store.state.toastMessage?.position == .bottom)
  }

  // MARK: - profileSaveFailed 테스트

  @Test("profileSaveFailed 시 에러 메시지 설정")
  func profileSaveFailed_setsErrorMessage() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-save-failed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.isEditingProfile = true
    state.isSavingProfile = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    } withDependencies: {
      $0.hapticFeedback.error = {}
    }
    // toastMessage는 UUID 기반 Equatable이므로 exhaustive 비교 불가
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.profileSaveFailed("저장 실패"))) {
      $0.isSavingProfile = false
      $0.errorMessage = "저장 실패"
    }

    // Toast 내용 검증
    #expect(store.state.toastMessage?.type == .error)
    #expect(store.state.toastMessage?.title == "프로필 저장에 실패했어요")
    #expect(store.state.toastMessage?.subtitle == "저장 실패")
    #expect(store.state.toastMessage?.position == .bottom)
  }

  // MARK: - profileImageTapped / imageDetailDismissed 테스트

  @Test("profileImageTapped 시 이미지 상세 보기 표시")
  func profileImageTapped_showsImageDetail() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-image-tapped")) var currentUser = user

    let store = TestStore(
      initialState: Settings.Feature.State(currentUser: $currentUser)
    ) {
      Settings.Feature()
    }

    await store.send(.view(.profileImageTapped)) {
      $0.showImageDetail = true
    }
  }

  @Test("imageDetailDismissed 시 이미지 상세 닫기")
  func imageDetailDismissed_hidesImageDetail() async {
    let user = makeCurrentUser()
    @Shared(.inMemory("test-image-dismissed")) var currentUser = user

    var state = Settings.Feature.State(currentUser: $currentUser)
    state.showImageDetail = true

    let store = TestStore(initialState: state) {
      Settings.Feature()
    }

    await store.send(.view(.imageDetailDismissed)) {
      $0.showImageDetail = false
    }
  }
}
