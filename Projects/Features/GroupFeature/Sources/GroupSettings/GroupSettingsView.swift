import ComposableArchitecture
import Clients
import PromisoShared
import SwiftUI
import PhotosUI
import UIKit

extension GroupSettings {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      content
        .navigationTitle("그룹 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.view(.onAppear)) }
        .modifier(SheetsModifier(store: store))
        .modifier(AlertsModifier(store: store))
        .sheet(
          isPresented: Binding(
            get: { store.editGroup != nil },
            set: { if !$0 { store.send(.view(.editGroupDismissed)) } }
          )
        ) {
          if store.editGroup != nil {
            EditGroupSheet(store: store)
              .presentationDetents([.large])
              .presentationDragIndicator(.visible)
          }
        }
    }

    private var content: some SwiftUI.View {
      ScrollView {
        VStack(spacing: 16) {
          groupHeaderSection
          menuSection
          dangerSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
    }

    // MARK: - Sections

    private var groupHeaderSection: some SwiftUI.View {
      VStack(spacing: 16) {
        HStack(spacing: 16) {
          GroupThumbnailView(
            imageUrl: store.group.imageUrl,
            name: store.group.name,
            size: 60
          )

          VStack(alignment: .leading, spacing: 6) {
            Text(store.group.name)
              .font(.system(size: 20, weight: .semibold))

            Text(groupDescriptionText)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(16)
      .adaptiveGlassCard()
      .overlay(alignment: .topTrailing) {
        if store.isHost {
          Button {
            store.send(.view(.editGroupTapped))
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
              Text("수정")
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.pmindigo.n500.opacity(0.12))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .padding(12)
        }
      }
    }

    private var menuSection: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 10) {
        VStack(spacing: 0) {
          menuRow(
            title: "멤버",
            systemImage: "person.2",
            trailingText: "\(store.memberCount)명",
            action: { store.send(.view(.membersTapped)) }
          )

          dividerLine

          menuRow(
            title: "친구 초대",
            systemImage: "square.and.arrow.up",
            trailingText: nil,
            action: { store.send(.view(.inviteTapped)) }
          )

          dividerLine

          menuRow(
            title: "지난 약속",
            systemImage: "clock.arrow.circlepath",
            trailingText: nil,
            action: { store.send(.view(.pastPromisesTapped)) }
          )
        }
        .adaptiveGlassCard()
      }
    }

    private var dangerSection: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 10) {
        VStack(spacing: 0) {
          if store.isHost {
            dangerRow(
              title: "그룹 삭제",
              systemImage: "trash",
              isLoading: store.isDeletingGroup,
              action: { store.send(.view(.deleteGroupTapped)) }
            )
            .disabled(store.isDeletingGroup)
          } else {
            dangerRow(
              title: "그룹 나가기",
              systemImage: "rectangle.portrait.and.arrow.right",
              isLoading: store.isLeavingGroup,
              action: { store.send(.view(.leaveGroupTapped)) }
            )
            .disabled(store.isLeavingGroup)
          }
        }
        .adaptiveGlassCard()
      }
    }

    private var groupDescriptionText: String {
      let description = store.group.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return description.isEmpty ? "설명이 없습니다" : description
    }

    private var dividerLine: some SwiftUI.View {
      Divider()
        .background(Color.white.opacity(0.12))
    }

    private func menuRow(
      title: String,
      systemImage: String,
      trailingText: String?,
      action: @escaping () -> Void
    ) -> some SwiftUI.View {
      Button(action: action) {
        HStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)

          Text(title)
            .foregroundStyle(.primary)
          Spacer()
          if let trailingText {
            Text(trailingText)
              .foregroundStyle(.secondary)
          }
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .foregroundStyle(.primary)
    }

    private func dangerRow(
      title: String,
      systemImage: String,
      isLoading: Bool,
      action: @escaping () -> Void
    ) -> some SwiftUI.View {
      Button(role: .destructive, action: action) {
        HStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.pmerror.n500)

          Text(title)
            .foregroundStyle(.primary)
          Spacer()
          if isLoading {
            ProgressView()
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

private struct EditGroupSheet: View {
  @Bindable var store: StoreOf<GroupSettings.Feature>

  private var editState: GroupSettings.Feature.EditGroupState? {
    store.editGroup
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 20) {
            photoSection
              .glassSection()

            groupNameSection
              .glassSection()

            descriptionSection
              .glassSection()

            maxMembersSection
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
      .navigationTitle("그룹 수정")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            store.send(.view(.editGroupDismissed))
          } label: {
            Image(systemName: "xmark")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        BottomButton(
          isLoading: editState?.isSaving == true,
          isEnabled: !saveDisabled,
          action: { store.send(.view(.editGroupSaveTapped)) }
        )
      }
    }
    .alert(
      "그룹 수정 실패",
      isPresented: Binding(
        get: { store.editGroup?.error != nil },
        set: { if !$0 { store.send(.view(.editGroupErrorDismissed)) } }
      ),
      actions: {
        Button("확인", role: .cancel) {
          store.send(.view(.editGroupErrorDismissed))
        }
      },
      message: {
        Text(store.editGroup?.error ?? "잠시 후 다시 시도해주세요.")
      }
    )
  }

  private var saveDisabled: Bool {
    guard let editState else { return true }
    return editState.isSaving ||
      editState.maxMembers < store.minMaxMembers ||
      editState.maxMembers > store.maxMembersUpperLimit
  }

  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case description
  }

  private var photoSection: some View {
    VStack(spacing: 12) {
      Text("그룹 사진")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      PhotosPicker(
        selection: Binding(
          get: { editState?.selectedPhoto },
          set: { store.send(.view(.editGroupPhotoSelected($0))) }
        ),
        matching: .images
      ) {
        ZStack {
          if let photoData = editState?.photoData,
             let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
              .resizable()
              .scaledToFill()
              .frame(width: 120, height: 120)
              .clipShape(Circle())
          } else if let imageUrl = store.group.imageUrl {
            GroupThumbnailView(
              imageUrl: imageUrl,
              name: store.group.name,
              size: 120
            )
          } else {
            photoPlaceholder
          }

          Image(systemName: "pencil.circle.fill")
            .font(.system(size: 24))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.pmindigo.n500, Color(.systemBackground))
            .frame(width: 28, height: 28)
            .background(
              Circle().fill(Color(.systemBackground))
            )
            .overlay(
              Circle().stroke(Color.pmindigo.n500.opacity(0.2), lineWidth: 1)
            )
            .offset(x: 38, y: 38)
        }
      }
    }
  }

  private var groupNameSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("그룹 이름")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()
      }

      Text(store.group.name)
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)

      Label("그룹 이름은 변경할 수 없습니다", systemImage: "info.circle")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var descriptionSection: some View {
    let count = editState?.description.count ?? 0
    let maxLength = 50

    return VStack(spacing: 12) {
      HStack {
        Text("그룹 설명")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(count)/\(maxLength)")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      TextField(
        "그룹 설명을 입력하세요 (선택)",
        text: Binding(
          get: { editState?.description ?? "" },
          set: { store.send(.view(.editGroupDescriptionChanged($0))) }
        ),
        axis: .vertical
      )
      .lineLimit(2, reservesSpace: true)
      .textFieldStyle(.plain)
      .padding(12)
      .background(Color(.systemBackground))
      .cornerRadius(8)
      .focused($focusedField, equals: .description)
      .id(Field.description)
    }
  }

  private var maxMembersSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("최대 인원")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Picker(
          "",
          selection: Binding(
            get: { editState?.maxMembers ?? store.group.maxMembers },
            set: { store.send(.view(.editGroupMaxMembersChanged($0))) }
          )
        ) {
          ForEach(store.minMaxMembers...10, id: \.self) { value in
            Text("\(value)명")
              .tag(value)
          }
        }
        .pickerStyle(.menu)
        .tint(.blue)
      }

      Text("현재 인원 \(store.group.memberIds.count)명 이상, 최대 10명까지 설정할 수 있어요.")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
  }

  private var photoPlaceholder: some View {
    Circle()
      .fill(Color(.systemGray5))
      .frame(width: 120, height: 120)
      .overlay {
        VStack(spacing: 8) {
          Image(systemName: "camera.fill")
            .font(.system(size: 28))
            .foregroundColor(.secondary)
          Text("사진 변경")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
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
}

private struct BottomButton: View {
  let isLoading: Bool
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      GlassActionButton(
        title: isLoading ? "저장 중..." : "그룹 수정하기",
        isPrimary: true,
        isVisible: true,
        isEnabled: isEnabled && !isLoading,
        action: action
      )
      .overlay(alignment: .trailing) {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding(.trailing, 16)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
  }
}

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

// MARK: - SheetsModifier

private struct SheetsModifier: ViewModifier {
  let store: StoreOf<GroupSettings.Feature>

  private var memberSheetBinding: Binding<Bool> {
    Binding(
      get: { store.showMemberSheet },
      set: { if !$0 { store.send(.view(.dismissMemberSheet)) } }
    )
  }

  private var inviteSheetBinding: Binding<Bool> {
    Binding(
      get: { store.showInviteSheet },
      set: { if !$0 { store.send(.view(.dismissInviteSheet)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: memberSheetBinding) {
        GroupMemberListSheet(
          members: store.members,
          hostId: store.group.createdBy,
          currentUserId: store.currentUserId,
          onDismiss: { store.send(.view(.dismissMemberSheet)) },
          onMemberImageTap: { store.send(.view(.memberImageTapped($0))) }
        )
      }
      .sheet(isPresented: inviteSheetBinding) {
        InviteSheet(
          inviteCode: store.inviteCode,
          inviteLink: store.inviteLink,
          onDismiss: { store.send(.view(.dismissInviteSheet)) }
        )
      }
  }
}

// MARK: - AlertsModifier

private struct AlertsModifier: ViewModifier {
  let store: StoreOf<GroupSettings.Feature>

  private var leaveAlertBinding: Binding<Bool> {
    Binding(
      get: { store.showLeaveAlert },
      set: { if !$0 { store.send(.view(.dismissLeaveAlert)) } }
    )
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { store.showDeleteAlert },
      set: { if !$0 { store.send(.view(.dismissDeleteAlert)) } }
    )
  }

  private var errorAlertBinding: Binding<Bool> {
    Binding(
      get: { store.leaveError != nil || store.deleteError != nil },
      set: { if !$0 { store.send(.view(.dismissError)) } }
    )
  }

  private var imageDetailBinding: Binding<UserPublicModel?> {
    Binding(
      get: { store.selectedMemberForImage },
      set: { if $0 == nil { store.send(.view(.imageDetailDismissed)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .alert("그룹 나가기", isPresented: leaveAlertBinding) {
        Button("취소", role: .cancel) {}
        Button("나가기", role: .destructive) { store.send(.view(.confirmLeave)) }
      } message: {
        Text("정말 '\(store.group.name)' 그룹을 나가시겠습니까?")
      }
      .alert("그룹 삭제", isPresented: deleteAlertBinding) {
        Button("취소", role: .cancel) {}
        Button("삭제", role: .destructive) { store.send(.view(.confirmDelete)) }
      } message: {
        Text("정말 '\(store.group.name)' 그룹을 삭제하시겠습니까?\n모든 약속과 데이터가 삭제됩니다.")
      }
      .alert("오류", isPresented: errorAlertBinding) {
        Button("확인") { store.send(.view(.dismissError)) }
      } message: {
        Text(store.leaveError ?? store.deleteError ?? "알 수 없는 오류가 발생했습니다.")
      }
      .fullScreenCover(item: imageDetailBinding) { member in
        PromisoShared.ImageDetailView(
          imageUrl: member.profileImageUrl,
          displayName: member.displayName,
          onDismiss: { store.send(.view(.imageDetailDismissed)) }
        )
      }
  }
}

// MARK: - GroupMemberListSheet

struct GroupMemberListSheet: View {
  let members: [UserPublicModel]
  let hostId: String
  let currentUserId: String
  let onDismiss: () -> Void
  let onMemberImageTap: (UserPublicModel) -> Void

  var body: some View {
    NavigationStack {
      List(members) { member in
        MemberRow(
          member: member,
          isHost: member.userId == hostId,
          isCurrentUser: member.userId == currentUserId,
          onImageTap: { onMemberImageTap(member) }
        )
      }
      .navigationTitle("멤버 (\(members.count)명)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기", action: onDismiss)
        }
      }
    }
  }
}

private struct MemberRow: View {
  let member: UserPublicModel
  let isHost: Bool
  let isCurrentUser: Bool
  let onImageTap: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onImageTap) {
        ProfileAvatarView(
          profileImageUrl: member.profileImageUrl,
          displayName: member.displayName,
          isCurrentUser: isCurrentUser,
          size: 44
        )
      }
      .buttonStyle(.hapticBounce(.light))

      Text(member.displayName)
        .font(.body)

      Spacer()

      if isHost {
        HStack(spacing: 4) {
          Image(systemName: "crown.fill")
            .font(.system(size: 12))
          Text("호스트")
            .font(.caption)
        }
        .foregroundStyle(.orange)
      }

      if isCurrentUser {
        Text("(나)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - InviteSheet

struct InviteSheet: View {
  let inviteCode: String
  let inviteLink: String
  let onDismiss: () -> Void

  @State private var isCopied = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // 초대 코드 표시
        VStack(spacing: 8) {
          Text("초대 코드")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          HStack(spacing: 12) {
            Text(inviteCode)
              .font(.system(size: 28, weight: .bold, design: .monospaced))

            Button {
              UIPasteboard.general.string = inviteCode
              Haptic.success()
              withAnimation {
                isCopied = true
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                  isCopied = false
                }
              }
            } label: {
              Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 18))
                .foregroundStyle(isCopied ? .green : Color.pmindigo.n500)
            }
            .buttonStyle(.bounce)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 16)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        // 공유 링크
        ShareLink(item: URL(string: inviteLink)!) {
          HStack {
            Image(systemName: "square.and.arrow.up")
            Text("링크 공유하기")
          }
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.pmindigo.n500)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.scale)
        .padding(.horizontal, 24)

        Spacer()
      }
      .padding(.top, 32)
      .navigationTitle("친구 초대")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("닫기", action: onDismiss)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    GroupSettings.View(
      store: Store(
        initialState: GroupSettings.Feature.State(
          group: GroupModel(
            id: "g1",
            name: "지민과 나",
            maxMembers: 10,
            inviteCode: "ABC123",
            createdBy: "preview-user"
          ),
          summary: UserGroupInfo(
            id: "g1",
            name: "지민과 나",
            role: .admin,
            hasNewActivity: true
          ),
          currentUserId: "preview-user",
          preloadedMembers: [
            UserPublicModel(
              userId: "preview-user",
              name: "나",
              nickname: "나",
              metadata: Metadata()
            ),
            UserPublicModel(
              userId: "user2",
              name: "지민",
              nickname: "지민",
              metadata: Metadata()
            )
          ]
        )
      ) {
        GroupSettings.Feature()
      }
    )
  }
}
