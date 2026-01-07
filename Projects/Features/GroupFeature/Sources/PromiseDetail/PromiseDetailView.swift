import SwiftUI
import UIKit
import ComposableArchitecture
import Clients
import PromisoShared

extension PromiseDetail {
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
          responseSection

          if store.isHost {
            hostActionsSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            store.send(.view(.shareTapped))
          } label: {
            Image(systemName: "square.and.arrow.up")
          }
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      VStack(spacing: 16) {
        // 이모지
        Text(store.promise.displayEmoji)
          .font(.system(size: 64))

        // 제목
        Text(store.promise.title)
          .font(.system(size: 24, weight: .bold))
          .multilineTextAlignment(.center)

        // 설명
        if let description = store.promise.description, !description.isEmpty {
          ExpandableText(text: description, isExpanded: $isDescriptionExpanded)
        }

        // 상태 배지
        StatusBadgeView(status: store.responseStatus)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        SectionHeader(title: "일정")

        VStack(spacing: 0) {
          // 날짜 & 시간
          EmojiInfoRow(
            emoji: "📅",
            title: "날짜",
            value: formatFullDate(store.promise.startAt)
          )

          Divider().padding(.leading, 44)

          EmojiInfoRow(
            emoji: "⏰",
            title: "시간",
            value: store.promise.timeText
          )

          // 장소
          if store.promise.location != nil {
            Divider().padding(.leading, 44)

            EmojiInfoRow(
              emoji: "📍",
              title: "장소",
              value: store.promise.locationText
            )
          }

          // 투표 마감
          if let deadline = store.promise.deadlineText {
            Divider().padding(.leading, 44)

            EmojiInfoRow(
              emoji: "⏳",
              title: "투표 마감",
              value: deadline
            )
          }
        }
        .glassCard()
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
          // 수락
          if !store.promise.votes.accepted.isEmpty {
            ParticipantGroup(
              title: "참여",
              count: store.promise.votes.acceptedCount,
              userIds: store.promise.votes.accepted,
              members: store.groupMembers,
              color: .green
            )
          }

          // 거절
          if !store.promise.votes.declined.isEmpty {
            ParticipantGroup(
              title: "불참",
              count: store.promise.votes.declinedCount,
              userIds: store.promise.votes.declined,
              members: store.groupMembers,
              color: .red
            )
          }

          // 대기 (그룹 멤버 - 수락 - 거절)
          if let members = store.groupMembers {
            let respondedIds = Set(store.promise.votes.accepted + store.promise.votes.declined)
            let pendingUserIds = members.filter { !respondedIds.contains($0.userId) }.map(\.userId)

            if !pendingUserIds.isEmpty {
              ParticipantGroup(
                title: "미응답",
                count: pendingUserIds.count,
                userIds: pendingUserIds,
                members: members,
                color: .gray
              )
            }
          }
        }
      }
    }

    // MARK: - Response Section

    private var responseSection: some View {
      VStack(spacing: 12) {
        SectionHeader(title: "내 응답")

        HStack(spacing: 12) {
          // 수락 버튼
          ResponseButton(
            title: "참여",
            icon: "checkmark.circle.fill",
            color: .green,
            isSelected: store.myVoteStatus == .accepted,
            isLoading: store.respondingState == .accepting
          ) {
            store.send(.view(.acceptTapped))
          }

          // 거절 버튼
          ResponseButton(
            title: "불참",
            icon: "xmark.circle.fill",
            color: .red,
            isSelected: store.myVoteStatus == .declined,
            isLoading: store.respondingState == .rejecting
          ) {
            store.send(.view(.rejectTapped))
          }
        }

        // 되돌리기 버튼
        if store.myVoteStatus != .pending {
          Button {
            store.send(.view(.resetTapped))
          } label: {
            HStack(spacing: 6) {
              if store.respondingState == .resetting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                  .scaleEffect(0.8)
              }
              Text("미정으로 되돌리기")
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.secondary)
          }
          .disabled(store.respondingState != .idle)
          .padding(.top, 4)
        }
      }
    }

    // MARK: - Host Actions Section

    private var hostActionsSection: some View {
      VStack(spacing: 12) {
        SectionHeader(title: "호스트 옵션")

        VStack(spacing: 0) {
          Button {
            store.send(.view(.editTapped))
          } label: {
            HStack {
              Image(systemName: "pencil")
                .foregroundStyle(.blue)
              Text("약속 수정")
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          }

          Divider().padding(.leading, 44)

          Button {
            store.send(.view(.deleteTapped))
          } label: {
            HStack {
              if store.isDeleting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .red))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              }
              Text("약속 삭제")
                .foregroundStyle(.red)
              Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          }
          .disabled(store.isDeleting)
        }
        .glassCard()
      }
    }

    // MARK: - Helpers

    private func formatFullDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "M월 d일 (E)"
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

private struct ParticipantGroup: View {
  let title: String
  let count: Int
  let userIds: [String]
  let members: [UserPublicModel]?
  let color: Color

  var body: some View {
    HStack {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)

      Text(title)
        .font(.system(size: 14, weight: .medium))

      Text("\(count)명")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)

      Spacer()

      // 참여자 아바타 (최대 5명)
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
            .background(
              LinearGradient(
                colors: [Color(red: 0.6, green: 0.6, blue: 0.65), Color(red: 0.45, green: 0.45, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .clipShape(Circle())
            .overlay(
              Circle()
                .stroke(Color.white, lineWidth: 2)
            )
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .glassCard()
  }
}

private struct ResponseButton: View {
  let title: String
  let icon: String
  let color: Color
  let isSelected: Bool
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : color))
            .scaleEffect(0.8)
        } else {
          Image(systemName: icon)
            .font(.system(size: 18))
        }

        Text(title)
          .font(.system(size: 16, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(isSelected ? color : color.opacity(0.1))
      .foregroundStyle(isSelected ? .white : color)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(isLoading || isSelected)
  }
}

private struct StatusBadgeView: View {
  let status: PromiseResponseStatus

  private var displayText: String {
    switch status {
    case .needResponse:
      return "응답 필요"
    case .responded:
      return "확정 대기"
    case .confirmed:
      return "확정됨"
    case .failed:
      return "불발"
    }
  }

  private var color: Color {
    switch status {
    case .needResponse:
      return .orange
    case .responded:
      return .blue
    case .confirmed:
      return .green
    case .failed:
      return .gray
    }
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.iconName)
        .font(.system(size: 12))
      Text(displayText)
        .font(.system(size: 13, weight: .semibold))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
  }
}

// MARK: - Glass Card Modifier

private extension View {
  func glassCard() -> some View {
    self
      .background(Color(.systemBackground).opacity(0.8))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(.systemGray5), lineWidth: 1)
      )
  }
}
