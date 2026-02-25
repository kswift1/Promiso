// MARK: - ProPlanFeature.swift
// TCA 1.22.2를 사용한 ProPlan Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import PromisoShared
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
      /// 구독 관리 화면 표시 여부
      public var showManageView: Bool = false

      /// State를 위한 기본 initializer
      public init(
        products: [SubscriptionProduct] = [],
        subscriptionStatus: SubscriptionStatus = .none,
        isLoadingProducts: Bool = false,
        isPurchasing: Bool = false,
        selectedProductId: String? = nil,
        errorMessage: String? = nil,
        showManageView: Bool = false
      ) {
        self.products = products
        self.subscriptionStatus = subscriptionStatus
        self.isLoadingProducts = isLoadingProducts
        self.isPurchasing = isPurchasing
        self.selectedProductId = selectedProductId
        self.errorMessage = errorMessage
        self.showManageView = showManageView
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
      /// 구독 관리 버튼 탭
      case manageSubscriptionTapped
      /// 구독 관리 화면 닫기
      case dismissManageView
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
    }

    /// 부모 Feature에게 전달할 delegate 액션
    @CasePathable
    public enum DelegateAction: Equatable, Sendable {
      /// 구독 상태 변경됨
      case subscriptionStatusChanged(SubscriptionStatus)
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
            // 상품 목록 조회 + 구독 상태 조회 (병렬)
            state.isLoadingProducts = true
            return .run { send in
              // 병렬 조회
              async let productsResult = Result { try await subscriptionClient.fetchProducts() }
              async let statusResult = Result { try await subscriptionClient.fetchStatus() }

              // 상품 목록 결과 전송
              await send(.internal(.productsResponse(await productsResult)))

              // 구독 상태 결과는 statusUpdated로 전송
              if case .success(let status) = await statusResult {
                await send(.internal(.statusUpdated(status)))
              }

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

          case .manageSubscriptionTapped:
            state.showManageView = true
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .dismissManageView:
            state.showManageView = false
            return .none
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
      .sheet(isPresented: Binding(
        get: { store.showManageView },
        set: { if !$0 { store.send(.view(.dismissManageView)) } }
      )) {
        ProPlanManageView(store: store)
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
    default:
      return false
    }
  }
}
