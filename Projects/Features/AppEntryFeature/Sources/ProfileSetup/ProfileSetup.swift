//
//  ProfileSetup.swift
//  AppEntryFeature
//
//  Created by 김성원 on 12/9/25.
//

import Foundation
import SwiftUI
import PhotosUI
import Shared
import ResourceKit
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
      
      var selectedPhoto: PhotosPickerItem?
      var profileImage: ProfileImageType
      var email: String?
      var uid: String
      var fullName: String
      var nickname: String = ""
      var nicknameError: String?
      var step: Step = .welcome
      
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
      case nextTapped
      case backTapped
      case skipTapped
      case startTapped
      case nicknameChanged(String)
      case photoSelected(PhotosPickerItem?)
      case photoLoaded(Data?)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    public enum Internal {
      case saveProfile
      case profileSaved
      case profileSaveFailed(Error)
    }

    public enum Delegate: Equatable {
      case completed
    }
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .nextTapped:
          switch state.step {
          case .welcome:
            state.step = .nickname
            return .none
          case .nickname:
            if let error = validateNickname(state.nickname) {
              state.nicknameError = error
              return .none
            }
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
            state.step = .welcome
            return .none
          case .photo:
            state.step = .nickname
            return .none
          }

        case .skipTapped:
          return .send(.internal(.saveProfile))
          
        case .startTapped:
          state.step = .nickname
          return .none
          
        case .nicknameChanged(let name):
          state.nickname = name
          state.nicknameError = validateNickname(name)
          return .none
          
        case .photoSelected(let item):
          guard let item else { return .none }
          return .run { send in
            if let data = try? await item.loadTransferable(type: Data.self) {
              await send(.photoLoaded(data))
            }
          }
          
        case .photoLoaded(let data):
          state.profileImage = .data(data)
          return .none

        case .internal(let internalAction):
          switch internalAction {
          case .saveProfile:
            return .run { [state] send in
              do {
                // 1. 프로필 이미지가 있으면 업로드
                var profileImageUrl: String? = nil
                switch state.profileImage {
                case .data(let data):
                  if let imageData = data {
//                    let url = try await userProfileClient.uploadProfileImage(state.uid, imageData)
//                    profileImageUrl = url.absoluteString
                  }
                case .url(let url):
                  profileImageUrl = url.absoluteString
                case .none:
                  profileImageUrl = nil
                }

                // 2. UserProfile 생성
                let profile = UserProfile(
                  name: state.fullName,
                  nickname: state.nickname,
                  email: state.email,
                  profileType: profileImageUrl != nil ? .url : .firebase,
                  profileImageUrl: profileImageUrl,
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
            return .send(.delegate(.completed))

          case .profileSaveFailed(let error):
            print("❌ Profile save failed: \(error)")
            // TODO: 에러 처리 UI 추가
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
    
    public struct View: SwiftUI.View {
      @Bindable private var store: StoreOf<ProfileSetup>
      private let indicatorCount: Int = State.Step.allCases.count
      @SwiftUI.State private var showAnimation: Bool?
      @SwiftUI.State private var showButtons: Bool = false
      @SwiftUI.State private var completedSteps: Set<State.Step> = []
      
      public init(store: StoreOf<ProfileSetup>) {
        self.store = store
      }
      
      public var body: some SwiftUI.View {
        content
          .toolbarVisibility(.visible, for: .navigationBar)
          .animation(.easeInOut, value: store.step)
          .auroraBackground()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .task(id: store.step) {
            if completedSteps.contains(store.step) {
              // 이미 완료된 step이면 애니메이션 없이 바로 표시
              showAnimation = false
              showButtons = true
            } else {
              // 새로운 step이면 애니메이션 재생
              showAnimation = nil
              showButtons = false
              try? await Task.sleep(for: .seconds(1))
              showAnimation = true
            }
          }
      }
      
      @ViewBuilder
      private var content: some SwiftUI.View {
        switch store.step {
        case .welcome:
          WelcomeStepView(
            store: store,
            showAnimation: showAnimation,
            showButtons: showButtons,
            onAnimationCompleted: {
              completedSteps.insert(.welcome)
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButtons = true
              }
            }
          )
        case .nickname:
          NicknameStepView(
            store: store,
            showAnimation: showAnimation,
            showButtons: showButtons,
            onAnimationCompleted: {
              completedSteps.insert(.nickname)
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButtons = true
              }
            }
          )
        case .photo:
          PhotoStepView(
            store: store,
            showAnimation: showAnimation,
            showButtons: showButtons,
            onAnimationCompleted: {
              completedSteps.insert(.photo)
              withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showButtons = true
              }
            }
          )
        }
      }
      
    }
  }
}

private struct PhotoSection: SwiftUI.View {
  let profileImage: ProfileImageType
  @Binding var selectedPhoto: PhotosPickerItem?
  
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
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
      }
  }
}

// MARK: - Step Views

private struct WelcomeStepView: SwiftUI.View {
  @Bindable var store: StoreOf<AppEntry.ProfileSetup>
  let showAnimation: Bool?
  let showButtons: Bool
  let onAnimationCompleted: () -> Void
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        PagingIndicator(
          count: 3,
          progress: 0,
          activeColor: Color(red: 0.6, green: 0.4, blue: 0.9)
        )
        .frame(height: 10)
        
        TypewriterLinesView(
          animated: showAnimation,
          lines: [
            .init(
              text: "반가워요! 👋",
              font: .system(size: 38, weight: .semibold, design: .default),
              style: AnyShapeStyle(Color.pmtext.primary)
            ),
            .init(
              text: "안녕하세요 \(store.fullName.isEmpty ? "," : "\(store.fullName) 님,")",
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
      .padding(.top, 48)
      
      Spacer()
      
      GlassActionButton(
        title: "시작하기",
        isVisible: showButtons,
        action: { store.send(.nextTapped) }
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
  }
}

private struct NicknameStepView: SwiftUI.View {
  @Bindable var store: StoreOf<AppEntry.ProfileSetup>
  let showAnimation: Bool?
  let showButtons: Bool
  let onAnimationCompleted: () -> Void
  @SwiftUI.State private var showTextField: Bool = false
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        PagingIndicator(
          count: 3,
          progress: 1,
          activeColor: Color(red: 0.6, green: 0.4, blue: 0.9)
        )
        .frame(height: 10)
        
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
      .padding(.top, 48)
      
      if showTextField {
        VStack(alignment: .leading, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("닉네임")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(.primary)
            
            TextField("2-12자 이내로 입력해주세요", text: $store.nickname.sending(\.nicknameChanged))
              .textFieldStyle(.roundedBorder)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(borderColor, lineWidth: 1)
              )
          }
          
          HStack {
            if store.nickname.isEmpty {
              Text("한글, 영문, 숫자만 사용 가능해요")
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else if let error = store.nicknameError, !error.isEmpty {
              Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
            } else {
              HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundStyle(.green)
                  .font(.footnote)
                Text("사용 가능한 닉네임이에요")
                  .font(.footnote)
                  .foregroundStyle(.green)
              }
            }
            
            Spacer()
            
            Text("\(store.nickname.count)/12")
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
        isEnabled: (store.nicknameError?.isEmpty ?? true) && store.nickname.count >= 2 && store.nickname.count <= 12,
        action: { store.send(.nextTapped) }
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
    .onAppear(perform: onAppearActions)
    .onChange(of: showAnimation, { _, newValue in
      onAnimationStateChange(newValue)
    })
    .toolbar {
      if showButtons {
        ToolbarItem(placement: .topBarLeading) {
          ToolbarButton(
            imageName: "chevron.left",
            action: { store.send(.backTapped) }
          )
          .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
        }
      }
    }
  }
  
  private var borderColor: Color {
    if store.nickname.isEmpty {
      return Color(.systemGray4)
    } else if let error = store.nicknameError, !error.isEmpty {
      return .red
    } else {
      return .blue
    }
  }
  
  private func handleAnimationCompleted() {
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
      showTextField = true
    }
    onAnimationCompleted()
  }
  
  private func updateTextFieldVisibility(for animationState: Bool?) {
    switch animationState {
    case false:
      // 이미 완료된 단계는 바로 표시
      showTextField = true
    case nil:
      showTextField = false
    default:
      break
    }
  }
  
  private func onAppearActions() {
    updateTextFieldVisibility(for: showAnimation)
  }
  
  private func onAnimationStateChange(_ newValue: Bool?) {
    updateTextFieldVisibility(for: newValue)
  }
}

private struct PhotoStepView: SwiftUI.View {
  @Bindable var store: StoreOf<AppEntry.ProfileSetup>
  let showAnimation: Bool?
  let showButtons: Bool
  let onAnimationCompleted: () -> Void
  @SwiftUI.State private var showPhotoSection: Bool = false
  
  var body: some SwiftUI.View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        PagingIndicator(
          count: 3,
          progress: 2,
          activeColor: Color(red: 0.6, green: 0.4, blue: 0.9)
        )
        .frame(height: 10)
        
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
      .padding(.top, 48)
      
      Spacer()
      
      if showPhotoSection {
        PhotoSection(
          profileImage: store.profileImage,
          selectedPhoto: $store.selectedPhoto.sending(\.photoSelected)
        )
        .padding(.horizontal, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      
      Spacer()

      VStack(spacing: 15) {
        GlassActionButton(
          title: "완료",
          isVisible: showButtons,
          action: { store.send(.nextTapped) }
        )

        Button {
          store.send(.skipTapped)
        } label: {
          Text("나중에 설정할게요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .opacity(showButtons ? 1 : 0)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
    }
    .onAppear(perform: onAppearActions)
    .onChange(of: showAnimation, { _, newValue in
      onAnimationStateChange(newValue)
    })
    .toolbar {
      if showButtons {
        ToolbarItem(placement: .topBarLeading) {
          ToolbarButton(
            imageName: "chevron.left",
            action: { store.send(.backTapped) }
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
  
  private func onAppearActions() {
    updatePhotoSectionVisibility(for: showAnimation)
  }
  
  private func onAnimationStateChange(_ newValue: Bool?) {
    updatePhotoSectionVisibility(for: newValue)
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


// MARK: - Nickname Validation

private func validateNickname(_ name: String) -> String? {
  if name.count < 2 { return "2자 이상 입력해주세요" }
  if name.count > 12 { return "12자 이하로 입력해주세요" }
  let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789가-힣")
  if name.rangeOfCharacter(from: allowed.inverted) != nil {
    return "한글, 영문, 숫자만 입력 가능해요"
  }
  return nil
}
