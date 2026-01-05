//
//  ProfileSetup.swift
//  AppEntryFeature
//
//  Created by 김성원 on 12/9/25.
//

import Foundation
import SwiftUI
import PhotosUI
import PromisoShared
import Clients
import ComposableArchitecture

enum ProfileImageType: Equatable {
  case url(URL)
  case data(Data?)
  case none
}

extension AppEntry {
  @Reducer
  public struct ProfileSetup {
    @Dependency(\.userProfileClient) var userProfileClient
    
    @ObservableState
    public struct State: Equatable {
      public enum Step: Int, CaseIterable, Equatable {
        case welcome = 0
        case nickname = 1
        case photo = 2
      }
      
      // MARK: - Nested States
      
      public struct UIState: Equatable {
        var showAnimation: Bool?
        var showButtons: Bool = false
        var completedSteps: Set<Step> = []
        var previousStep: Step = .welcome
      }
      
      public struct ValidationState: Equatable {
        var nicknameError: String?
        var isCheckingNickname: Bool = false
        var isNicknameAvailable: Bool?
      }
      
      // MARK: - State Properties
      
      // Profile Data
      var selectedPhoto: PhotosPickerItem?
      var profileImage: ProfileImageType
      var email: String?
      var uid: String
      var fullName: String
      var nickname: String = ""
      var providerId: String?
      var providerUid: String?
      var providerType: String?
      
      // Flow State
      var step: Step = .welcome
      var isSaving: Bool = false
      var isSkippingPhoto: Bool = false

      // Nested States
      var ui: UIState = UIState()
      var validation: ValidationState = ValidationState()

      // Alert State
      @Presents var alert: AlertState<Action.Alert>?
      
      // MARK: - Computed Properties for Backward Compatibility
      
      var showAnimation: Bool? {
        get { ui.showAnimation }
        set { ui.showAnimation = newValue }
      }
      
      var showButtons: Bool {
        get { ui.showButtons }
        set { ui.showButtons = newValue }
      }
      
      var completedSteps: Set<Step> {
        get { ui.completedSteps }
        set { ui.completedSteps = newValue }
      }
      
      var previousStep: Step {
        get { ui.previousStep }
        set { ui.previousStep = newValue }
      }
      
      var nicknameError: String? {
        get { validation.nicknameError }
        set { validation.nicknameError = newValue }
      }
      
      var isCheckingNickname: Bool {
        get { validation.isCheckingNickname }
        set { validation.isCheckingNickname = newValue }
      }
      
      var isNicknameAvailable: Bool? {
        get { validation.isNicknameAvailable }
        set { validation.isNicknameAvailable = newValue }
      }
      
      public init(profileImageUrl: String? = nil, email: String = "", uid: String = "", fullName: String = "") {
        if let profileImageUrl, profileImageUrl.isNotEmpty,
           let url = URL(string: profileImageUrl) {
          self.profileImage = .url(url)
        } else {
          self.profileImage = .none
        }
        self.email = email
        self.uid = uid
        self.fullName = fullName
        self.nickname = fullName.replacingOccurrences(of: " ", with: "")
      }
    }
    
    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
      case alert(PresentationAction<Alert>)

      public enum Alert: Equatable {
        case confirmError
      }
    }
    
    public enum ViewAction {
      // Navigation Actions
      case nextTapped
      case backTapped
      case skipTapped
      
      // Input Actions
      case nicknameChanged(String)
      case photoSelected(PhotosPickerItem?)
      
      // Lifecycle Actions
      case stepDidAppear(State.Step)
      case animationCompleted(State.Step)
    }
    
    public enum InternalAction {
      // Profile Save Flow
      case saveProfile
      case profileSaved(UserPrivate)
      case profileSaveFailed(Error)

      // Animation Flow
      case startAnimation(State.Step)

      // Validation Flow
      case nicknameAvailabilityResponse(Result<Bool, Error>)

      // Photo Loading
      case photoLoaded(Data?)
    }
    
    public enum DelegateAction: Equatable {
      case completed(UserPrivate)
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(state: &state, action: viewAction)

        case .internal(let internalAction):
          return handleInternalAction(state: &state, action: internalAction)

        case .delegate:
          return .none

        case .alert:
          return .none
        }
      }
      .ifLet(\.$alert, action: \.alert)
    }
    
    private func handleViewAction(state: inout State, action: ViewAction) -> Effect<Action> {
      switch action {
      case .nextTapped:
        if state.isSaving { return .none }
        switch state.step {
        case .welcome:
          state.previousStep = state.step
          state.step = .nickname
          prepareUIState(for: &state, step: .nickname)
          return .none
        case .nickname:
          // Shared Layer의 검증 로직 사용
          if let error = UserPublic.validateNickname(state.nickname) {
            state.nicknameError = error.message
            return .none
          }
          if state.isNicknameAvailable != true {
            state.nicknameError = "닉네임 중복 확인을 완료해주세요"
            return .none
          }
          state.previousStep = state.step
          state.step = .photo
          prepareUIState(for: &state, step: .photo)
          return .none
        case .photo:
          return .send(.internal(.saveProfile))
        }
        
      case .backTapped:
        switch state.step {
        case .welcome:
          return .none
        case .nickname:
          state.previousStep = state.step
          state.step = .welcome
          prepareUIState(for: &state, step: .welcome)
          return .none
        case .photo:
          state.previousStep = state.step
          state.step = .nickname
          prepareUIState(for: &state, step: .nickname)
          return .none
        }
        
      case .skipTapped:
        if state.isSaving { return .none }
        state.isSkippingPhoto = true
        return .send(.internal(.saveProfile))
        
      case .nicknameChanged(let name):
        state.nickname = name
        // Shared Layer의 검증 로직 사용
        state.nicknameError = UserPublic.validateNickname(name)?.message
        state.isNicknameAvailable = nil

        guard state.nicknameError == nil, !name.isEmpty else {
          state.isCheckingNickname = false
          return .cancel(id: CancelID.nicknameCheck)
        }
        
        state.isCheckingNickname = true
        return .run { [nickname = name] send in
          try await Task.sleep(for: .milliseconds(400))
          do {
            let isAvailable = try await userProfileClient.isNicknameAvailable(nickname)
            await send(.internal(.nicknameAvailabilityResponse(.success(isAvailable))))
          } catch {
            await send(.internal(.nicknameAvailabilityResponse(.failure(error))))
          }
        }
        .cancellable(id: CancelID.nicknameCheck, cancelInFlight: true)
        
      case .photoSelected(let item):
        guard let item else { return .none }
        return .run { send in
          if let data = try? await item.loadTransferable(type: Data.self) {
            await send(.internal(.photoLoaded(data)))
          }
        }
        
      case .stepDidAppear(let step):
        // step이 변경되어 화면에 나타날 때 애니메이션 상태 초기화
        let isFirstVisit = !state.completedSteps.contains(step)
        if isFirstVisit {
          return .run { send in
            try await Task.sleep(for: .seconds(0.1))
            await send(.internal(.startAnimation(step)))
          }
        } else {
          return .none
        }
        
      case .animationCompleted(let step):
        // 애니메이션 완료 시 버튼 표시
        state.completedSteps.insert(step)
        state.showButtons = true
        return .none
      }
    }
    
    private func handleInternalAction(state: inout State, action: InternalAction) -> Effect<Action> {
      switch action {
      case .photoLoaded(let data):
        state.profileImage = .data(data)
        return .none
        
      case .nicknameAvailabilityResponse(let result):
        state.isCheckingNickname = false
        switch result {
        case .success(let isAvailable):
          state.isNicknameAvailable = isAvailable
          state.nicknameError = isAvailable ? nil : "이미 사용 중인 닉네임이에요"
        case .failure:
          state.isNicknameAvailable = nil
          state.nicknameError = "닉네임 확인에 실패했어요. 잠시 후 다시 시도해주세요"
        }
        return .none
        
      case .saveProfile:
        state.isSaving = true
        return .run { [state] send in
          // Provider 정보 추출
          guard let providerType = state.providerType ?? state.providerId?.providerTypeIdentifier else {
            let error = NSError(domain: "ProfileSetup", code: -1, userInfo: [
              NSLocalizedDescriptionKey: "Provider type is missing"
            ])
            await send(.internal(.profileSaveFailed(error)))
            return
          }
          let providerUid = state.providerUid ?? state.uid
          let email = state.email ?? ""

          // 프로필 이미지 데이터 추출
          let imageData: Data? = if !state.isSkippingPhoto, case .data(let data) = state.profileImage {
            data
          } else {
            nil
          }

          // 사용자 생성 + 프로필 이미지 업로드 + 조회 (Client에서 일괄 처리)
          do {
            let userModel = try await userProfileClient.createUserWithProfile(
              state.fullName,
              state.nickname,
              providerType,
              providerUid,
              email,
              imageData
            )
            await send(.internal(.profileSaved(userModel)))
          } catch let error as UserProfileError {
            // uploadFailed 에러는 무시하고 프로필 조회만 시도
            if error == .uploadFailed {
              print("⚠️ Profile image upload failed, continuing without image...")
              do {
                // 이미지 없이 프로필 조회 (프로필은 이미 생성됨)
                let userModel = try await userProfileClient.getPrivateProfile(.me)
                await send(.internal(.profileSaved(userModel)))
              } catch {
                await send(.internal(.profileSaveFailed(error)))
              }
            } else {
              // 그 외 에러는 실패 처리
              await send(.internal(.profileSaveFailed(error)))
            }
          } catch {
            // 알 수 없는 에러도 실패 처리
            await send(.internal(.profileSaveFailed(error)))
          }
        }
        
      case .profileSaved(let profile):
        state.isSaving = false
        state.isSkippingPhoto = false
        return .send(.delegate(.completed(profile)))
        
      case .profileSaveFailed(let error):
        state.isSaving = false
        state.isSkippingPhoto = false
        print("❌ Profile save failed: \(error.localizedDescription)")

        state.alert = AlertState {
          TextState("프로필 저장 실패")
        } actions: {
          ButtonState(role: .cancel) {
            TextState("확인")
          }
        } message: {
          TextState(error.localizedDescription)
        }

        return .none
        
      case .startAnimation:
        state.showAnimation = true
        return .none
      }
    }
    
    // MARK: - UI Helpers
    
    private func prepareUIState(for state: inout State, step: State.Step) {
      let isVisited = state.completedSteps.contains(step)
      state.showAnimation = isVisited ? false : nil
      state.showButtons = isVisited
    }
    
    public struct View: SwiftUI.View {
      @Bindable private var store: StoreOf<ProfileSetup>
      private let indicatorCount: Int = State.Step.allCases.count
      
      public init(store: StoreOf<ProfileSetup>) {
        self.store = store
      }
      
      public var body: some SwiftUI.View {
        VStack(spacing: 0) {
          pagingIndicator
          
          ZStack {
            switch store.step {
            case .welcome:
              WelcomeStepView(
                fullName: store.fullName,
                showAnimation: store.showAnimation,
                showButtons: store.showButtons,
                onAnimationCompleted: {
                  store.send(.view(.animationCompleted(.welcome)))
                },
                onNextTapped: {
                  store.send(.view(.nextTapped))
                }
              )

            case .nickname:
              NicknameStepView(
                nickname: store.nickname,
                nicknameError: store.nicknameError,
                isCheckingNickname: store.isCheckingNickname,
                isNicknameAvailable: store.isNicknameAvailable,
                showAnimation: store.showAnimation,
                showButtons: store.showButtons,
                onAnimationCompleted: {
                  store.send(.view(.animationCompleted(.nickname)))
                },
                onNicknameChanged: { newValue in
                  store.send(.view(.nicknameChanged(newValue)))
                },
                onNextTapped: {
                  store.send(.view(.nextTapped))
                },
                onBackTapped: {
                  store.send(.view(.backTapped))
                }
              )

            case .photo:
              PhotoStepView(
                profileImage: store.profileImage,
                selectedPhoto: store.selectedPhoto,
                isSaving: store.isSaving,
                showAnimation: store.showAnimation,
                showButtons: store.showButtons,
                onAnimationCompleted: {
                  store.send(.view(.animationCompleted(.photo)))
                },
                onPhotoSelected: { item in
                  store.send(.view(.photoSelected(item)))
                },
                onNextTapped: {
                  store.send(.view(.nextTapped))
                },
                onSkipTapped: {
                  store.send(.view(.skipTapped))
                },
                onBackTapped: {
                  store.send(.view(.backTapped))
                }
              )
            }
          }
        }
        .toolbarVisibility(.visible, for: .navigationBar)
        .auroraBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: store.step) {
          store.send(.view(.stepDidAppear(store.step)))
        }
        .alert($store.scope(state: \.alert, action: \.alert))
      }
      
      private var pagingIndicator: some SwiftUI.View {
        PagingIndicator(
          count: indicatorCount,
          progress: Double(store.step.rawValue),
          activeColor: Color(red: 0.6, green: 0.4, blue: 0.9)
        )
        .frame(maxWidth: .infinity, maxHeight: 10, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.85), value: store.step)
      }
    }
  }
}

private struct PhotoSection: SwiftUI.View {
  let profileImage: ProfileImageType
  @Binding var selectedPhoto: PhotosPickerItem?
  let onPhotoSelected: (PhotosPickerItem?) -> Void
  
  var body: some SwiftUI.View {
    VStack(spacing: 24) {
      ZStack(alignment: .bottomTrailing) {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
          ZStack {
            // 점선 테두리
            Circle()
              .strokeBorder(
                style: StrokeStyle(lineWidth: 2, dash: [8, 4])
              )
              .foregroundStyle(Color(.systemGray4))
              .frame(width: 120, height: 120)
            
            profileImageView
          }
        }
        .onChange(of: selectedPhoto) { _, newValue in
          onPhotoSelected(newValue)
        }
        
        // 이미지 선택 후 편집 버튼
        if case .data = profileImage {
          PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Circle()
              .fill(Color.pmindigo.n500)
              .frame(width: 32, height: 32)
              .overlay {
                Image(systemName: "pencil")
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundStyle(Color.white)
              }
          }
          .onChange(of: selectedPhoto) { _, newValue in
            onPhotoSelected(newValue)
          }
          .offset(x: -4, y: -4)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
  
  private var profileImageView: some SwiftUI.View {
    Group {
      switch profileImage {
      case .url(let url):
        AsyncImage(url: url) { image in
          image
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } placeholder: {
          ProgressView()
        }
      case .data(let data):
        if let data, let image = UIImage(data: data) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
          emptyImageView
        }
      case .none:
        emptyImageView
      }
    }
  }
  
  private var emptyImageView: some SwiftUI.View {
    Circle()
      .fill(Color(.systemGray6))
      .frame(width: 120, height: 120)
      .overlay {
        VStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(Color(.systemGray3))
          Text("사진 선택")
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.pmtext.primary.opacity(0.8))
        }
      }
  }
}

// MARK: - Step1: Welcome
private struct WelcomeStepView: SwiftUI.View {
  // Data
  let fullName: String
  let showAnimation: Bool?
  let showButtons: Bool
  
  // Actions
  let onAnimationCompleted: () -> Void
  let onNextTapped: () -> Void
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        TypewriterLinesView(
          animated: showAnimation,
          lines: [
            .init(
              text: "반가워요! 👋",
              font: .system(size: 38, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "안녕하세요 \(fullName.isEmpty ? "," : "\(fullName) 님,")",
              font: .system(size: 25, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            ),
            .init(
              text: "Promiso를 시작하기 전에",
              font: .system(size: 25, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            ),
            .init(
              text: "간단한 정보를 입력해주세요",
              font: .system(size: 25, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            )
          ],
          typingAnimationCompleted: onAnimationCompleted,
          lineSpacingProvider: { line in
            return line == 0 ? 8 : 4
          },
          lineDelayProvider: { line in
            return line == 0 ? 1.0 : 0.3
          }
        )
        .id("welcome-\(String(describing: showAnimation))")
      }
      .padding(.horizontal, 24)
      .padding(.top, 12)
      
      Spacer()
      
      GlassActionButton(
        title: "시작하기",
        isVisible: showButtons,
        action: onNextTapped
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
  }
}

// MARK: - Step2: Nickname
private struct NicknameStepView: SwiftUI.View {
  // Data
  let nickname: String
  let nicknameError: String?
  let isCheckingNickname: Bool
  let isNicknameAvailable: Bool?
  let showAnimation: Bool?
  let showButtons: Bool
  
  // Actions
  let onAnimationCompleted: () -> Void
  let onNicknameChanged: (String) -> Void
  let onNextTapped: () -> Void
  let onBackTapped: () -> Void
  
  // Local State
  @SwiftUI.State private var localNickname: String
  @SwiftUI.State private var showTextField: Bool = false
  @FocusState private var isNicknameFocused: Bool
  
  init(
    nickname: String,
    nicknameError: String?,
    isCheckingNickname: Bool,
    isNicknameAvailable: Bool?,
    showAnimation: Bool?,
    showButtons: Bool,
    onAnimationCompleted: @escaping () -> Void,
    onNicknameChanged: @escaping (String) -> Void,
    onNextTapped: @escaping () -> Void,
    onBackTapped: @escaping () -> Void
  ) {
    self.nickname = nickname
    self.nicknameError = nicknameError
    self.isCheckingNickname = isCheckingNickname
    self.isNicknameAvailable = isNicknameAvailable
    self.showAnimation = showAnimation
    self.showButtons = showButtons
    self.onAnimationCompleted = onAnimationCompleted
    self.onNicknameChanged = onNicknameChanged
    self.onNextTapped = onNextTapped
    self.onBackTapped = onBackTapped
    self._localNickname = State(initialValue: nickname.replacingOccurrences(of: " ", with: ""))
  }
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        TypewriterLinesView(
          animated: showAnimation,
          lines: [
            .init(
              text: "어떻게 불러드릴까요?",
              font: .system(size: 38, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "Promiso에서 사용할",
              font: .system(size: 25, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            ),
            .init(
              text: "닉네임을 알려주세요",
              font: .system(size: 25, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            )
          ],
          typingAnimationCompleted: handleAnimationCompleted,
          lineSpacingProvider: { line in
            return line == 0 ? 8 : 4
          },
          lineDelayProvider: { line in
            return line == 0 ? 1.0 : 0.3
          }
        )
        .id("nickname-\(String(describing: showAnimation))")
      }
      .padding(.horizontal, 24)
      .padding(.top, 12)
      
      if showTextField {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("닉네임")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.primary)
            
            TextField("2-12자 이내로 입력해주세요", text: $localNickname)
              .onChange(of: localNickname) { _, newValue in
                onNicknameChanged(newValue)
              }
              .focused($isNicknameFocused)
              .textFieldStyle(.roundedBorder)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(borderColor, lineWidth: 1)
              )
          }
          
          HStack {
            nicknameStatusView
            
            Spacer()
            
            Text("\(localNickname.count)/12")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
      }
      
      Spacer()
      
      GlassActionButton(
        title: "다음",
        isVisible: showButtons,
        isEnabled: nicknameError == nil
        && nickname.count >= 2
        && nickname.count <= 12
        && isNicknameAvailable == true
        && !isCheckingNickname,
        action: handleNextTapped
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
    .onAppear {
      updateTextFieldVisibility(for: showAnimation)
      triggerInitialNicknameCheckIfNeeded()
    }
    .onChange(of: nickname) { _, newValue in
      localNickname = newValue
    }
    .toolbar {
      if showButtons {
        ToolbarItem(placement: .topBarLeading) {
          ToolbarButton(
            imageName: "chevron.left",
            action: handleBackTapped
          )
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
        }
      }
    }
  }

  // MARK: - Helper Methods

  private func handleNextTapped() {
    if isNicknameFocused {
      isNicknameFocused = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        onNextTapped()
      }
    } else {
      onNextTapped()
    }
  }

  private func handleBackTapped() {
    if isNicknameFocused {
      isNicknameFocused = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        onBackTapped()
      }
    } else {
      onBackTapped()
    }
  }
  
  private var borderColor: Color {
    if localNickname.isEmpty {
      return Color(.systemGray4)
    } else if let error = nicknameError, !error.isEmpty {
      return .red
    } else {
      return .blue
    }
  }
  
  @ViewBuilder
  private var nicknameStatusView: some SwiftUI.View {
    if localNickname.isEmpty {
      EmptyView()
    } else if let error = nicknameError, !error.isEmpty {
      Text(error)
        .font(.footnote)
        .foregroundStyle(.red)
    } else if isCheckingNickname {
      HStack(spacing: 6) {
        ProgressView()
          .scaleEffect(0.6, anchor: .center)
        Text("닉네임 확인 중...")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    } else if isNicknameAvailable == false {
      Text("이미 사용 중인 닉네임이에요")
        .font(.footnote)
        .foregroundStyle(.red)
    } else if isNicknameAvailable == true {
      HStack(spacing: 4) {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.footnote)
        Text("사용 가능한 닉네임이에요")
          .font(.footnote)
          .foregroundStyle(.green)
      }
    } else {
      Text("닉네임 중복 확인을 완료해주세요")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }
  
  private func handleAnimationCompleted() {
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
      showTextField = true
    }
    focusNicknameIfNeeded()
    onAnimationCompleted()
  }
  
  private func updateTextFieldVisibility(for animationState: Bool?) {
    switch animationState {
    case false:
      // 이미 완료된 단계는 애니메이션 없이 바로 표시
      showTextField = true
    case nil:
      showTextField = false
    default:
      break
    }
  }
  
  private func triggerInitialNicknameCheckIfNeeded() {
    guard !localNickname.isEmpty,
          isNicknameAvailable == nil,
          !isCheckingNickname else { return }
    onNicknameChanged(localNickname)
  }
  
  private func focusNicknameIfNeeded() {
    guard showTextField else { return }
    isNicknameFocused = true
  }
}

// MARK: - Step3: Profile
private struct PhotoStepView: SwiftUI.View {
  // Data
  let profileImage: ProfileImageType
  let selectedPhoto: PhotosPickerItem?
  let isSaving: Bool
  let showAnimation: Bool?
  let showButtons: Bool
  
  // Actions
  let onAnimationCompleted: () -> Void
  let onPhotoSelected: (PhotosPickerItem?) -> Void
  let onNextTapped: () -> Void
  let onSkipTapped: () -> Void
  let onBackTapped: () -> Void
  
  // Local State
  @SwiftUI.State private var localSelectedPhoto: PhotosPickerItem?
  @SwiftUI.State private var showPhotoSection: Bool = false
  
  init(
    profileImage: ProfileImageType,
    selectedPhoto: PhotosPickerItem?,
    isSaving: Bool,
    showAnimation: Bool?,
    showButtons: Bool,
    onAnimationCompleted: @escaping () -> Void,
    onPhotoSelected: @escaping (PhotosPickerItem?) -> Void,
    onNextTapped: @escaping () -> Void,
    onSkipTapped: @escaping () -> Void,
    onBackTapped: @escaping () -> Void
  ) {
    self.profileImage = profileImage
    self.selectedPhoto = selectedPhoto
    self.isSaving = isSaving
    self.showAnimation = showAnimation
    self.showButtons = showButtons
    self.onAnimationCompleted = onAnimationCompleted
    self.onPhotoSelected = onPhotoSelected
    self.onNextTapped = onNextTapped
    self.onSkipTapped = onSkipTapped
    self.onBackTapped = onBackTapped
    self._localSelectedPhoto = State(initialValue: selectedPhoto)
  }
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        TypewriterLinesView(
          animated: showAnimation,
          lines: [
            .init(
              text: "프로필 사진을 설정해 주세요",
              font: .system(size: 30, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "나중에 설정에서 변경할 수 있어요",
              font: .system(size: 24, weight: .medium, design: .serif),
              style: AnyShapeStyle(Color.pmtext.secondary)
            )
          ],
          typingAnimationCompleted: handleAnimationCompleted,
          lineSpacingProvider: { _ in 8 },
          lineDelayProvider: { line in
            return line == 0 ? 1.0 : 0.3
          }
        )
        .id("photo-\(String(describing: showAnimation))")
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 24)
      .padding(.top, 12)
      
      Spacer()
      
      if showPhotoSection {
        PhotoSection(
          profileImage: profileImage,
          selectedPhoto: $localSelectedPhoto,
          onPhotoSelected: onPhotoSelected
        )
        .padding(.horizontal, 24)
      }
      
      Spacer()
      
      if showButtons {
        VStack(spacing: 15) {
          GlassActionButton(
            title: isSaving ? "저장중..." : "완료",
            isPrimary: true,
            isVisible: showButtons,
            isEnabled: !isSaving,
            action: {
              guard !isSaving else { return }
              onNextTapped()
            }
          )
          .overlay(alignment: .trailing) {
            if isSaving {
              ProgressView()
                .tint(.white)
                .padding(.trailing, 16)
            }
          }
          .offset(y: showButtons ? 0 : 20)
          
          Button {
            onSkipTapped()
          } label: {
            Text("나중에 설정할게요")
              .font(.callout.weight(.semibold))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .opacity(showButtons ? 1 : 0)
          .disabled(isSaving)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
      }
      
      
    }
    .onAppear {
      updatePhotoSectionVisibility(for: showAnimation)
    }
    .onChange(of: selectedPhoto) { _, newValue in
      localSelectedPhoto = newValue
    }
    .toolbar {
      if showButtons {
        ToolbarItem(placement: .topBarLeading) {
          ToolbarButton(
            imageName: "chevron.left",
            action: onBackTapped
          )
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
        }
      }
    }
  }
  
  private func handleAnimationCompleted() {
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
      showPhotoSection = true
    }
    onAnimationCompleted()
  }
  
  private func updatePhotoSectionVisibility(for animationState: Bool?) {
    switch animationState {
    case false:
      // 이미 완료된 단계는 바로 표시
      showPhotoSection = true
    case nil:
      showPhotoSection = false
    default:
      break
    }
  }
}

// MARK: - Effects ID

private enum CancelID {
  case nicknameCheck
}
