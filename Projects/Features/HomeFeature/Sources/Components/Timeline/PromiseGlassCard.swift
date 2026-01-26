import SwiftUI
import PromisoShared

struct PromiseGlassCard: View {
  let promise: PromiseModel
  let currentUserId: String
  let onTap: () -> Void

  private var myVoteStatus: VoteStatus {
    promise.myVoteStatus(userId: currentUserId)
  }

  private var statusColor: Color {
    switch myVoteStatus {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .orange
    }
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 시간 + 확정 여부
        VStack(spacing: 2) {
          Text(timeText)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)

          if promise.isConfirmed {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption2)
              .foregroundStyle(.green)
          }
        }
        .frame(width: 60)

        // 약속 내용
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Text(promise.displayEmoji)
              .font(.title3)

            Text(promise.title)
              .font(.system(size: 16, weight: .semibold))
              .lineLimit(1)
          }

          // 장소
          if let location = promise.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.caption2)

              Text(location.name)
                .font(.caption)
                .lineLimit(1)
            }
            .foregroundStyle(.secondary)
          }

          // 응답 상태 또는 투표 현황
          if !promise.isConfirmed {
            HStack(spacing: 4) {
              Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

              Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }

        Spacer()
      }
      .padding(14)
      .adaptiveGlassCard(cornerRadius: 14)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Computed Properties

  private var timeText: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: promise.startAt)
  }

  private var statusText: String {
    if myVoteStatus == .pending {
      let calendar = Calendar.current
      let daysLeft = calendar.dateComponents([.day], from: Date(), to: promise.votes.until).day ?? 0
      return "D-\(daysLeft) 마감"
    } else {
      return "\(promise.votes.accepted.count)/\(promise.minimumParticipants)명 참여"
    }
  }
}

// MARK: - Preview

#Preview("확정된 약속") {
  VStack(spacing: 12) {
    PromiseGlassCard(
      promise: PromiseModel.mock(
        title: "점심 약속",
        emoji: "🍕",
        votes: PromiseVotesModel(
          accepted: ["user1", "user2"],
          declined: [],
          until: Date().addingTimeInterval(86400)
        ),
        startAt: Date().addingTimeInterval(7200)
      ),
      currentUserId: "user1",
      onTap: {}
    )

    PromiseGlassCard(
      promise: PromiseModel.mock(
        title: "커피 타임",
        emoji: "☕",
        votes: PromiseVotesModel(
          accepted: ["user1", "user2"],
          declined: [],
          until: Date().addingTimeInterval(86400)
        ),
        startAt: Date().addingTimeInterval(14400),
        location: LocationInfoModel(name: "스타벅스 강남점")
      ),
      currentUserId: "user1",
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}

#Preview("응답 필요") {
  VStack(spacing: 12) {
    PromiseGlassCard(
      promise: PromiseModel.mock(
        title: "저녁 약속",
        emoji: "🍽️",
        votes: PromiseVotesModel(
          accepted: ["user2"],
          declined: [],
          until: Date().addingTimeInterval(86400 * 2)
        ),
        startAt: Date().addingTimeInterval(28800)
      ),
      currentUserId: "user1",
      onTap: {}
    )

    PromiseGlassCard(
      promise: PromiseModel.mock(
        title: "팀 미팅",
        emoji: "💼",
        votes: PromiseVotesModel(
          accepted: [],
          declined: [],
          until: Date().addingTimeInterval(86400)
        ),
        startAt: Date().addingTimeInterval(36000)
      ),
      currentUserId: "user1",
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
