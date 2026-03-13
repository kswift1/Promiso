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
import PromisoShared
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
    #expect(state.productsLoadErrorMessage == nil)
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
      $0.selectedProductId = SubscriptionProductType.yearly.productId
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .none
    }
  }

  @Test("Paywall 노출 시 analytics 이벤트 로깅")
  func paywallAppeared_logsAnalyticsEvent() async {
    let didLogPaywallOpen = LockIsolated(false)

    let store = makeStore {
      $0.analyticsClient.logEvent = { name, _ in
        if name == AnalyticsClient.EventName.paywallOpen {
          didLogPaywallOpen.setValue(true)
        }
      }
    }

    await store.send(.view(.paywallAppeared))
    #expect(didLogPaywallOpen.value == true)
  }

  @Test("Paywall 종료 시 analytics 이벤트 로깅")
  func paywallDisappeared_logsAnalyticsEvent() async {
    let didLogPaywallClose = LockIsolated(false)

    let store = makeStore {
      $0.analyticsClient.logEvent = { name, _ in
        if name == AnalyticsClient.EventName.paywallClose {
          didLogPaywallClose.setValue(true)
        }
      }
    }

    await store.send(.view(.paywallDisappeared))
    #expect(didLogPaywallClose.value == true)
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
      $0.productsLoadErrorMessage = LocalizedStrings.ProPlan.productsLoadFailed
      $0.errorMessage = LocalizedStrings.ProPlan.productsLoadFailed
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .none
    }
  }

  @Test("상품 로딩 실패 후 retry 시 에러를 지우고 다시 로드")
  func retryProductsLoadTapped_retriesLoading() async {
    enum TestError: Error {
      case failed
    }

    let fetchProductsCallCount = LockIsolated(0)
    let mockProducts = Self.mockProducts

    let store = makeStore {
      $0.subscriptionClient.fetchProducts = {
        let currentCallCount = fetchProductsCallCount.withValue {
          $0 += 1
          return $0
        }

        if currentCallCount == 1 {
          throw TestError.failed
        }
        return mockProducts
      }
      $0.hapticFeedback.selection = {}
    }

    await store.send(.view(.onAppear)) {
      $0.isLoadingProducts = true
    }

    await store.receive(\.internal.productsResponse.failure) {
      $0.isLoadingProducts = false
      $0.productsLoadErrorMessage = LocalizedStrings.ProPlan.productsLoadFailed
      $0.errorMessage = LocalizedStrings.ProPlan.productsLoadFailed
    }

    await store.receive(\.internal.statusUpdated)
    await store.receive(\.internal.introOfferEligibilityResult)
    await store.receive(\.internal.purchaseDateLoaded)

    await store.send(.view(.retryProductsLoadTapped)) {
      $0.isLoadingProducts = true
      $0.errorMessage = nil
      $0.productsLoadErrorMessage = nil
    }

    await store.receive(\.internal.productsResponse.success) {
      $0.isLoadingProducts = false
      $0.products = mockProducts
      $0.selectedProductId = SubscriptionProductType.yearly.productId
    }

    await store.receive(\.internal.statusUpdated)
    await store.receive(\.internal.introOfferEligibilityResult)
    await store.receive(\.internal.purchaseDateLoaded)
  }

  // MARK: - 상품 선택

  @Test("상품 선택 시 selectedProductId 업데이트")
  func productSelected_updatesSelectedProductId() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.productSelected(SubscriptionProductType.monthly.productId))) {
      $0.selectedProductId = SubscriptionProductType.monthly.productId
    }
  }

  @Test("연간 할인율은 Decimal 올림으로 계산")
  func yearlyDiscountPercent_roundsUpWithDecimal() {
    #expect(
      ProPlan.yearlyDiscountPercent(
        yearlyPrice: Decimal(string: "80.01")!,
        monthlyPrice: Decimal(string: "10")!
      ) == 34
    )
  }

  @Test("연간 할인율은 유효하지 않은 가격이면 nil")
  func yearlyDiscountPercent_invalidPricing_returnsNil() {
    #expect(
      ProPlan.yearlyDiscountPercent(
        yearlyPrice: Decimal(string: "120")!,
        monthlyPrice: Decimal(string: "10")!
      ) == nil
    )
    #expect(
      ProPlan.yearlyDiscountPercent(
        yearlyPrice: Decimal(string: "39")!,
        monthlyPrice: nil
      ) == nil
    )
  }

  // MARK: - 구매

  @Test("구매 성공 시 구독 상태 업데이트 및 delegate 전달")
  func purchaseTapped_success_updatesStatusAndSendsDelegate() async {
    let didLogPurchase = LockIsolated(false)

    var state = ProPlan.Feature.State()
    state.selectedProductId = SubscriptionProductType.yearly.productId

    let store = makeStore(state: state) {
      $0.analyticsClient.logEvent = { name, _ in
        if name == AnalyticsClient.EventName.paywallPurchase {
          didLogPurchase.setValue(true)
        }
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
    #expect(didLogPurchase.value == true)

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("구매 성공 시 축하 화면과 별도로 Pro 기본값 초기화 시작")
  func purchaseTapped_success_initializesProDefaultsBeforeCelebrationDismiss() async {
    let initialized = LockIsolated(false)
    let expirationDate = Date().addingTimeInterval(365 * 24 * 3600)

    var state = ProPlan.Feature.State()
    state.selectedProductId = SubscriptionProductType.yearly.productId

    let store = makeStore(state: state) {
      $0.subscriptionClient.purchaseWithReceipt = { _ in
        PurchaseResult(
          jwsString: "mock-jws-token",
          localStatus: .subscribed(productType: .yearly, expirationDate: expirationDate)
        )
      }
      $0.subscriptionClient.verifyPurchase = { _, _ in
        .subscribed(productType: .yearly, expirationDate: expirationDate)
      }
      $0.userSettingsClient.hasProSettings = { _ in false }
      $0.userSettingsClient.initializeProDefaults = { _ in
        initialized.setValue(true)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.purchaseTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.purchaseResponse.success) {
      $0.isPurchasing = false
      $0.subscriptionStatus = .subscribed(productType: .yearly, expirationDate: expirationDate)
      $0.showCelebration = true
      $0.isSettingUpDefaults = true
    }

    await store.receive(\.delegate.subscriptionStatusChanged)

    await store.receive(\.internal.proDefaultsInitialized) {
      $0.isSettingUpDefaults = false
      $0.showProOnboarding = true
    }

    #expect(initialized.value == true)
  }

  @Test("구매 실패 시 에러 메시지 설정")
  func purchaseTapped_failure_setsErrorMessage() async {
    enum TestError: Error {
      case failed
    }

    var state = ProPlan.Feature.State()
    state.selectedProductId = SubscriptionProductType.yearly.productId

    let store = makeStore(state: state) {
      $0.subscriptionClient.purchaseWithReceipt = { _ in throw TestError.failed }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.purchaseTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.purchaseResponse.failure) {
      $0.isPurchasing = false
      $0.errorMessage = LocalizedStrings.ProPlan.purchaseFailed
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
    let didLogRestore = LockIsolated(false)

    let store = makeStore {
      $0.subscriptionClient.restoreWithReceipt = {
        RestoreResult(
          jwsString: "mock-restore-jws-token",
          productId: SubscriptionProductType.lifetime.productId,
          localStatus: .lifetime
        )
      }
      $0.subscriptionClient.verifyPurchase = { _, _ in .lifetime }
      $0.analyticsClient.logEvent = { name, _ in
        if name == AnalyticsClient.EventName.paywallRestore {
          didLogRestore.setValue(true)
        }
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

    #expect(didLogRestore.value == true)

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("기존 Pro 설정이 있으면 브리핑 알림 시간 nil이어도 기본값으로 덮어쓰지 않음")
  func restoreTapped_existingProSettings_preservesExistingValues() async {
    let initializeCalled = LockIsolated(false)
    let existingSettings = UserSettings(
      notificationEnabled: true,
      groupSortOption: .joinedRecent,
      conflictDetectionThreshold: 30,
      briefingStyle: .calm,
      briefingNotificationHour: nil,
      availableTransports: [.car]
    )

    let store = makeStore {
      $0.subscriptionClient.restoreWithReceipt = {
        RestoreResult(
          jwsString: "mock-restore-jws-token",
          productId: SubscriptionProductType.lifetime.productId,
          localStatus: .lifetime
        )
      }
      $0.subscriptionClient.verifyPurchase = { _, _ in .lifetime }
      $0.userSettingsClient.hasProSettings = { _ in true }
      $0.userSettingsClient.fetchSettings = { _ in existingSettings }
      $0.userSettingsClient.initializeProDefaults = { _ in
        initializeCalled.setValue(true)
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
      $0.isSettingUpDefaults = true
    }

    await store.receive(\.delegate.subscriptionStatusChanged)

    await store.receive(\.internal.proExistingSettingsLoaded) {
      $0.isSettingUpDefaults = false
      $0.onboardingConflictThreshold = 30
      $0.onboardingBriefingStyle = .calm
      $0.onboardingBriefingHour = 8
      $0.onboardingTransports = [.car]
      $0.showProOnboarding = true
    }

    #expect(initializeCalled.value == false)
  }

  @Test("복원 실패 시 에러 메시지 설정")
  func restoreTapped_failure_setsErrorMessage() async {
    enum TestError: Error {
      case failed
    }

    let store = makeStore {
      $0.subscriptionClient.restoreWithReceipt = { throw TestError.failed }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.restoreTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.restoreResponse.failure) {
      $0.isPurchasing = false
      $0.errorMessage = LocalizedStrings.ProPlan.restoreFailed
    }
  }

  @Test("복원 성공 but 구독 없음 시 delegate 전달 안함")
  func restoreTapped_successButNone_doesNotSendDelegate() async {
    let store = makeStore {
      $0.subscriptionClient.restoreWithReceipt = {
        RestoreResult(jwsString: nil, productId: nil, localStatus: .none)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.restoreTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.restoreResponse.success) {
      $0.isPurchasing = false
      $0.subscriptionStatus = .none
      $0.errorMessage = LocalizedStrings.ProPlan.restoreNoPurchaseHistory
    }
  }

  @Test("다른 계정 소유 구독 구매 시 소유권 충돌 에러 메시지 표시")
  func purchaseTapped_alreadyOwnedByOther_showsOwnershipError() async {
    var state = ProPlan.Feature.State()
    state.selectedProductId = SubscriptionProductType.yearly.productId

    let store = makeStore(state: state) {
      $0.subscriptionClient.purchaseWithReceipt = { _ in
        PurchaseResult(jwsString: "mock-jws", localStatus: .subscribed(productType: .yearly, expirationDate: Date().addingTimeInterval(365 * 24 * 3600)))
      }
      $0.subscriptionClient.verifyPurchase = { _, _ in
        throw SubscriptionError.alreadyOwnedByOther
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.purchaseTapped)) {
      $0.isPurchasing = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.purchaseResponse.failure) {
      $0.isPurchasing = false
      $0.errorMessage = SubscriptionError.alreadyOwnedByOther.errorDescription
    }
  }

  @Test("onAppear 시 fetchStatus .none이면 기존 Pro 상태 해제")
  func onAppear_fetchStatusNone_clearsExistingProStatus() async {
    var state = ProPlan.Feature.State()
    state.subscriptionStatus = .subscribed(productType: .monthly, expirationDate: Date().addingTimeInterval(30 * 24 * 3600))

    let store = makeStore(state: state) {
      $0.subscriptionClient.fetchStatus = { .none }
      $0.subscriptionClient.unifiedStatusStream = { .finished }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingProducts = true
    }

    await store.receive(\.internal.productsResponse.success) {
      $0.isLoadingProducts = false
      $0.products = Self.mockProducts
      $0.selectedProductId = SubscriptionProductType.yearly.productId
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .none
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
    await store.finish()
  }

  @Test("onAppear 후 unifiedStatusStream revoked 수신 시 상태 갱신")
  func onAppear_unifiedStatusStreamRevoked_updatesStatus() async {
    let store = makeStore {
      $0.subscriptionClient.fetchStatus = { .lifetime }
      $0.subscriptionClient.unifiedStatusStream = {
        AsyncStream { continuation in
          continuation.yield(.revoked)
          continuation.finish()
        }
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoadingProducts = true
    }

    await store.receive(\.internal.productsResponse.success) {
      $0.isLoadingProducts = false
      $0.products = Self.mockProducts
      $0.selectedProductId = SubscriptionProductType.yearly.productId
    }

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .lifetime
    }

    await store.receive(\.delegate.subscriptionStatusChanged)

    await store.receive(\.internal.statusUpdated) {
      $0.subscriptionStatus = .revoked
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
    await store.finish()
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

  // MARK: - Internal Actions

  @Test("productsResponse success 시 연간 플랜 기본 선택")
  func productsResponse_success_selectsYearlyByDefault() async {
    let store = makeStore()

    await store.send(.internal(.productsResponse(.success(Self.mockProducts)))) {
      $0.isLoadingProducts = false
      $0.products = Self.mockProducts
      $0.selectedProductId = SubscriptionProductType.yearly.productId
    }
  }

  @Test("statusUpdated 시 상태 변경되면 delegate 전달")
  func statusUpdated_changedStatus_sendsDelegate() async {
    let store = makeStore()
    store.exhaustivity = .off(showSkippedAssertions: false)

    let expirationDate = Date().addingTimeInterval(30 * 24 * 3600)

    await store.send(.internal(.statusUpdated(.subscribed(productType: .monthly, expirationDate: expirationDate)))) {
      $0.subscriptionStatus = .subscribed(productType: .monthly, expirationDate: expirationDate)
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("statusUpdated 시 동일한 상태면 delegate 전달 안함")
  func statusUpdated_sameStatus_noDelegate() async {
    var state = ProPlan.Feature.State()
    state.subscriptionStatus = .none

    let store = makeStore(state: state)

    await store.send(.internal(.statusUpdated(.none)))
    // delegate 없음 - 상태 동일
  }

  @Test("statusUpdated 시 revoked로 변경되면 delegate 전달")
  func statusUpdated_revoked_sendsDelegate() async {
    var state = ProPlan.Feature.State()
    state.subscriptionStatus = .lifetime

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.internal(.statusUpdated(.revoked))) {
      $0.subscriptionStatus = .revoked
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
  }

  @Test("statusUpdated 시 gracePeriod로 변경되면 delegate 전달")
  func statusUpdated_gracePeriod_sendsDelegate() async {
    let expirationDate = Date().addingTimeInterval(15 * 24 * 3600)
    var state = ProPlan.Feature.State()
    state.subscriptionStatus = .subscribed(productType: .monthly, expirationDate: expirationDate)

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    let gracePeriodDate = Date().addingTimeInterval(7 * 24 * 3600)
    await store.send(.internal(.statusUpdated(.gracePeriod(expirationDate: gracePeriodDate)))) {
      $0.subscriptionStatus = .gracePeriod(expirationDate: gracePeriodDate)
    }

    await store.receive(\.delegate.subscriptionStatusChanged)
  }
}

// MARK: - Helpers

private extension ProPlanFeatureTests {
  static let mockProducts: [SubscriptionProduct] = [
    SubscriptionProduct(
      id: SubscriptionProductType.monthly.productId,
      type: .monthly,
      displayName: "월간 프로",
      description: "매월 자동 갱신",
      displayPrice: "₩3,900",
      price: 3900
    ),
    SubscriptionProduct(
      id: SubscriptionProductType.yearly.productId,
      type: .yearly,
      displayName: "연간 프로",
      description: "매년 자동 갱신 (월 ₩3,250)",
      displayPrice: "₩39,000",
      price: 39000
    ),
    SubscriptionProduct(
      id: SubscriptionProductType.lifetime.productId,
      type: .lifetime,
      displayName: "평생 프로",
      description: "한 번 결제, 영구 사용",
      displayPrice: "₩59,000",
      price: 59000
    )
  ]

  func makeStore(
    state: ProPlan.Feature.State = .init(),
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<ProPlan.Feature> {
    let mockProducts = Self.mockProducts
    return TestStore(initialState: state) {
      ProPlan.Feature()
    } withDependencies: {
      let expirationDate = Date().addingTimeInterval(365 * 24 * 3600)
      $0.subscriptionClient.fetchProducts = { mockProducts }
      $0.subscriptionClient.purchase = { _ in .subscribed(productType: .monthly, expirationDate: expirationDate) }
      $0.subscriptionClient.purchaseWithReceipt = { _ in
        PurchaseResult(jwsString: "mock-jws-token", localStatus: .subscribed(productType: .monthly, expirationDate: expirationDate))
      }
      $0.subscriptionClient.verifyPurchase = { _, _ in .subscribed(productType: .monthly, expirationDate: expirationDate) }
      $0.subscriptionClient.restore = { .none }
      $0.subscriptionClient.restoreWithReceipt = {
        RestoreResult(jwsString: nil, productId: nil, localStatus: .none)
      }
      $0.subscriptionClient.fetchStatus = { .none }
      $0.subscriptionClient.checkIntroOfferEligibility = { false }
      $0.subscriptionClient.unifiedStatusStream = { .finished }
      $0.subscriptionClient.fetchPurchaseDate = { nil }
      $0.analyticsClient.logEvent = { _, _ in }
      $0.authClient.currentUser = {
        FirebaseUserSnapshot(uid: "test-user", email: "test@example.com", displayName: "Test User", photoURL: nil)
      }
      $0.userSettingsClient.fetchSettings = { _ in .default }
      $0.userSettingsClient.hasProSettings = { _ in false }
      $0.userSettingsClient.initializeProDefaults = { _ in }
      $0.userSettingsClient.updateConflictDetectionThreshold = { _, _ in }
      $0.userSettingsClient.updateBriefingStyle = { _, _ in }
      $0.userSettingsClient.updateBriefingNotificationHour = { _, _ in }
      $0.userSettingsClient.updateAvailableTransports = { _, _ in }
      $0.hapticFeedback = .testValue
      configure(&$0)
    }
  }
}
