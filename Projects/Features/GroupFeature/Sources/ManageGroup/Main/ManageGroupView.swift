import Clients
import Nuke
import SwiftUI
import ComposableArchitecture
import PromisoShared

// TODO: 한번 UI 변경 필요

extension ManageGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<ManageGroup.Feature>
    @State private var isCopied = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showTransferConfirmation = false

    public init(store: StoreOf<ManageGroup.Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // Header Section
          headerSection
            .padding(.top, 32)

          // Group Info Card
          VStack(alignment: .leading, spacing: 20) {
            // Description
            if let description = store.group.description, !description.isEmpty {
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
                value: "\(store.group.memberIds.count)"
              )

              Divider()
                .frame(height: 40)

              statItem(
                icon: "person.3.fill",
                label: LocalizedStrings.ManageGroup.maxMembers,
                value: "\(store.group.maxMembers)"
              )

              Divider()
                .frame(height: 40)

              statItem(
                icon: "clock.fill",
                label: LocalizedStrings.ManageGroup.activePromises,
                value: "\(store.activePromiseCount)"
              )
            }
            .frame(maxWidth: .infinity)
          }
          .padding(20)
          .adaptiveGlassCard(cornerRadius: 20)

          // Members Section
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              Label(LocalizedStrings.Group.members, systemImage: "person.2")
                .font(.headline)
                .foregroundStyle(.primary)

              Spacer()

              if case .loaded(let members) = store.membersState {
                Text(LocalizedStrings.ManageGroup.membersCount(members.count))
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(.secondary)
              }
            }

            membersContent
          }
          .padding(20)
          .adaptiveGlassCard(cornerRadius: 20)

          // Past Promises Section
          Button {
            store.send(.view(.pastPromisesTapped))
          } label: {
            HStack {
              Label(LocalizedStrings.ManageGroup.pastPromises, systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundStyle(.primary)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
            }
            .padding(20)
            .contentShape(Rectangle())
            .adaptiveGlassCard(cornerRadius: 20)
          }
          .buttonStyle(.plain)

          // Danger Zone
          dangerZoneSection

          Spacer()
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.ManageGroup.title)
      .navigationBarTitleDisplayMode(.inline)
//      .toolbar {
//        ToolbarItem(placement: .topBarTrailing) {
//          Menu {
//            Button {
//              copyCode()
//            } label: {
//              Label(
//                isCopied ? "복사됨!" : "초대 코드 복사",
//                systemImage: isCopied ? "checkmark" : "doc.on.doc"
//              )
//            }
//
//            ShareLink(
//              item: GroupInviteShareMessage.message(groupName: store.group.name, inviteCode: store.group.inviteCode),
//              preview: SharePreview(
//                "\(store.group.name) 그룹에 초대합니다! 🎉",
//                image: ResourceKitAsset.notificationLogo.swiftUIImage
//              )
//            ) {
//              Label("초대 링크 공유", systemImage: "square.and.arrow.up")
//            }
//          } label: {
//            Text("초대")
//          }
//        }
//      }
      .onAppear { store.send(.view(.onAppear)) }
      .confirmationDialog(
        LocalizedStrings.ManageGroup.leaveGroup,
        isPresented: $showLeaveConfirmation,
        actions: {
          Button(LocalizedStrings.ManageGroup.leave, role: .destructive) {
            store.send(.view(.confirmLeave))
          }
          Button(LocalizedStrings.Common.cancel, role: .cancel) {}
        },
        message: {
          Text(LocalizedStrings.ManageGroup.leaveGroupConfirm)
        }
      )
      .confirmationDialog(
        LocalizedStrings.ManageGroup.deleteGroup,
        isPresented: $showDeleteConfirmation,
        actions: {
          Button(LocalizedStrings.Common.delete, role: .destructive) {
            store.send(.view(.confirmDelete))
          }
          Button(LocalizedStrings.Common.cancel, role: .cancel) {}
        },
        message: {
          Text(LocalizedStrings.ManageGroup.deleteGroupConfirm)
        }
      )
      .alert(
        LocalizedStrings.Common.error,
        isPresented: .constant(store.leaveError != nil || store.deleteError != nil),
        actions: {
          Button(LocalizedStrings.Common.ok) {
            store.send(.view(.dismissError))
          }
        },
        message: {
          if let error = store.leaveError ?? store.deleteError {
            Text(error)
          }
        }
      )
      .fullScreenCover(
        item: Binding(
          get: { store.selectedMemberForImage },
          set: { _ in store.send(.view(.imageDetailDismissed)) }
        )
      ) { member in
        ImageDetailView(
          imageUrl: member.profileImageUrl,
          displayName: member.nickname,
          onDismiss: {
            store.send(.view(.imageDetailDismissed))
          }
        )
        .presentationBackground(.black)
      }
      .fullScreenCover(
        isPresented: Binding(
          get: { store.showGroupImageDetail },
          set: { if !$0 { store.send(.view(.imageDetailDismissed)) } }
        )
      ) {
        ImageDetailView(
          imageUrl: store.group.imageUrl,
          displayName: store.group.name,
          onDismiss: {
            store.send(.view(.imageDetailDismissed))
          }
        )
        .presentationBackground(.black)
      }
      .sheet(
        isPresented: Binding(
          get: { store.isShowingTransferSheet },
          set: { if !$0 { store.send(.view(.transferSheetDismissed)) } }
        )
      ) {
        TransferHostSheet(
          candidates: store.transferCandidates,
          selectedMember: store.selectedNewHost,
          isTransferring: store.isTransferringHost,
          error: store.transferError,
          onSelect: { member in
            store.send(.view(.newHostSelected(member)))
          },
          onConfirm: {
            showTransferConfirmation = true
          },
          onCancel: {
            store.send(.view(.transferSheetDismissed))
          }
        )
        .presentationDetents([.medium, .large])
      }
      .confirmationDialog(
        LocalizedStrings.ManageGroup.transferHost,
        isPresented: $showTransferConfirmation,
        actions: {
          Button(LocalizedStrings.ManageGroup.transfer, role: .destructive) {
            store.send(.view(.confirmTransferHost))
          }
          Button(LocalizedStrings.Common.cancel, role: .cancel) {
            store.send(.view(.cancelTransferHost))
          }
        },
        message: {
          if let newHost = store.selectedNewHost {
            Text(LocalizedStrings.ManageGroup.transferHostConfirm(newHost.nickname))
          }
        }
      )
      .alert(
        LocalizedStrings.ManageGroup.transferHostFailed,
        isPresented: .constant(store.transferError != nil),
        actions: {
          Button(LocalizedStrings.Common.ok) {
            store.send(.view(.dismissError))
          }
        },
        message: {
          if let error = store.transferError {
            Text(error)
          }
        }
      )
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 20) {
        // Group Image
        GroupImageView(
          imageUrl: store.group.imageUrl,
          onTap: {
            store.send(.view(.groupImageTapped))
          }
        )

        // Group Name
        Text(store.group.name)
          .font(.system(size: 32, weight: .bold))
          .multilineTextAlignment(.center)

        // Role Badge
        HStack(spacing: 6) {
          Image(systemName: store.isHost ? "crown.fill" : "person.fill")
            .font(.system(size: 12))
          Text(store.isHost ? LocalizedStrings.ManageGroup.host : LocalizedStrings.ManageGroup.memberRole)
            .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          LinearGradient(
            colors: store.isHost ? [.orange, .red] : [.blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .clipShape(Capsule())
      }
    }

    // MARK: - Stat Item

    @ViewBuilder
    private func statItem(icon: String, label: String, value: String) -> some View {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 20))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        Text(value)
          .font(.system(size: 24, weight: .bold))
          .foregroundStyle(.primary)

        Text(label)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
    }

    // MARK: - Members Content

    @ViewBuilder
    private var membersContent: some View {
      switch store.membersState {
      case .idle:
        EmptyView()

      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()

      case .loaded(let members):
        memberGridView(members: members)

      case .failed:
        VStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
          Text(LocalizedStrings.ManageGroup.memberLoadFailed)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
    }

    @ViewBuilder
    private func memberGridView(members: [UserPublicModel]) -> some View {
      let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
      ]

      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(members) { member in
          MemberGridItem(
            member: member,
            isHost: member.userId == store.group.createdBy,
            onImageTap: {
              store.send(.view(.memberImageTapped(member)))
            }
          )
        }
      }
    }

    // MARK: - Danger Zone Section

    @ViewBuilder
    private var dangerZoneSection: some View {
      VStack(alignment: .leading, spacing: 12) {

        VStack(spacing: 0) {
          if store.isHost {
            // 호스트 양도 (다른 멤버가 있을 때만)
            if store.canTransferHost {
              Button {
                store.send(.view(.transferHostTapped))
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "person.badge.key")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                    .frame(width: 24)

                  Text(LocalizedStrings.ManageGroup.transferHost)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)

                  Spacer()

                  Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
              }

              Divider()
                .padding(.leading, 52)
            }

            // 호스트: 그룹 삭제
            Button {
              showDeleteConfirmation = true
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "trash")
                  .font(.system(size: 16))
                  .foregroundStyle(.red)
                  .frame(width: 24)

                Text(LocalizedStrings.ManageGroup.deleteGroup)
                  .font(.system(size: 16))
                  .foregroundStyle(.red)

                Spacer()

                if store.isDeletingGroup {
                  ProgressView()
                    .scaleEffect(0.8)
                } else {
                  Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
            }
            .disabled(store.isDeletingGroup)
          } else {
            // 멤버: 그룹 나가기
            Button {
              showLeaveConfirmation = true
            } label: {
              HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                  .font(.system(size: 16))
                  .foregroundStyle(.primary)
                  .frame(width: 24)

                Text(LocalizedStrings.ManageGroup.leaveGroup)
                  .font(.system(size: 16))
                  .foregroundStyle(.primary)

                Spacer()

                if store.isLeavingGroup {
                  ProgressView()
                    .scaleEffect(0.8)
                } else {
                  Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
            }
            .disabled(store.isLeavingGroup)
          }
        }
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color(.secondarySystemBackground))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(store.isHost ? Color.red.opacity(0.2) : Color(.separator).opacity(0.3), lineWidth: 1)
        )
      }
    }

    private func copyCode() {
      UIPasteboard.general.string = store.group.inviteCode
      withAnimation(.spring()) {
        isCopied = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
        withAnimation(.spring()) {
          isCopied = false
        }
      }
    }
  }
}

// MARK: - Member Grid Item

private struct MemberGridItem: View {
  let member: UserPublicModel
  let isHost: Bool
  var onImageTap: (() -> Void)?

  var body: some View {
    VStack(spacing: 8) {
      ZStack(alignment: .topTrailing) {
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

        // Host Badge
        if isHost {
          Image(systemName: "crown.fill")
            .font(.system(size: 16))
            .foregroundStyle(.orange)
            .background(
              Circle()
                .fill(Color(.systemBackground))
                .frame(width: 24, height: 24)
            )
            .offset(x: 4, y: -4)
        }
      }

      Text(member.nickname)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
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
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 120, height: 120)
          .clipShape(Circle())
      } else if isLoading {
        ProgressView()
          .scaleEffect(1.2)
      } else {
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
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      AppLogger.general.warning("ManageGroup image load failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Transfer Host Sheet

private struct TransferHostSheet: View {
  let candidates: [UserPublicModel]
  let selectedMember: UserPublicModel?
  let isTransferring: Bool
  let error: String?
  let onSelect: (UserPublicModel) -> Void
  let onConfirm: () -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Header
        VStack(spacing: 8) {
          Image(systemName: "person.badge.key.fill")
            .font(.system(size: 48))
            .foregroundStyle(
              LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )

          Text(LocalizedStrings.ManageGroup.selectNewHost)
            .font(.title2.weight(.bold))

          Text(LocalizedStrings.ManageGroup.selectNewHostDescription)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
        .padding(.bottom, 20)

        // Member List
        ScrollView {
          VStack(spacing: 16) {
            VStack(spacing: 0) {
              ForEach(Array(candidates.enumerated()), id: \.element.userId) { index, member in
                Button {
                  onSelect(member)
                } label: {
                  HStack(spacing: 12) {
                    ProfileAvatarView(
                      profileImageUrl: member.profileImageUrl,
                      displayName: member.displayName,
                      size: 48
                    )

                    VStack(alignment: .leading, spacing: 2) {
                      Text(member.nickname)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                      if member.name != member.nickname {
                        Text(member.name)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                    }

                    Spacer()

                    if selectedMember?.userId == member.userId {
                      Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                    } else {
                      Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary.opacity(0.3))
                    }
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 12)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < candidates.count - 1 {
                  Divider()
                    .background(Color.white.opacity(0.12))
                }
              }
            }
            .adaptiveGlassCard()
          }
          .padding(.horizontal, 16)
          .padding(.top, 12)
        }

        // Footer
        VStack(spacing: 12) {
          Button {
            onConfirm()
          } label: {
            HStack {
              if isTransferring {
                ProgressView()
                  .tint(.white)
              } else {
                Text(LocalizedStrings.ManageGroup.transferHost)
              }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(selectedMember != nil ? Color.orange : Color.gray)
            )
          }
          .disabled(selectedMember == nil || isTransferring)
        }
        .padding(20)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(LocalizedStrings.Common.cancel) {
            onCancel()
          }
        }
      }
    }
  }
}
