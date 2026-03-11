import Clients
import ComposableArchitecture
import PhotosUI
import PromisoShared
import ResourceKit
import SwiftUI
import UIKit

// MARK: - SheetsModifier

struct SheetsModifier: ViewModifier {
  let store: StoreOf<GroupSettings.Feature>
  @State private var inviteSheetHeight: CGFloat = 360

  private var inviteSheetBinding: Binding<Bool> {
    Binding(
      get: { store.showInviteSheet },
      set: { if !$0 { store.send(.view(.dismissInviteSheet)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: inviteSheetBinding) {
        InviteSheet(
          groupName: store.group.name,
          inviteCode: store.inviteCode,
          isKakaoSharing: store.isKakaoSharing,
          onKakaoShareTapped: {
            store.send(.view(.kakaoShareTapped))
          }
        )
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: Binding(
        get: { store.showSystemShareSheet },
        set: { if !$0 { store.send(.view(.systemShareSheetDismissed)) } }
      )) {
        ShareSheet(items: [GroupInviteShareMessage.message(
          groupName: store.group.name,
          inviteCode: store.inviteCode
        )])
      }
  }
}

// MARK: - AlertsModifier

struct AlertsModifier: ViewModifier {
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
      get: { store.leaveError != nil || store.deleteError != nil || store.notificationError != nil },
      set: { if !$0 { store.send(.view(.dismissError)) } }
    )
  }

  private var imageDetailBinding: Binding<UserPublicModel?> {
    Binding(
      get: { store.selectedMemberForImage },
      set: { if $0 == nil { store.send(.view(.imageDetailDismissed)) } }
    )
  }

  private var groupImageDetailBinding: Binding<Bool> {
    Binding(
      get: { store.showGroupImageDetail },
      set: { if !$0 { store.send(.view(.groupImageDetailDismissed)) } }
    )
  }

  private var transferSheetBinding: Binding<Bool> {
    Binding(
      get: { store.isShowingTransferSheet },
      set: { if !$0 { store.send(.view(.dismissTransferSheet)) } }
    )
  }

  private var transferErrorBinding: Binding<Bool> {
    Binding(
      get: { store.transferError != nil },
      set: { if !$0 { store.send(.view(.dismissTransferError)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .alert(LocalizedStrings.ManageGroup.leaveGroup, isPresented: leaveAlertBinding) {
        Button(LocalizedStrings.Common.cancel, role: .cancel) {}
        Button(LocalizedStrings.ManageGroup.leave, role: .destructive) { store.send(.view(.confirmLeave)) }
      } message: {
        Text(LocalizedStrings.GroupSettingsView.leaveGroupConfirm(store.group.name))
      }
      .alert(LocalizedStrings.ManageGroup.deleteGroup, isPresented: deleteAlertBinding) {
        Button(LocalizedStrings.Common.cancel, role: .cancel) {}
        Button(LocalizedStrings.Common.delete, role: .destructive) { store.send(.view(.confirmDelete)) }
      } message: {
        Text(LocalizedStrings.GroupSettingsView.deleteGroupConfirm(store.group.name))
      }
      .alert(LocalizedStrings.Common.error, isPresented: errorAlertBinding) {
        Button(LocalizedStrings.Common.ok) { store.send(.view(.dismissError)) }
      } message: {
        Text(store.leaveError ?? store.deleteError ?? store.notificationError ?? LocalizedStrings.GroupSettingsView.unknownError)
      }
      .fullScreenCover(item: imageDetailBinding) { member in
        PromisoShared.ImageDetailView(
          imageUrl: member.profileImageUrl,
          displayName: member.displayName,
          onDismiss: { store.send(.view(.imageDetailDismissed)) }
        )
      }
      .fullScreenCover(isPresented: groupImageDetailBinding) {
        PromisoShared.ImageDetailView(
          imageUrl: store.group.imageUrl,
          displayName: store.group.name,
          onDismiss: { store.send(.view(.groupImageDetailDismissed)) }
        )
        .presentationBackground(.black)
      }
      .sheet(isPresented: transferSheetBinding) {
        TransferHostSheet(store: store)
      }
      .alert(LocalizedStrings.ManageGroup.transferHostFailed, isPresented: transferErrorBinding) {
        Button(LocalizedStrings.Common.ok) { store.send(.view(.dismissTransferError)) }
      } message: {
        Text(store.transferError ?? LocalizedStrings.GroupSettingsView.unknownError)
      }
  }
}

// MARK: - TransferHostSheet

private struct TransferHostSheet: View {
  let store: StoreOf<GroupSettings.Feature>

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          // 안내 텍스트
          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.GroupSettingsView.selectNewHost)
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              ForEach(Array(store.transferCandidates.enumerated()), id: \.element.userId) { index, member in
                transferCandidateRow(member: member)

                if index < store.transferCandidates.count - 1 {
                  Divider()
                    .background(Color.white.opacity(0.12))
                }
              }
            }
            .adaptiveGlassCard()

            Text(LocalizedStrings.GroupSettingsView.transferHostDescription)
              .font(.system(size: 12))
              .foregroundStyle(Color.pmtext.secondary)
              .padding(.horizontal, 4)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.ManageGroup.transferHost)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(LocalizedStrings.Common.cancel) {
            store.send(.view(.dismissTransferSheet))
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          confirmButton
        }
      }
    }
    .interactiveDismissDisabled(store.isTransferringHost)
  }

  private func transferCandidateRow(member: UserPublicModel) -> some View {
    Button {
      store.send(.view(.selectNewHost(member)))
    } label: {
      HStack(spacing: 12) {
        ProfileAvatarView(
          profileImageUrl: member.profileImageUrl,
          displayName: member.displayName,
          isCurrentUser: false,
          size: 44
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(member.displayName)
            .font(.body)
            .foregroundStyle(.primary)
          if member.name != member.nickname {
            Text(member.name)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if store.selectedNewHost?.userId == member.userId {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.pmindigo.n500)
            .font(.title3)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var confirmButton: some View {
    if store.isTransferringHost {
      ProgressView()
    } else {
      Button(LocalizedStrings.ManageGroup.transfer) {
        store.send(.view(.confirmTransferHost))
      }
      .disabled(store.selectedNewHost == nil)
    }
  }
}

// MARK: - GroupMemberListView

struct GroupMemberListView: View {
  @Bindable var store: StoreOf<GroupSettings.Feature>

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // 멤버 목록
        VStack(alignment: .leading, spacing: 10) {
          Text(LocalizedStrings.GroupComponents.members)
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 4)

          VStack(spacing: 0) {
            ForEach(Array(store.members.enumerated()), id: \.element.userId) { index, member in
              HStack(spacing: 0) {
                // 편집 모드: 본인이 아닌 멤버에게 삭제 버튼 표시
                if store.isEditingMembers && member.userId != store.currentUserId {
                  Button {
                    store.send(.view(.expelMemberTapped(member)))
                  } label: {
                    Image(systemName: "minus.circle.fill")
                      .font(.system(size: 22))
                      .foregroundStyle(Color.pmerror.n500)
                  }
                  .buttonStyle(.plain)
                  .padding(.leading, 16)
                  .transition(.move(edge: .leading).combined(with: .opacity))
                }

                MemberRow(
                  member: member,
                  isHost: member.userId == store.group.createdBy,
                  isCurrentUser: member.userId == store.currentUserId,
                  onImageTap: { store.send(.view(.memberImageTapped(member))) }
                )
              }

              if index < store.members.count - 1 {
                Divider()
                  .background(Color.white.opacity(0.12))
              }
            }
          }
          .adaptiveGlassCard()
          .animation(.easeInOut(duration: 0.25), value: store.isEditingMembers)
        }

        // 초대 섹션
        if !store.isEditingMembers {
          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.GroupSettingsView.invite)
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            InviteTileRow {
              store.send(.view(.inviteTapped))
            }
            .adaptiveGlassCard()
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
    }
    .auroraBackground()
    .navigationTitle(LocalizedStrings.GroupSettingsView.membersTitle(store.members.count))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if store.canExpelMembers {
        ToolbarItem(placement: .topBarTrailing) {
          Button(store.isEditingMembers ? LocalizedStrings.Common.done : LocalizedStrings.GroupSettingsView.editMembers) {
            if store.isEditingMembers {
              store.send(.view(.doneEditingMembersTapped))
            } else {
              store.send(.view(.editMembersTapped))
            }
          }
        }
      }
    }
    .alert(
      LocalizedStrings.GroupSettingsView.expelMember,
      isPresented: Binding(
        get: { store.memberToExpel != nil && !store.isExpellingMember },
        set: { if !$0 { store.send(.view(.dismissExpelAlert)) } }
      )
    ) {
      Button(LocalizedStrings.Common.cancel, role: .cancel) {
        store.send(.view(.dismissExpelAlert))
      }
      Button(LocalizedStrings.GroupSettingsView.expel, role: .destructive) {
        store.send(.view(.confirmExpelMember))
      }
    } message: {
      if let member = store.memberToExpel {
        Text(LocalizedStrings.GroupSettingsView.expelConfirm(member.displayName))
      }
    }
    .alert(LocalizedStrings.GroupSettingsView.expelFailed, isPresented: Binding(
      get: { store.expelError != nil },
      set: { if !$0 { store.send(.view(.dismissExpelError)) } }
    )) {
      Button(LocalizedStrings.Common.ok) { store.send(.view(.dismissExpelError)) }
    } message: {
      Text(store.expelError ?? LocalizedStrings.GroupSettingsView.unknownError)
    }
    .fullScreenCover(
      item: Binding(
        get: { store.selectedMemberForImage },
        set: { _ in store.send(.view(.imageDetailDismissed)) }
      )
    ) { member in
      PromisoShared.ImageDetailView(
        imageUrl: member.profileImageUrl,
        displayName: member.displayName,
        onDismiss: { store.send(.view(.imageDetailDismissed)) }
      )
      .presentationBackground(.clear)
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
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        isCurrentUser: isCurrentUser,
        size: 44
      )
      .padding(4)
      .contentShape(Rectangle())
      .onTapGesture(perform: onImageTap)

      Text(member.displayName)
        .font(.body)

      Spacer()

      if isHost {
        HStack(spacing: 4) {
          Image(systemName: "crown.fill")
            .font(.system(size: 12))
          Text(LocalizedStrings.ManageGroup.host)
            .font(.caption)
        }
        .foregroundStyle(.orange)
      }

      if isCurrentUser {
        Text(LocalizedStrings.GroupSettingsView.me)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Color.pmindigo.n600)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.pmindigo.n500.opacity(0.12))
          .clipShape(Capsule())
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

private struct InviteTileRow: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: "person.badge.plus")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)

        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.GroupSettingsView.inviteFriends)
            .font(.body)
            .foregroundStyle(.primary)

          Text(LocalizedStrings.GroupSettingsView.inviteFriendsDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - InviteSheet

struct InviteSheet: View {
  let groupName: String
  let inviteCode: String
  let isKakaoSharing: Bool
  let onKakaoShareTapped: () -> Void

  @State private var isCopied = false

  var body: some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.GroupSettingsView.inviteTitle)
            .font(.system(size: 20, weight: .bold))

          Text(LocalizedStrings.GroupSettingsView.inviteSubtitle)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 12)

        Spacer()
      }

      VStack(spacing: 12) {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStrings.JoinGroup.enterInviteCode)
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.secondary)

            Text(inviteCode)
              .font(.system(size: 28, weight: .bold, design: .monospaced))
              .tracking(2)
          }

          Spacer()

          Button {
            copyCode()
          } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(isCopied ? .green : Color.pmindigo.n500)
              .frame(width: 36, height: 36)
              .background(Color.pmindigo.n500.opacity(0.12))
              .clipShape(Circle())
          }
          .buttonStyle(.bounce)
        }

      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      // 카카오톡으로 초대장 보내기 (Primary)
      Button {
        onKakaoShareTapped()
      } label: {
        HStack(spacing: 8) {
          ResourceKitAsset.kakaoLogo.swiftUIImage
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
          Text(LocalizedStrings.KakaoShare.kakaoInviteButton)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 254/255, green: 229/255, blue: 0/255))
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.scale)
      .disabled(isKakaoSharing)
      .opacity(isKakaoSharing ? 0.6 : 1)

      // 다른 앱으로 공유 (Secondary)
      GroupInviteShareMessage.shareLink(groupName: groupName, inviteCode: inviteCode) {
        HStack(spacing: 8) {
          Image(systemName: "square.and.arrow.up")
          Text(LocalizedStrings.GroupSettingsView.shareLink)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.pmindigo.n500.opacity(0.12))
        .foregroundStyle(Color.pmindigo.n500)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.scale)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
  }

  private func copyCode() {
    UIPasteboard.general.string = inviteCode
    Haptic.success()
    withAnimation(.easeInOut(duration: 0.2)) {
      isCopied = true
    }
  }
}

// MARK: - Preview

// MARK: - GroupColorPickerView

struct GroupColorPickerView: View {
  let store: StoreOf<GroupSettings.Feature>

  private let columns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        previewSection
        colorGridSection

        if store.groupColor != nil {
          resetButton
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
    }
    .navigationTitle(LocalizedStrings.GroupSettingsView.groupColorTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  private var previewSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(LocalizedStrings.GroupSettingsView.groupColorPreview)
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      VStack(spacing: 16) {
        // 1. 그룹 바 아이템 미리보기
        groupBarPreview

        Divider()
          .padding(.horizontal, 8)

        // 2. 일정 카드 미리보기
        scheduleCardPreview
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }

  /// 그룹 바 아이템 미리보기 - 홈 상단 그룹 바에서 보이는 형태
  private var groupBarPreview: some View {
    HStack(spacing: 16) {
      // 미리보기 라벨
      VStack(alignment: .leading, spacing: 4) {
        Text(LocalizedStrings.GroupSettingsView.groupColorGroupTab)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(LocalizedStrings.GroupSettingsView.colorPreviewBarDescription)
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }

      Spacer()

      // 그룹 바 아이템 (실제 GroupBarItemView와 동일한 스타일)
      VStack(alignment: .center, spacing: 6) {
        GroupThumbnailView(
          imageUrl: store.group.imageUrl,
          name: store.group.name,
          size: 56
        )
        .overlay(
          Circle()
            .stroke(
              store.groupColor?.color ?? Color.pmindigo.n500,
              lineWidth: 3
            )
        )

        Text(store.group.name)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
          .frame(width: 72)
      }
    }
  }

  /// 일정 카드 미리보기 - 일정 카드 왼쪽에 색상 바로 표시
  private var scheduleCardPreview: some View {
    HStack(spacing: 16) {
      // 미리보기 라벨
      VStack(alignment: .leading, spacing: 4) {
        Text(LocalizedStrings.GroupSettingsView.groupColorScheduleCard)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
        Text(LocalizedStrings.GroupSettingsView.colorPreviewCardDescription)
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
      }

      Spacer()

      // 미니 일정 카드 미리보기
      HStack(spacing: 0) {
        // 왼쪽 색상 바
        RoundedRectangle(cornerRadius: 2)
          .fill(store.groupColor?.color ?? Color.pmgray.n300)
          .frame(width: 4)

        // 카드 내용
        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.GroupSettingsView.colorPreviewSampleTitle)
            .font(.system(size: 13, weight: .bold))
          HStack(spacing: 4) {
            Text("⏰")
              .font(.system(size: 11))
            Text(LocalizedStrings.GroupSettingsView.colorPreviewSampleTime)
              .font(.system(size: 11, weight: .medium))
          }
          .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
      }
      .background(Color.pmgray.n50.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(Color.pmgray.n200, lineWidth: 0.5)
      )
    }
  }

  private var colorGridSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(LocalizedStrings.GroupSettingsView.colorPickerTitle)
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(GroupColor.allCases, id: \.self) { color in
          colorCell(color)
        }
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }

  private func colorCell(_ color: GroupColor) -> some View {
    Button {
      store.send(.view(.groupColorChanged(color)))
    } label: {
      ZStack {
        Circle()
          .fill(color.color)
          .frame(width: 48, height: 48)

        if store.groupColor == color {
          Circle()
            .strokeBorder(.white, lineWidth: 3)
            .frame(width: 48, height: 48)

          Image(systemName: "checkmark")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private var resetButton: some View {
    Button {
      store.send(.view(.groupColorChanged(nil)))
    } label: {
      HStack {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 14, weight: .semibold))
        Text(LocalizedStrings.GroupSettingsView.groupColorReset)
          .font(.system(size: 14, weight: .medium))
      }
      .foregroundStyle(Color.pmgray.n500)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .adaptiveGlassCard()
    }
    .buttonStyle(.plain)
  }
}

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
          isPro: false,
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
