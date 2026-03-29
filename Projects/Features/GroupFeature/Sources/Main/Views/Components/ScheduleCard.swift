import Clients
import PromisoShared
import ResourceKit
import SwiftUI

struct ScheduleCard: View {
  let schedule: ScheduleModel
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let respondingState: GroupMain.RespondingState
  let isLive: Bool
  let onTap: () -> Void
  let onAccept: () -> Void
  let onReject: () -> Void
  let onEdit: (() -> Void)?
  let onDelete: (() -> Void)?
  let onChangeResponse: ((ScheduleAttendanceStatus) -> Void)?
  let onShare: (() -> Void)?
  let onDirections: (() -> Void)?
  let statusOverride: ScheduleResponseStatus?
  let showsResponseDetails: Bool

  let weather: WeatherInfo?
  let conflicts: [ConflictInfo]
  let isCheckingConflicts: Bool
  let conflictsChecked: Bool

  init(
    schedule: ScheduleModel,
    currentUserId: String,
    groupMembers: [UserPublicModel]?,
    respondingState: GroupMain.RespondingState,
    isLive: Bool = false,
    weather: WeatherInfo? = nil,
    conflicts: [ConflictInfo] = [],
    isCheckingConflicts: Bool = false,
    conflictsChecked: Bool = false,
    onTap: @escaping () -> Void,
    onAccept: @escaping () -> Void,
    onReject: @escaping () -> Void,
    onEdit: (() -> Void)? = nil,
    onDelete: (() -> Void)? = nil,
    onChangeResponse: ((ScheduleAttendanceStatus) -> Void)? = nil,
    onShare: (() -> Void)? = nil,
    onDirections: (() -> Void)? = nil,
    statusOverride: ScheduleResponseStatus? = nil,
    showsResponseDetails: Bool = true
  ) {
    self.schedule = schedule
    self.currentUserId = currentUserId
    self.groupMembers = groupMembers
    self.respondingState = respondingState
    self.isLive = isLive
    self.weather = weather
    self.conflicts = conflicts
    self.isCheckingConflicts = isCheckingConflicts
    self.conflictsChecked = conflictsChecked
    self.onTap = onTap
    self.onAccept = onAccept
    self.onReject = onReject
    self.onEdit = onEdit
    self.onDelete = onDelete
    self.onChangeResponse = onChangeResponse
    self.onShare = onShare
    self.onDirections = onDirections
    self.statusOverride = statusOverride
    self.showsResponseDetails = showsResponseDetails
  }

  /// 수정 가능 여부 (호스트 && 시작 전)
  private var canEdit: Bool {
    isHost && schedule.startAt > Date()
  }

  private var host: UserPublicModel? {
    groupMembers?.first { $0.userId == schedule.hostId }
  }

  private var votedMembers: [UserPublicModel] {
    guard let members = groupMembers else { return [] }
    let votedIds = schedule.votes.accepted + schedule.votes.declined
    return votedIds.compactMap { votedId in
      members.first { $0.userId == votedId }
    }
  }

  private var isLocationUndecided: Bool {
    schedule.location?.name == nil
  }

  private var hasCoordinates: Bool {
    schedule.location?.latitude != nil && schedule.location?.longitude != nil
  }

  private var isHost: Bool {
    schedule.isHost(userId: currentUserId)
  }

  private var myVoteStatus: VoteStatus {
    schedule.myVoteStatus(userId: currentUserId)
  }

  private var responseStatus: ScheduleResponseStatus {
    schedule.responseStatus(currentUserId: currentUserId, totalGroupMembers: groupMembers?.count)
  }

  private var displayStatus: ScheduleResponseStatus {
    statusOverride ?? responseStatus
  }

  // MARK: - Participation Progress

  private var totalMembers: Int {
    groupMembers?.count ?? schedule.minimumParticipants
  }

  private var acceptedCount: Int {
    schedule.votes.acceptedCount
  }

  private var declinedCount: Int {
    schedule.votes.declinedCount
  }

  private var participationProgress: some View {
    let total = max(totalMembers, schedule.minimumParticipants)
    let accepted = acceptedCount
    let declined = declinedCount
    let confirm = schedule.minimumParticipants
    let isConfirmed = accepted >= confirm

    return VStack(spacing: 6) {
      // 프로그레스 바
      GeometryReader { geometry in
        let barWidth = geometry.size.width
        let acceptedRatio = min(1.0, CGFloat(accepted) / CGFloat(max(total, 1)))
        let declinedRatio = min(1.0 - acceptedRatio, CGFloat(declined) / CGFloat(max(total, 1)))
        let confirmRatio = min(1.0, CGFloat(confirm) / CGFloat(max(total, 1)))

        ZStack(alignment: .leading) {
          // 배경 (전체)
          Capsule()
            .fill(Color.gray.opacity(0.15))

          // 참여 + 불참 채움
          HStack(spacing: 0) {
            Rectangle()
              .fill(isConfirmed ? Color.green : Color.green.opacity(0.7))
              .frame(width: max(0, barWidth * acceptedRatio))
            Rectangle()
              .fill(Color.red.opacity(0.5))
              .frame(width: max(0, barWidth * declinedRatio))
          }
          .clipShape(Capsule())

          // 인원별 마디 (점선)
          if total > 1 {
            ForEach(1..<total, id: \.self) { i in
              let x = barWidth * CGFloat(i) / CGFloat(total)
              RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.gray.opacity(0.35))
                .frame(width: 1, height: 6)
                .offset(x: x - 0.5)
            }
          }

          // 확정 기준선
          if confirm < total {
            RoundedRectangle(cornerRadius: 1)
              .fill(Color.pmindigo.n500)
              .frame(width: 2, height: 10)
              .offset(x: barWidth * confirmRatio - 1)
          }
        }
        .animation(.easeInOut(duration: 0.35), value: accepted)
        .animation(.easeInOut(duration: 0.35), value: declined)
      }
      .frame(height: 6)

      // 범례 + 내 응답
      HStack(spacing: 0) {
        HStack(spacing: 3) {
          Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
          Text(LocalizedStrings.ScheduleCard.acceptedCount(accepted))
            .contentTransition(.numericText())
            .foregroundColor(.green)
        }

        Text(" · ")
          .foregroundColor(.secondary.opacity(0.5))

        HStack(spacing: 3) {
          Circle()
            .fill(Color.red.opacity(0.7))
            .frame(width: 6, height: 6)
          Text(LocalizedStrings.ScheduleCard.declinedCount(declined))
            .contentTransition(.numericText())
            .foregroundColor(.red)
        }

        Text(" · ")
          .foregroundColor(.secondary.opacity(0.5))

        HStack(spacing: 3) {
          RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.pmindigo.n500)
            .frame(width: 2, height: 8)
          Text(LocalizedStrings.ScheduleCard.confirmedCount(confirm))
            .foregroundColor(Color.pmindigo.n500)
        }

        Text(" · ")
          .foregroundColor(.secondary.opacity(0.5))

        HStack(spacing: 3) {
          Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 6, height: 6)
          Text(LocalizedStrings.ScheduleCard.totalCount(totalMembers))
            .foregroundColor(.secondary)
        }

        Spacer()

        // 내 응답 + 아바타
        if myVoteStatus != .pending {
          HStack(spacing: 4) {
            Circle()
              .fill(myVoteStatus == .accepted ? Color.green : Color.red)
              .frame(width: 5, height: 5)
            Text(myVoteStatus == .accepted ? LocalizedStrings.ScheduleCard.responseAccepted : LocalizedStrings.ScheduleCard.responseDeclined)
              .foregroundColor(myVoteStatus == .accepted ? .green : .red)
          }
          .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }

        if !votedMembers.isEmpty {
          ParticipantsAvatarView(
            members: votedMembers,
            currentUserId: currentUserId,
            maxDisplay: 4
          )
          .padding(.leading, 6)
        }
      }
      .font(.system(size: 11, weight: .medium))
      .minimumScaleFactor(0.8)
      .lineLimit(1)
      .animation(.easeInOut(duration: 0.35), value: accepted)
      .animation(.easeInOut(duration: 0.35), value: declined)
      .animation(.easeInOut(duration: 0.3), value: myVoteStatus)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Host Section
      HStack(spacing: 10) {
        // Profile Image
        ProfileAvatarView(
          profileImageUrl: host?.profileImageUrl,
          displayName: host?.displayName ?? "",
          isCurrentUser: isHost,
          size: 32
        )

        VStack(alignment: .leading, spacing: 2) {
          if isHost {
            Text(LocalizedStrings.ScheduleCard.myProposal)
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.primary)
          } else if let hostName = host?.displayName {
            Text(LocalizedStrings.ScheduleCard.hostProposal(hostName))
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.primary)
          } else {
            Text(LocalizedStrings.ScheduleCard.proposal)
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.primary)
          }
        }

        Spacer()

        // Live Badge (실시간 공유 중) 또는 Status Badge
        if isLive {
          LiveBadge()
        } else {
          StatusBadge(status: displayStatus, respondingState: respondingState)
        }
      }

      Divider()

      // Main Content
      HStack(alignment: .top, spacing: 12) {
        Text(schedule.displayEmoji)
          .font(.system(size: 44))

        VStack(alignment: .leading, spacing: 10) {
          Text(schedule.title)
            .font(.system(size: 19, weight: .bold))
            .foregroundColor(.primary)

          // Description
          if let description = schedule.description, !description.isEmpty {
            Text(description)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .lineLimit(3)
          }

          VStack(alignment: .leading, spacing: 6) {
            // Date & Time
            HStack(spacing: 4) {
              Text("⏰")
                .font(.system(size: 14))
              Text("\(schedule.dateText) \(schedule.timeRangeText)")
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)

            // Location (only if not "장소 미정")
            if !isLocationUndecided {
              HStack(spacing: 4) {
                Text("📍")
                  .font(.system(size: 14))
                Text(schedule.locationText)
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.primary)
            }

            // Arrival Sharing (과거 일정은 표시 안 함)
            if let minutes = schedule.trackingStartMinutesBefore, !schedule.isPast {
              HStack(spacing: 4) {
                Text("📡")
                  .font(.system(size: 14))
                Text(LocalizedStrings.ScheduleCard.liveShareStart(minutes))
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.secondary)
            }

            // 사진 첨부 표시
            if !schedule.imageUrls.isEmpty {
              HStack(spacing: 4) {
                Text("📷")
                  .font(.system(size: 14))
                Text(LocalizedStrings.ScheduleCard.photoCount(schedule.imageUrls.count))
                  .font(.system(size: 14, weight: .medium))
              }
              .foregroundColor(.secondary)
            }
          }
        }

        Spacer()
      }

      // Bottom Section - 참여 현황 프로그레스
      participationProgress

      // 길찾기 버튼 (Live 상태 + 좌표가 있을 때)
      if showsResponseDetails, isLive && hasCoordinates, let onDirections {
        HStack {
          Spacer()
          Button(action: onDirections) {
            HStack(spacing: 4) {
              Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.system(size: 12, weight: .semibold))
              Text(LocalizedStrings.Common.directions)
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Color.pmindigo.n500)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.pmindigo.n500.opacity(0.12))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      // PRO 혜택 (날씨 + 충돌 통합)
      ProBenefitCardView(
        weather: weather,
        eventStartAt: schedule.startAt,
        eventEndAt: schedule.endAt,
        conflicts: conflicts,
        isCheckingConflicts: isCheckingConflicts,
        eventTitle: schedule.title,
        eventEmoji: schedule.displayEmoji,
        conflictsChecked: conflictsChecked
      )
    }
    .padding(16)
    .adaptiveGlassCard()
    .contextMenu {
      // 응답 변경 옵션 (과거 일정, 실시간 공유 중인 일정은 제외)
      if let onChangeResponse = onChangeResponse, !schedule.isPast, !schedule.isRealtimeShareable {
        Section(LocalizedStrings.ScheduleCard.changeResponse) {
          if myVoteStatus != .accepted {
            Button(action: { onChangeResponse(.accepted) }) {
              Label(LocalizedStrings.ScheduleCard.acceptAction, systemImage: "checkmark.circle.fill")
            }
          }

          if myVoteStatus != .declined {
            Button(action: { onChangeResponse(.declined) }) {
              Label(LocalizedStrings.ScheduleCard.rejectAction, systemImage: "xmark.circle.fill")
            }
          }

          if myVoteStatus != .pending {
            Button(action: { onChangeResponse(.pending) }) {
              Label(LocalizedStrings.ScheduleCard.resetToPending, systemImage: "arrow.uturn.backward.circle.fill")
            }
          }
        }
      }

      // Host인 경우 수정/삭제 옵션
      if isHost {
        if canEdit, let onEdit = onEdit {
          Button(action: onEdit) {
            Label(LocalizedStrings.ScheduleCard.editSchedule, systemImage: "pencil")
          }
        }

        if let onDelete = onDelete {
          Button(role: .destructive, action: onDelete) {
            Label(LocalizedStrings.ScheduleCard.deleteSchedule, systemImage: "trash")
          }
        }
      }

      // 항상 표시되는 옵션들
      Button(action: onTap) {
        Label(LocalizedStrings.ScheduleCard.viewDetail, systemImage: "info.circle")
      }

      if let onShare {
        Button(action: onShare) {
          Label(LocalizedStrings.ScheduleCard.share, systemImage: "square.and.arrow.up")
        }
      }
    }
  }
}

// MARK: - Participants Avatar View

private struct ParticipantsAvatarView: View {
  let members: [UserPublicModel]
  let currentUserId: String
  let maxDisplay: Int

  private var displayMembers: [UserPublicModel] {
    Array(members.prefix(maxDisplay))
  }

  private var remainingCount: Int {
    max(0, members.count - maxDisplay)
  }

  var body: some View {
    HStack(spacing: -8) {
      ForEach(displayMembers) { member in
        ProfileAvatarView(
          profileImageUrl: member.profileImageUrl,
          displayName: member.displayName,
          isCurrentUser: member.userId == currentUserId,
          size: 24
        )
      }

      if remainingCount > 0 {
        Text("+\(remainingCount)")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.white)
          .frame(width: 24, height: 24)
          .background(
            LinearGradient(
              colors: [Color.pmgray.n400, Color.pmgray.n500],
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
}

private struct StatusBadge: View {
  let status: ScheduleResponseStatus
  let respondingState: GroupMain.RespondingState

  private var isResponding: Bool {
    respondingState != .idle
  }

  private var respondingText: String {
    switch respondingState {
    case .accepting:
      return LocalizedStrings.ScheduleCard.accepting
    case .rejecting:
      return LocalizedStrings.ScheduleCard.rejecting
    case .resetting:
      return LocalizedStrings.ScheduleCard.resetting
    case .idle:
      return ""
    }
  }

  private var respondingColor: Color {
    switch respondingState {
    case .accepting:
      return .green
    case .rejecting:
      return .red
    case .resetting:
      return .blue
    case .idle:
      return .clear
    }
  }

  var body: some View {
    HStack(spacing: 4) {
      if isResponding {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: respondingColor))
          .scaleEffect(0.7)

        Text(respondingText)
          .font(.system(size: 12, weight: .semibold))
      } else {
        Image(systemName: status.iconName)
          .font(.system(size: 12, weight: .semibold))

        Text(status.displayText)
          .font(.system(size: 12, weight: .semibold))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(isResponding ? respondingColor.opacity(0.1) : backgroundColor)
    .foregroundColor(isResponding ? respondingColor : foregroundColor)
    .clipShape(Capsule())
    .animation(.easeInOut(duration: 0.2), value: isResponding)
  }

  private var backgroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange.opacity(0.1)
    case .responded:
      return Color.blue.opacity(0.1)
    case .confirmed:
      return Color.green.opacity(0.1)
    case .expired:
      return Color.clear
    case .failed:
      return Color.gray.opacity(0.1)
    }
  }

  private var foregroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange
    case .responded:
      return Color.blue
    case .confirmed:
      return Color.green
    case .expired:
      return Color.gray
    case .failed:
      return Color.gray
    }
  }
}

// MARK: - Extension

extension ScheduleResponseStatus {
  var displayText: String {
    switch self {
    case .needResponse: return LocalizedStrings.ScheduleCard.statusNeedResponse
    case .responded: return LocalizedStrings.ScheduleCard.statusResponded
    case .confirmed: return LocalizedStrings.ScheduleCard.statusConfirmed
    case .expired: return LocalizedStrings.Common.expired
    case .failed: return LocalizedStrings.ScheduleCard.statusFailed
    }
  }

  var iconName: String {
    switch self {
    case .needResponse: return "exclamationmark.circle.fill"
    case .responded: return "clock.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .expired: return "clock.badge.xmark"
    case .failed: return "xmark.circle.fill"
    }
  }
}
