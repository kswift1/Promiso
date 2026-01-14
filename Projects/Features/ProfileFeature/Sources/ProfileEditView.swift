//
//  ProfileEditView.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-15.
//

import SwiftUI
import PhotosUI
import ComposableArchitecture
import Clients
import ResourceKit
import PromisoShared

// MARK: - Profile Edit View

extension Profile {

  /// 프로필 편집 화면
  public struct ProfileEditView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var selectedPhotoItem: PhotosPickerItem?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Body

    public var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 32) {
            // 프로필 이미지 섹션
            profileImageSection

            // 닉네임 입력 섹션
            nicknameSection

            // 안내 문구
            infoSection
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 24)
        }
        .auroraBackground()
        .navigationTitle("프로필 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("취소") {
              store.send(.view(.cancelEditTapped))
            }
            .foregroundStyle(Color.pmtext.secondary)
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Button("저장") {
              store.send(.view(.saveProfileTapped))
            }
            .fontWeight(.semibold)
            .foregroundStyle(saveButtonColor)
            .disabled(!canSave)
          }
        }
        .overlay {
          if store.isSavingProfile {
            savingOverlay
          }
        }
        .alert(
          "오류",
          isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.send(.view(.dismissError)) } }
          )
        ) {
          Button("확인", role: .cancel) {
            store.send(.view(.dismissError))
          }
        } message: {
          if let message = store.errorMessage {
            Text(message)
          }
        }
      }
    }

    // MARK: - Computed Properties

    private var canSave: Bool {
      let nicknameChanged = store.editedNickname != store.currentUser.nickname
      let imageChanged = store.editedProfileImageData != nil
      let nicknameValid = store.nicknameValidation == .available ||
                          store.editedNickname == store.currentUser.nickname

      return (nicknameChanged || imageChanged) && nicknameValid && !store.isSavingProfile
    }

    private var saveButtonColor: Color {
      canSave ? Color.pmindigo.n500 : Color.pmgray.n400
    }

    // MARK: - Profile Image Section

    private var profileImageSection: some View {
      VStack(spacing: 16) {
        ZStack(alignment: .bottomTrailing) {
          // 프로필 이미지
          Group {
            if let imageData = store.editedProfileImageData,
               let uiImage = UIImage(data: imageData) {
              Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
            } else {
              ProfileAvatarView(
                profileImageUrl: store.currentUser.profileImageUrl,
                displayName: store.currentUser.nickname,
                isCurrentUser: true,
                size: 120,
                borderWidth: 3
              )
            }
          }
          .frame(width: 120, height: 120)
          .clipShape(Circle())

          // 편집 버튼
          PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            ZStack {
              Circle()
                .fill(Color.pmindigo.n500)
                .frame(width: 36, height: 36)

              Image(systemName: "camera.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            }
          }
          .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
              if let data = try? await newValue?.loadTransferable(type: Data.self) {
                store.send(.view(.profileImageSelected(data)))
              }
            }
          }
        }

        Text("프로필 사진을 탭하여 변경")
          .font(.caption)
          .foregroundStyle(Color.pmgray.n400)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .adaptiveGlassBackground()
    }

    // MARK: - Nickname Section

    private var nicknameSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("닉네임")
          .font(.headline)
          .foregroundStyle(Color.pmtext.primary)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            TextField("닉네임을 입력하세요", text: Binding(
              get: { store.editedNickname },
              set: { store.send(.view(.nicknameChanged($0))) }
            ))
            .textFieldStyle(.plain)
            .font(.body)

            // 유효성 검사 상태 표시
            validationStatusIcon
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .background(Color.pmgray.n100.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 12))

          // 유효성 검사 메시지
          validationMessage
        }
        .adaptiveGlassBackground()
      }
    }

    @ViewBuilder
    private var validationStatusIcon: some View {
      switch store.nicknameValidation {
      case .idle:
        EmptyView()
      case .checking:
        ProgressView()
          .scaleEffect(0.8)
      case .available:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(Color.pmsuccess.n500)
      case .unavailable:
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.pmerror.n500)
      case .invalid:
        Image(systemName: "exclamationmark.circle.fill")
          .foregroundStyle(Color.pmwarning.n500)
      }
    }

    @ViewBuilder
    private var validationMessage: some View {
      switch store.nicknameValidation {
      case .idle, .checking:
        Text("2~20자 이내로 입력해주세요")
          .font(.caption)
          .foregroundStyle(Color.pmgray.n400)
      case .available:
        Text("사용 가능한 닉네임입니다")
          .font(.caption)
          .foregroundStyle(Color.pmsuccess.n500)
      case .unavailable:
        Text("이미 사용 중인 닉네임입니다")
          .font(.caption)
          .foregroundStyle(Color.pmerror.n500)
      case .invalid(let message):
        Text(message)
          .font(.caption)
          .foregroundStyle(Color.pmwarning.n500)
      }
    }

    // MARK: - Info Section

    private var infoSection: some View {
      VStack(alignment: .leading, spacing: 8) {
        Label {
          Text("닉네임은 다른 사용자에게 표시됩니다")
        } icon: {
          Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(Color.pmgray.n400)

        Label {
          Text("프로필 사진은 약속 및 그룹에서 사용됩니다")
        } icon: {
          Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(Color.pmgray.n400)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .adaptiveGlassBackground()
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
      ZStack {
        Color.black.opacity(0.3)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(.white)

          Text("저장 중...")
            .font(.body)
            .foregroundStyle(.white)
        }
        .padding(32)
        .adaptiveGlassBackground()
      }
    }
  }
}

// MARK: - Glass Effect Extension

private extension View {
  @ViewBuilder
  func adaptiveGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }
}

// MARK: - Preview

#Preview("Profile Edit") {
  Profile.ProfileEditView(
    store: Store(initialState: Profile.Feature.State(isEditingProfile: true)) {
      Profile.Feature()
    }
  )
}

#Preview("Profile Edit - Saving") {
  var state = Profile.Feature.State(isEditingProfile: true)
  state.isSavingProfile = true
  return Profile.ProfileEditView(
    store: Store(initialState: state) {
      Profile.Feature()
    }
  )
}
