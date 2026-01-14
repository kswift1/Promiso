// MARK: - ProfileFeature.swift
// TCA 1.22.2를 사용한 Profile Feature

import PhotosUI

// MARK: - Feature Namespace

/// Profile Feature 컴포넌트를 위한 Namespace
public enum Profile {}

// MARK: - Feature Implementation

extension Profile {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.openURL) var openURL

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 유저 정보
      var currentUser: UserPrivateModel

      /// 설정
      var notificationEnabled: Bool = true
      var isLoadingSettings: Bool = false

      /// 프로필 편집 시트
      @Presents var editProfile: EditProfileFeature.State?

      /// 로그아웃 확인 알림
      var showLogoutAlert: Bool = false

      /// 회원탈퇴 확인 알림
      var showDeleteAccountAlert: Bool = false

      /// 로딩/에러 상태
      var isLoading: Bool = false
      var errorMessage: String?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // MARK: - Computed Properties

      /// 앱 버전
      var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
      }

      /// 가입일
      var joinedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: currentUser.metadata.createdAt)
      }

      /// 로그인 제공자 표시 이름
      var providerDisplayName: String {
        switch currentUser.provider.lowercased() {
        case "google": return "Google"
        case "apple": return "Apple"
        default: return currentUser.provider
        }
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case editProfile(PresentationAction<EditProfileFeature.Action>)

      @CasePathable
      public enum View: Sendable {
        /// 화면 나타남
        case onAppear
        /// 프로필 편집 탭
        case editProfileTapped
        /// 알림 설정 토글
        case notificationToggled(Bool)
        /// 로그아웃 탭
        case logoutTapped
        /// 로그아웃 확인
        case logoutConfirmed
        /// 로그아웃 취소
        case logoutCancelled
        /// 회원탈퇴 탭
        case deleteAccountTapped
        /// 회원탈퇴 확인
        case deleteAccountConfirmed
        /// 회원탈퇴 취소
        case deleteAccountCancelled
        /// 서비스 약관 탭
        case termsOfServiceTapped
        /// 개인정보 처리방침 탭
        case privacyPolicyTapped
      }

      public enum Internal: Sendable, Equatable {
        case loadSettings
        case settingsLoaded(Result<UserSettings, Error>)
        case settingsUpdated(Result<Void, Error>)
        case logoutCompleted
        case accountDeleted(Result<Void, Error>)
        case profileUpdated(UserPrivateModel)

        public static func == (lhs: Internal, rhs: Internal) -> Bool {
          switch (lhs, rhs) {
          case (.loadSettings, .loadSettings):
            return true
          case (.settingsLoaded(let lResult), .settingsLoaded(let rResult)):
            switch (lResult, rResult) {
            case (.success(let lValue), .success(let rValue)):
              return lValue == rValue
            case (.failure, .failure):
              return true
            default:
              return false
            }
          case (.settingsUpdated(let lResult), .settingsUpdated(let rResult)):
            switch (lResult, rResult) {
            case (.success, .success):
              return true
            case (.failure, .failure):
              return true
            default:
              return false
            }
          case (.logoutCompleted, .logoutCompleted):
            return true
          case (.accountDeleted(let lResult), .accountDeleted(let rResult)):
            switch (lResult, rResult) {
            case (.success, .success):
              return true
            case (.failure, .failure):
              return true
            default:
              return false
            }
          case (.profileUpdated(let lUser), .profileUpdated(let rUser)):
            return lUser == rUser
          default:
            return false
          }
        }
      }

      public enum Delegate: Sendable, Equatable {
        case logoutRequested
        case accountDeleted
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(&state, viewAction)
        case .internal(let internalAction):
          return handleInternalAction(&state, internalAction)
        case .delegate:
          return .none
        case .editProfile(.presented(.delegate(.profileUpdated(let user)))):
          state.currentUser = user
          return .none
        case .editProfile(.presented(.delegate(.dismissed))):
          state.editProfile = nil
          return .none
        case .editProfile:
          return .none
        }
      }
      .ifLet(\.$editProfile, action: \.editProfile) {
        EditProfileFeature()
      }
    }

    // MARK: - View Action Handler

    private func handleViewAction(
      _ state: inout State,
      _ action: Action.View
    ) -> Effect<Action> {
      switch action {
      case .onAppear:
        return .send(.internal(.loadSettings))

      case .editProfileTapped:
        state.editProfile = EditProfileFeature.State(currentUser: state.currentUser)
        return .none

      case .notificationToggled(let enabled):
        state.notificationEnabled = enabled
        return .run { send in
          do {
            try await userProfileClient.updateUserSettings(enabled)
            await send(.internal(.settingsUpdated(.success(()))))
          } catch {
            await send(.internal(.settingsUpdated(.failure(error))))
          }
        }

      case .logoutTapped:
        state.showLogoutAlert = true
        return .none

      case .logoutConfirmed:
        state.showLogoutAlert = false
        return .run { send in
          try? await authClient.logout()
          await send(.internal(.logoutCompleted))
        }

      case .logoutCancelled:
        state.showLogoutAlert = false
        return .none

      case .deleteAccountTapped:
        state.showDeleteAccountAlert = true
        return .none

      case .deleteAccountConfirmed:
        state.showDeleteAccountAlert = false
        state.isLoading = true
        return .run { send in
          do {
            try await userProfileClient.deleteAccount()
            await send(.internal(.accountDeleted(.success(()))))
          } catch {
            await send(.internal(.accountDeleted(.failure(error))))
          }
        }

      case .deleteAccountCancelled:
        state.showDeleteAccountAlert = false
        return .none

      case .termsOfServiceTapped:
        // TODO: 실제 URL로 교체 필요
        return .run { _ in
          if let url = URL(string: "https://promiso.app/terms") {
            await openURL(url)
          }
        }

      case .privacyPolicyTapped:
        // TODO: 실제 URL로 교체 필요
        return .run { _ in
          if let url = URL(string: "https://promiso.app/privacy") {
            await openURL(url)
          }
        }
      }
    }

    // MARK: - Internal Action Handler

    private func handleInternalAction(
      _ state: inout State,
      _ action: Action.Internal
    ) -> Effect<Action> {
      switch action {
      case .loadSettings:
        state.isLoadingSettings = true
        return .run { send in
          do {
            let settings = try await userProfileClient.getUserSettings()
            await send(.internal(.settingsLoaded(.success(settings))))
          } catch {
            await send(.internal(.settingsLoaded(.failure(error))))
          }
        }

      case .settingsLoaded(let result):
        state.isLoadingSettings = false
        switch result {
        case .success(let settings):
          state.notificationEnabled = settings.notificationEnabled
        case .failure:
          // 설정 로드 실패 시 기본값 유지
          break
        }
        return .none

      case .settingsUpdated(let result):
        switch result {
        case .success:
          break
        case .failure:
          // 설정 업데이트 실패 시 이전 값으로 롤백
          state.notificationEnabled.toggle()
          state.errorMessage = "설정 변경에 실패했습니다"
        }
        return .none

      case .logoutCompleted:
        return .send(.delegate(.logoutRequested))

      case .accountDeleted(let result):
        state.isLoading = false
        switch result {
        case .success:
          return .send(.delegate(.accountDeleted))
        case .failure(let error):
          state.errorMessage = error.localizedDescription
          return .none
        }

      case .profileUpdated(let user):
        state.currentUser = user
        return .none
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // 프로필 헤더
          profileHeaderSection

          // 메뉴 섹션들
          settingsSection

          accountSection

          infoSection
        }
        .padding(.vertical, 16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("프로필")
      .navigationBarTitleDisplayMode(.large)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        "로그아웃",
        isPresented: Binding(
          get: { store.showLogoutAlert },
          set: { isPresented in
            if !isPresented {
              store.send(.view(.logoutCancelled))
            }
          }
        )
      ) {
        Button("취소", role: .cancel) {
          store.send(.view(.logoutCancelled))
        }
        Button("로그아웃", role: .destructive) {
          store.send(.view(.logoutConfirmed))
        }
      } message: {
        Text("정말 로그아웃 하시겠습니까?")
      }
      .alert(
        "회원 탈퇴",
        isPresented: Binding(
          get: { store.showDeleteAccountAlert },
          set: { isPresented in
            if !isPresented {
              store.send(.view(.deleteAccountCancelled))
            }
          }
        )
      ) {
        Button("취소", role: .cancel) {
          store.send(.view(.deleteAccountCancelled))
        }
        Button("탈퇴", role: .destructive) {
          store.send(.view(.deleteAccountConfirmed))
        }
      } message: {
        Text("정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.")
      }
      .sheet(item: $store.scope(state: \.editProfile, action: \.editProfile)) { editStore in
        NavigationStack {
          EditProfileFeature.RootView(store: editStore)
        }
      }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
      VStack(spacing: 16) {
        // 프로필 이미지
        profileImage
          .frame(width: 100, height: 100)
          .clipShape(Circle())
          .overlay(
            Circle()
              .stroke(Color(.systemGray4), lineWidth: 1)
          )

        // 닉네임
        Text(store.currentUser.displayName)
          .font(.system(size: 24, weight: .bold))
          .foregroundColor(.primary)

        // 이메일
        Text(store.currentUser.email)
          .font(.system(size: 15))
          .foregroundColor(.secondary)

        // 가입 정보
        HStack(spacing: 4) {
          Image(systemName: "calendar")
            .font(.system(size: 12))
          Text("\(store.state.joinedDate) 가입")
            .font(.system(size: 13))
          Text("·")
          Image(systemName: store.currentUser.provider == "google" ? "g.circle.fill" : "apple.logo")
            .font(.system(size: 12))
          Text(store.state.providerDisplayName)
            .font(.system(size: 13))
        }
        .foregroundColor(.secondary)

        // 편집 버튼
        Button {
          store.send(.view(.editProfileTapped))
        } label: {
          Text("프로필 편집")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(20)
        }
      }
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity)
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var profileImage: some View {
      if let imageUrl = store.currentUser.profileImageUrl,
         let url = URL(string: imageUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          case .failure:
            defaultProfileImage
          @unknown default:
            defaultProfileImage
          }
        }
      } else {
        defaultProfileImage
      }
    }

    private var defaultProfileImage: some View {
      Image(systemName: "person.circle.fill")
        .resizable()
        .foregroundColor(Color(.systemGray3))
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
      VStack(spacing: 0) {
        sectionHeader("설정")

        menuRow(
          icon: "bell.fill",
          iconColor: .red,
          title: "알림 설정",
          trailing: {
            AnyView(
              Toggle("", isOn: Binding(
                get: { store.notificationEnabled },
                set: { store.send(.view(.notificationToggled($0))) }
              ))
              .labelsHidden()
            )
          }
        )
      }
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .padding(.horizontal, 16)
    }

    // MARK: - Account Section

    private var accountSection: some View {
      VStack(spacing: 0) {
        sectionHeader("계정")

        menuRow(
          icon: "rectangle.portrait.and.arrow.right",
          iconColor: .orange,
          title: "로그아웃",
          isDestructive: false,
          action: { store.send(.view(.logoutTapped)) }
        )

        Divider()
          .padding(.leading, 52)

        menuRow(
          icon: "person.badge.minus",
          iconColor: .red,
          title: "회원 탈퇴",
          isDestructive: true,
          action: { store.send(.view(.deleteAccountTapped)) }
        )
      }
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .padding(.horizontal, 16)
    }

    // MARK: - Info Section

    private var infoSection: some View {
      VStack(spacing: 0) {
        sectionHeader("정보")

        menuRow(
          icon: "doc.text",
          iconColor: .gray,
          title: "서비스 약관",
          action: { store.send(.view(.termsOfServiceTapped)) }
        )

        Divider()
          .padding(.leading, 52)

        menuRow(
          icon: "hand.raised",
          iconColor: .gray,
          title: "개인정보 처리방침",
          action: { store.send(.view(.privacyPolicyTapped)) }
        )

        Divider()
          .padding(.leading, 52)

        menuRow(
          icon: "info.circle",
          iconColor: .gray,
          title: "앱 버전",
          trailing: {
            AnyView(
              Text(store.state.appVersion)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            )
          }
        )
      }
      .background(Color(.systemBackground))
      .cornerRadius(16)
      .padding(.horizontal, 16)
    }

    // MARK: - Helper Views

    private func sectionHeader(_ title: String) -> some View {
      HStack {
        Text(title)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.secondary)
          .textCase(.uppercase)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 8)
    }

    @ViewBuilder
    private func menuRow(
      icon: String,
      iconColor: Color,
      title: String,
      isDestructive: Bool = false,
      trailing: (() -> AnyView)? = nil,
      action: (() -> Void)? = nil
    ) -> some View {
      Button {
        action?()
      } label: {
        HStack(spacing: 12) {
          Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundColor(iconColor)
            .frame(width: 28, height: 28)

          Text(title)
            .font(.system(size: 17))
            .foregroundColor(isDestructive ? .red : .primary)

          Spacer()

          if let trailing = trailing {
            trailing()
          } else if action != nil {
            Image(systemName: "chevron.right")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(Color(.systemGray3))
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(action == nil && trailing != nil)
    }
  }
}

// MARK: - Edit Profile Feature

@Reducer
public struct EditProfileFeature {
  @Dependency(\.userProfileClient) var userProfileClient
  @Dependency(\.dismiss) var dismiss

  public init() {}

  @ObservableState
  public struct State: Equatable {
    var currentUser: UserPrivateModel
    var nickname: String
    var profileImageData: Data?
    var isNicknameValid: Bool = true
    var nicknameErrorMessage: String?
    var isCheckingNickname: Bool = false
    var isSaving: Bool = false

    public init(currentUser: UserPrivateModel) {
      self.currentUser = currentUser
      self.nickname = currentUser.nickname
    }

    var hasChanges: Bool {
      nickname != currentUser.nickname || profileImageData != nil
    }

    var canSave: Bool {
      hasChanges && isNicknameValid && !isSaving && !isCheckingNickname
    }
  }

  @CasePathable
  public enum Action: Sendable {
    case view(View)
    case `internal`(Internal)
    case delegate(Delegate)

    @CasePathable
    public enum View: Sendable, Equatable {
      case nicknameChanged(String)
      case photoSelected
      case photoLoaded(Data?)
      case saveTapped
      case cancelTapped
    }

    public enum Internal: Sendable, Equatable {
      case nicknameValidated(Result<Bool, Error>)
      case saveCompleted(Result<UserPrivateModel, Error>)

      public static func == (lhs: Internal, rhs: Internal) -> Bool {
        switch (lhs, rhs) {
        case (.nicknameValidated(let lResult), .nicknameValidated(let rResult)):
          switch (lResult, rResult) {
          case (.success(let l), .success(let r)): return l == r
          case (.failure, .failure): return true
          default: return false
          }
        case (.saveCompleted(let lResult), .saveCompleted(let rResult)):
          switch (lResult, rResult) {
          case (.success(let l), .success(let r)): return l == r
          case (.failure, .failure): return true
          default: return false
          }
        default:
          return false
        }
      }
    }

    public enum Delegate: Sendable, Equatable {
      case profileUpdated(UserPrivateModel)
      case dismissed
    }
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.nicknameChanged(let nickname)):
        state.nickname = nickname
        state.nicknameErrorMessage = nil

        // 닉네임 유효성 검사 (인라인)
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
          state.isNicknameValid = false
          state.nicknameErrorMessage = "닉네임을 입력해주세요"
          return .none
        }
        if trimmed.count < 2 {
          state.isNicknameValid = false
          state.nicknameErrorMessage = "닉네임은 2자 이상이어야 합니다"
          return .none
        }
        if trimmed.count > 12 {
          state.isNicknameValid = false
          state.nicknameErrorMessage = "닉네임은 12자 이하여야 합니다"
          return .none
        }
        if trimmed.contains(" ") {
          state.isNicknameValid = false
          state.nicknameErrorMessage = "공백을 포함할 수 없습니다"
          return .none
        }

        // 기존 닉네임과 같으면 검사 안 함
        if nickname == state.currentUser.nickname {
          state.isNicknameValid = true
          return .none
        }

        // 서버에서 중복 검사
        state.isCheckingNickname = true
        return .run { send in
          do {
            let isAvailable = try await userProfileClient.isNicknameAvailable(nickname)
            await send(.internal(.nicknameValidated(.success(isAvailable))))
          } catch {
            await send(.internal(.nicknameValidated(.failure(error))))
          }
        }

      case .view(.photoSelected):
        // PhotosPicker에서 선택 시 onChange로 처리됨
        return .none

      case .view(.photoLoaded(let data)):
        state.profileImageData = data
        return .none

      case .view(.saveTapped):
        guard state.canSave else { return .none }
        state.isSaving = true

        let nickname = state.nickname
        let imageData = state.profileImageData
        let currentUser = state.currentUser

        return .run { send in
          do {
            // 닉네임 변경
            if nickname != currentUser.nickname {
              try await userProfileClient.updateProfile(nickname)
            }

            // 프로필 이미지 변경
            if let imageData {
              _ = try await userProfileClient.updateProfileImage(imageData)
            }

            // 업데이트된 프로필 조회
            let updatedUser = try await userProfileClient.getPrivateProfile(.me)
            await send(.internal(.saveCompleted(.success(updatedUser))))
          } catch {
            await send(.internal(.saveCompleted(.failure(error))))
          }
        }

      case .view(.cancelTapped):
        return .run { send in
          await send(.delegate(.dismissed))
        }

      case .internal(.nicknameValidated(let result)):
        state.isCheckingNickname = false
        switch result {
        case .success(let isAvailable):
          state.isNicknameValid = isAvailable
          if !isAvailable {
            state.nicknameErrorMessage = "이미 사용 중인 닉네임입니다"
          }
        case .failure:
          state.isNicknameValid = true // 에러 시 일단 허용
        }
        return .none

      case .internal(.saveCompleted(let result)):
        state.isSaving = false
        switch result {
        case .success(let user):
          return .run { send in
            await send(.delegate(.profileUpdated(user)))
            await send(.delegate(.dismissed))
          }
        case .failure:
          // TODO: 에러 처리
          return .none
        }

      case .delegate:
        return .none
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable var store: StoreOf<EditProfileFeature>
    @SwiftUI.State private var selectedPhoto: PhotosPickerItem?

    public init(store: StoreOf<EditProfileFeature>) {
      self.store = store
    }

    public var body: some View {
      Form {
        // 프로필 이미지 섹션
        Section {
          HStack {
            Spacer()
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
              ZStack(alignment: .bottomTrailing) {
                profileImageView
                  .frame(width: 100, height: 100)
                  .clipShape(Circle())

                Image(systemName: "camera.circle.fill")
                  .font(.system(size: 28))
                  .foregroundColor(.blue)
                  .background(Color.white)
                  .clipShape(Circle())
              }
            }
            .onChange(of: selectedPhoto) { _, newItem in
              guard let newItem else { return }
              Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                  store.send(.view(.photoLoaded(data)))
                }
              }
            }
            Spacer()
          }
          .listRowBackground(Color.clear)
        }

        // 닉네임 섹션
        Section {
          VStack(alignment: .leading, spacing: 8) {
            TextField("닉네임", text: $store.nickname.sending(\.view.nicknameChanged))
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()

            if store.isCheckingNickname {
              HStack {
                ProgressView()
                  .scaleEffect(0.8)
                Text("확인 중...")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            } else if let errorMessage = store.nicknameErrorMessage {
              Text(errorMessage)
                .font(.caption)
                .foregroundColor(.red)
            }
          }
        } header: {
          Text("닉네임")
        } footer: {
          Text("2~12자, 공백 없이 입력해주세요")
        }
      }
      .navigationTitle("프로필 편집")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            store.send(.view(.cancelTapped))
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          if store.isSaving {
            ProgressView()
          } else {
            Button("저장") {
              store.send(.view(.saveTapped))
            }
            .disabled(!store.canSave)
          }
        }
      }
    }

    @ViewBuilder
    private var profileImageView: some View {
      if let imageData = store.profileImageData,
         let uiImage = UIImage(data: imageData) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
      } else if let imageUrl = store.currentUser.profileImageUrl,
                let url = URL(string: imageUrl) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
          case .success(let image):
            image
              .resizable()
              .scaledToFill()
          case .failure:
            defaultImage
          @unknown default:
            defaultImage
          }
        }
      } else {
        defaultImage
      }
    }

    private var defaultImage: some View {
      Image(systemName: "person.circle.fill")
        .resizable()
        .foregroundColor(Color(.systemGray3))
    }
  }
}
