// MARK: - ProfileFeature.swift
// TCA 1.22.2를 사용한 Profile Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import PromisoShared
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
      /// 프로필 이미지 상세 보기 표시 여부
      public var showImageDetail: Bool = false
      /// 24시간 형식 사용 여부 (@Shared로 앱 전체 공유)
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false
      /// 약속 탭 기본 모드 (group/own)
      @Shared(.appStorage(AppConstants.UserDefaults.defaultPromiseTabMode)) public var defaultPromiseTabMode: String = "group"

      /// State를 위한 기본 initializer
      public init(
        currentUser: Shared<UserPrivateModel>,
        showLogoutAlert: Bool = false,
        isLoading: Bool = false,
        isEditingProfile: Bool = false
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
      }
    }

    // MARK: - Path

    @Reducer
    public enum Path {
      case accountInfo(AccountInfo.Feature)
      case dateTimeSettings(DateTimeSettings.Feature)
      case promiseTabModeSettings(PromiseTabModeSettings.Feature)
      case themeSettings(ThemeSettings.Feature)
      case languageSettings(LanguageSettings.Feature)
      case notificationSettings(NotificationSettings.Feature)
      case groupNotificationDetail(GroupNotificationDetail.Feature)
      case calendarSettings(CalendarSettings.Feature)
      case support(Support.Feature)
      case faq(FAQ.Feature)
      case legalInfo(LegalInfo.Feature)
      case policyView(PolicyView.Feature)
      case appInfo(AppInfo.Feature)
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
      /// 약속 탭 기본 모드 탭
      case promiseTabModeSettingsTapped
      /// 화면 모드 탭
      case themeSettingsTapped
      /// 언어 설정 탭
      case languageSettingsTapped
      /// 알림 설정 탭
      case notificationSettingsTapped
      /// 캘린더 설정 탭
      case calendarSettingsTapped
      /// 지원 탭
      case supportTapped
      /// 약관 및 정책 탭
      case legalInfoTapped
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
      /// 약속 탭 기본 모드 변경
      case defaultPromiseTabModeChanged(String)
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

          case .promiseTabModeSettingsTapped:
            state.path.append(.promiseTabModeSettings(PromiseTabModeSettings.Feature.State()))
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

          case .supportTapped:
            state.path.append(.support(Support.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          case .legalInfoTapped:
            state.path.append(.legalInfo(LegalInfo.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

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

          case .defaultPromiseTabModeChanged(let mode):
            state.$defaultPromiseTabMode.withLock { $0 = mode }
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
              title: "로그아웃에 실패했어요",
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
              title: "프로필 저장에 실패했어요",
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

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
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
        case .promiseTabModeSettings(let store):
          PromiseTabModeSettings.RootView(store: store)
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
        #if DEBUG
        case .developerSettings(let store):
          DeveloperSettings.RootView(store: store)
        #endif
        }
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

// MARK: - DateTimeSettings Namespace

public enum DateTimeSettings {}

// MARK: - DateTimeSettings Feature

extension DateTimeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false
      /// 선택된 값 (임시)
      var selectedValue: Bool = false

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case formatSelected(Bool)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.selectedValue = state.use24HourFormat
            return .none

          case .formatSelected(let value):
            state.selectedValue = value
            state.$use24HourFormat.withLock { $0 = value }
            LocalizedDateFormatters.use24HourFormat = value
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          timeFormatSection
          exampleCardSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.dateTimeDisplay)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var timeFormatSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.timeFormatSection)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          formatRow(is24Hour: false, title: LocalizedStrings.SettingsStrings.timeFormat12Hour, description: LocalizedStrings.SettingsStrings.timeFormat12HourExample)
          Divider()
            .padding(.leading, 48)
          formatRow(is24Hour: true, title: LocalizedStrings.SettingsStrings.timeFormat24Hour, description: LocalizedStrings.SettingsStrings.timeFormat24HourExample)
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.timeFormatHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func formatRow(is24Hour: Bool, title: String, description: String) -> some View {
      Button {
        store.send(.view(.formatSelected(is24Hour)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "clock")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if store.selectedValue == is24Hour {
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
    }

    private var exampleCardSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.preview)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        ExamplePromiseCard(use24Hour: store.selectedValue)

        Text(LocalizedStrings.SettingsStrings.previewHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - Example Promise Card

  private struct ExamplePromiseCard: View {
    let use24Hour: Bool

    private var timeString: String {
      if use24Hour {
        return LocalizedStrings.SettingsStrings.exampleTime24
      } else {
        return LocalizedStrings.SettingsStrings.exampleTime12
      }
    }

    private var dateString: String {
      LocalizedStrings.SettingsStrings.exampleDate
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        // Main Content
        HStack(alignment: .top, spacing: 12) {
          Text("🍽️")
            .font(.system(size: 44))

          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.exampleTitle)
              .font(.system(size: 19, weight: .bold))
              .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 6) {
              // Date & Time
              HStack(spacing: 4) {
                Text("⏰")
                  .font(.system(size: 14))
                Text("\(dateString) \(timeString)")
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)

              // Location
              HStack(spacing: 4) {
                Text("📍")
                  .font(.system(size: 14))
                Text(LocalizedStrings.SettingsStrings.exampleLocation)
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)
            }
          }

          Spacer()
        }
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }
}

// MARK: - ThemeSettings Namespace

public enum ThemeSettings {}

// MARK: - ThemeSettings Feature

extension ThemeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.preferredThemeMode)) public var themeMode: String = AppConstants.ThemeMode.system.rawValue

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case themeModeChanged(AppConstants.ThemeMode)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .themeModeChanged(let mode):
            guard mode.rawValue != state.themeMode else { return .none }
            state.$themeMode.withLock { $0 = mode.rawValue }
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private var currentMode: AppConstants.ThemeMode {
      AppConstants.ThemeMode(rawValue: store.themeMode) ?? .system
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          themeModeSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.themeModeNavigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var themeModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.themeModeSectionTitle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(AppConstants.ThemeMode.allCases, id: \.rawValue) { mode in
            themeModeRow(mode: mode)
            if mode != AppConstants.ThemeMode.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.themeModeSectionHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func themeModeRow(mode: AppConstants.ThemeMode) -> some View {
      Button {
        store.send(.view(.themeModeChanged(mode)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: iconName(for: mode))
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(mode.displayName)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description(for: mode))
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if currentMode == mode {
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
    }

    private func iconName(for mode: AppConstants.ThemeMode) -> String {
      switch mode {
      case .system: return "iphone"
      case .light: return "sun.max.fill"
      case .dark: return "moon.fill"
      }
    }

    private func description(for mode: AppConstants.ThemeMode) -> String {
      switch mode {
      case .system: return LocalizedStrings.SettingsStrings.themeModeSystemDescription
      case .light: return LocalizedStrings.SettingsStrings.themeModeLightDescription
      case .dark: return LocalizedStrings.SettingsStrings.themeModeDarkDescription
      }
    }
  }
}

// MARK: - LanguageSettings Namespace

public enum LanguageSettings {}

// MARK: - LanguageSettings Feature

extension LanguageSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.preferredLanguage)) public var preferredLanguage: String = ""

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case languageChanged(AppLanguage)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .languageChanged(let language):
            guard language.rawValue != state.preferredLanguage else { return .none }
            state.$preferredLanguage.withLock { $0 = language.rawValue }
            LocalizedStrings.configure()
            LocalizedDateFormatters.updateLocale()
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private var currentLanguage: AppLanguage {
      if store.preferredLanguage.isEmpty {
        // 시스템 기본 - 현재 시스템 언어 감지
        let systemLang = Locale.current.language.languageCode?.identifier ?? "ko"
        return AppLanguage(rawValue: systemLang) ?? .korean
      }
      return AppLanguage(rawValue: store.preferredLanguage) ?? .korean
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          languageSection

          systemLanguageHint
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.language)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var languageSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.languageSectionTitle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(AppLanguage.allCases, id: \.rawValue) { language in
            languageRow(language: language)
            if language != AppLanguage.allCases.last {
              Divider()
                .padding(.leading, 48)
            }
          }
        }
        .adaptiveGlassCard()
      }
    }

    private var systemLanguageHint: some View {
      Text(LocalizedStrings.SettingsStrings.languageHint)
        .font(.system(size: 12))
        .foregroundStyle(Color.pmtext.secondary)
        .padding(.horizontal, 4)
    }

    private func languageRow(language: AppLanguage) -> some View {
      Button {
        store.send(.view(.languageChanged(language)))
      } label: {
        HStack(spacing: 12) {
          Text(language.icon)
            .font(.system(size: 20))
            .frame(width: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(language.displayName)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)
          }

          Spacer()

          if currentLanguage == language {
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
    }
  }
}

// MARK: - PromiseTabModeSettings Namespace

public enum PromiseTabModeSettings {}

// MARK: - PromiseTabModeSettings Feature

extension PromiseTabModeSettings {

  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      @Shared(.appStorage(AppConstants.UserDefaults.defaultPromiseTabMode)) public var defaultPromiseTabMode: String = "group"

      public init() {}
    }

    public enum Action: Equatable, Sendable {
      case view(View)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case tabModeChanged(String)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .tabModeChanged(let mode):
            state.$defaultPromiseTabMode.withLock { $0 = mode }
            return .run { _ in
              await hapticFeedback.selection()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          tabModeSection
          tabBarPreviewSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.promiseTabDefaultMode)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    private var tabModeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.promiseTabModeDefault)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          tabModeRow(mode: "group", icon: "person.3.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeGroup, description: LocalizedStrings.SettingsStrings.promiseTabModeGroupDescription)
          Divider()
            .padding(.leading, 48)
          tabModeRow(mode: "own", icon: "person.fill", title: LocalizedStrings.SettingsStrings.promiseTabModeOwn, description: LocalizedStrings.SettingsStrings.promiseTabModeOwnDescription)
        }
        .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.promiseTabModeHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    private func tabModeRow(mode: String, icon: String, title: String, description: String) -> some View {
      Button {
        store.send(.view(.tabModeChanged(mode)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 20)

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Text(description)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

          Spacer()

          if store.defaultPromiseTabMode == mode {
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
    }

    private var tabBarPreviewSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.preview)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        TabBarPreview(selectedMode: store.defaultPromiseTabMode)
          .adaptiveGlassCard()

        Text(LocalizedStrings.SettingsStrings.promiseTabModePreviewHint)
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - TabBarPreview

  private struct TabBarPreview: View {
    let selectedMode: String

    var body: some View {
      if #available(iOS 26.0, *) {
        ios26TabBarPreview
      } else {
        fallbackTabBarPreview
      }
    }

    @available(iOS 26.0, *)
    private var ios26TabBarPreview: some View {
      HStack(spacing: 8) {
        TabItemView(icon: "house.fill", label: LocalizedStrings.SettingsStrings.tabHome, isSelected: false)
        TabItemView(
          icon: selectedMode == "group" ? "person.3.fill" : "person.fill",
          label: selectedMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: "calendar", label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: false)
        TabItemView(icon: "gearshape.fill", label: LocalizedStrings.SettingsStrings.tabSettings, isSelected: false)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(.regularMaterial.opacity(0.7))
      )
      .frame(height: 76)
    }

    private var fallbackTabBarPreview: some View {
      HStack(spacing: 8) {
        TabItemView(icon: "house.fill", label: LocalizedStrings.SettingsStrings.tabHome, isSelected: false)
        TabItemView(
          icon: selectedMode == "group" ? "person.3.fill" : "person.fill",
          label: selectedMode == "group" ? LocalizedStrings.SettingsStrings.tabGroup : LocalizedStrings.SettingsStrings.tabOwn,
          isSelected: true
        )
        TabItemView(icon: "calendar", label: LocalizedStrings.SettingsStrings.tabCalendar, isSelected: false)
        TabItemView(icon: "gearshape.fill", label: LocalizedStrings.SettingsStrings.tabSettings, isSelected: false)
      }
      .padding(8)
      .background(
        RoundedRectangle(cornerRadius: 24)
          .fill(Color.white.opacity(0.1))
      )
      .frame(height: 76)
    }
  }

  // MARK: - TabItemView

  private struct TabItemView: View {
    let icon: String
    let label: String
    let isSelected: Bool

    var body: some View {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)

        Text(label)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(
        Group {
          if isSelected {
            if #available(iOS 26.0, *) {
              Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
              Capsule()
                .fill(Color.white.opacity(0.2))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
          }
        }
      )
    }
  }
}

// MARK: - CalendarSyncError Localization

extension CalendarSyncError {
  var localizedMessage: String {
    switch self {
    case .noWritePermission: return LocalizedStrings.Error.calendarNoWritePermission
    case .fetchFailed(_): return LocalizedStrings.Error.calendarFetchFailed
    case .syncFailed(_): return LocalizedStrings.Error.calendarSyncFailed
    }
  }
}

// MARK: - UserProfileError Localization

extension UserProfileError {
  var localizedMessage: String {
    switch self {
    case .invalidData: return LocalizedStrings.Error.userInvalidData
    case .userNotFound: return LocalizedStrings.Error.userNotFound
    case .uploadFailed: return LocalizedStrings.Error.userUploadFailed
    case .networkError: return LocalizedStrings.Error.userNetworkError
    case .authenticationRequired: return LocalizedStrings.Error.userAuthRequired
    case .permissionDenied: return LocalizedStrings.Error.userPermissionDenied
    }
  }
}

// MARK: - AppConfigClientError Localization

extension AppConfigClientError {
  var localizedMessage: String {
    switch self {
    case .fetchFailed(_): return LocalizedStrings.Error.appConfigFetchFailed
    case .invalidVersion(_): return LocalizedStrings.Error.appConfigInvalidVersion
    }
  }
}
