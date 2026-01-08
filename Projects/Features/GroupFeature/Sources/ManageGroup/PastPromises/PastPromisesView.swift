import Clients
import SwiftUI
import ComposableArchitecture
import PromisoShared

extension PastPromises {
  public struct RootView: View {
    @Bindable private var store: StoreOf<PastPromises.Feature>

    public init(store: StoreOf<PastPromises.Feature>) {
      self.store = store
    }

    private var groupedPromises: [(date: String, promises: [PromiseModel])] {
      guard let promises = store.promisesState.value else { return [] }

      let grouped = Dictionary(grouping: promises) { promise -> String in
        formatDateHeader(promise.startAt)
      }

      // 최신순 정렬 (내림차순)
      return grouped.sorted { lhs, rhs in
        guard let lhsDate = lhs.value.first?.startAt,
              let rhsDate = rhs.value.first?.startAt else { return false }
        return lhsDate > rhsDate
      }.map { (date: $0.key, promises: $0.value) }
    }

    public var body: some View {
      Group {
        switch store.promisesState {
        case .idle, .loading:
          loadingView

        case .loaded(let promises):
          if promises.isEmpty {
            emptyView
          } else {
            promiseListView
          }

        case .failed:
          errorView
        }
      }
      .auroraBackground()
      .navigationTitle("지난 약속")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { store.send(.view(.onAppear)) }
      .refreshable { store.send(.view(.refreshTriggered)) }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      VStack {
        Spacer()
        ProgressView()
          .scaleEffect(1.2)
        Spacer()
      }
    }

    // MARK: - Empty View

    @ViewBuilder
    private var emptyView: some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "calendar.badge.clock")
          .font(.system(size: 64))
          .foregroundStyle(
            LinearGradient(
              colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        Text("지난 약속이 없습니다")
          .font(.headline)
          .foregroundStyle(.secondary)

        Text("완료된 약속이 여기에 표시됩니다")
          .font(.subheadline)
          .foregroundStyle(.tertiary)

        Spacer()
      }
      .padding()
    }

    // MARK: - Error View

    @ViewBuilder
    private var errorView: some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text("데이터를 불러올 수 없습니다")
          .font(.headline)
          .foregroundStyle(.secondary)

        Button(action: { store.send(.view(.refreshTriggered)) }) {
          Text("다시 시도")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(Capsule())
        }

        Spacer()
      }
      .padding()
    }

    // MARK: - Promise List View

    @ViewBuilder
    private var promiseListView: some View {
      List {
        ForEach(groupedPromises, id: \.date) { section in
          Section {
            ForEach(section.promises) { promise in
              PastPromiseCardRow(
                promise: promise,
                currentUserId: store.currentUserId,
                groupMembers: store.groupMembers,
                onTap: { store.send(.view(.promiseTapped(promise))) }
              )
              .onAppear {
                // 마지막 아이템이 나타나면 더 불러오기
                if promise.id == store.promisesState.value?.last?.id {
                  store.send(.view(.loadMoreTriggered))
                }
              }
            }
          } header: {
            sectionHeader(for: section.date)
          }
          .listSectionSeparator(.hidden)
        }

        // 로딩 인디케이터
        if store.isLoadingMore {
          HStack {
            Spacer()
            ProgressView()
              .padding(.vertical, 16)
            Spacer()
          }
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func sectionHeader(for date: String) -> some View {
      HStack {
        Text(date)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)
          .textCase(nil)

        Rectangle()
          .fill(Color(.systemGray4))
          .frame(height: 1)
      }
      .padding(.horizontal, 16)
      .padding(.top, date == groupedPromises.first?.date ? 12 : 24)
      .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")

      let currentYear = Calendar.current.component(.year, from: Date())
      let dateYear = Calendar.current.component(.year, from: date)

      if dateYear == currentYear {
        formatter.dateFormat = "M월 d일"
      } else {
        formatter.dateFormat = "yyyy년 M월 d일"
      }

      return formatter.string(from: date)
    }
  }
}

// MARK: - Past Promise Card Row

private struct PastPromiseCardRow: View {
  let promise: PromiseModel
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let onTap: () -> Void

  private var host: UserPublicModel? {
    groupMembers?.first { $0.userId == promise.hostId }
  }

  private var acceptedMembers: [UserPublicModel] {
    guard let members = groupMembers else { return [] }
    return promise.votes.accepted.compactMap { acceptedId in
      members.first { $0.userId == acceptedId }
    }
  }

  private var statusText: String {
    if promise.status == .completed || promise.isConfirmed {
      return "완료"
    } else {
      return "불발"
    }
  }

  private var statusColor: Color {
    if promise.status == .completed || promise.isConfirmed {
      return .green
    } else {
      return .gray
    }
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 14) {
        // Host Section
        HStack(spacing: 10) {
          ProfileAvatarView(
            profileImageUrl: host?.profileImageUrl,
            displayName: host?.displayName ?? "",
            isCurrentUser: promise.isHost(userId: currentUserId),
            size: 32
          )

          VStack(alignment: .leading, spacing: 2) {
            if let hostName = host?.displayName {
              Text("\(hostName)님의 약속")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            } else {
              Text("약속")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            }
          }

          Spacer()

          // Status Badge
          Text(statusText)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
        }

        Divider()

        // Main Content
        HStack(alignment: .top, spacing: 12) {
          Text(promise.displayEmoji)
            .font(.system(size: 44))

          VStack(alignment: .leading, spacing: 10) {
            Text(promise.title)
              .font(.system(size: 19, weight: .bold))
              .foregroundColor(.primary)

            if let description = promise.description, !description.isEmpty {
              Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
            }

            // Time
            HStack(spacing: 4) {
              Text("⏰")
                .font(.system(size: 14))
              Text(promise.timeText)
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)

            // Location
            if promise.locationText != "장소 미정" {
              HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                  .font(.system(size: 13))
                  .foregroundColor(.red)
                Text(promise.locationText)
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)
            }
          }

          Spacer()
        }

        // Bottom Section - Participant count & Avatars
        HStack {
          Text("\(promise.votes.acceptedCount)/\(promise.minimumParticipants)명 참여")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)

          Spacer()

          if !acceptedMembers.isEmpty {
            HStack(spacing: -8) {
              ForEach(acceptedMembers.prefix(4)) { member in
                ProfileAvatarView(
                  profileImageUrl: member.profileImageUrl,
                  displayName: member.displayName,
                  isCurrentUser: member.userId == currentUserId,
                  size: 24
                )
              }

              if acceptedMembers.count > 4 {
                Text("+\(acceptedMembers.count - 4)")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundColor(.white)
                  .frame(width: 24, height: 24)
                  .background(Color.gray)
                  .clipShape(Circle())
                  .overlay(Circle().stroke(Color.white, lineWidth: 2))
              }
            }
          }
        }
      }
      .padding(16)
      .background(Color(.systemBackground).opacity(0.8))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color(.systemGray5), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
  }
}
