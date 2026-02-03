import SwiftUI
import PhotosUI
import ComposableArchitecture

import PromisoShared
import Clients
import UIKit

extension CreateGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<CreateGroup.Feature>
    @FocusState private var focusedField: Field?

    public init(store: StoreOf<CreateGroup.Feature>) {
      self.store = store
    }

    private enum Field: Hashable {
      case groupName
      case groupDescription
    }

    public var body: some View {
      NavigationStack {
        Group {
          switch store.step {
          case .input:
            inputView

          case .success(let result):
            CreateGroupSuccessView(result: result) {
              store.send(.view(.successAcknowledged))
            }

          case .settings(let result):
            CreateGroupSettingsView(
              groupName: result.name,
              notificationEnabled: store.notificationEnabled,
              calendarSyncEnabled: store.calendarSyncEnabled,
              notificationAuthStatus: store.notificationAuthStatus,
              calendarAuthStatus: store.calendarAuthStatus,
              isSaving: store.isSavingSettings,
              showCalendarPermissionInfoAlert: store.showCalendarPermissionInfoAlert,
              onNotificationToggle: { store.send(.view(.notificationToggled($0))) },
              onCalendarSyncToggle: { store.send(.view(.calendarSyncToggled($0))) },
              onComplete: { store.send(.view(.settingsCompleted)) },
              onSkip: { store.send(.view(.settingsSkipped)) },
              onCalendarPermissionInfoAlertDismiss: { store.send(.view(.calendarPermissionInfoAlertDismissed)) },
              onAppear: { store.send(.view(.settingsAppeared)) }
            )
          }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            if case .input = store.step {
              Button {
                store.send(.view(.cancelTapped))
              } label: {
                Image(systemName: "xmark")
              }
            }
          }
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        "그룹 생성에 실패했어요",
        isPresented: Binding(
          get: { store.creationError != nil },
          set: { isPresented in
            if !isPresented {
              store.send(.view(.errorAlertDismissed))
            }
          }
        ),
        actions: {
          Button("확인", role: .cancel) {
            store.send(.view(.errorAlertDismissed))
          }
        },
        message: {
          Text(store.creationError ?? "잠시 후 다시 시도해주세요.")
        }
      )
      .auroraBackground()
    }

    private var navigationTitle: String {
      switch store.step {
      case .input:
        return "그룹 만들기"
      case .success:
        return ""
      case .settings:
        return ""
      }
    }

    private var inputView: some View {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 20) {
            PhotoUploadSection(
              photoData: store.photoData,
              selectedPhoto: $store.selectedPhoto.sending(\.view.photoSelected)
            )
            .glassSection()

            GroupNameSection(
              groupName: $store.groupName,
              characterCount: store.characterCount
            )
            .focused($focusedField, equals: .groupName)
            .id(Field.groupName)
            .glassSection()

            GroupDescriptionSection(
              groupDescription: $store.groupDescription,
              characterCount: store.descriptionCharacterCount
            )
            .focused($focusedField, equals: .groupDescription)
            .id(Field.groupDescription)
            .glassSection()

            MaxMembersSection(
              maxMembers: $store.maxMembers
            )
            .glassSection()

            Spacer(minLength: 12)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focusedField) { _, newValue in
          guard let newValue else { return }
          withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(newValue, anchor: .center)
          }
        }
      }
      .onTapGesture {
        dismissKeyboard()
      }
      .safeAreaInset(edge: .bottom) {
        BottomButton(
          isInputValid: store.isValid,
          isLoading: store.isCreating,
          action: { store.send(.view(.createGroupTapped)) }
        )
      }
    }
  }
}

private func dismissKeyboard() {
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder),
    to: nil,
    from: nil,
    for: nil
  )
}

// MARK: - Photo Upload Section

private struct PhotoUploadSection: View {
  let photoData: Data?
  @Binding var selectedPhoto: PhotosPickerItem?
  
  var body: some View {
    VStack(spacing: 12) {
      Text("그룹 사진")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      PhotosPickerButton(
        photoData: photoData,
        selectedPhoto: $selectedPhoto
      )
    }
  }
}

private struct PhotosPickerButton: View {
  let photoData: Data?
  @Binding var selectedPhoto: PhotosPickerItem?
  
  var body: some View {
    PhotosPicker(selection: $selectedPhoto, matching: .images) {
      ZStack {
        if let photoData, let uiImage = UIImage(data: photoData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
        } else {
          Circle()
            .fill(Color(.systemGray5))
            .frame(width: 120, height: 120)
            .overlay {
              VStack(spacing: 8) {
                Image(systemName: "camera.fill")
                  .font(.system(size: 28))
                  .foregroundColor(.secondary)
                Text("사진 추가")
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
              }
            }
        }
      }
    }
  }
}

// MARK: - Group Name Section

private struct GroupNameSection: View {
  @Binding var groupName: String
  let characterCount: Int

  private let maxLength = 12

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("그룹 이름")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(characterCount)/\(maxLength)")
          .font(.system(size: 13))
          .foregroundColor(characterCount >= 2 ? .secondary : .red)
      }

      TextField("그룹 이름을 입력하세요", text: $groupName)
        .textFieldStyle(.plain)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onChange(of: groupName) { _, newValue in
          if newValue.count > maxLength {
            groupName = String(newValue.prefix(maxLength))
          }
        }

      VStack(alignment: .leading, spacing: 4) {
        if characterCount > 0 && characterCount < 2 {
          Text("최소 2자 이상 입력해주세요")
            .font(.system(size: 12))
            .foregroundColor(.red)
        }

        Label("그룹 이름은 생성 후 변경할 수 없습니다", systemImage: "info.circle")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

// MARK: - Group Description Section

private struct GroupDescriptionSection: View {
  @Binding var groupDescription: String
  let characterCount: Int

  private let maxLength = 50

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Text("그룹 설명")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(characterCount)/\(maxLength)")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      TextField("그룹 설명을 입력하세요 (선택)", text: $groupDescription, axis: .vertical)
        .lineLimit(2, reservesSpace: true)
        .textFieldStyle(.plain)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .onChange(of: groupDescription) { _, newValue in
          if newValue.count > maxLength {
            groupDescription = String(newValue.prefix(maxLength))
          }
        }
    }
  }
}

// MARK: - Max Members Section

private struct MaxMembersSection: View {
  @Binding var maxMembers: MaxMembers
  
  var body: some View {
    HStack {
      Text("최대 인원")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
      
      Spacer()
      
      Picker("", selection: $maxMembers) {
        ForEach(MaxMembers.allCases, id: \.self) { option in
          Text(option.displayText).tag(option)
        }
      }
      .pickerStyle(.menu)
      .tint(.blue)
    }
  }
}

// MARK: - Bottom Button

private struct BottomButton: View {
  let isInputValid: Bool
  let isLoading: Bool
  let action: () -> Void
  
  var body: some View {
    VStack(spacing: 8) {
      GlassActionButton(
        title: isLoading ? "만드는 중..." : "그룹 만들기",
        isPrimary: true,
        isVisible: true,
        isEnabled: isInputValid && !isLoading,
        action: action
      )
      .overlay(alignment: .trailing) {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding(.trailing, 16)
        }
      }
      
      Text("그룹을 만들면 자동으로 관리자가 됩니다")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
  }
}

// MARK: - Glass Section Helper

private extension View {
  func glassSection() -> some View {
    self
      .padding(16)
      .background(
        Group {
          if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.clear)
              .glassEffect(
                .regular
                  .tint(.pmindigo.n200.opacity(0.1))
                  .interactive(),
                in: .rect(cornerRadius: 16)
              )
          } else {
            glassBackground
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12))
      )
  }
  
  var glassBackground: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(Color.white.opacity(0.06))
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.ultraThinMaterial)
      )
  }
}

// MARK: - Preview

//#Preview {
//  let store = Store(initialState: CreateGroup.Feature.State(
//    currentUser: UserModel(
//      id: "preview-user",
//      email: "preview@promiso.com",
//      nickname: "프리뷰"
//    )
//  )) {
//    CreateGroup.Feature()
//  }
//  
//  return CreateGroup.RootView(store: store)
//}
