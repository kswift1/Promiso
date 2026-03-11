// MARK: - ProfileFeature.swift
// TCA 1.22.2를 사용한 Profile Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import PromisoShared
import ProPlanFeature
import SwiftUI

// MARK: - Feature Namespace

/// Profile Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum Settings {}

// MARK: - Feature Implementation

extension Settings {

  // MARK: - Reducer

  /// Profile Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {

    // MARK: - Cancel IDs

    private enum CancelID: Hashable {
      case nicknameCheck
    }

    // MARK: - Dependencies

    @Dependency(\.authClient) private var authClient
    @Dependency(\.userProfileClient) private var userProfileClient
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
      /// 현재 로그인한 사용자 정보 (RootTab과 참조 공유)
      @Shared public var currentUser: UserPrivateModel
      /// 로그아웃 확인 Alert 표시 여부
      public var showLogoutAlert: Bool
      /// 로딩 상태 (로그아웃 진행 중 등)
      public var isLoading: Bool

      // MARK: - Profile Edit State

      /// 프로필 편집 화면 표시 여부
      public var isEditingProfile: Bool
      /// 편집 중인 닉네임
      public var editedNickname: String
      /// 편집 중인 프로필 이미지 데이터
      public var editedProfileImageData: Data?
      /// 닉네임 유효성 검사 상태
      public var nicknameValidation: NicknameValidation
      /// 프로필 저장 중 여부
      public var isSavingProfile: Bool
      /// 에러 메시지
      public var errorMessage: String?
      /// 화면 토스트 메시지
      public var toastMessage: ToastMessage?
      /// 네비게이션 경로
      public var path = StackState<Path.State>()
      /// Pro Plan 시트 표시 상태
      @Presents public var proPlan: ProPlan.Feature.State?
      /// 프로필 이미지 상세 보기 표시 여부
      public var showImageDetail: Bool = false
      /// 24시간 형식 사용 여부 (@Shared로 앱 전체 공유)
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false
      /// 일정 탭 기본 모드 (group/own)
      @Shared(.appStorage(AppConstants.UserDefaults.defaultScheduleTabMode)) public var defaultScheduleTabMode: String = "group"
      /// 구독 상태 (RootTab에서 전달)
      public var subscriptionStatus: SubscriptionStatus = .none

      /// State를 위한 기본 initializer
      public init(
        currentUser: Shared<UserPrivateModel>,
        showLogoutAlert: Bool = false,
        isLoading: Bool = false,
        isEditingProfile: Bool = false,
        subscriptionStatus: SubscriptionStatus = .none
      ) {
        self._currentUser = currentUser
        self.showLogoutAlert = showLogoutAlert
        self.isLoading = isLoading
        self.isEditingProfile = isEditingProfile
        self.editedNickname = currentUser.wrappedValue.nickname
        self.editedProfileImageData = nil
        self.nicknameValidation = .idle
        self.isSavingProfile = false
        self.errorMessage = nil
        self.toastMessage = nil
        self.subscriptionStatus = subscriptionStatus
      }
    }

    // MARK: - Path

    @Reducer
    public enum Path {
      case accountInfo(AccountInfo.Feature)
      case dateTimeSettings(DateTimeSettings.Feature)
      case tabSettings(TabSettings.Feature)
      case conflictThresholdSettings(ConflictThresholdSettings.Feature)
      case themeSettings(ThemeSettings.Feature)
      case languageSettings(LanguageSettings.Feature)
      case notificationSettings(NotificationSettings.Feature)
      case groupNotificationDetail(GroupNotificationDetail.Feature)
      case calendarSettings(CalendarSettings.Feature)
      case briefingSettings(BriefingSettings.Feature)
      case support(Support.Feature)
      case faq(FAQ.Feature)
      case legalInfo(LegalInfo.Feature)
      case policyView(PolicyView.Feature)
      case appInfo(AppInfo.Feature)
      case proPlanManage(ProPlan.Feature)
      #if DEBUG
      case developerSettings(DeveloperSettings.Feature)
      #endif
    }

    /// 닉네임 유효성 검사 상태
    public enum NicknameValidation: Equatable {
      case idle
      case checking
      case available
      case unavailable
      case invalid(String)
      case error(String)
    }

    // MARK: - Action

    /// Profile Feature 내에서 발생할 수 있는 모든 가능한 action
    /// ViewAction / InternalAction / DelegateAction으로 분리하여 관심사 분리
    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case path(StackActionOf<Path>)
      case proPlan(PresentationAction<ProPlan.Feature.Action>)
    }

    /// View에서 발생하는 사용자 인터랙션 액션
    @CasePathable
    public enum View: Equatable, Sendable {
      /// View가 처음 나타날 때 트리거
      case onAppear
      /// 로그아웃 버튼 탭
      case logoutTapped
      /// 로그아웃 확인 (Alert에서 확인 버튼)
      case logoutConfirmed
      /// 로그아웃 취소 (Alert에서 취소 버튼)
      case logoutCancelled
      /// 계정 정보 탭
      case accountInfoTapped
      /// 날짜 시간 표시 탭
      case dateTimeSettingsTapped
      /// 탭 설정 탭
      case tabSettingsTapped
      /// 일정 충돌 감지 설정 탭
      case conflictThresholdSettingsTapped
      /// 화면 모드 탭
      case themeSettingsTapped
      /// 언어 설정 탭
      case languageSettingsTapped
      /// 알림 설정 탭
      case notificationSettingsTapped
      /// 캘린더 설정 탭
      case calendarSettingsTapped
      /// 브리핑 설정 탭
      case briefingSettingsTapped
      /// 지원 탭
      case supportTapped
      /// 약관 및 정책 탭
      case legalInfoTapped
      /// 프로 플랜 탭
      case proPlanTapped
      /// 앱 정보 탭
      case appInfoTapped
      #if DEBUG
      /// 개발자 설정 탭
      case developerSettingsTapped
      #endif

      // MARK: - Profile Edit Actions
      /// 프로필 편집 버튼 탭
      case editProfileTapped
      /// 닉네임 변경
      case nicknameChanged(String)
      /// 프로필 이미지 선택
      case profileImageSelected(Data?)
      /// 프로필 저장 버튼 탭
      case saveProfileTapped
      /// 프로필 편집 취소
      case cancelEditTapped
      /// 에러 메시지 닫기
      case dismissError
      /// 프로필 이미지 탭
      case profileImageTapped
      /// 프로필 이미지 상세 닫기
      case imageDetailDismissed
      /// 일정 탭 기본 모드 변경
      case defaultScheduleTabModeChanged(String)
      /// 토스트 닫힘
      case toastDismissed
    }

    /// 내부 비즈니스 로직 처리 결과 액션
    @CasePathable
    public enum Internal: Equatable, Sendable {
      /// 로그아웃 완료
      case logoutCompleted
      /// 로그아웃 실패
      case logoutFailed(AuthClientError)

      // MARK: - Profile Edit Internal
      /// 닉네임 중복 확인 결과
      case nicknameCheckResult(Bool)
      /// 닉네임 중복 확인 실패
      case nicknameCheckFailed(String)
      /// 프로필 저장 완료
      case profileSaveCompleted(UserPrivateModel)
      /// 프로필 저장 실패
      case profileSaveFailed(String)
    }

    /// 부모 Feature에게 전달할 delegate 액션
    public enum Delegate: Equatable, Sendable {
      /// 로그아웃 완료됨 (부모에서 화면 전환 처리)
      case didLogout
      /// 구독 상태 변경됨 (ProPlan에서 전달)
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
            return .none

          case .accountInfoTapped:
            state.path.append(.accountInfo(AccountInfo.Feature.State(currentUser: state.currentUser)))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .dateTimeSettingsTapped:
            state.path.append(.dateTimeSettings(DateTimeSettings.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .tabSettingsTapped:
            state.path.append(.tabSettings(TabSettings.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .conflictThresholdSettingsTapped:
            state.path.append(.conflictThresholdSettings(
              ConflictThresholdSettings.Feature.State(isPro: state.subscriptionStatus.isPro)
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .themeSettingsTapped:
            state.path.append(.themeSettings(ThemeSettings.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .languageSettingsTapped:
            state.path.append(.languageSettings(LanguageSettings.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .notificationSettingsTapped:
            state.path.append(.notificationSettings(
              NotificationSettings.Feature.State(currentUserId: state.currentUser.userId)
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .calendarSettingsTapped:
            state.path.append(.calendarSettings(CalendarSettings.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .briefingSettingsTapped:
            state.path.append(.briefingSettings(
              BriefingSettings.Feature.State(isPro: state.subscriptionStatus.isPro)
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .supportTapped:
            state.path.append(.support(Support.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .legalInfoTapped:
            state.path.append(.legalInfo(LegalInfo.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .proPlanTapped:
            if state.subscriptionStatus.isPro {
              state.path.append(.proPlanManage(ProPlan.Feature.State(subscriptionStatus: state.subscriptionStatus)))
            } else {
              state.proPlan = ProPlan.Feature.State()
            }
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .appInfoTapped:
            state.path.append(.appInfo(AppInfo.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          #if DEBUG
          case .developerSettingsTapped:
            state.path.append(.developerSettings(
              DeveloperSettings.Feature.State()
            ))
            return .run { _ in await hapticFeedback.selection() }
          #endif

          // MARK: - Profile Edit View Actions

          case .editProfileTapped:
            state.isEditingProfile = true
            state.editedNickname = state.currentUser.nickname
            state.editedProfileImageData = nil
            state.nicknameValidation = .idle
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .nicknameChanged(let nickname):
            state.editedNickname = nickname
            // 닉네임 유효성 검사
            if nickname.isEmpty {
              state.nicknameValidation = .invalid(LocalizedStrings.SettingsStrings.nicknameRequired)
              return .none
            }
            if nickname.count < 2 {
              state.nicknameValidation = .invalid(LocalizedStrings.SettingsStrings.nicknameTooShort)
              return .none
            }
            if nickname.count > 20 {
              state.nicknameValidation = .invalid(LocalizedStrings.SettingsStrings.nicknameTooLong)
              return .none
            }
            // 현재 닉네임과 동일하면 검사 생략
            if nickname == state.currentUser.nickname {
              state.nicknameValidation = .idle
              return .none
            }
            // 중복 확인 (debounce 적용)
            state.nicknameValidation = .checking
            return .run { send in
              do {
                let isAvailable = try await userProfileClient.isNicknameAvailable(nickname)
                await send(.internal(.nicknameCheckResult(isAvailable)))
              } catch {
                await send(.internal(.nicknameCheckFailed((error as? UserProfileError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)))
              }
            }
            .debounce(id: CancelID.nicknameCheck, for: .milliseconds(500), scheduler: DispatchQueue.main)
            .cancellable(id: CancelID.nicknameCheck, cancelInFlight: true)

          case .profileImageSelected(let imageData):
            state.editedProfileImageData = imageData
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .saveProfileTapped:
            guard state.nicknameValidation == .available || state.editedNickname == state.currentUser.nickname else {
              return .none
            }
            state.isSavingProfile = true
            let nickname = state.editedNickname
            let imageData = state.editedProfileImageData
            let currentNickname = state.currentUser.nickname
            return .run { send in
              await hapticFeedback.medium()
              do {
                // 닉네임이 변경된 경우
                if nickname != currentNickname {
                  try await userProfileClient.updateProfile(nickname)
                }
                // 이미지가 선택된 경우
                if let imageData = imageData {
                  _ = try await userProfileClient.updateProfileImage(imageData)
                }
                // 업데이트된 프로필 조회
                let updatedUser = try await userProfileClient.getPrivateProfile(.me)
                await send(.internal(.profileSaveCompleted(updatedUser)))
              } catch {
                await send(.internal(.profileSaveFailed((error as? UserProfileError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)))
              }
            }

          case .cancelEditTapped:
            state.isEditingProfile = false
            state.editedNickname = state.currentUser.nickname
            state.editedProfileImageData = nil
            state.nicknameValidation = .idle
            return .none

          case .dismissError:
            state.errorMessage = nil
            return .none

          case .profileImageTapped:
            state.showImageDetail = true
            return .none

          case .imageDetailDismissed:
            state.showImageDetail = false
            return .none

          case .defaultScheduleTabModeChanged(let mode):
            state.$defaultScheduleTabMode.withLock { $0 = mode }
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .toastDismissed:
            state.toastMessage = nil
            return .none
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
            state.errorMessage = error.localizedMessage
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.logoutFailed,
              subtitle: error.localizedMessage,
              position: .top
            )
            return .run { _ in
              await hapticFeedback.error()
            }

          // MARK: - Profile Edit Internal Actions

          case .nicknameCheckResult(let isAvailable):
            state.nicknameValidation = isAvailable ? .available : .unavailable
            return .none

          case .nicknameCheckFailed(let errorMessage):
            state.nicknameValidation = .error(errorMessage)
            return .none

          case .profileSaveCompleted(let updatedUser):
            state.$currentUser.withLock { $0 = updatedUser }
            state.isSavingProfile = false
            state.isEditingProfile = false
            state.editedProfileImageData = nil
            state.nicknameValidation = .idle
            return .none

          case .profileSaveFailed(let errorMessage):
            state.isSavingProfile = false
            state.errorMessage = errorMessage
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.profileSaveFailed,
              subtitle: errorMessage,
              position: .top
            )
            return .run { _ in
              await hapticFeedback.error()
            }
          }

        // MARK: - Delegate Actions
        case .delegate:
          // Delegate 액션은 부모에서 처리하므로 여기서는 pass-through
          return .none

        // MARK: - Path Actions
        case .path(.element(_, action: .accountInfo(.delegate(let delegate)))):
          switch delegate {
          case .editProfileRequested:
            return .send(.view(.editProfileTapped))

          case .logoutRequested:
            return .send(.view(.logoutConfirmed))

          case .deleteAccountRequested:
            // AccountInfo에서 직접 처리하므로 여기서는 무시
            return .none

          case .didDeleteAccount:
            // 회원 탈퇴 완료 - 로그아웃과 동일하게 처리
            return .send(.delegate(.didLogout))
          }

        case .path(.element(_, action: .notificationSettings(.delegate(let delegate)))):
          switch delegate {
          case .navigateToGroupDetail(let group, let isSystemNotificationEnabled):
            state.path.append(.groupNotificationDetail(
              GroupNotificationDetail.Feature.State(
                group: group,
                isSystemNotificationEnabled: isSystemNotificationEnabled
              )
            ))
            return .none
          }

        case .path(.element(_, action: .conflictThresholdSettings(.delegate(let delegate)))):
          switch delegate {
          case .proPlanRequested:
            state.proPlan = ProPlan.Feature.State()
            return .none
          }

        case .path(.element(_, action: .briefingSettings(.delegate(let delegate)))):
          switch delegate {
          case .proPlanRequested:
            state.proPlan = ProPlan.Feature.State()
            return .none
          }

        case .path(.element(_, action: .support(.delegate(let delegate)))):
          switch delegate {
          case .navigateToFAQ:
            state.path.append(.faq(FAQ.Feature.State()))
            return .none
          }

        case .path(.element(_, action: .legalInfo(.delegate(let delegate)))):
          switch delegate {
          case .navigateToPolicy(let policyType, let url):
            state.path.append(.policyView(
              PolicyView.Feature.State(policyType: policyType, url: url)
            ))
            return .none
          }

        case .path(.element(_, action: .groupNotificationDetail(.delegate(let delegate)))):
          switch delegate {
          case .settingsUpdated(let groupId, let settings):
            // NotificationSettings의 groups 상태 업데이트
            for id in state.path.ids {
              if case .notificationSettings(var notifState) = state.path[id: id] {
                if let index = notifState.groups.firstIndex(where: { $0.id == groupId }) {
                  notifState.groups[index] = notifState.groups[index].withNotifications(settings)
                  state.path[id: id] = .notificationSettings(notifState)
                }
              }
            }
            return .none
          }

        case .proPlan(.presented(.delegate(let delegate))):
          switch delegate {
          case .subscriptionStatusChanged(let status):
            syncSubscriptionStatus(status, state: &state)
            return .send(.delegate(.subscriptionStatusChanged(status)))

          case .dismissRequested:
            state.proPlan = nil
            return .none
          }

        case .proPlan:
          return .none

        case .path(.element(_, action: .proPlanManage(.delegate(let delegate)))):
          switch delegate {
          case .subscriptionStatusChanged(let status):
            syncSubscriptionStatus(status, state: &state)
            return .send(.delegate(.subscriptionStatusChanged(status)))
          case .dismissRequested:
            return .none
          }

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
      .ifLet(\.$proPlan, action: \.proPlan) {
        ProPlan.Feature()
      }
    }

    private func syncSubscriptionStatus(_ status: SubscriptionStatus, state: inout State) {
      state.subscriptionStatus = status

      for id in state.path.ids {
        if case .conflictThresholdSettings(var conflictState) = state.path[id: id] {
          conflictState.isPro = status.isPro
          if status.isPro {
            conflictState.isEnabled = true
          }
          state.path[id: id] = .conflictThresholdSettings(conflictState)
          continue
        }

        if case .briefingSettings(var briefingState) = state.path[id: id] {
          briefingState.isPro = status.isPro
          state.path[id: id] = .briefingSettings(briefingState)
        }
      }
    }
  }

  // MARK: - Root View

  /// Profile Feature를 위한 Main view implementation
  /// NavigationStackStore를 사용한 Path 기반 네비게이션
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStackStore(store.scope(state: \.path, action: \.path)) {
        ProfileView(store: store)
      } destination: { store in
        switch store.case {
        case .accountInfo(let accountInfoStore):
          AccountInfo.RootView(store: accountInfoStore)
        case .dateTimeSettings(let store):
          DateTimeSettings.RootView(store: store)
        case .tabSettings(let store):
          TabSettings.RootView(store: store)
        case .conflictThresholdSettings(let store):
          ConflictThresholdSettings.RootView(store: store)
        case .themeSettings(let store):
          ThemeSettings.RootView(store: store)
        case .languageSettings(let store):
          LanguageSettings.RootView(store: store)
        case .notificationSettings(let store):
          NotificationSettings.RootView(store: store)
        case .groupNotificationDetail(let store):
          GroupNotificationDetail.RootView(store: store)
        case .calendarSettings(let store):
          CalendarSettings.RootView(store: store)
        case .briefingSettings(let store):
          BriefingSettings.RootView(store: store)
        case .support(let store):
          Support.RootView(store: store)
        case .faq(let store):
          FAQ.RootView(store: store)
        case .legalInfo(let store):
          LegalInfo.RootView(store: store)
        case .policyView(let store):
          PolicyView.RootView(store: store)
        case .appInfo(let store):
          AppInfo.RootView(store: store)
        case .proPlanManage(let store):
          ProPlan.RootView(store: store)
        #if DEBUG
        case .developerSettings(let store):
          DeveloperSettings.RootView(store: store)
        #endif
        }
      }
      .sheet(
        item: $store.scope(state: \.proPlan, action: \.proPlan)
      ) { proPlanStore in
        ProPlan.PaywallView(store: proPlanStore)
          .onAppear { proPlanStore.send(.view(.onAppear)) }
      }
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
    }
  }
}

// MARK: - Path Conformances

extension Settings.Feature.Path.State: Equatable, Sendable {}
extension Settings.Feature.Path.Action: Sendable {}

// MARK: - Error Types

/// Profile Feature 관련 에러 타입
public enum SettingsError: Error, Equatable, LocalizedError {
  case logoutFailed
  case userNotFound
  case imageLoadFailed
  case unknown

  public var errorDescription: String? {
    switch self {
    case .logoutFailed:
      return LocalizedStrings.SettingsStrings.logoutFailed
    case .userNotFound:
      return LocalizedStrings.SettingsStrings.userNotFound
    case .imageLoadFailed:
      return LocalizedStrings.SettingsStrings.imageLoadFailed
    case .unknown:
      return LocalizedStrings.SettingsStrings.unknownError
    }
  }
}
