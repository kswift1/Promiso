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
                Label("소개", systemImage: "text.alignleft")
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
                label: "현재 인원",
                value: "\(store.group.memberIds.count)"
              )

              Divider()
                .frame(height: 40)

              statItem(
                icon: "person.3.fill",
                label: "최대 인원",
                value: "\(store.group.maxMembers)"
              )

              Divider()
                .frame(height: 40)

              statItem(
                icon: "clock.fill",
                label: "진행중 약속",
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
              Label("멤버", systemImage: "person.2")
                .font(.headline)
                .foregroundStyle(.primary)

              Spacer()

              if case .loaded(let members) = store.membersState {
                Text("\(members.count)명")
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
              Label("지난 약속", systemImage: "clock.arrow.circlepath")
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
      .navigationTitle("그룹 상세")
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
        "그룹 나가기",
        isPresented: $showLeaveConfirmation,
        actions: {
          Button("나가기", role: .destructive) {
            store.send(.view(.confirmLeave))
          }
          Button("취소", role: .cancel) {}
        },
        message: {
          Text("정말로 이 그룹을 나가시겠습니까?")
        }
      )
      .confirmationDialog(
        "그룹 삭제",
        isPresented: $showDeleteConfirmation,
        actions: {
          Button("삭제", role: .destructive) {
            store.send(.view(.confirmDelete))
          }
          Button("취소", role: .cancel) {}
        },
        message: {
          Text("그룹을 삭제하면 모든 멤버가 그룹에서 제거되며, 복구할 수 없습니다.")
        }
      )
      .alert(
        "오류",
        isPresented: .constant(store.leaveError != nil || store.deleteError != nil),
        actions: {
          Button("확인") {
            store.send(.view(.dismissError))
          }
        },
        message: {
          if let error = store.leaveError ?? store.deleteError {
            Text(error)
          }
        }
      )
      .overlay {
        if let member = store.selectedMemberForImage {
          ImageDetailView(
            imageUrl: member.profileImageUrl,
            displayName: member.nickname,
            onDismiss: {
              store.send(.view(.imageDetailDismissed))
            }
          )
          .ignoresSafeArea()
          .transition(.opacity)
          .zIndex(1)
        } else if store.showGroupImageDetail {
          ImageDetailView(
            imageUrl: store.group.imageUrl,
            displayName: store.group.name,
            onDismiss: {
              store.send(.view(.imageDetailDismissed))
            }
          )
          .ignoresSafeArea()
          .transition(.opacity)
          .zIndex(1)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: store.selectedMemberForImage != nil)
      .animation(.easeInOut(duration: 0.2), value: store.showGroupImageDetail)
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
        "호스트 양도",
        isPresented: $showTransferConfirmation,
        actions: {
          Button("양도", role: .destructive) {
            store.send(.view(.confirmTransferHost))
          }
          Button("취소", role: .cancel) {
            store.send(.view(.cancelTransferHost))
          }
        },
        message: {
          if let newHost = store.selectedNewHost {
            Text("\(newHost.nickname)님에게 호스트를 양도하시겠습니까?\n양도 후에는 되돌릴 수 없습니다.")
          }
        }
      )
      .alert(
        "호스트 양도 실패",
        isPresented: .constant(store.transferError != nil),
        actions: {
          Button("확인") {
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
          Text(store.isHost ? "호스트" : "멤버")
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
          Text("멤버 목록을 불러올 수 없습니다")
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

                  Text("호스트 양도")
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

                Text("그룹 삭제")
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

                Text("그룹 나가기")
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
      print("Failed to load image: \(error)")
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

          Text("새로운 호스트 선택")
            .font(.title2.weight(.bold))

          Text("그룹을 관리할 새로운 호스트를 선택해주세요")
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
                Text("호스트 양도")
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
          Button("취소") {
            onCancel()
          }
        }
      }
    }
  }
}
