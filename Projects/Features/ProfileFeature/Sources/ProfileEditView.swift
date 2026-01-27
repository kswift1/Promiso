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
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
            if store.isSavingProfile {
              ProgressView()
                .tint(Color.pmtext.secondary)
            } else {
              Button("저장") {
                store.send(.view(.saveProfileTapped))
              }
              .fontWeight(.semibold)
              .foregroundStyle(saveButtonColor)
              .disabled(!canSave)
            }
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
      let currentNickname = store.currentUser?.nickname ?? ""
      let nicknameChanged = store.editedNickname != currentNickname
      let imageChanged = store.editedProfileImageData != nil
      let nicknameValid = store.nicknameValidation == .available ||
                          store.editedNickname == currentNickname

      return (nicknameChanged || imageChanged) && nicknameValid && !store.isSavingProfile
    }

    private var saveButtonColor: Color {
      canSave ? Color.pmindigo.n500 : Color.pmgray.n400
    }

    // MARK: - Profile Image Section

    private var profileImageSection: some View {
      PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
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
                profileImageUrl: store.currentUser?.profileImageUrl,
                displayName: store.currentUser?.nickname ?? "",
                isCurrentUser: true,
                size: 120,
                borderWidth: 3
              )
            }
          }
          .frame(width: 120, height: 120)
          .clipShape(Circle())

          // 카메라 아이콘 뱃지
          ZStack {
            Circle()
              .fill(Color.pmindigo.n500)
              .frame(width: 36, height: 36)

            Image(systemName: "camera.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white)
          }
        }
      }
      .onChange(of: selectedPhotoItem) { _, newValue in
        Task {
          guard let newValue else { return }
          do {
            if let image = try await newValue.loadTransferable(type: TransferableImage.self) {
              store.send(.view(.profileImageSelected(image.data)))
            }
          } catch {
            store.send(.internal(.profileSaveFailed(ProfileError.imageLoadFailed.localizedDescription)))
          }
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
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
      case .error:
        Image(systemName: "wifi.slash")
          .foregroundStyle(Color.pmgray.n400)
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
      case .error(let message):
        Text("확인 실패: \(message)")
          .font(.caption)
          .foregroundStyle(Color.pmgray.n400)
      }
    }
  }
}

// MARK: - Transferable Image

private struct TransferableImage: Transferable {
  let data: Data

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { data in
      TransferableImage(data: data)
    }
  }
}

// MARK: - Preview

#Preview("Profile Edit") {
  Profile.ProfileEditView(
    store: Store(initialState: Profile.Feature.State(currentUser: Shared(value: .exampleUser), isEditingProfile: true)) {
      Profile.Feature()
    }
  )
}

#Preview("Profile Edit - Saving") {
  Profile.ProfileEditView(
    store: Store(
      initialState: {
        var state = Profile.Feature.State(currentUser: Shared(value: .exampleUser), isEditingProfile: true)
        state.isSavingProfile = true
        return state
      }()
    ) {
      Profile.Feature()
    }
  )
}
