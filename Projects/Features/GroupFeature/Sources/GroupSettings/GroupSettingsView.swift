import ComposableArchitecture
import Clients
import PromisoShared
import SwiftUI

extension GroupSettings {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      listContent
        .navigationTitle("그룹 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.view(.onAppear)) }
        .modifier(SheetsModifier(store: store))
        .modifier(AlertsModifier(store: store))
    }

    private var listContent: some SwiftUI.View {
      List {
        groupHeaderSection
        menuSection
        dangerSection
      }
    }

    // MARK: - Sections

    private var groupHeaderSection: some SwiftUI.View {
      Section {
        HStack(spacing: 16) {
          // 그룹 아바타 (PromisoShared 컴포넌트 사용)
          GroupThumbnailView(
            imageUrl: store.group.imageUrl,
            name: store.group.name,
            size: 60
          )

          VStack(alignment: .leading, spacing: 4) {
            Text(store.group.name)
              .font(.system(size: 18, weight: .semibold))

            Text("\(store.memberCount)명")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 8)
      }
    }

    private var menuSection: some SwiftUI.View {
      Section {
        // 멤버
        Button {
          store.send(.view(.membersTapped))
        } label: {
          HStack {
            Label("멤버", systemImage: "person.2")
            Spacer()
            Text("\(store.memberCount)명")
              .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .foregroundStyle(.primary)

        // 초대하기
        Button {
          store.send(.view(.inviteTapped))
        } label: {
          HStack {
            Label("친구 초대", systemImage: "square.and.arrow.up")
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .foregroundStyle(.primary)

        // 지난 약속
        Button {
          store.send(.view(.pastPromisesTapped))
        } label: {
          HStack {
            Label("지난 약속", systemImage: "clock.arrow.circlepath")
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.tertiary)
          }
        }
        .foregroundStyle(.primary)
      }
    }

    private var dangerSection: some SwiftUI.View {
      Section {
        if store.isHost {
          Button(role: .destructive) {
            store.send(.view(.deleteGroupTapped))
          } label: {
            HStack {
              Label("그룹 삭제", systemImage: "trash")
              Spacer()
              if store.isDeletingGroup {
                ProgressView()
              }
            }
          }
          .disabled(store.isDeletingGroup)
        } else {
          Button(role: .destructive) {
            store.send(.view(.leaveGroupTapped))
          } label: {
            HStack {
              Label("그룹 나가기", systemImage: "rectangle.portrait.and.arrow.right")
              Spacer()
              if store.isLeavingGroup {
                ProgressView()
              }
            }
          }
          .disabled(store.isLeavingGroup)
        }
      }
    }
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
