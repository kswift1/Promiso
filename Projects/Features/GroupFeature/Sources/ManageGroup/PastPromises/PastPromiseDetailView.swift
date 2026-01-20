import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

extension PastPromiseDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection
          participantsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("지난 약속")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(
        item: Binding(
          get: { store.memberSheet },
          set: { _ in store.send(.view(.memberSheetDismissed)) }
        )
      ) { sheetState in
        MemberListSheet(
          title: sheetState.title,
          members: sheetState.members,
          colorType: sheetState.colorType
        )
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      VStack(spacing: 16) {
        Text(store.promise.displayEmoji)
          .font(.system(size: 64))

        Text(store.promise.title)
          .font(.system(size: 24, weight: .bold))
          .multilineTextAlignment(.center)

        if let description = store.promise.description, !description.isEmpty {
          ExpandableText(text: description, isExpanded: $isDescriptionExpanded)
        }

        // 상태 배지 (완료/불발)
        PastStatusBadge(promise: store.promise)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        SectionHeader(title: "일정")

        VStack(spacing: 0) {
          EmojiInfoRow(
            emoji: "📅",
            title: "날짜",
            value: formatDate(store.promise.startAt)
          )

          Divider().padding(.leading, 44)

          EmojiInfoRow(
            emoji: "⏰",
            title: "시간",
            value: store.promise.timeText
          )

          if store.promise.location != nil {
            Divider().padding(.leading, 44)

            EmojiInfoRow(
              emoji: "📍",
              title: "장소",
              value: store.promise.locationText
            )
          }
        }
        .adaptiveGlassCard(cornerRadius: 12)
      }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
      VStack(spacing: 0) {
        SectionHeader(
          title: "참여자",
          trailing: "\(store.promise.votes.acceptedCount)/\(store.promise.minimumParticipants)명"
        )

        VStack(spacing: 12) {
          if !store.promise.votes.accepted.isEmpty {
            ParticipantGroupRow(
              title: "참여",
              count: store.promise.votes.acceptedCount,
              userIds: store.promise.votes.accepted,
              members: store.groupMembers,
              colorType: .accepted
            ) {
              store.send(.view(.participantGroupTapped(
                title: "참여",
                userIds: store.promise.votes.accepted,
                colorType: .accepted
              )))
            }
          }

          if !store.promise.votes.declined.isEmpty {
            ParticipantGroupRow(
              title: "불참",
              count: store.promise.votes.declinedCount,
              userIds: store.promise.votes.declined,
              members: store.groupMembers,
              colorType: .declined
            ) {
              store.send(.view(.participantGroupTapped(
                title: "불참",
                userIds: store.promise.votes.declined,
                colorType: .declined
              )))
            }
          }

          if let members = store.groupMembers {
            let respondedIds = Set(store.promise.votes.accepted + store.promise.votes.declined)
            let pendingUserIds = members.filter { !respondedIds.contains($0.userId) }.map(\.userId)

            if !pendingUserIds.isEmpty {
              ParticipantGroupRow(
                title: "미응답",
                count: pendingUserIds.count,
                userIds: pendingUserIds,
                members: members,
                colorType: .pending
              ) {
                store.send(.view(.participantGroupTapped(
                  title: "미응답",
                  userIds: pendingUserIds,
                  colorType: .pending
                )))
              }
            }
          }
        }
      }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "M월 d일"
      return formatter.string(from: date)
    }
  }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
  let title: String
  var trailing: String? = nil

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Spacer()

      if let trailing {
        Text(trailing)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 8)
  }
}

private struct ExpandableText: View {
  let text: String
  @Binding var isExpanded: Bool
  @State private var isTruncated = false
  private let lineLimit = 3

  var body: some View {
    VStack(spacing: 4) {
      Text(text)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(isExpanded ? nil : lineLimit)
        .background(
          GeometryReader { geometry in
            Color.clear.onAppear {
              checkTruncation(geometry: geometry)
            }
          }
        )

      if isTruncated || isExpanded {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        } label: {
          Text(isExpanded ? "접기" : "더보기")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.blue)
        }
      }
    }
  }

  private func checkTruncation(geometry: GeometryProxy) {
    let font = UIFont.systemFont(ofSize: 15)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = CGSize(width: geometry.size.width, height: .greatestFiniteMagnitude)
    let boundingRect = (text as NSString).boundingRect(
      with: size,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
    let lineHeight = font.lineHeight
    let numberOfLines = Int(ceil(boundingRect.height / lineHeight))
    isTruncated = numberOfLines > lineLimit
  }
}

private struct EmojiInfoRow: View {
  let emoji: String
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 10) {
      Text(emoji)
        .font(.system(size: 18))
        .frame(width: 28)

      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.system(size: 15, weight: .medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct ParticipantGroupRow: View {
  let title: String
  let count: Int
  let userIds: [String]
  let members: [UserPublicModel]?
  let colorType: PastPromiseDetail.Feature.ParticipantColorType
  let onTap: () -> Void

  private var color: Color {
    switch colorType {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .gray
    }
  }

  var body: some View {
    Button(action: onTap) {
      HStack {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)

        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)

        Text("\(count)명")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Spacer()

        HStack(spacing: -8) {
          ForEach(userIds.prefix(5), id: \.self) { userId in
            if let member = members?.first(where: { $0.userId == userId }) {
              ProfileAvatarView(
                profileImageUrl: member.profileImageUrl,
                displayName: member.displayName,
                size: 28
              )
            } else {
              ProfileAvatarView(
                profileImageUrl: nil,
                displayName: "?",
                size: 28
              )
            }
          }

          if userIds.count > 5 {
            Text("+\(userIds.count - 5)")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 28, height: 28)
              .background(Color.gray)
              .clipShape(Circle())
              .overlay(Circle().stroke(Color.white, lineWidth: 2))
          }
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .adaptiveGlassCard(cornerRadius: 12)
    }
    .buttonStyle(.plain)
  }
}

private struct PastStatusBadge: View {
  let promise: PromiseModel

  private var statusText: String {
    promise.isConfirmed ? "완료" : "미성사"
  }

  private var color: Color {
    promise.isConfirmed ? .green : .gray
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: promise.isConfirmed ? "checkmark.circle.fill" : "xmark.circle.fill")
        .font(.system(size: 12))
      Text(statusText)
        .font(.system(size: 13, weight: .semibold))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
  }
}

// MARK: - Member List Sheet

private struct MemberListSheet: View {
  let title: String
  let members: [UserPublicModel]
  let colorType: PastPromiseDetail.Feature.ParticipantColorType

  private var color: Color {
    switch colorType {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .gray
    }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(members) { member in
            MemberRow(member: member, color: color)

            if member.id != members.last?.id {
              Divider().padding(.leading, 72)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .navigationTitle("\(title) (\(members.count)명)")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

private struct MemberRow: View {
  let member: UserPublicModel
  let color: Color

  var body: some View {
    HStack(spacing: 16) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        size: 48,
        borderWidth: 0
      )

      VStack(alignment: .leading, spacing: 4) {
        Text(member.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)

        if !member.nickname.isEmpty && member.nickname != member.displayName {
          Text("@\(member.nickname)")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Circle()
        .fill(color)
        .frame(width: 10, height: 10)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }
}

