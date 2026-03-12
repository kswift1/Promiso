// MARK: - ProPlanFeature.swift
// TCA 1.22.2를 사용한 ProPlan Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import Lottie
import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - Feature Namespace

/// ProPlan Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum ProPlan {}

// MARK: - Feature Implementation

extension ProPlan {

  // MARK: - Reducer

  /// ProPlan Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {

    // MARK: - Cancel IDs

    private enum CancelID: Hashable {
      case statusStream
    }

    // MARK: - Dependencies

    @Dependency(\.subscriptionClient) private var subscriptionClient
    @Dependency(\.hapticFeedback) private var hapticFeedback
    @Dependency(\.userSettingsClient) private var userSettingsClient
    @Dependency(\.authClient) private var authClient
    @Dependency(\.analyticsClient) private var analyticsClient

    /// Reducer를 위한 기본 initializer
    public init() {}

    // MARK: - State

    /// ProPlan Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    ///
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      /// 구독 상품 목록
      public var products: [SubscriptionProduct] = []
      /// 현재 구독 상태
      public var subscriptionStatus: SubscriptionStatus = .none
      /// 상품 로딩 중 여부
      public var isLoadingProducts: Bool = false
      /// 구매 진행 중 여부
      public var isPurchasing: Bool = false
      /// 선택된 상품 ID
      public var selectedProductId: String?
      /// 에러 메시지
      public var errorMessage: String?
      /// 무료 체험 대상 여부
      public var isEligibleForIntroOffer: Bool = false
      /// 구매 성공 축하 화면 표시 여부
      public var showCelebration: Bool = false
      /// 최초 구매일
      public var purchaseDate: Date? = nil
      /// 요금제 페이지 표시 여부
      public var showPricing: Bool = false
      /// Pro 온보딩 설정 화면 표시 여부
      public var showProOnboarding: Bool = false
      /// Pro 기본값 설정 중 여부
      public var isSettingUpDefaults: Bool = false
      /// 온보딩 설정: 컨플릭트 여유값 (분)
      public var onboardingConflictThreshold: Int = 0
      /// 온보딩 설정: 브리핑 스타일
      public var onboardingBriefingStyle: BriefingStyle = .friendly
      /// 온보딩 설정: 브리핑 알림 시간
      public var onboardingBriefingHour: Int = 8
      /// 온보딩 설정: 이용 가능 교통수단
      public var onboardingTransports: Set<AvailableTransport> = [.transit, .car]
      /// 온보딩 현재 스텝 (0: 충돌감지, 1: 브리핑, 2: 완료)
      public var onboardingStep: Int = 0

      /// State를 위한 기본 initializer
      public init(
        products: [SubscriptionProduct] = [],
        subscriptionStatus: SubscriptionStatus = .none,
        isLoadingProducts: Bool = false,
        isPurchasing: Bool = false,
        selectedProductId: String? = nil,
        errorMessage: String? = nil,
        isEligibleForIntroOffer: Bool = false,
        purchaseDate: Date? = nil
      ) {
        self.products = products
        self.subscriptionStatus = subscriptionStatus
        self.isLoadingProducts = isLoadingProducts
        self.isPurchasing = isPurchasing
        self.selectedProductId = selectedProductId
        self.errorMessage = errorMessage
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
        self.purchaseDate = purchaseDate
      }
    }

    // MARK: - Action

    /// ProPlan Feature 내에서 발생할 수 있는 모든 가능한 action
    /// ViewAction / InternalAction / DelegateAction으로 분리하여 관심사 분리
    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
    }

    /// View에서 발생하는 사용자 인터랙션 액션
    @CasePathable
    public enum ViewAction: Equatable, Sendable {
      /// View가 처음 나타날 때 트리거
      case onAppear
      /// Paywall이 화면에 표시됨
      case paywallAppeared
      /// Paywall이 화면에서 사라짐
      case paywallDisappeared
      /// 상품 선택
      case productSelected(String)
      /// 구매 버튼 탭
      case purchaseTapped
      /// 구매 복원 버튼 탭
      case restoreTapped
      /// 에러 메시지 닫기
      case dismissError
      /// 축하 화면 닫기
      case dismissCelebration
      /// 요금제 보기 탭
      case showPricingTapped
      /// 요금제에서 뒤로가기
      case backToBenefitsTapped
      /// Pro 온보딩에서 설정 완료
      case proOnboardingCompleted
      /// 온보딩 컨플릭트 임계값 변경
      case onboardingConflictChanged(Int)
      /// 온보딩 브리핑 스타일 변경
      case onboardingStyleChanged(BriefingStyle)
      /// 온보딩 브리핑 시간 변경
      case onboardingHourChanged(Int)
      /// 온보딩 교통수단 변경
      case onboardingTransportToggled(AvailableTransport)
      /// 온보딩 다음 스텝
      case onboardingNextStep
      /// 온보딩 이전 스텝
      case onboardingPreviousStep
    }

    /// 내부 비즈니스 로직 처리 결과 액션
    @CasePathable
    public enum InternalAction: Equatable, Sendable {
      /// 상품 목록 조회 결과
      case productsResponse(Result<[SubscriptionProduct], Error>)
      /// 구매 결과
      case purchaseResponse(Result<SubscriptionStatus, Error>)
      /// 복원 결과
      case restoreResponse(Result<SubscriptionStatus, Error>)
      /// 구독 상태 업데이트
      case statusUpdated(SubscriptionStatus)
      /// 무료 체험 대상 여부 결과
      case introOfferEligibilityResult(Bool)
      /// 최초 구매일 조회 결과
      case purchaseDateLoaded(Date?)
      /// Pro 기본값 설정 완료 (신규)
      case proDefaultsInitialized
      /// Pro 기존 설정 로드 완료 (재구독자)
      case proExistingSettingsLoaded(UserSettings)
      /// Pro 기본값 설정 실패
      case proDefaultsFailed
    }

    /// 부모 Feature에게 전달할 delegate 액션
    @CasePathable
    public enum DelegateAction: Equatable, Sendable {
      /// 구독 상태 변경됨
      case subscriptionStatusChanged(SubscriptionStatus)
      /// 시트 dismiss 요청 (구매 완료 후 축하 화면에서 "시작하기" 탭)
      case dismissRequested
    }

    // MARK: - Reducer Body

    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      let prepareProOnboarding = { [authClient, userSettingsClient] in
        Effect<Action>.run { send in
          do {
            guard let userId = await authClient.currentUser()?.uid else {
              await send(.internal(.proDefaultsFailed))
              return
            }

            if try await userSettingsClient.hasProSettings(userId) {
              let existingSettings = try await userSettingsClient.fetchSettings(userId)
              await send(.internal(.proExistingSettingsLoaded(existingSettings)))
            } else {
              try await userSettingsClient.initializeProDefaults(userId)
              await send(.internal(.proDefaultsInitialized))
            }
          } catch {
            print("[ProPlan] Pro defaults initialization failed: \(error)")
            await send(.internal(.proDefaultsFailed))
          }
        }
      }

      Reduce { state, action in
        switch action {

        // MARK: - View Actions
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 상품 목록 조회 + 구독 상태 조회 + 무료 체험 대상 확인 (병렬)
            state.isLoadingProducts = true
            return .run { [subscriptionClient] send in
              // 병렬 조회
              async let productsResult = Result { try await subscriptionClient.fetchProducts() }
              async let statusResult = Result { try await subscriptionClient.fetchStatus() }
              async let eligibility = subscriptionClient.checkIntroOfferEligibility()
              async let purchaseDate = subscriptionClient.fetchPurchaseDate()

              // 상품 목록 결과 전송
              await send(.internal(.productsResponse(await productsResult)))

              // 구독 상태 결과는 statusUpdated로 전송
              if case .success(let status) = await statusResult {
                await send(.internal(.statusUpdated(status)))
              }

              // 무료 체험 대상 여부 전송
              await send(.internal(.introOfferEligibilityResult(await eligibility)))

              // 최초 구매일 전송
              await send(.internal(.purchaseDateLoaded(await purchaseDate)))

              // 구독 상태 스트림 구독 시작 (Firestore 서버 우선)
              for await status in subscriptionClient.unifiedStatusStream() {
                await send(.internal(.statusUpdated(status)))
              }
            }
            .cancellable(id: CancelID.statusStream, cancelInFlight: true)

          case .paywallAppeared:
            let hasIntroOffer = state.isEligibleForIntroOffer
            return .run { [analyticsClient, hasIntroOffer] _ in
              analyticsClient.log(.paywallOpen(hasIntroOffer: hasIntroOffer))
            }

          case .paywallDisappeared:
            return .run { [analyticsClient] _ in
              analyticsClient.log(.paywallClose)
            }

          case .productSelected(let productId):
            state.selectedProductId = productId
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .purchaseTapped:
            guard let productId = state.selectedProductId else {
              return .none
            }
            state.isPurchasing = true
            state.errorMessage = nil
            return .run { [analyticsClient] send in
              analyticsClient.log(.paywallPurchase(productID: productId))
              await hapticFeedback.medium()
              do {
                // 1. StoreKit 구매 + JWS 토큰 획득
                let result = try await subscriptionClient.purchaseWithReceipt(productId)
                // 2. 서버에 검증 요청
                let verifiedStatus = try await subscriptionClient.verifyPurchase(result.jwsString, productId)
                await send(.internal(.purchaseResponse(.success(verifiedStatus))))
              } catch {
                await send(.internal(.purchaseResponse(.failure(error))))
              }
            }

          case .restoreTapped:
            state.isPurchasing = true
            state.errorMessage = nil
            return .run { [subscriptionClient, analyticsClient] send in
              analyticsClient.log(.paywallRestore)
              await hapticFeedback.medium()
              do {
                // 1. StoreKit 복원 + JWS 토큰 추출
                let result = try await subscriptionClient.restoreWithReceipt()

                if result.localStatus.isPro {
                  guard let jwsString = result.jwsString, let productId = result.productId else {
                    throw SubscriptionError.verificationFailed
                  }

                  // 2. 서버에 검증 요청 (Firestore 동기화)
                  let verifiedStatus = try await subscriptionClient.verifyPurchase(jwsString, productId)
                  await send(.internal(.restoreResponse(.success(verifiedStatus))))
                } else {
                  await send(.internal(.restoreResponse(.success(result.localStatus))))
                }
              } catch {
                await send(.internal(.restoreResponse(.failure(error))))
              }
            }

          case .dismissError:
            state.errorMessage = nil
            return .none

          case .dismissCelebration:
            state.showCelebration = false
            return .none

          case .showPricingTapped:
            state.showPricing = true
            return .run { _ in await hapticFeedback.selection() }

          case .backToBenefitsTapped:
            state.showPricing = false
            return .none

          case .proOnboardingCompleted:
            state.showProOnboarding = false
            return .run { [state, userSettingsClient, authClient] send in
              if let userId = await authClient.currentUser()?.uid {
                do {
                  async let t1: Void = userSettingsClient.updateConflictDetectionThreshold(userId, state.onboardingConflictThreshold)
                  async let t2: Void = userSettingsClient.updateBriefingStyle(userId, state.onboardingBriefingStyle)
                  async let t3: Void = userSettingsClient.updateBriefingNotificationHour(userId, state.onboardingBriefingHour)
                  async let t4: Void = userSettingsClient.updateAvailableTransports(userId, state.onboardingTransports)
                  _ = try await (t1, t2, t3, t4)
                } catch {
                  print("[ProPlan] Onboarding settings save failed: \(error)")
                }
              }
              await send(.delegate(.dismissRequested))
            }

          case .onboardingConflictChanged(let threshold):
            state.onboardingConflictThreshold = threshold
            return .none

          case .onboardingStyleChanged(let style):
            state.onboardingBriefingStyle = style
            return .none

          case .onboardingHourChanged(let hour):
            state.onboardingBriefingHour = hour
            return .none

          case .onboardingTransportToggled(let transport):
            if state.onboardingTransports.contains(transport) {
              // 최소 1개는 유지
              if state.onboardingTransports.count > 1 {
                state.onboardingTransports.remove(transport)
              }
            } else {
              state.onboardingTransports.insert(transport)
            }
            return .none

          case .onboardingNextStep:
            if state.onboardingStep < 2 {
              state.onboardingStep += 1
            }
            return .run { _ in await hapticFeedback.selection() }

          case .onboardingPreviousStep:
            if state.onboardingStep > 0 {
              state.onboardingStep -= 1
            }
            return .run { _ in await hapticFeedback.selection() }
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .productsResponse(.success(let products)):
            state.isLoadingProducts = false
            state.products = products
            // 기본 선택: 연간 플랜
            state.selectedProductId = products.first { $0.type == .yearly }?.id
            return .none

          case .productsResponse(.failure(let error)):
            state.isLoadingProducts = false
            if let subscriptionError = error as? SubscriptionError,
               subscriptionError == .productNotFound {
              state.errorMessage = LocalizedStrings.Error.subscriptionProductNotFound
            } else {
              state.errorMessage = LocalizedStrings.ProPlan.productsLoadFailed
            }
            return .run { _ in
              await hapticFeedback.error()
            }

          case .purchaseResponse(.success(let status)):
            state.isPurchasing = false
            state.subscriptionStatus = status

            if status.isPro {
              state.showCelebration = true
              state.isSettingUpDefaults = true
              return .concatenate(
                .run { send in
                  await hapticFeedback.success()
                  await send(.delegate(.subscriptionStatusChanged(status)))
                },
                prepareProOnboarding()
              )
            }
            return .run { _ in
              await hapticFeedback.success()
            }

          case .purchaseResponse(.failure(let error)):
            state.isPurchasing = false
            if let subscriptionError = error as? SubscriptionError {
              switch subscriptionError {
              case .purchaseCancelled:
                return .none
              case .purchasePending:
                state.errorMessage = LocalizedStrings.Error.subscriptionPurchasePending
                return .none
              case .alreadyOwnedByOther:
                state.errorMessage = subscriptionError.errorDescription
                return .none
              case .productNotFound, .verificationFailed, .unknown:
                state.errorMessage = subscriptionError.errorDescription ?? LocalizedStrings.ProPlan.purchaseFailed
              }
            } else {
              state.errorMessage = LocalizedStrings.ProPlan.purchaseFailed
            }
            return .run { _ in
              await hapticFeedback.error()
            }

          case .restoreResponse(.success(let status)):
            state.isPurchasing = false
            state.subscriptionStatus = status

            if status.isPro {
              state.isSettingUpDefaults = true
              return .concatenate(
                .run { send in
                  await hapticFeedback.success()
                  await send(.delegate(.subscriptionStatusChanged(status)))
                },
                prepareProOnboarding()
              )
            } else {
              state.errorMessage = LocalizedStrings.ProPlan.restoreNoPurchaseHistory
              return .none
            }

          case .restoreResponse(.failure(let error)):
            state.isPurchasing = false
            if let subscriptionError = error as? SubscriptionError {
              state.errorMessage = subscriptionError.errorDescription ?? LocalizedStrings.ProPlan.restoreFailed
            } else {
              state.errorMessage = LocalizedStrings.ProPlan.restoreFailed
            }
            return .run { _ in
              await hapticFeedback.error()
            }

          case .statusUpdated(let status):
            let previousStatus = state.subscriptionStatus
            state.subscriptionStatus = status
            if previousStatus != status {
              return .send(.delegate(.subscriptionStatusChanged(status)))
            }
            return .none

          case .introOfferEligibilityResult(let isEligible):
            state.isEligibleForIntroOffer = isEligible
            return .none

          case .purchaseDateLoaded(let date):
            state.purchaseDate = date
            return .none

          case .proDefaultsInitialized:
            state.isSettingUpDefaults = false
            state.showProOnboarding = true  // 기본값 설정 완료 후 온보딩 표시
            return .none

          case .proDefaultsFailed:
            state.isSettingUpDefaults = false
            state.showProOnboarding = true  // 실패해도 온보딩은 표시
            return .none

          case .proExistingSettingsLoaded(let settings):
            state.isSettingUpDefaults = false
            state.onboardingConflictThreshold = settings.conflictDetectionThreshold
            state.onboardingBriefingStyle = settings.briefingStyle
            state.onboardingBriefingHour = settings.briefingNotificationHour ?? 8
            state.onboardingTransports = settings.availableTransports
            state.showProOnboarding = true
            return .none
          }

        // MARK: - Delegate Actions
        case .delegate:
          // Delegate 액션은 부모에서 처리하므로 여기서는 pass-through
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  /// ProPlan Feature를 위한 Main view implementation
  /// 구독 상태에 따라 Paywall 또는 관리 화면을 표시
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      Group {
        if store.subscriptionStatus.isActive {
          ProPlanManageView(store: store)
        } else {
          PaywallView(store: store)
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        LocalizedStrings.Common.error,
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.view(.dismissError)) } }
        ),
        actions: {
          Button(LocalizedStrings.Common.confirm, role: .cancel) {
            store.send(.view(.dismissError))
          }
        },
        message: {
          if let errorMessage = store.errorMessage {
            Text(errorMessage)
          }
        }
      )
      .overlay {
        if store.showCelebration {
          ProCelebrationView {
            store.send(.view(.dismissCelebration))
          }
        } else if store.showProOnboarding {
          ProOnboardingSetupView(store: store)
        }
      }
    }
  }
}

// MARK: - Celebration View

/// 구매 성공 시 표시되는 축하 화면
private struct ProCelebrationView: View {
  let onDismiss: () -> Void
  @State private var showContent = false

  var body: some View {
    ZStack {
      Color.black.opacity(0.6)
        .ignoresSafeArea()
        .onTapGesture { onDismiss() }

      VStack(spacing: 24) {
        LottieView(animation: LottieAsset.fanfare.animation)
          .playing(loopMode: .playOnce)
          .frame(width: 200, height: 200)

      VStack(spacing: 8) {
          Text(LocalizedStrings.ProPlan.celebrationTitle)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)

          Text(LocalizedStrings.ProPlan.celebrationSubtitle)
            .font(.body)
            .foregroundStyle(.white.opacity(0.8))
        }

        Button {
          onDismiss()
        } label: {
          Text(LocalizedStrings.ProPlan.startButton)
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 40)
      }
      .scaleEffect(showContent ? 1 : 0.8)
      .opacity(showContent ? 1 : 0)
    }
    .onAppear {
      withAnimation(.spring(duration: 0.5)) {
        showContent = true
      }
    }
  }
}

// MARK: - Error Conformance

extension ProPlan.Feature.InternalAction {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.productsResponse(.success(let lhsProducts)), .productsResponse(.success(let rhsProducts))):
      return lhsProducts == rhsProducts
    case (.productsResponse(.failure), .productsResponse(.failure)):
      return true
    case (.purchaseResponse(.success(let lhsStatus)), .purchaseResponse(.success(let rhsStatus))):
      return lhsStatus == rhsStatus
    case (.purchaseResponse(.failure), .purchaseResponse(.failure)):
      return true
    case (.restoreResponse(.success(let lhsStatus)), .restoreResponse(.success(let rhsStatus))):
      return lhsStatus == rhsStatus
    case (.restoreResponse(.failure), .restoreResponse(.failure)):
      return true
    case (.statusUpdated(let lhsStatus), .statusUpdated(let rhsStatus)):
      return lhsStatus == rhsStatus
    case (.introOfferEligibilityResult(let lhs), .introOfferEligibilityResult(let rhs)):
      return lhs == rhs
    case (.purchaseDateLoaded(let lhs), .purchaseDateLoaded(let rhs)):
      return lhs == rhs
    case (.proDefaultsInitialized, .proDefaultsInitialized):
      return true
    case (.proDefaultsFailed, .proDefaultsFailed):
      return true
    case (.proExistingSettingsLoaded(let lhs), .proExistingSettingsLoaded(let rhs)):
      return lhs == rhs
    default:
      return false
    }
  }
}
