import Clients
import SwiftUI
import ComposableArchitecture
import Nuke

extension ManageGroup {
  public struct RootView: View {
    @Bindable private var store: StoreOf<ManageGroup.Feature>
    @State private var isCopied = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false

    public init(store: StoreOf<ManageGroup.Feature>) {
      self.store = store
    }

    private var deeplinkURL: URL {
      URL(string: "promiso://join/\(store.group.inviteCode)")!
    }

    private var shareMessage: String {
      """
      \(store.group.name) 그룹에 초대합니다! 🎉

      아래 링크를 클릭하여 참여하세요:
      \(deeplinkURL.absoluteString)

      또는 초대 코드를 직접 입력하세요: \(store.group.inviteCode)
      """
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
                value: "\(store.group.activePromiseCount)"
              )
            }
            .frame(maxWidth: .infinity)
          }
          .padding(20)
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)

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
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 20))
          .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)

          // Invite Section
          inviteSection

          // Leave/Delete Button
          actionButtons

          Spacer()
            .frame(height: 8)
        }
        .padding(.horizontal, 20)
      }
      .navigationTitle("그룹 상세")
      .navigationBarTitleDisplayMode(.inline)
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
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 20) {
        // Group Image
        GroupImageView(imageUrl: store.group.imageUrl)

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
            isHost: member.userId == store.group.createdBy
          )
        }
      }
    }

    // MARK: - Invite Section

    @ViewBuilder
    private var inviteSection: some View {
      VStack(spacing: 16) {
        HStack {
          Label("초대 코드", systemImage: "link.circle.fill")
            .font(.headline)
            .foregroundStyle(.primary)

          Spacer()
        }

        // Code Display with Copy Button
        HStack(spacing: 12) {
          Text(store.group.inviteCode)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .tracking(3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )

          Button(action: copyCode) {
            ZStack {
              RoundedRectangle(cornerRadius: 16)
                .fill(
                  isCopied
                  ? LinearGradient(
                    colors: [.green, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                  : LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 56, height: 56)
                .shadow(
                  color: isCopied ? .green.opacity(0.3) : .blue.opacity(0.3),
                  radius: 8,
                  x: 0,
                  y: 4
                )

              Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            }
          }
          .animation(.spring(response: 0.3), value: isCopied)
        }

        if isCopied {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14))
            Text("복사되었습니다!")
              .font(.subheadline.weight(.medium))
          }
          .foregroundStyle(.green)
          .transition(.scale.combined(with: .opacity))
        }

        // Share Button
        ShareLink(item: shareMessage) {
          HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 18))
            Text("초대 링크 공유하기")
              .font(.headline)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 14))
          .shadow(
            color: .blue.opacity(0.3),
            radius: 10,
            x: 0,
            y: 5
          )
        }
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color(.systemBackground))
          .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
      )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
      if store.isHost {
        // Delete Button (Host only)
        Button {
          showDeleteConfirmation = true
        } label: {
          HStack(spacing: 8) {
            if store.isDeletingGroup {
              ProgressView()
                .tint(.white)
            } else {
              Image(systemName: "trash.fill")
                .font(.system(size: 18))
            }

            Text(store.isDeletingGroup ? "삭제 중..." : "그룹 삭제")
              .font(.system(size: 16, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(
            LinearGradient(
              colors: [.red, .orange],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .shadow(
            color: .red.opacity(0.3),
            radius: 12,
            x: 0,
            y: 6
          )
        }
        .disabled(store.isDeletingGroup)
      } else {
        // Leave Button (Member only)
        Button {
          showLeaveConfirmation = true
        } label: {
          HStack(spacing: 8) {
            if store.isLeavingGroup {
              ProgressView()
                .tint(.white)
            } else {
              Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 18))
            }

            Text(store.isLeavingGroup ? "나가는 중..." : "그룹 나가기")
              .font(.system(size: 16, weight: .semibold))
          }
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(Color(.systemGray5))
          .foregroundStyle(.primary)
          .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(store.isLeavingGroup)
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
  @State private var loadedImage: UIImage?
  @State private var isLoading = false

  var body: some View {
    VStack(spacing: 8) {
      ZStack(alignment: .topTrailing) {
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 64, height: 64)

          if let loadedImage {
            Image(uiImage: loadedImage)
              .resizable()
              .scaledToFill()
              .frame(width: 64, height: 64)
              .clipShape(Circle())
          } else if isLoading {
            ProgressView()
              .tint(.secondary)
          } else {
            Text(initials)
              .font(.system(size: 24, weight: .semibold))
              .foregroundStyle(
                LinearGradient(
                  colors: [.blue, .purple],
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
    .task {
      await loadImage()
    }
  }

  private var initials: String {
    String(member.name.prefix(1))
  }

  private func loadImage() async {
    guard let profile = member.profile else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      guard let url = URL(string: profile.url) else { return }
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }
}

// MARK: - Group Image View

private struct GroupImageView: View {
  let imageUrl: String?
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
