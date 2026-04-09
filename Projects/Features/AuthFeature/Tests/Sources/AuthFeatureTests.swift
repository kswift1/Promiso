import Testing
@testable import AuthFeature

@Suite("Auth.Feature 테스트")
@MainActor
struct AuthFeatureTests {

  // MARK: - Initial State 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = Auth.Feature.State()

    #expect(state.isLoading == false)
    #expect(state.errorMessage == nil)
    #expect(state.pendingAppleLoginNonce == nil)
  }

  // MARK: - Apple Login 테스트

  @Test("Apple 로그인 탭 시 로딩 상태 설정 및 nonce 생성")
  func appleLoginTapped_setsLoadingAndGeneratesNonce() async {
    let store = TestStore(
      initialState: Auth.Feature.State()
    ) {
      Auth.Feature()
    }
    // nonce는 랜덤 생성이므로 exhaustivity off 후 별도 검증
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.appleLoginTapped)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }
    #expect(store.state.pendingAppleLoginNonce != nil)
    #expect(store.state.pendingAppleLoginNonce?.count == 32)
  }

  @Test("Apple 인증 실패 시 에러 상태 설정")
  func appleAuthorizationResult_failure_setsErrorState() async {
    var state = Auth.Feature.State()
    state.isLoading = true
    state.pendingAppleLoginNonce = "test-nonce"

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }

    let testError = NSError(
      domain: "ASAuthorizationError",
      code: 1001,
      userInfo: [NSLocalizedDescriptionKey: "사용자가 취소함"]
    )

    await store.send(.internal(.appleAuthorizationResult(.failure(testError)))) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.invalidAppleCredential.localizedMessage
    }
  }

  // MARK: - Google Login 테스트

  @Test("Google 로그인 탭 시 로딩 상태 설정")
  func googleLoginTapped_setsLoading() async {
    let mockBundle = ServiceTokenBundle(
      authUser: nil,
      providerTokenBundle: ProviderTokenBundle(
        provider: .google,
        identityToken: "test-id-token",
        accessToken: "test-access-token",
        userIdentifier: "google-user-123",
        email: "test@gmail.com",
        fullName: "테스트 유저"
      )
    )

    let store = TestStore(
      initialState: Auth.Feature.State()
    ) {
      Auth.Feature()
    } withDependencies: {
      $0.authClient.signInWithGoogle = { mockBundle }
    }

    await store.send(.view(.googleLoginTapped)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.authResponse.success) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
    }

    await store.receive(\.delegate.loggedIn)
  }

  @Test("Google 로그인 실패 시 에러 상태 설정")
  func googleLoginTapped_failure_setsErrorState() async {
    let store = TestStore(
      initialState: Auth.Feature.State()
    ) {
      Auth.Feature()
    } withDependencies: {
      $0.authClient.signInWithGoogle = { throw AuthClientError.network }
    }

    await store.send(.view(.googleLoginTapped)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.authResponse.failure) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.network.localizedMessage
    }
  }

  // MARK: - Auth Response 테스트

  @Test("인증 응답 성공 시 로딩 해제")
  func authResponse_success_clearsLoadingState() async {
    var state = Auth.Feature.State()
    state.isLoading = true
    state.pendingAppleLoginNonce = "test-nonce"

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }

    let mockBundle = ServiceTokenBundle(
      authUser: nil,
      providerTokenBundle: ProviderTokenBundle(
        provider: .apple,
        identityToken: "token",
        accessToken: nil,
        userIdentifier: "apple-user-123"
      )
    )

    await store.send(.internal(.authResponse(.success(mockBundle)))) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
    }
  }

  @Test("인증 응답 실패 시 에러 메시지 설정")
  func authResponse_failure_setsErrorMessage() async {
    var state = Auth.Feature.State()
    state.isLoading = true

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }

    await store.send(.internal(.authResponse(.failure(.unknown)))) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.unknown.localizedMessage
    }
  }

  // MARK: - Helper 테스트

  @Test("randomNonceString 길이 검증")
  func randomNonceString_generatesCorrectLength() {
    let nonce16 = Auth.Feature.randomNonceString(length: 16)
    #expect(nonce16.count == 16)

    let nonce32 = Auth.Feature.randomNonceString(length: 32)
    #expect(nonce32.count == 32)
  }

  @Test("sha256 해시 생성")
  func sha256_generatesHash() {
    let hash = Auth.Feature.sha256("test-input")
    #expect(!hash.isEmpty)
    #expect(hash.count == 64) // SHA256은 64자 hex string
  }

  // MARK: - 동일 입력 해시 일관성 테스트

  @Test("sha256 동일 입력 시 동일 해시 반환")
  func sha256_sameInput_returnsSameHash() {
    let hash1 = Auth.Feature.sha256("consistent-input")
    let hash2 = Auth.Feature.sha256("consistent-input")
    #expect(hash1 == hash2)
  }

  @Test("sha256 다른 입력 시 다른 해시 반환")
  func sha256_differentInput_returnsDifferentHash() {
    let hash1 = Auth.Feature.sha256("input-a")
    let hash2 = Auth.Feature.sha256("input-b")
    #expect(hash1 != hash2)
  }

  // MARK: - 랜덤 Nonce 유일성 테스트

  @Test("randomNonceString 호출마다 다른 값 생성")
  func randomNonceString_generatesUniqueValues() {
    let nonce1 = Auth.Feature.randomNonceString()
    let nonce2 = Auth.Feature.randomNonceString()
    #expect(nonce1 != nonce2)
  }

  // MARK: - Apple Login 로딩 중 테스트

  @Test("appleLoginTapped 시 이전 에러 메시지 초기화")
  func appleLoginTapped_clearsExistingError() async {
    var state = Auth.Feature.State()
    state.errorMessage = "이전 에러 메시지"

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.appleLoginTapped)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }
    #expect(store.state.pendingAppleLoginNonce != nil)
  }

  // MARK: - 다양한 AuthClientError 테스트

  @Test("authResponse - invalidAppleCredential 에러 메시지")
  func authResponse_invalidAppleCredential_setsCorrectMessage() async {
    var state = Auth.Feature.State()
    state.isLoading = true

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }

    await store.send(.internal(.authResponse(.failure(.invalidAppleCredential)))) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.invalidAppleCredential.localizedMessage
    }
  }

  @Test("authResponse - network 에러 메시지")
  func authResponse_network_setsCorrectMessage() async {
    var state = Auth.Feature.State()
    state.isLoading = true

    let store = TestStore(initialState: state) {
      Auth.Feature()
    }

    await store.send(.internal(.authResponse(.failure(.network)))) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.network.localizedMessage
    }
  }

  // MARK: - Google 로그인 에러 폴백 테스트

  @Test("Google 로그인 시 일반 Error는 .unknown으로 폴백")
  func googleLoginTapped_genericError_fallsBackToUnknown() async {
    enum GenericError: Error { case unexpected }

    let store = TestStore(
      initialState: Auth.Feature.State()
    ) {
      Auth.Feature()
    } withDependencies: {
      $0.authClient.signInWithGoogle = { throw GenericError.unexpected }
    }

    await store.send(.view(.googleLoginTapped)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.authResponse.failure) {
      $0.isLoading = false
      $0.pendingAppleLoginNonce = nil
      $0.errorMessage = AuthClientError.unknown.localizedMessage
    }
  }
}
