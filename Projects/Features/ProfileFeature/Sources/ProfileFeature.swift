// MARK: - ProfileFeature.swift
// TCA 1.22.2를 사용한 Profile Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import SwiftUI

// MARK: - Feature Namespace

/// Profile Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum Profile {}

// MARK: - Feature Implementation

extension Profile {

  // MARK: - Reducer

  /// Profile Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.authClient) private var authClient
    @Dependency(\.hapticFeedback) private var hapticFeedback

    /// Reducer를 위한 기본 initializer
    public init() {}

    // MARK: - State

    /// Profile Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    ///
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      /// 현재 로그인한 사용자 정보
      public var currentUser: UserPrivateModel
      /// 로그아웃 확인 Alert 표시 여부
      public var showLogoutAlert: Bool
      /// 로딩 상태 (로그아웃 진행 중 등)
      public var isLoading: Bool

      /// State를 위한 기본 initializer
      public init(
        currentUser: UserPrivateModel = .exampleUser,
        showLogoutAlert: Bool = false,
        isLoading: Bool = false
      ) {
        self.currentUser = currentUser
        self.showLogoutAlert = showLogoutAlert
        self.isLoading = isLoading
      }
    }

    // MARK: - Action

    /// Profile Feature 내에서 발생할 수 있는 모든 가능한 action
    /// ViewAction / InternalAction / DelegateAction으로 분리하여 관심사 분리
    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    /// View에서 발생하는 사용자 인터랙션 액션
    public enum View: Sendable {
      /// View가 처음 나타날 때 트리거
      case onAppear
      /// 로그아웃 버튼 탭
      case logoutTapped
      /// 로그아웃 확인 (Alert에서 확인 버튼)
      case logoutConfirmed
      /// 로그아웃 취소 (Alert에서 취소 버튼)
      case logoutCancelled
      /// 알림 설정 탭
      case notificationSettingsTapped
      /// 개인정보처리방침 탭
      case privacyPolicyTapped
      /// 이용약관 탭
      case termsOfServiceTapped
      /// 앱 정보 탭
      case appInfoTapped
    }

    /// 내부 비즈니스 로직 처리 결과 액션
    public enum Internal: Sendable {
      /// 로그아웃 완료
      case logoutCompleted
      /// 로그아웃 실패
      case logoutFailed(AuthClientError)
    }

    /// 부모 Feature에게 전달할 delegate 액션
    public enum Delegate: Equatable {
      /// 로그아웃 완료됨 (부모에서 화면 전환 처리)
      case didLogout
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
            // View가 나타날 때 필요한 초기화 로직
            return .none

          case .logoutTapped:
            // 로그아웃 확인 Alert 표시
            state.showLogoutAlert = true
            return .run { _ in
              await hapticFeedback.medium()
            }

          case .logoutConfirmed:
            // 로그아웃 확인 - 실제 로그아웃 수행
            state.showLogoutAlert = false
            state.isLoading = true
            return .run { send in
              await hapticFeedback.heavy()
              do {
                try await authClient.logout()
                await send(.internal(.logoutCompleted))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.logoutFailed(clientError)))
              }
            }

          case .logoutCancelled:
            // 로그아웃 취소
            state.showLogoutAlert = false
            return .run { _ in
              await hapticFeedback.light()
            }

          case .notificationSettingsTapped:
            // 알림 설정 화면으로 이동 (향후 구현)
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .privacyPolicyTapped:
            // 개인정보처리방침 표시 (향후 구현)
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .termsOfServiceTapped:
            // 이용약관 표시 (향후 구현)
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .appInfoTapped:
            // 앱 정보 표시 (향후 구현)
            return .run { _ in
              await hapticFeedback.selection()
            }
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .logoutCompleted:
            state.isLoading = false
            return .run { send in
              await hapticFeedback.success()
              await send(.delegate(.didLogout))
            }

          case .logoutFailed(let error):
            state.isLoading = false
            // TODO: 에러 메시지 표시 로직 추가 가능
            _ = error
            return .run { _ in
              await hapticFeedback.error()
            }
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

  /// Profile Feature를 위한 Main view implementation
  /// 적절한 accessibility와 state handling을 통해 SwiftUI best practice를 따름
  /// Note: 실제 UI 구현은 별도의 View 에이전트가 담당
  public struct RootView: View {
    /// Feature의 state와 action dispatch 기능을 포함하는 Store
    @Bindable private var store: StoreOf<Feature>

    /// Designated initializer
    /// - Parameter store: state management와 action dispatch를 위한 TCA store
    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Body

    public var body: some View {
      // Placeholder - UI 구현은 별도 에이전트가 담당
      Text("Profile View Placeholder")
        .onAppear {
          store.send(.view(.onAppear))
        }
    }
  }
}

// MARK: - Error Types

/// Profile Feature 관련 에러 타입
public enum ProfileError: Error, Equatable, LocalizedError {
  case logoutFailed
  case userNotFound
  case unknown

  public var errorDescription: String? {
    switch self {
    case .logoutFailed:
      return "로그아웃에 실패했습니다. 다시 시도해주세요."
    case .userNotFound:
      return "사용자 정보를 찾을 수 없습니다."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}