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
      /// 네비게이션 경로
      public var path = StackState<Path.State>()
      /// 프로필 이미지 상세 보기 표시 여부
      public var showImageDetail: Bool = false

      // MARK: - Statistics

      /// 그룹 수
      public var groupCount: Int = 0
      /// 약속 수
      public var promiseCount: Int = 0

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
      }
    }

    // MARK: - Path

    @Reducer
    public enum Path {
      case accountInfo(AccountInfo.Feature)
      case notificationSettings(NotificationSettings.Feature)
      case policyView(PolicyView.Feature)
      case appInfo(AppInfo.Feature)
      case developerSettings(DeveloperSettings.Feature)
      case appSettings(AppSettings.Feature)
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
      /// 알림 설정 탭
      case notificationSettingsTapped
      /// 개인정보처리방침 탭
      case privacyPolicyTapped
      /// 이용약관 탭
      case termsOfServiceTapped
      /// 앱 정보 탭
      case appInfoTapped
      /// 계정 정보 탭
      case accountInfoTapped
      /// 개발자 설정 탭 (#if DEBUG)
      case developerSettingsTapped
      /// 앱 설정 탭 (toolbar)
      case appSettingsTapped

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
    }

    /// 내부 비즈니스 로직 처리 결과 액션
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

      // MARK: - Statistics

      /// 통계 로드 완료
      case statsLoaded(groupCount: Int, promiseCount: Int)
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
            // View가 나타날 때 통계 로드
            let groupCount = state.currentUser.groups.count
            // promiseCount는 Firestore 쿼리 필요 (향후 구현, 일단 0)
            return .send(.internal(.statsLoaded(groupCount: groupCount, promiseCount: 0)))

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

          case .notificationSettingsTapped:
            // 알림 설정 화면으로 이동
            let userId = state.currentUser.userId
            state.path.append(.notificationSettings(
              NotificationSettings.Feature.State(
                currentUserId: userId,
                notificationEnabled: true  // Default, will load actual value in onAppear
              )
            ))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .privacyPolicyTapped:
            // 개인정보처리방침 SafariView 표시
            state.path.append(.policyView(
              PolicyView.Feature.State(
                policyType: .privacyPolicy,
                url: URL(string: "https://promiso.app/privacy")!
              )
            ))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .termsOfServiceTapped:
            // 이용약관 SafariView 표시
            state.path.append(.policyView(
              PolicyView.Feature.State(
                policyType: .termsOfService,
                url: URL(string: "https://promiso.app/terms")!
              )
            ))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .appInfoTapped:
            // 앱 정보 화면 표시
            state.path.append(.appInfo(AppInfo.Feature.State()))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .accountInfoTapped:
            state.path.append(.accountInfo(AccountInfo.Feature.State(currentUser: state.currentUser)))
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .developerSettingsTapped:
            state.path.append(
              .developerSettings(
                DeveloperSettings.Feature.State(
                  currentUserId: state.currentUser.userId
                )
              )
            )
            return .run { _ in
              await hapticFeedback.selection()
            }

          case .appSettingsTapped:
            state.path.append(.appSettings(AppSettings.Feature.State()))
            return .run { _ in
              await hapticFeedback.selection()
            }

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
              state.nicknameValidation = .invalid("닉네임을 입력해주세요")
              return .none
            }
            if nickname.count < 2 {
              state.nicknameValidation = .invalid("닉네임은 2자 이상이어야 합니다")
              return .none
            }
            if nickname.count > 20 {
              state.nicknameValidation = .invalid("닉네임은 20자 이하여야 합니다")
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
                await send(.internal(.nicknameCheckFailed(error.localizedDescription)))
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
                await send(.internal(.profileSaveFailed(error.localizedDescription)))
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
            state.errorMessage = error.localizedDescription
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
            return .run { _ in
              await hapticFeedback.error()
            }

          case .statsLoaded(let groupCount, let promiseCount):
            state.groupCount = groupCount
            state.promiseCount = promiseCount
            return .none
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
            // TODO: 회원 탈퇴 구현
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
        case .notificationSettings(let notificationSettingsStore):
          NotificationSettings.RootView(store: notificationSettingsStore)
        case .policyView(let policyViewStore):
          PolicyView.RootView(store: policyViewStore)
        case .appInfo(let appInfoStore):
          AppInfo.RootView(store: appInfoStore)
        case .developerSettings(let developerSettingsStore):
          DeveloperSettings.RootView(store: developerSettingsStore)
        case .appSettings(let appSettingsStore):
          AppSettings.RootView(store: appSettingsStore)
        }
      }
    }
  }
}

// MARK: - Path Conformances

extension Profile.Feature.Path.State: Equatable, Sendable {}
extension Profile.Feature.Path.Action: Sendable {}

// MARK: - Error Types

/// Profile Feature 관련 에러 타입
public enum ProfileError: Error, Equatable, LocalizedError {
  case logoutFailed
  case userNotFound
  case imageLoadFailed
  case unknown

  public var errorDescription: String? {
    switch self {
    case .logoutFailed:
      return "로그아웃에 실패했습니다. 다시 시도해주세요."
    case .userNotFound:
      return "사용자 정보를 찾을 수 없습니다."
    case .imageLoadFailed:
      return "이미지를 불러오는데 실패했습니다."
    case .unknown:
      return "알 수 없는 오류가 발생했습니다."
    }
  }
}
