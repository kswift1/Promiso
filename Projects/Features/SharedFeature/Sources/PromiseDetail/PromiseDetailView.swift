import SwiftUI
import UIKit
import ComposableArchitecture
import Clients
import PromisoShared

extension PromiseDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection
          responseSection
          participantsSection
          liveActivitySection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          store.send(.view(.checkPendingIntents))
        }
      }
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
      .sheet(
        store: store.scope(state: \.$editPromise, action: \.editPromise)
      ) { editStore in
        EditPromise.RootView(store: editStore)
      }
      .alert(store: store.scope(state: \.$alert, action: \.alert))
      .sheet(isPresented: Binding(
        get: { store.showShareSheet },
        set: { _ in store.send(.view(.shareSheetDismissed)) }
      )) {
        ShareSheet(items: [store.promise.shareText])
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      HStack(alignment: .top, spacing: 12) {
        // 이모지
        Text(store.promise.displayEmoji)
          .font(.system(size: 44))

        // 제목 + 설명
        VStack(alignment: .leading, spacing: 6) {
          Text(store.promise.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)

          if let description = store.promise.description, !description.isEmpty {
            ExpandableText(text: description, isExpanded: $isDescriptionExpanded)
          }
        }

        Spacer()

        // 상태 배지 (우측 상단)
        StatusBadgeView(status: store.responseStatus)
      }
      .padding(16)
      .adaptiveGlassCard()
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

          Divider().padding(.leading, 44)

          // 최소 확정 인원
          EmojiInfoRow(
            emoji: "👥",
            title: "최소 확정 인원",
            value: "\(store.promise.minimumParticipants)명"
          )

          Divider().padding(.leading, 44)

          // 실시간 공유 시작
          EmojiInfoRow(
            emoji: "📡",
            title: "실시간 공유",
            value: formatRealtimeShareTime(store.promise.startAt)
          )
        }
        .adaptiveGlassCard()
      }
    }

    private func formatRealtimeShareTime(_ startAt: Date) -> String {
      let shareStartTime = startAt.addingTimeInterval(-1800) // 30분 전
      return "\(KoreanDateFormatters.time.string(from: shareStartTime))부터"
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
      VStack(spacing: 0) {
        SectionHeader(
          title: "참여자",
          trailing: "\(store.promise.votes.acceptedCount)/\(store.groupMembers?.count ?? 0)명 참여"
        )

        VStack(spacing: 12) {
          // 수락
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

          // 거절
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

          // 대기 (그룹 멤버 - 수락 - 거절)
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

    // MARK: - Response Section

    private var responseSection: some View {
      VStack(spacing: 0) {
        SectionHeader(title: "내 응답")

        ResponseBubblePicker(
          currentStatus: store.myVoteStatus,
          respondingState: store.respondingState,
          onAccept: { store.send(.view(.acceptTapped)) },
          onPending: { store.send(.view(.resetTapped)) },
          onDecline: { store.send(.view(.rejectTapped)) }
        )
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Live Activity Section

    @ViewBuilder
    private var liveActivitySection: some View {
      // 조건: 확정됨 + 30분 이내 + 내가 참여 중
      if store.promise.isConfirmed && store.promise.isRealtimeShareable && store.isParticipating {
        VStack(spacing: 0) {
          SectionHeader(title: "실시간 공유")

          VStack(spacing: 12) {
            if store.isLiveActivityActive {
              // 활성화 상태: 도착 버튼 + 종료 버튼
              Button {
                store.send(.view(.markArrivedTapped))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                  Text("도착 완료")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }

              Button {
                store.send(.view(.liveActivityStopTapped))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "stop.circle")
                    .font(.system(size: 18))
                  Text("실시간 공유 종료")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
            } else {
              // 비활성화 상태: 시작 버튼
              Button {
                store.send(.view(.liveActivityStartTapped))
              } label: {
                HStack(spacing: 8) {
                  if store.isStartingLiveActivity {
                    ProgressView()
                      .progressViewStyle(CircularProgressViewStyle(tint: .white))
                      .scaleEffect(0.8)
                  } else {
                    Image(systemName: "dot.radiowaves.left.and.right")
                      .font(.system(size: 18))
                  }
                  Text("실시간 공유 시작")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.pmindigo.n500)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .disabled(store.isStartingLiveActivity)

              Text("Dynamic Island에서 도착 현황을 확인할 수 있어요")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .padding(16)
          .adaptiveGlassCard()
        }
      }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        ToolbarButton(imageName: "square.and.arrow.up") {
          store.send(.view(.shareTapped))
        }
      }

      if store.isHost {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if store.canEdit {
              Button {
                store.send(.view(.editTapped))
              } label: {
                Label("약속 수정", systemImage: "pencil")
              }
            }

            Button(role: .destructive) {
              store.send(.view(.deleteTapped))
            } label: {
              Label("약속 삭제", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
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
    VStack(alignment: .leading, spacing: 4) {
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
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
  let colorType: PromiseDetail.Feature.ParticipantColorType
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

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .adaptiveGlassCard()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Member List Sheet

private struct MemberListSheet: View {
  let title: String
  let members: [UserPublicModel]
  let colorType: PromiseDetail.Feature.ParticipantColorType

  @State private var selectedMember: UserPublicModel?

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
            MemberRow(member: member, color: color) {
              selectedMember = member
            }

            if member.id != members.last?.id {
              Divider()
                .padding(.leading, 72)
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
    .fullScreenCover(item: $selectedMember) { member in
      ImageDetailView(
        imageUrl: member.profileImageUrl,
        displayName: member.displayName,
        onDismiss: { selectedMember = nil }
      )
    }
  }
}

private struct MemberRow: View {
  let member: UserPublicModel
  let color: Color
  let onProfileTap: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        size: 48,
        borderWidth: 0,
        onTap: onProfileTap
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


// MARK: - Response Bubble Picker

private struct ResponseBubblePicker: View {
  let currentStatus: VoteStatus
  let respondingState: PromiseDetail.Feature.RespondingState
  let onAccept: () -> Void
  let onPending: () -> Void
  let onDecline: () -> Void

  @State private var isExpanded = false
  private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
  private let selectionFeedback = UIImpactFeedbackGenerator(style: .heavy)

  private var isLoading: Bool {
    respondingState != .idle
  }

  private var statusColor: Color {
    switch currentStatus {
    case .accepted: return .green
    case .pending: return Color(.systemGray)
    case .declined: return .red
    }
  }

  private var statusIcon: String {
    switch currentStatus {
    case .accepted: return "checkmark"
    case .pending: return "minus"
    case .declined: return "xmark"
    }
  }

  private var statusText: String {
    switch currentStatus {
    case .accepted: return "참여"
    case .pending: return "미정"
    case .declined: return "불참"
    }
  }

  var body: some View {
    // 현재 상태 버튼
    Button {
      guard !isLoading else { return }
      feedbackGenerator.impactOccurred()
      isExpanded = true
    } label: {
      HStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(statusColor)
            .frame(width: 32, height: 32)

          if isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.7)
          } else {
            Image(systemName: statusIcon)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
          }
        }

        Text(statusText)
          .font(.system(size: 16, weight: .semibold))

        Spacer()

        Text("변경")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.secondarySystemBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
    .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
      ResponsePopoverContent(
        currentStatus: currentStatus,
        respondingState: respondingState,
        onSelect: { status in
          selectOption(status)
        }
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  private func selectOption(_ status: VoteStatus) {
    guard currentStatus != status else {
      isExpanded = false
      return
    }

    selectionFeedback.impactOccurred()

    switch status {
    case .accepted:
      onAccept()
    case .pending:
      onPending()
    case .declined:
      onDecline()
    }

    isExpanded = false
  }
}

private struct ResponsePopoverContent: View {
  let currentStatus: VoteStatus
  let respondingState: PromiseDetail.Feature.RespondingState
  let onSelect: (VoteStatus) -> Void

  var body: some View {
    HStack(spacing: 20) {
      PopoverBubble(
        icon: "checkmark",
        title: "참여",
        color: .green,
        isSelected: currentStatus == .accepted,
        isLoading: respondingState == .accepting
      ) {
        onSelect(.accepted)
      }

      PopoverBubble(
        icon: "minus",
        title: "미정",
        color: Color(.systemGray),
        isSelected: currentStatus == .pending,
        isLoading: respondingState == .resetting
      ) {
        onSelect(.pending)
      }

      PopoverBubble(
        icon: "xmark",
        title: "불참",
        color: .red,
        isSelected: currentStatus == .declined,
        isLoading: respondingState == .rejecting
      ) {
        onSelect(.declined)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }
}

private struct PopoverBubble: View {
  let icon: String
  let title: String
  let color: Color
  let isSelected: Bool
  let isLoading: Bool
  let action: () -> Void

  private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      feedbackGenerator.impactOccurred()
      action()
    } label: {
      VStack(spacing: 8) {
        ZStack {
          Circle()
            .fill(isSelected ? color : color.opacity(0.15))
            .frame(width: 56, height: 56)

          if isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : color))
              .scaleEffect(0.9)
          } else {
            Image(systemName: icon)
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(isSelected ? .white : color)
          }
        }
        .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, y: 3)

        Text(title)
          .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
          .foregroundStyle(isSelected ? color : .secondary)
      }
    }
    .disabled(isLoading)
    .scaleEffect(isSelected ? 1.05 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
      return "미성사"
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

