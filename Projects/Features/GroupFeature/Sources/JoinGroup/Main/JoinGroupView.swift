import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients
import Nuke

extension JoinGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<JoinGroup.Feature>
    
    public init(store: StoreOf<JoinGroup.Feature>) {
      self.store = store
    }
    
    public var body: some View {
      Group {
        switch store.step {
        case .enterCode:
          EnterCodeView(store: store)
        case .preview(let preview):
          PreviewView(
            store: store,
            group: preview.group,
            members: preview.members
          )
        case .settings(let group):
          CreateGroupSettingsView(
            groupName: group.name,
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
      .auroraBackground()
      .navigationTitle(navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert(
        LocalizedStrings.Common.error,
        isPresented: .constant(store.previewError != nil),
        actions: {
          Button(LocalizedStrings.Common.ok) {
            store.send(.view(.previewErrorAlertDismissed))
          }
        },
        message: {
          if let error = store.previewError {
            Text(error)
          }
        }
      )
      .alert(
        LocalizedStrings.JoinGroup.joinFailed,
        isPresented: .constant(store.joinError != nil),
        actions: {
          Button(LocalizedStrings.Common.ok) {
            store.send(.view(.joinErrorAlertDismissed))
          }
        },
        message: {
          if let error = store.joinError {
            Text(error)
          }
        }
      )
    }

    private var navigationTitle: String {
      switch store.step {
      case .enterCode, .preview:
        return LocalizedStrings.JoinGroup.title
      case .settings:
        return LocalizedStrings.JoinGroup.initialSettings
      }
    }
  }
}

// MARK: - Enter Code View

private struct EnterCodeView: View {
  @Bindable var store: StoreOf<JoinGroup.Feature>
  @FocusState private var isCodeFieldFocused: Bool
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      headerSection
        .padding(.top, 32)
        .padding(.horizontal, 24)
      
      // Code Input
      codeInputSection
        .padding(.top, 48)
        .padding(.horizontal, 24)
      
      Spacer()
      
      // Next Button
      nextButton
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    .onAppear {
      isCodeFieldFocused = true
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          store.send(.view(.cancelTapped))
        } label: {
          Image(systemName: "xmark")
        }
      }
    }
  }
  
  // MARK: - Header Section
  
  @ViewBuilder
  private var headerSection: some View {
    VStack(spacing: 16) {
      // Icon
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 80, height: 80)
        
        Image(systemName: "link.circle.fill")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
      
      // Title & Description
      VStack(spacing: 8) {
        Text(LocalizedStrings.JoinGroup.enterInviteCode)
          .font(.title2.bold())

        Text(LocalizedStrings.JoinGroup.enterCodeDescription)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
  }
  
  // MARK: - Code Input Section
  
  @ViewBuilder
  private var codeInputSection: some View {
    VStack(spacing: 16) {
      // Code Display Boxes with overlay TextField
      HStack(spacing: 12) {
        ForEach(0..<6, id: \.self) { index in
          codeCharacterBox(at: index)
        }
      }
      .overlay(
        // Transparent TextField overlay for paste support
        TextField("", text: .init(
          get: { store.inviteCode },
          set: { store.send(.view(.codeChanged($0))) }
        ))
        .keyboardType(.asciiCapable)
        .autocapitalization(.allCharacters)
        .disableAutocorrection(true)
        .textContentType(.oneTimeCode) // OTP 자동완성 및 복사-붙여넣기 지원
        .focused($isCodeFieldFocused)
        .foregroundColor(.clear) // 텍스트 색상 투명
        .accentColor(.clear) // 커서 색상 투명
        .tint(.clear)
        .background(Color.clear)
        .onChange(of: store.inviteCode) { oldValue, newValue in
          // 6자리가 완성되면 자동으로 다음 단계로
          if newValue.count == 6 && store.canProceedToPreview {
            // 키보드 내리기
            isCodeFieldFocused = false
            // 약간의 딜레이 후 다음 단계로 (UX 향상)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
              store.send(.view(.nextTapped))
            }
          }
        }
      )
    }
    .onTapGesture {
      isCodeFieldFocused = true
    }
    .contextMenu {
      // 복사-붙여넣기 메뉴
      if UIPasteboard.general.hasStrings {
        Button {
          if let pasteText = UIPasteboard.general.string {
            store.send(.view(.codeChanged(pasteText)))
            isCodeFieldFocused = true
          }
        } label: {
          Label(LocalizedStrings.JoinGroup.paste, systemImage: "doc.on.clipboard")
        }
      }

      if !store.inviteCode.isEmpty {
        Button {
          UIPasteboard.general.string = store.inviteCode
        } label: {
          Label(LocalizedStrings.JoinGroup.copy, systemImage: "doc.on.doc")
        }
      }
    }
  }
  
  // MARK: - Code Character Box
  
  @ViewBuilder
  private func codeCharacterBox(at index: Int) -> some View {
    let character = store.inviteCode.count > index
    ? String(store.inviteCode[store.inviteCode.index(store.inviteCode.startIndex, offsetBy: index)])
    : ""
    
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
      
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          store.inviteCode.count == index && isCodeFieldFocused
          ? LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          : LinearGradient(
            colors: [Color(.systemGray4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: store.inviteCode.count == index && isCodeFieldFocused ? 2 : 1
        )
      
      Text(character)
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(
          character.isEmpty
          ? AnyShapeStyle(Color.secondary.opacity(0.3))
          : AnyShapeStyle(LinearGradient(
            colors: [.primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ))
        )
    }
    .frame(width: 48, height: 60)
    .animation(.easeInOut(duration: 0.2), value: store.inviteCode)
    .animation(.easeInOut(duration: 0.2), value: isCodeFieldFocused)
  }
  
  // MARK: - Next Button
  
  @ViewBuilder
  private var nextButton: some View {
    Button {
      store.send(.view(.nextTapped))
    } label: {
      HStack(spacing: 8) {
        if store.isLoadingPreview {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 18))
        }
        
        Text(store.isLoadingPreview ? LocalizedStrings.JoinGroup.checking : LocalizedStrings.Common.next)
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        LinearGradient(
          colors: store.canProceedToPreview
          ? [.blue, .purple]
          : [Color(.systemGray4)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: store.canProceedToPreview ? .blue.opacity(0.3) : .clear,
        radius: 12,
        x: 0,
        y: 6
      )
    }
    .disabled(!store.canProceedToPreview)
    .animation(.easeInOut(duration: 0.2), value: store.canProceedToPreview)
    .animation(.easeInOut(duration: 0.2), value: store.isLoadingPreview)
  }
}

// MARK: - Preview View

private struct PreviewView: View {
  @Bindable var store: StoreOf<JoinGroup.Feature>
  let group: GroupModel
  let members: [UserPublicModel]

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 24) {
          // Header Section
          headerSection
            .padding(.top, 32)

          // Group Info Card
          VStack(alignment: .leading, spacing: 20) {
            // Description
            if let description = group.description, !description.isEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Label(LocalizedStrings.ManageGroup.introduction, systemImage: "text.alignleft")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.secondary)

                Text(description)
                  .font(.body)
                  .foregroundStyle(.primary)
                  .lineSpacing(4)
              }
            }

            // Stats
            HStack(spacing: 24) {
              statItem(
                icon: "person.2.fill",
                label: LocalizedStrings.ManageGroup.currentMembers,
                value: "\(group.memberIds.count)"
              )

              Divider()
                .frame(height: 40)

              statItem(
                icon: "person.3.fill",
                label: LocalizedStrings.ManageGroup.maxMembers,
                value: "\(group.maxMembers)"
              )
            }
            .frame(maxWidth: .infinity)
          }
          .padding(20)
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)

          // Members Section
          if !members.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
              HStack {
                Label(LocalizedStrings.Group.members, systemImage: "person.2")
                  .font(.headline)
                  .foregroundStyle(.primary)

                Spacer()

                Text(LocalizedStrings.ManageGroup.membersCount(members.count))
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.secondary)
              }

              memberGridView
            }
            .padding(20)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
          }

          Spacer()
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
      }

      // Join Button
      joinButton
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          store.send(.view(.backTapped))
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
          }
        }
      }
    }
    .fullScreenCover(
      item: Binding(
        get: {
          if let member = store.selectedMemberForImage {
            return ImageDetailItem(id: "member-\(member.userId)", imageUrl: member.profileImageUrl, displayName: member.nickname)
          } else if store.showGroupImageDetail {
            return ImageDetailItem(id: "group", imageUrl: group.imageUrl, displayName: group.name)
          }
          return nil
        },
        set: { if $0 == nil { store.send(.view(.imageDetailDismissed)) } }
      )
    ) { item in
      ImageDetailView(
        imageUrl: item.imageUrl,
        displayName: item.displayName,
        onDismiss: { store.send(.view(.imageDetailDismissed)) }
      )
      .presentationBackground(.black)
    }
  }

  // MARK: - Header Section

  @ViewBuilder
  private var headerSection: some View {
    VStack(spacing: 20) {
      // Group Image
      GroupImageView(
        imageUrl: group.imageUrl,
        onTap: {
          store.send(.view(.groupImageTapped))
        }
      )

      // Group Name
      Text(group.name)
        .font(.system(size: 32, weight: .bold))
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - Stat Item

  @ViewBuilder
  private func statItem(icon: String, label: String, value: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundStyle(
          LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

      Text(value)
        .font(.system(size: 28, weight: .bold))
        .foregroundStyle(.primary)

      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Member Grid View

  @ViewBuilder
  private var memberGridView: some View {
    let columns = [
      GridItem(.flexible(), spacing: 16),
      GridItem(.flexible(), spacing: 16),
      GridItem(.flexible(), spacing: 16)
    ]

    let displayMembers = Array(members.prefix(6))
    let overflowCount = max(members.count - 6, 0)

    LazyVGrid(columns: columns, spacing: 16) {
      ForEach(displayMembers) { member in
        MemberGridItem(
          member: member,
          onImageTap: {
            store.send(.view(.memberImageTapped(member)))
          }
        )
      }

      if overflowCount > 0 {
        OverflowGridItem(count: overflowCount)
      }
    }
  }

  // MARK: - Join Button

  @ViewBuilder
  private var joinButton: some View {
    Button {
      store.send(.view(.joinGroupTapped))
    } label: {
      HStack(spacing: 8) {
        if store.isJoining {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
        }

        Text(store.isJoining ? LocalizedStrings.JoinGroup.joining : LocalizedStrings.JoinGroup.joinButton)
          .font(.system(size: 18, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        LinearGradient(
          colors: store.canJoin ? [.blue, .purple] : [Color(.systemGray4)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .foregroundStyle(.white)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .shadow(
        color: store.canJoin ? .blue.opacity(0.3) : .clear,
        radius: 12,
        x: 0,
        y: 6
      )
    }
    .disabled(!store.canJoin)
    .animation(.easeInOut(duration: 0.2), value: store.canJoin)
    .animation(.easeInOut(duration: 0.2), value: store.isJoining)
  }
}

// MARK: - Member Grid Item

private struct MemberGridItem: View {
  let member: UserPublicModel
  var onImageTap: (() -> Void)?

  var body: some View {
    VStack(spacing: 8) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        size: 64,
        borderWidth: 0,
        onTap: onImageTap
      )
      .overlay(
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 2
          )
      )

      Text(member.nickname)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
  }
}

// MARK: - Overflow Grid Item

private struct OverflowGridItem: View {
  let count: Int

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(Color(.systemGray5))
          .frame(width: 64, height: 64)

        Text("+\(count)")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.secondary)
      }
      .overlay(
        Circle()
          .strokeBorder(Color(.systemGray4), lineWidth: 2)
      )

      Text(LocalizedStrings.JoinGroup.seeMore)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Group Image View

private struct GroupImageView: View {
  let imageUrl: String?
  var onTap: (() -> Void)?
  @State private var loadedImage: UIImage?
  @State private var isLoading = false

  var body: some View {
    ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 120, height: 120)

      if let uiImage = loadedImage {
        // 이미지 로딩 완료
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 120, height: 120)
          .clipShape(Circle())
      } else if isLoading {
        // 로딩 중
        ProgressView()
          .scaleEffect(1.2)
      } else {
        // 이미지 없음 - system image 표시
        Image(systemName: "person.2.circle.fill")
          .font(.system(size: 60))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue.opacity(0.7), .purple.opacity(0.5)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }
    }
    .overlay(
      Circle()
        .strokeBorder(
          LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 3
        )
    )
    .shadow(color: .blue.opacity(0.2), radius: 16, x: 0, y: 8)
    .contentShape(Circle())
    .onTapGesture {
      onTap?()
    }
    .task {
      await loadImage()
    }
  }

  private func loadImage() async {
    guard let imageUrl = imageUrl,
          let url = URL(string: imageUrl) else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      // Nuke ImagePipeline을 사용하여 이미지 로딩
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      AppLogger.general.warning("JoinGroup image load failed: \(error.localizedDescription)")
      // 에러 발생 시 system image 표시 (loadedImage가 nil이므로 자동으로 표시됨)
    }
  }
}
