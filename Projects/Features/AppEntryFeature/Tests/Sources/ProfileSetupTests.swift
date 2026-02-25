import Testing
import PromisoShared
@testable import AppEntryFeature

@Suite("AppEntry.ProfileSetup 테스트")
@MainActor
struct ProfileSetupTests {

  // MARK: - Helpers

  private func makeState(
    nickname: String = "",
    providerType: String? = "google",
    uid: String = "test-uid"
  ) -> AppEntry.ProfileSetup.State {
    var state = AppEntry.ProfileSetup.State(uid: uid, fullName: "")
    state.nickname = nickname
    state.providerType = providerType
    return state
  }

  private var testUser: UserPrivateModel {
    UserPrivateModel(
      userId: "user-1",
      name: "테스트",
      nickname: "테스터",
      email: "user-1@example.com",
      provider: "google",
      metadata: .init()
    )
  }

  // MARK: - 초기 상태

  @Test("초기 상태 기본값")
  func initialState_defaults() {
    let state = AppEntry.ProfileSetup.State(
      profileImageUrl: nil, email: "test@test.com", uid: "uid-1", fullName: "Test User"
    )
    #expect(state.step == .welcome)
    #expect(state.nickname == "TestUser")
    #expect(state.isSaving == false)
    #expect(state.isSkippingPhoto == false)
    #expect(state.nicknameError == nil)
    #expect(state.isNicknameAvailable == nil)
    #expect(state.profileImage == .none)
  }

  @Test("profileImageUrl 있으면 .url 설정")
  func initialState_withUrl() {
    let state = AppEntry.ProfileSetup.State(
      profileImageUrl: "https://example.com/photo.jpg", uid: "uid-1", fullName: ""
    )
    #expect(state.profileImage == .url(URL(string: "https://example.com/photo.jpg")!))
  }

  // MARK: - nextTapped

  @Test("isSaving 중 nextTapped 무시")
  func nextTapped_whileSaving_ignored() async {
    var state = makeState(nickname: "테스터")
    state.isSaving = true
    state.validation.isNicknameAvailable = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nextTapped))
  }

  @Test("닉네임 1자 → tooShort 에러")
  func nextTapped_tooShort_showsError() async {
    let store = TestStore(initialState: makeState(nickname: "a")) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nextTapped)) {
      $0.nicknameError = "2자 이상 입력해주세요"
    }
  }

  @Test("닉네임 13자 → tooLong 에러")
  func nextTapped_tooLong_showsError() async {
    let store = TestStore(initialState: makeState(nickname: "가나다라마바사아자차카타마")) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nextTapped)) {
      $0.nicknameError = "12자 이하로 입력해주세요"
    }
  }

  @Test("닉네임 중복확인 nil → 에러")
  func nextTapped_notChecked_showsError() async {
    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nextTapped)) {
      $0.nicknameError = LocalizedStrings.Profile.nicknameCheckRequired
    }
  }

  @Test("isNicknameAvailable=false → 에러")
  func nextTapped_unavailable_showsError() async {
    var state = makeState(nickname: "테스터")
    state.validation.isNicknameAvailable = false

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nextTapped)) {
      $0.nicknameError = LocalizedStrings.Profile.nicknameCheckRequired
    }
  }

  @Test("유효 + 사용가능 → saveProfile 시작")
  func nextTapped_valid_triggersSave() async {
    var state = makeState(nickname: "테스터")
    state.validation.isNicknameAvailable = true
    let user = testUser

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in user }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.nextTapped))
    await store.receive(\.internal) {
      $0.isSaving = true
    }
    await store.receive(\.internal)
    await store.receive(\.delegate)
  }

  // MARK: - backTapped

  @Test("welcome 단계에서 backTapped 무시")
  func backTapped_welcome_ignored() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.backTapped))
  }

  @Test("nickname → welcome 이동")
  func backTapped_nickname_goesToWelcome() async {
    var state = makeState()
    state.step = .nickname

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.backTapped)) {
      $0.previousStep = .nickname
      $0.step = .welcome
      $0.showAnimation = nil
      $0.showButtons = false
    }
  }

  @Test("photo → nickname 이동")
  func backTapped_photo_goesToNickname() async {
    var state = makeState()
    state.step = .photo

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.backTapped)) {
      $0.previousStep = .photo
      $0.step = .nickname
      $0.showAnimation = nil
      $0.showButtons = false
    }
  }

  @Test("방문한 단계로 back 시 showButtons=true")
  func backTapped_visitedStep_showsButtons() async {
    var state = makeState()
    state.step = .nickname
    state.ui.completedSteps = [.welcome]

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.backTapped)) {
      $0.previousStep = .nickname
      $0.step = .welcome
      $0.showAnimation = false
      $0.showButtons = true
    }
  }

  // MARK: - skipTapped

  @Test("isSaving 중 skipTapped 무시")
  func skipTapped_whileSaving_ignored() async {
    var state = makeState()
    state.isSaving = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.skipTapped))
  }

  @Test("skipTapped → isSkippingPhoto + saveProfile")
  func skipTapped_triggersSave() async {
    let user = testUser
    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in user }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.skipTapped)) {
      $0.isSkippingPhoto = true
    }
    await store.receive(\.internal)
    await store.receive(\.internal)
    await store.receive(\.delegate)
  }

  // MARK: - nicknameChanged

  @Test("빈 문자열 → 에러 + 체크 취소")
  func nicknameChanged_empty_cancelsCheck() async {
    var state = makeState(nickname: "테스터")
    state.validation.isCheckingNickname = true
    state.validation.isNicknameAvailable = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nicknameChanged(""))) {
      $0.nickname = ""
      $0.nicknameError = "2자 이상 입력해주세요"
      $0.isNicknameAvailable = nil
      $0.isCheckingNickname = false
    }
  }

  @Test("1자 입력 → tooShort 에러")
  func nicknameChanged_tooShort() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nicknameChanged("a"))) {
      $0.nickname = "a"
      $0.nicknameError = "2자 이상 입력해주세요"
    }
  }

  @Test("13자 입력 → tooLong 에러")
  func nicknameChanged_tooLong() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nicknameChanged("가나다라마바사아자차카타마"))) {
      $0.nickname = "가나다라마바사아자차카타마"
      $0.nicknameError = "12자 이하로 입력해주세요"
    }
  }

  @Test("공백 포함 → containsWhitespace 에러")
  func nicknameChanged_whitespace() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.nicknameChanged("테 스터"))) {
      $0.nickname = "테 스터"
      $0.nicknameError = "닉네임엔 공백을 넣을 수 없어요"
    }
  }

  @Test("유효 닉네임 → 중복 체크 시작 + 응답")
  func nicknameChanged_valid_startsCheck() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.isNicknameAvailable = { _ in true }
    }
    await store.send(.view(.nicknameChanged("테스터"))) {
      $0.nickname = "테스터"
      $0.isCheckingNickname = true
    }
    await store.receive(\.internal) {
      $0.isCheckingNickname = false
      $0.isNicknameAvailable = true
    }
  }

  // MARK: - nicknameAvailabilityResponse

  @Test("사용 가능 → isNicknameAvailable=true")
  func nicknameResponse_available() async {
    var state = makeState(nickname: "테스터")
    state.validation.isCheckingNickname = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.internal(.nicknameAvailabilityResponse(.success(true)))) {
      $0.isCheckingNickname = false
      $0.isNicknameAvailable = true
    }
  }

  @Test("사용 불가 → 에러 메시지")
  func nicknameResponse_unavailable() async {
    var state = makeState(nickname: "테스터")
    state.validation.isCheckingNickname = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.internal(.nicknameAvailabilityResponse(.success(false)))) {
      $0.isCheckingNickname = false
      $0.isNicknameAvailable = false
      $0.nicknameError = LocalizedStrings.Profile.nicknameTaken
    }
  }

  @Test("실패 → 에러 메시지")
  func nicknameResponse_failure() async {
    var state = makeState(nickname: "테스터")
    state.validation.isCheckingNickname = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    let error = NSError(domain: "test", code: -1)
    await store.send(.internal(.nicknameAvailabilityResponse(.failure(error)))) {
      $0.isCheckingNickname = false
      $0.isNicknameAvailable = nil
      $0.nicknameError = LocalizedStrings.Profile.nicknameCheckFailed
    }
  }

  // MARK: - saveProfile

  @Test("providerType nil → profileSaveFailed")
  func saveProfile_noProvider_fails() async {
    let store = TestStore(initialState: makeState(providerType: nil)) {
      AppEntry.ProfileSetup()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.saveProfile)) {
      $0.isSaving = true
    }
    await store.receive(\.internal) {
      $0.isSaving = false
    }
    #expect(store.state.alert != nil)
  }

  @Test("저장 성공 → delegate.completed")
  func saveProfile_success() async {
    let user = testUser

    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in user }
    }

    await store.send(.internal(.saveProfile)) {
      $0.isSaving = true
    }
    await store.receive(\.internal) {
      $0.isSaving = false
    }
    await store.receive(\.delegate)
  }

  @Test("uploadFailed → getPrivateProfile 복구 성공")
  func saveProfile_uploadFailed_recovers() async {
    let user = testUser

    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in
        throw UserProfileError.uploadFailed
      }
      $0.userProfileClient.getPrivateProfile = { _ in user }
    }

    await store.send(.internal(.saveProfile)) {
      $0.isSaving = true
    }
    await store.receive(\.internal) {
      $0.isSaving = false
    }
    await store.receive(\.delegate)
  }

  @Test("uploadFailed → 복구 실패 → alert")
  func saveProfile_uploadFailed_recoveryFails() async {
    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in
        throw UserProfileError.uploadFailed
      }
      $0.userProfileClient.getPrivateProfile = { _ in
        throw UserProfileError.networkError
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.saveProfile)) {
      $0.isSaving = true
    }
    await store.receive(\.internal) {
      $0.isSaving = false
    }
    #expect(store.state.alert != nil)
  }

  @Test("일반 에러 → alert")
  func saveProfile_otherError_showsAlert() async {
    let store = TestStore(initialState: makeState(nickname: "테스터")) {
      AppEntry.ProfileSetup()
    } withDependencies: {
      $0.userProfileClient.createUserWithProfile = { _, _, _, _, _, _ in
        throw UserProfileError.networkError
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.saveProfile)) {
      $0.isSaving = true
    }
    await store.receive(\.internal) {
      $0.isSaving = false
    }
    #expect(store.state.alert != nil)
  }

  // MARK: - profileSaved / profileSaveFailed

  @Test("profileSaved → isSaving 리셋 + delegate")
  func profileSaved_resetsAndCompletes() async {
    var state = makeState()
    state.isSaving = true
    state.isSkippingPhoto = true
    let user = testUser

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }

    await store.send(.internal(.profileSaved(user))) {
      $0.isSaving = false
      $0.isSkippingPhoto = false
    }
    await store.receive(\.delegate)
  }

  @Test("profileSaveFailed → alert 표시")
  func profileSaveFailed_showsAlert() async {
    var state = makeState()
    state.isSaving = true
    state.isSkippingPhoto = true

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    let error = NSError(domain: "test", code: -1, userInfo: [
      NSLocalizedDescriptionKey: "테스트 에러"
    ])
    await store.send(.internal(.profileSaveFailed(error))) {
      $0.isSaving = false
      $0.isSkippingPhoto = false
    }
    #expect(store.state.alert != nil)
  }

  // MARK: - Lifecycle

  @Test("stepDidAppear 첫 방문 → 애니메이션 시작")
  func stepDidAppear_firstVisit_startsAnimation() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }

    await store.send(.view(.stepDidAppear(.welcome)))
    await store.receive(\.internal) {
      $0.showAnimation = true
    }
  }

  @Test("stepDidAppear 재방문 → 무시")
  func stepDidAppear_revisit_ignored() async {
    var state = makeState()
    state.ui.completedSteps = [.welcome]

    let store = TestStore(initialState: state) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.stepDidAppear(.welcome)))
  }

  @Test("animationCompleted → completedSteps + showButtons")
  func animationCompleted_updatesUI() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.view(.animationCompleted(.welcome))) {
      $0.completedSteps = [.welcome]
      $0.showButtons = true
    }
  }

  @Test("photoLoaded → profileImage 업데이트")
  func photoLoaded_updatesImage() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    let data = Data([0x1, 0x2, 0x3])
    await store.send(.internal(.photoLoaded(data))) {
      $0.profileImage = .data(data)
    }
  }

  @Test("startAnimation → showAnimation=true")
  func startAnimation_setsFlag() async {
    let store = TestStore(initialState: makeState()) {
      AppEntry.ProfileSetup()
    }
    await store.send(.internal(.startAnimation(.welcome))) {
      $0.showAnimation = true
    }
  }
}
