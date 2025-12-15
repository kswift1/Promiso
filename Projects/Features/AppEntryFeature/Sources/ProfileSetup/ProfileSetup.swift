//
//  ProfileSetup.swift
//  AppEntryFeature
//
//  Created by 김성원 on 12/9/25.
//

/// TODO: 업로드중일떄 버튼 인디케이터는 동작하나 완료에서 인디케이터라 어색함
/// 프로필 사진 업로드할떄 구글로 이미지 가지고 들어오는 경우 나중에 할게요 눌러도 세팅값으로 넘어가는 문제, 그외 나중에 할게요 대응 필요

import Foundation
import SwiftUI
import PhotosUI
import Shared
import ResourceKit
import Clients
import ComposableArchitecture
import CoreInfrastructure

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
      
      // Flow State
      var step: Step = .welcome
      var isSaving: Bool = false
      
      // Nested States
      var ui: UIState = UIState()
      var validation: ValidationState = ValidationState()
      
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
        self.nickname = fullName.isEmpty ? "" : fullName
      }
    }
    
    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
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
      case profileSaved
      case profileSaveFailed(Error)
      
      // Animation Flow
      case startAnimation(State.Step)
      
      // Validation Flow
      case nicknameAvailabilityResponse(Result<Bool, Error>)
      
      // Photo Loading
      case photoLoaded(Data?)
    }
    
    public enum DelegateAction: Equatable {
      case completed
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
        }
      }
    }
    
    private func handleViewAction(state: inout State, action: ViewAction) -> Effect<Action> {
      switch action {
      case .nextTapped:
        if state.isSaving { return .none }
        switch state.step {
        case .welcome:
          state.previousStep = state.step
          state.step = .nickname
          return .none
        case .nickname:
          if let error = validateNickname(state.nickname) {
            state.nicknameError = error
            return .none
          }
          if state.isNicknameAvailable != true {
            state.nicknameError = "닉네임 중복 확인을 완료해주세요"
            return .none
          }
          state.previousStep = state.step
          state.step = .photo
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
          return .none
        case .photo:
          state.previousStep = state.step
          state.step = .nickname
          return .none
        }
        
      case .skipTapped:
        if state.isSaving { return .none }
        state.profileImage = .none
        state.selectedPhoto = nil
        return .send(.internal(.saveProfile))
        
      case .nicknameChanged(let name):
        state.nickname = name
        state.nicknameError = validateNickname(name)
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
        if state.completedSteps.contains(step) {
          // 이미 완료된 step이면 애니메이션 없이 바로 표시
          state.showAnimation = false
          state.showButtons = true
        } else {
          // 새로운 step이면 애니메이션 준비
          state.showAnimation = nil
          state.showButtons = false
          return .run { send in
            try await Task.sleep(for: .seconds(0.1))
            await send(.internal(.startAnimation(step)))
          }
        }
        return .none
        
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
          do {
            // 1. 프로필 이미지가 있으면 업로드
            var profileImageUrl: String? = nil
            var profileImagePath: String? = nil
            var profileType: ProfileType = .firebase
            switch state.profileImage {
            case .data(let data):
              if let imageData = data {
                let uploadData = compressImageDataForUpload(imageData) ?? imageData
                _ = try await userProfileClient.uploadProfileImage(state.uid, uploadData)
                profileImagePath = "profile_images/\(state.uid).jpg"
                profileType = .firebase
              }
            case .url(let url):
              profileImageUrl = url.absoluteString
              profileType = .url
            case .none:
              profileImageUrl = nil
              profileImagePath = nil
              profileType = .firebase
            }
            
            // 2. UserProfile 생성
            let profile = UserProfile(
              name: state.fullName,
              nickname: state.nickname,
              email: state.email,
              profileType: profileType,
              profileImageUrl: profileImageUrl,
              profileImagePath: profileImagePath,
              pinnedGroupId: nil,
              notificationSettings: .default,
              createdAt: Date(),
              updatedAt: Date()
            )
            
            // 3. Firestore에 저장
            try await userProfileClient.saveProfile(state.uid, profile)
            
            await send(.internal(.profileSaved))
          } catch {
            await send(.internal(.profileSaveFailed(error)))
          }
        }
        
      case .profileSaved:
        state.isSaving = false
        return .send(.delegate(.completed))
        
      case .profileSaveFailed(let error):
        state.isSaving = false
        print("❌ Profile save failed: \(error)")
        return .none
        
      case .startAnimation:
        state.showAnimation = true
        return .none
      }
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
              .transition(stepTransition)
              
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
              .transition(stepTransition)
              
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
              .transition(stepTransition)
            }
          }
          //          .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.9), value: store.step)
        }
        .toolbarVisibility(.visible, for: .navigationBar)
        .animation(.easeInOut, value: store.step)
        .auroraBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: store.step) {
          store.send(.view(.stepDidAppear(store.step)))
        }
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
      
      private var stepTransition: AnyTransition {
        let isForward = store.step.rawValue > store.previousStep.rawValue
        let insertionEdge: Edge = isForward ? .trailing : .leading
        let removalEdge: Edge = isForward ? .leading : .trailing
        return .asymmetric(
          insertion: .move(edge: insertionEdge).combined(with: .opacity),
          removal: .move(edge: removalEdge).combined(with: .opacity)
        )
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
              .fill(Color.blue)
              .frame(width: 32, height: 32)
              .overlay {
                Image(systemName: "pencil")
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundStyle(.white)
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
          lineSpacingProvider: { index in
            switch index {
            case 0: return 8
            default: return 4
            }
          }
        )
        .id("welcome-\(showAnimation ?? false)")
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
    self._localNickname = State(initialValue: nickname)
  }
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        TypewriterLinesView(
          animated: showAnimation,
          lines: [
            .init(
              text: "어떻게 불러드릴까요?",
              font: .system(size: 28, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "Promiso에서 사용할 닉네임을 알려주세요",
              font: .system(size: 17, weight: .regular, design: .default),
              style: AnyShapeStyle(Color.pmtext.secondary)
            )
          ],
          typingAnimationCompleted: handleAnimationCompleted,
          lineSpacingProvider: { _ in 6 }
        )
        .id("nickname-\(showAnimation ?? false)")
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
        action: {
          isNicknameFocused = false
          onNextTapped()
        }
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
            action: onBackTapped
          )
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
        }
      }
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
      Text("공백 없이 2-12자로 입력해주세요")
        .font(.footnote)
        .foregroundStyle(.secondary)
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
      // 이미 완료된 단계는 바로 표시
      showTextField = true
      focusNicknameIfNeeded()
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

private extension AppEntry.ProfileSetup.State {
  
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
              text: "프로필 사진을 설정해주세요",
              font: .system(size: 28, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "나중에 설정에서 변경할 수 있어요",
              font: .system(size: 17, weight: .regular, design: .default),
              style: AnyShapeStyle(Color.pmtext.secondary)
            )
          ],
          typingAnimationCompleted: handleAnimationCompleted,
          lineSpacingProvider: { _ in 6 }
        )
        .id("photo-\(showAnimation ?? false)")
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      
      Spacer()
      
      if showButtons {
        VStack(spacing: 15) {
          IndicatorButton(
            isSaving ? "저장중..." : "완료",
            isLoading: isSaving,
            isDisabled: !showButtons || isSaving,
            style: .primary,
            indicatorPosition: .trailing,
            action: onNextTapped
          )
          .opacity(showButtons ? 1 : 0)
          .offset(y: showButtons ? 0 : 20)
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
          
          Button {
            onSkipTapped()
          } label: {
            Text("나중에 설정할게요")
              .font(.body.weight(.semibold))
              .foregroundStyle(Color.pmtext.primary)
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

// MARK: - Glass Action Button

private struct GlassActionButton: SwiftUI.View {
  let title: String
  var isPrimary: Bool = true
  var isVisible: Bool = true
  var isEnabled: Bool = true
  let action: () -> Void
  
  var body: some SwiftUI.View {
    Group {
      if #available(iOS 26.0, *) {
        // 리퀴드 글래스 버전
        Button(action: action) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(isPrimary ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .glassEffect(
              .regular
                .tint(
                  isPrimary
                  ? .pmindigo.n500.opacity(0.74)   // 조금 더 투명한 느낌
                  : .purple.opacity(0.14)
                )
                .interactive(),
              in: .rect(cornerRadius: 14)
            )
            .shadow(
              color: isPrimary
              ? Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.28)
              : Color.black.opacity(0.1),
              radius: 12,
              y: 6
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
      } else {
        // MARK: - Fallback: 기존 커스텀 글래스 스타일
        Button(action: action) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(isPrimary ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
              ZStack {
                if isPrimary {
                  LinearGradient(
                    colors: [
                      Color(red: 0.6, green: 0.4, blue: 0.9),
                      Color(red: 0.5, green: 0.3, blue: 0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                } else {
                  Color.clear
                }
                
                LinearGradient(
                  colors: [
                    Color.white.opacity(isPrimary ? 0.2 : 0.1),
                    Color.white.opacity(0)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              }
            )
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(
                  LinearGradient(
                    colors: [
                      Color.white.opacity(isPrimary ? 0.3 : 0.2),
                      Color.white.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ),
                  lineWidth: 1
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
              color: isPrimary
              ? Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.3)
              : Color.clear,
              radius: 12,
              y: 6
            )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
      }
    }
  }
}

// MARK: - Effects ID

private enum CancelID {
  case nicknameCheck
}


// MARK: - Nickname Validation

private func validateNickname(_ name: String) -> String? {
  let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
  
  if trimmed.count < 2 { return "2자 이상 입력해주세요" }
  if trimmed.count > 12 { return "12자 이하로 입력해주세요" }
  if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return "닉네임엔 공백을 넣을 수 없어요" }
  if trimmed != name { return "앞뒤 공백 없이 입력해주세요" }
  return nil
}
