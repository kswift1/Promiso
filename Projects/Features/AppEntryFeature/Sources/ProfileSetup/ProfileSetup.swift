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
      case profileSaved(UserPrivateModel)
      case profileSaveFailed(Error)

      // Animation Flow
      case startAnimation(State.Step)

      // Validation Flow
      case nicknameAvailabilityResponse(Result<Bool, Error>)

      // Photo Loading
      case photoLoaded(Data?)
    }
    
    public enum DelegateAction: Equatable {
      case completed(UserPrivateModel)
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .nextTapped:
            if state.isSaving { return .none }
            // 닉네임 검증 후 바로 저장
            if let error = UserPublicModel.validateNickname(state.nickname) {
              state.nicknameError = error.message
              return .none
            }
            if state.isNicknameAvailable != true {
              state.nicknameError = LocalizedStrings.Profile.nicknameCheckRequired
              return .none
            }
            return .send(.internal(.saveProfile))

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
            state.nicknameError = UserPublicModel.validateNickname(name)?.message
            state.isNicknameAvailable = nil

            guard state.nicknameError == nil, !name.isEmpty else {
              state.isCheckingNickname = false
              return .cancel(id: CancelID.nicknameCheck)
            }

            state.isCheckingNickname = true
            return .run { [nickname = name] send in
              try await Task.sleep(for: .milliseconds(500))
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

        case .internal(let internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.profileImage = .data(data)
            return .none

          case .nicknameAvailabilityResponse(let result):
            state.isCheckingNickname = false
            switch result {
            case .success(let isAvailable):
              state.isNicknameAvailable = isAvailable
              state.nicknameError = isAvailable ? nil : LocalizedStrings.Profile.nicknameTaken
            case .failure:
              state.isNicknameAvailable = nil
              state.nicknameError = LocalizedStrings.Profile.nicknameCheckFailed
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
              } catch {
                if let userProfileError = error as? UserProfileError, userProfileError == .uploadFailed {
                  // uploadFailed 에러는 무시하고 프로필 조회만 시도
                  AppLogger.general.warning("Profile image upload failed, continuing without image")
                  do {
                    let userModel = try await userProfileClient.getPrivateProfile(.me)
                    await send(.internal(.profileSaved(userModel)))
                  } catch let fetchError {
                    await send(.internal(.profileSaveFailed(fetchError)))
                  }
                } else {
                  await send(.internal(.profileSaveFailed(error)))
                }
              }
            }

          case .profileSaved(let profile):
            state.isSaving = false
            state.isSkippingPhoto = false
            return .send(.delegate(.completed(profile)))

          case .profileSaveFailed(let error):
            state.isSaving = false
            state.isSkippingPhoto = false
            AppLogger.general.error("Profile save failed: \(error.localizedDescription)")

            state.alert = AlertState {
              TextState(LocalizedStrings.Profile.saveFailed)
            } actions: {
              ButtonState(role: .cancel) {
                TextState("확인")
              }
            } message: {
              TextState((error as? UserProfileError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)
            }

            return .none

          case .startAnimation:
            state.showAnimation = true
            return .none
          }

        case .delegate:
          return .none

        case .alert:
          return .none
        }
      }
      .ifLet(\.$alert, action: \.alert)
    }
    
    // MARK: - UI Helpers
    
    private func prepareUIState(for state: inout State, step: State.Step) {
      let isVisited = state.completedSteps.contains(step)
      state.showAnimation = isVisited ? false : nil
      state.showButtons = isVisited
    }
    
    public struct View: SwiftUI.View {
      @Bindable private var store: StoreOf<ProfileSetup>

      @SwiftUI.State private var localNickname: String = ""
      @SwiftUI.State private var localSelectedPhoto: PhotosPickerItem?
      @FocusState private var isNicknameFocused: Bool

      public init(store: StoreOf<ProfileSetup>) {
        self.store = store
      }

      public var body: some SwiftUI.View {
        VStack(spacing: 0) {
          Spacer()
            .frame(height: 60)

          // 타이틀
          VStack(spacing: 8) {
            Text(LocalizedStrings.Profile.setupTitle1)
              .font(.title2.bold())
              .foregroundStyle(Color.pmtext.primary)
            Text(LocalizedStrings.Profile.setupTitle2)
              .font(.title2.bold())
              .foregroundStyle(Color.pmtext.primary)
          }
          .padding(.bottom, 32)

          // 프로필 사진
          PhotoSection(
            profileImage: store.profileImage,
            selectedPhoto: $localSelectedPhoto,
            onPhotoSelected: { item in
              store.send(.view(.photoSelected(item)))
            }
          )
          .padding(.horizontal, 24)

          // 닉네임 입력
          VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text(LocalizedStrings.Profile.nickname)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

              TextField(LocalizedStrings.Profile.nicknamePlaceholder, text: $localNickname)
                .onChange(of: localNickname) { _, newValue in
                  store.send(.view(.nicknameChanged(newValue)))
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
          .padding(.top, 8)

          Spacer()

          // 완료 버튼
          VStack(spacing: 15) {
            GlassActionButton(
              title: store.isSaving ? LocalizedStrings.Profile.saving : LocalizedStrings.Common.done,
              isPrimary: true,
              isEnabled: store.nicknameError == nil
                && store.nickname.count >= 2
                && store.nickname.count <= 12
                && store.isNicknameAvailable == true
                && !store.isCheckingNickname
                && !store.isSaving,
              action: {
                isNicknameFocused = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                  store.send(.view(.nextTapped))
                }
              }
            )
            .overlay(alignment: .trailing) {
              if store.isSaving {
                ProgressView()
                  .tint(.white)
                  .padding(.trailing, 16)
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 32)
        }
        .navigationBarBackButtonHidden()
        .auroraBackground()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
          localNickname = store.nickname.replacingOccurrences(of: " ", with: "")
          if !localNickname.isEmpty {
            store.send(.view(.nicknameChanged(localNickname)))
          }
        }
        .onChange(of: store.nickname) { _, newValue in
          if localNickname != newValue {
            localNickname = newValue
          }
        }
        .onChange(of: store.selectedPhoto) { _, newValue in
          localSelectedPhoto = newValue
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .onTapGesture {
          isNicknameFocused = false
        }
      }

      // MARK: - Nickname Status

      private var borderColor: Color {
        if localNickname.isEmpty {
          return Color(.systemGray4)
        } else if let error = store.nicknameError, !error.isEmpty {
          return .red
        } else {
          return .blue
        }
      }

      @ViewBuilder
      private var nicknameStatusView: some SwiftUI.View {
        if localNickname.isEmpty {
          EmptyView()
        } else if let error = store.nicknameError, !error.isEmpty {
          Text(error)
            .font(.footnote)
            .foregroundStyle(.red)
        } else if store.isCheckingNickname {
          HStack(spacing: 6) {
            ProgressView()
              .scaleEffect(0.6, anchor: .center)
            Text(LocalizedStrings.Profile.nicknameChecking)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        } else if store.isNicknameAvailable == false {
          Text(LocalizedStrings.Profile.nicknameTaken)
            .font(.footnote)
            .foregroundStyle(.red)
        } else if store.isNicknameAvailable == true {
          HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .font(.footnote)
            Text(LocalizedStrings.Profile.nicknameAvailable)
              .font(.footnote)
              .foregroundStyle(.green)
          }
        }
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
          Text(LocalizedStrings.Profile.selectPhoto)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.pmtext.primary.opacity(0.8))
        }
      }
  }
}

// MARK: - Effects ID

private enum CancelID {
  case nicknameCheck
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
