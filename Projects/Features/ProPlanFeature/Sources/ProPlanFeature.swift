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
      /// 온보딩 설정: 선호 교통수단
      public var onboardingTransport: PreferredTransport = .all
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
      case onboardingTransportChanged(PreferredTransport)
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

              // 구독 상태 스트림 구독 시작
              for await status in subscriptionClient.statusStream() {
                await send(.internal(.statusUpdated(status)))
              }
            }
            .cancellable(id: CancelID.statusStream, cancelInFlight: true)

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
            return .run { send in
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
            return .run { send in
              await hapticFeedback.medium()
              await send(.internal(.restoreResponse(
                Result { try await subscriptionClient.restore() }
              )))
            }

          case .dismissError:
            state.errorMessage = nil
            return .none

          case .dismissCelebration:
            state.showCelebration = false
            if state.subscriptionStatus.isPro {
              state.isSettingUpDefaults = true
              return .run { [userSettingsClient, authClient] send in
                do {
                  let userId = await authClient.currentUser()?.uid ?? ""
                  // 기존 설정 확인 — 재구독자는 이미 proSettings가 있음
                  let existingSettings = try await userSettingsClient.fetchSettings(userId)
                  if existingSettings.briefingNotificationHour != nil {
                    // 재구독자 — 기존 설정을 온보딩에 표시
                    await send(.internal(.proExistingSettingsLoaded(existingSettings)))
                  } else {
                    // 신규 Pro 사용자 — 기본값 초기화 후 온보딩 표시
                    try await userSettingsClient.initializeProDefaults(userId)
                    await send(.internal(.proDefaultsInitialized))
                  }
                } catch {
                  await send(.internal(.proDefaultsFailed))
                }
              }
            }
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
              do {
                let userId = await authClient.currentUser()?.uid ?? ""
                try await userSettingsClient.updateConflictDetectionThreshold(userId, state.onboardingConflictThreshold)
                try await userSettingsClient.updateBriefingStyle(userId, state.onboardingBriefingStyle)
                try await userSettingsClient.updateBriefingNotificationHour(userId, state.onboardingBriefingHour)
                try await userSettingsClient.updatePreferredTransport(userId, state.onboardingTransport)
              } catch {
                // 실패해도 dismiss는 진행
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

          case .onboardingTransportChanged(let transport):
            state.onboardingTransport = transport
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
            state.errorMessage = "상품 정보를 불러올 수 없습니다. 다시 시도해 주세요."
            return .run { _ in
              await hapticFeedback.error()
            }

          case .purchaseResponse(.success(let status)):
            state.isPurchasing = false
            state.subscriptionStatus = status

            if status.isPro {
              state.showCelebration = true
              return .run { send in
                await hapticFeedback.success()
                await send(.delegate(.subscriptionStatusChanged(status)))
              }
            }
            return .run { _ in
              await hapticFeedback.success()
            }

          case .purchaseResponse(.failure(let error)):
            state.isPurchasing = false
            // 사용자 취소는 에러가 아님
            if let subscriptionError = error as? SubscriptionError,
               subscriptionError == .purchaseCancelled {
              return .none
            }
            // 가족 구매 승인 대기
            if let subscriptionError = error as? SubscriptionError,
               subscriptionError == .purchasePending {
              state.errorMessage = "가족 구성원의 구매 승인이 필요합니다. 승인 후 자동으로 적용됩니다."
              return .none
            }
            state.errorMessage = "구매에 실패했습니다. 다시 시도해 주세요."
            return .run { _ in
              await hapticFeedback.error()
            }

          case .restoreResponse(.success(let status)):
            state.isPurchasing = false
            state.subscriptionStatus = status

            if status.isPro {
              return .run { send in
                await hapticFeedback.success()
                await send(.delegate(.subscriptionStatusChanged(status)))
              }
            }
            // 구매 내역 없음
            state.errorMessage = "이전에 구매한 내역이 없습니다."
            return .none

          case .restoreResponse(.failure(let error)):
            state.isPurchasing = false
            state.errorMessage = "복원에 실패했습니다. 이전에 구매한 내역이 없습니다."
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
            state.onboardingTransport = settings.preferredTransport
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
        "오류",
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.view(.dismissError)) } }
        ),
        actions: {
          Button("확인", role: .cancel) {
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
          Text("Pro 플랜 시작!")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)

          Text("모든 프리미엄 기능을 이용할 수 있습니다")
            .font(.body)
            .foregroundStyle(.white.opacity(0.8))
        }

        Button {
          onDismiss()
        } label: {
          Text("시작하기")
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

// MARK: - Pro Onboarding Setup View

/// Pro 가입 후 초기 설정 화면 (RootView overlay용)
private struct ProOnboardingSetupView: View {
  @Bindable private var store: StoreOf<ProPlan.Feature>

  init(store: StoreOf<ProPlan.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(spacing: 0) {
      // 상단 진행 인디케이터
      onboardingProgressBar

      // 스텝별 콘텐츠
      TabView(selection: Binding(
        get: { store.onboardingStep },
        set: { _ in }
      )) {
        onboardingStep0.tag(0)
        onboardingStep1.tag(1)
        onboardingStep2.tag(2)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .animation(.easeInOut(duration: 0.3), value: store.onboardingStep)

      // 하단 네비게이션 버튼
      onboardingBottomBar
    }
    .auroraBackground()
    .toolbar(.hidden, for: .navigationBar)
    .interactiveDismissDisabled()
  }

  @ViewBuilder
  private var onboardingProgressBar: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { step in
        Capsule()
          .fill(step <= store.onboardingStep
            ? LinearGradient(colors: [Color.pmaurora.purple, Color.pmaurora.pink], startPoint: .leading, endPoint: .trailing)
            : LinearGradient(colors: [Color.pmgray.n700.opacity(0.2), Color.pmgray.n700.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
          )
          .frame(height: 4)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private var onboardingStep0: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "calendar.badge.exclamationmark")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmwarning.n500)

          Text("일정 충돌 감지")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("약속을 잡을 때 겹치는 일정이 있으면\n미리 알려드려요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        if store.isSettingUpDefaults {
          ProgressView()
        } else {
          conflictPreviewCard

          VStack(alignment: .leading, spacing: 10) {
            Text("감지 기준 설정")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(Color.pmtext.primary)

            Text("약속 사이 여유 시간이 설정값보다 짧으면 충돌로 감지해요")
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)

            VStack(spacing: 0) {
              ForEach([(0, "겹칠 때만", "시간이 겹치는 약속만 감지"), (15, "15분", "15분 이내 간격도 감지"), (30, "30분", "30분 이내 간격도 감지"), (60, "1시간", "1시간 이내 간격도 감지")], id: \.0) { value, label, desc in
                Button {
                  store.send(.view(.onboardingConflictChanged(value)))
                } label: {
                  HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                      Text(label)
                        .font(.body)
                        .foregroundStyle(Color.pmtext.primary)
                      Text(desc)
                        .font(.caption)
                        .foregroundStyle(Color.pmtext.secondary)
                    }

                    Spacer()

                    if store.onboardingConflictThreshold == value {
                      Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pmindigo.n500)
                    }
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 14)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if value != 60 {
                  Divider()
                    .padding(.leading, 16)
                }
              }
            }
            .adaptiveGlassCard()
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  @ViewBuilder
  private var conflictPreviewCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmwarning.n500)
        Text("일정 충돌이 감지되었어요")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("팀 회의")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text("오후 1:00 - 2:00")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pmwarning.n500.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

        Image(systemName: "arrow.left.arrow.right")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)

        VStack(alignment: .leading, spacing: 4) {
          Text("점심 약속")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
          Text("오후 1:30 - 3:00")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pmindigo.n500.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }

      HStack(spacing: 4) {
        Image(systemName: "clock.fill")
          .font(.system(size: 11))
        Text("30분 겹침")
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundStyle(Color.pmwarning.n500)
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  @ViewBuilder
  private var onboardingStep1: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "bell.badge.waveform")
            .font(.system(size: 44))
            .foregroundStyle(Color.pmaurora.purple)

          Text("스마트 브리핑")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("매일 아침, 오늘의 약속 정보를\n한눈에 브리핑해드려요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 20)

        briefingPreviewCard

        VStack(alignment: .leading, spacing: 10) {
          Text("브리핑 스타일")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          VStack(spacing: 0) {
            ForEach(BriefingStyle.allCases, id: \.rawValue) { style in
              Button {
                store.send(.view(.onboardingStyleChanged(style)))
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: briefingStyleIcon(style))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 20)

                  VStack(alignment: .leading, spacing: 2) {
                    Text(style.displayName)
                      .font(.body)
                      .foregroundStyle(Color.pmtext.primary)
                    Text(style.description)
                      .font(.caption)
                      .foregroundStyle(Color.pmtext.secondary)
                  }

                  Spacer()

                  if store.onboardingBriefingStyle == style {
                    Image(systemName: "checkmark")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundStyle(Color.pmindigo.n500)
                  }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)

              if style != BriefingStyle.allCases.last {
                Divider()
                  .padding(.leading, 48)
              }
            }
          }
          .adaptiveGlassCard()
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("알림 및 이동수단")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)

          VStack(spacing: 0) {
            HStack {
              HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(Color.pmindigo.n500)
                Text("브리핑 알림")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
              }

              Spacer()

              Menu {
                ForEach(5..<24, id: \.self) { hour in
                  Button {
                    store.send(.view(.onboardingHourChanged(hour)))
                  } label: {
                    HStack {
                      Text(hourLabel(hour))
                      if store.onboardingBriefingHour == hour {
                        Image(systemName: "checkmark")
                      }
                    }
                  }
                }
              } label: {
                HStack(spacing: 4) {
                  Text(hourLabel(store.onboardingBriefingHour))
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pmindigo.n500)
                  Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.pmtext.secondary)
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                Image(systemName: "car.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(Color.pmindigo.n500)
                Text("선호 교통수단")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)
              }
              .padding(.horizontal, 16)
              .padding(.top, 14)

              ForEach(PreferredTransport.allCases, id: \.self) { transport in
                Button {
                  store.send(.view(.onboardingTransportChanged(transport)))
                } label: {
                  HStack(spacing: 12) {
                    Image(systemName: transport.iconName)
                      .font(.system(size: 14))
                      .foregroundStyle(Color.pmindigo.n500)
                      .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                      Text(transport.displayName)
                        .font(.body)
                        .foregroundStyle(Color.pmtext.primary)
                      Text(transport.description)
                        .font(.caption)
                        .foregroundStyle(Color.pmtext.secondary)
                    }

                    Spacer()

                    if store.onboardingTransport == transport {
                      Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pmindigo.n500)
                    }
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
              .padding(.bottom, 6)
            }
          }
          .adaptiveGlassCard()
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  @ViewBuilder
  private var briefingPreviewCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmaurora.purple)
        Text("오늘의 브리핑")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
        Text("오전 8시")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("오후 2시에 강남역 카페에서 약속이 있어요")
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.primary)

        HStack(spacing: 12) {
          Label("22° 맑음", systemImage: "sun.max.fill")
            .font(.system(size: 11))
            .symbolRenderingMode(.multicolor)
          Label("대중교통 35분", systemImage: "bus.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
          Label("1:20 출발", systemImage: "clock.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmaurora.purple)
        }
      }
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  private func briefingStyleIcon(_ style: BriefingStyle) -> String {
    switch style {
    case .friendly: return "face.smiling"
    case .humorous: return "theatermasks"
    case .concise: return "text.alignleft"
    case .motivational: return "flame"
    case .calm: return "leaf"
    }
  }

  @ViewBuilder
  private var onboardingStep2: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 56))
            .foregroundStyle(
              LinearGradient(
                colors: [Color.pmaurora.purple, Color.pmaurora.pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )

          Text("설정이 완료되었어요!")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(Color.pmtext.primary)

          Text("설정은 언제든 변경할 수 있어요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(.top, 40)

        VStack(spacing: 0) {
          summaryRow(
            icon: "calendar.badge.exclamationmark",
            iconColor: Color.pmwarning.n500,
            title: "일정 충돌 감지",
            value: store.onboardingConflictThreshold == 0 ? "겹칠 때만" : "\(store.onboardingConflictThreshold)분"
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: briefingStyleIcon(store.onboardingBriefingStyle),
            iconColor: Color.pmindigo.n500,
            title: "브리핑 스타일",
            value: store.onboardingBriefingStyle.displayName
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: "bell.fill",
            iconColor: Color.pmaurora.purple,
            title: "브리핑 알림",
            value: hourLabel(store.onboardingBriefingHour)
          )
          Divider().padding(.leading, 48)
          summaryRow(
            icon: store.onboardingTransport.iconName,
            iconColor: Color.pmindigo.n500,
            title: "선호 교통수단",
            value: store.onboardingTransport.displayName
          )
        }
        .adaptiveGlassCard()
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 100)
    }
  }

  private func summaryRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(iconColor, in: Circle())

      Text(title)
        .font(.body)
        .foregroundStyle(Color.pmtext.primary)

      Spacer()

      Text(value)
        .font(.body)
        .foregroundStyle(Color.pmindigo.n500)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private var onboardingBottomBar: some View {
    HStack(spacing: 12) {
      if store.onboardingStep > 0 {
        Button {
          store.send(.view(.onboardingPreviousStep))
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmtext.primary)
            .frame(width: 52, height: 52)
            .background(Color.pmgray.n700.opacity(0.15), in: Circle())
            .contentShape(Circle())
        }
      }

      Button {
        if store.onboardingStep < 2 {
          store.send(.view(.onboardingNextStep))
        } else {
          store.send(.view(.proOnboardingCompleted))
        }
      } label: {
        HStack {
          Text(store.onboardingStep == 2 ? "시작하기" : "다음")
            .font(.headline)
            .foregroundStyle(.white)

          Spacer()

          Image(systemName: store.onboardingStep == 2 ? "checkmark" : "arrow.right")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
          LinearGradient(
            colors: [Color.pmaurora.purple, Color.pmaurora.pink],
            startPoint: .leading,
            endPoint: .trailing
          ),
          in: RoundedRectangle(cornerRadius: 16)
        )
        .contentShape(Rectangle())
      }
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 16)
    .padding(.top, 8)
    .background(
      LinearGradient(
        stops: [
          .init(color: .clear, location: 0),
          .init(color: Color(.systemBackground).opacity(0.8), location: 0.3),
          .init(color: Color(.systemBackground), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 100)
      .frame(maxHeight: .infinity, alignment: .bottom)
      .ignoresSafeArea()
    )
  }

  private func hourLabel(_ hour: Int) -> String {
    let period = hour < 12 ? "오전" : "오후"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    return "\(period) \(displayHour)시"
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
