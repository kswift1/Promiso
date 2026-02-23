//
//  ProPlanFeatureTests.swift
//  ProPlanFeature
//
//  ProPlan.Feature 테스트
//
//  ## 테스트 대상
//  - `ProPlanFeature/Sources/ProPlanFeature.swift`
//
//  ## 사용처
//  - **ProPlanView**: UI 표시 로직
//  - **ProPlanFeature**: State 관리, Action 처리
//
//  ## 테스트 목적
//  - Reducer 액션 처리 검증
//  - State computed properties 검증
//

import Testing
import ComposableArchitecture
@testable import ProPlanFeature
@testable import Clients

@Suite("ProPlan.Feature 테스트")
@MainActor
struct ProPlanFeatureTests {

  // MARK: - 초기 상태

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = ProPlan.Feature.State()
    #expect(state.products.isEmpty)
    #expect(state.subscriptionStatus == .none)
    #expect(state.isLoadingProducts == false)
    #expect(state.isPurchasing == false)
    #expect(state.selectedProductId == nil)
    #expect(state.errorMessage == nil)
    #expect(state.showManageView == false)
  }

  // MARK: - 상품 로딩

  @Test("onAppear 시 상품 로딩 시작")
  func onAppear_startsLoadingProducts() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingProducts = true
    }

    await store.receive(\.internal.productsResponse.success) {
      $0.isLoadingProducts = false
      $0.products = Self.mockProducts
      $0.selectedProductId = "promiso_pro_yearly"
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .none
    }
  }

  @Test("상품 로딩 실패 시 에러 메시지 설정")
  func onAppear_productsFailure_setsErrorMessage() async {
    enum TestError: Error {
      case failed
    }

    let store = makeStore {
      $0.subscriptionClient.fetchProducts = { throw TestError.failed }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingProducts = true
    }

    await store.receive(\.internal.productsResponse.failure) {
      $0.isLoadingProducts = false
      $0.errorMessage = "상품 정보를 불러올 수 없습니다. 다시 시도해 주세요."
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .none
    }
  }

  // MARK: - 상품 선택

  @Test("상품 선택 시 selectedProductId 업데이트")
  func productSelected_updatesSelectedProductId() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.productSelected("promiso_pro_monthly"))) {
      $0.selectedProductId = "promiso_pro_monthly"
    }
  }

  // MARK: - 구매

  @Test("구매 성공 시 구독 상태 업데이트 및 delegate 전달")
  func purchaseTapped_success_updatesStatusAndSendsDelegate() async {
    var state = ProPlan.Feature.State()
    state.selectedProductId = "promiso_pro_yearly"

    let store = makeStore(state: state) {
      $0.authClient.currentUser = {
        FirebaseUserSnapshot(uid: "test-uid", email: "test@test.com", displayName: "Test", photoURL: nil)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.purchaseTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.purchaseResponse.success)
    #expect(store.state.isPurchasing == false)
    #expect(store.state.subscriptionStatus.isPro == true)

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("구매 실패 시 에러 메시지 설정")
  func purchaseTapped_failure_setsErrorMessage() async {
    enum TestError: Error {
      case failed
    }

    var state = ProPlan.Feature.State()
    state.selectedProductId = "promiso_pro_yearly"

    let store = makeStore(state: state) {
      $0.subscriptionClient.purchase = { _ in throw TestError.failed }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.purchaseTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.purchaseResponse.failure) {
      $0.isPurchasing = false
      $0.errorMessage = "구매에 실패했습니다. 다시 시도해 주세요."
    }
  }

  @Test("selectedProductId 없을 때 구매 시도 무시")
  func purchaseTapped_noSelectedProduct_doesNothing() async {
    var state = ProPlan.Feature.State()
    state.selectedProductId = nil

    let store = makeStore(state: state)

    await store.send(.view(.purchaseTapped))
  }

  // MARK: - 복원

  @Test("복원 성공 시 구독 상태 업데이트")
  func restoreTapped_success_updatesStatus() async {
    let store = makeStore {
      $0.subscriptionClient.restore = { .lifetime }
      $0.authClient.currentUser = {
        FirebaseUserSnapshot(uid: "test-uid", email: "test@test.com", displayName: "Test", photoURL: nil)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.restoreTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.restoreResponse.success) {
      $0.isPurchasing = false
      $0.subscriptionStatus = .lifetime
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("복원 실패 시 에러 메시지 설정")
  func restoreTapped_failure_setsErrorMessage() async {
    enum TestError: Error {
      case failed
    }

    let store = makeStore {
      $0.subscriptionClient.restore = { throw TestError.failed }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.restoreTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.restoreResponse.failure) {
      $0.isPurchasing = false
      $0.errorMessage = "복원에 실패했습니다. 이전에 구매한 내역이 없습니다."
    }
  }

  @Test("복원 성공 but 구독 없음 시 delegate 전달 안함")
  func restoreTapped_successButNone_doesNotSendDelegate() async {
    let store = makeStore {
      $0.subscriptionClient.restore = { .none }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.restoreTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.restoreResponse.success) {
      $0.isPurchasing = false
      $0.subscriptionStatus = .none
    }
  }

  // MARK: - UI 액션

  @Test("에러 메시지 닫기")
  func dismissError_clearsErrorMessage() async {
    var state = ProPlan.Feature.State()
    state.errorMessage = "테스트 에러"

    let store = makeStore(state: state)

    await store.send(.view(.dismissError)) {
      $0.errorMessage = nil
    }
  }

  @Test("구독 관리 화면 열기")
  func manageSubscriptionTapped_showsManageView() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.manageSubscriptionTapped)) {
      $0.showManageView = true
    }
  }

  @Test("구독 관리 화면 닫기")
  func dismissManageView_hidesManageView() async {
    var state = ProPlan.Feature.State()
    state.showManageView = true

    let store = makeStore(state: state)

    await store.send(.view(.dismissManageView)) {
      $0.showManageView = false
    }
  }

  // MARK: - Internal Actions

  @Test("productsResponse success 시 연간 플랜 기본 선택")
  func productsResponse_success_selectsYearlyByDefault() async {
    let store = makeStore()

    await store.send(.internal(.productsResponse(.success(Self.mockProducts)))) {
      $0.isLoadingProducts = false
      $0.products = Self.mockProducts
      $0.selectedProductId = "promiso_pro_yearly"
    }
  }

  @Test("statusUpdated 시 구독 상태 업데이트")
  func statusUpdated_updatesSubscriptionStatus() async {
    let store = makeStore()

    let expirationDate = Date().addingTimeInterval(30 * 24 * 3600)

    await store.send(.internal(.statusUpdated(.subscribed(expirationDate: expirationDate)))) {
      $0.subscriptionStatus = .subscribed(expirationDate: expirationDate)
    }
  }
}

// MARK: - Helpers

private extension ProPlanFeatureTests {
  static let mockProducts: [SubscriptionProduct] = [
    SubscriptionProduct(
      id: "promiso_pro_monthly",
      type: .monthly,
      displayName: "월간 프로",
      description: "매월 자동 갱신",
      displayPrice: "₩4,900",
      price: 4900
    ),
    SubscriptionProduct(
      id: "promiso_pro_yearly",
      type: .yearly,
      displayName: "연간 프로",
      description: "매년 자동 갱신",
      displayPrice: "₩39,000",
      price: 39000
    ),
    SubscriptionProduct(
      id: "promiso_pro_lifetime",
      type: .lifetime,
      displayName: "평생 프로",
      description: "한 번 결제, 영구 사용",
      displayPrice: "₩99,000",
      price: 99000
    )
  ]

  func makeStore(
    state: ProPlan.Feature.State = .init(),
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<ProPlan.Feature> {
    TestStore(initialState: state) {
      ProPlan.Feature()
    } withDependencies: {
      let expirationDate = Date().addingTimeInterval(365 * 24 * 3600)
      $0.subscriptionClient.fetchProducts = { Self.mockProducts }
      $0.subscriptionClient.purchase = { _ in .subscribed(expirationDate: expirationDate) }
      $0.subscriptionClient.restore = { .none }
      $0.subscriptionClient.fetchStatus = { .none }
      $0.subscriptionClient.statusStream = { .finished }
      $0.userSettingsClient.updatePlan = { _, _ in }
      $0.authClient.currentUser = { nil }
      $0.hapticFeedback = .testValue
      configure(&$0)
    }
  }
}
