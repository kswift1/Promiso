import Clients
import PromisoShared
import SwiftUI

struct PromiseCard: View {
  let promise: PromiseModel
  let currentUserId: String
  let onAccept: () -> Void
  let onReject: () -> Void
  let onDelete: (() -> Void)?
  let onChangeResponse: ((PromiseAttendanceStatus) -> Void)?

  private var isLocationUndecided: Bool {
    promise.locationText == "장소 미정"
  }

  private var isHost: Bool {
    promise.isHost(userId: currentUserId)
  }

  private var myVoteStatus: VoteStatus {
    promise.myVoteStatus(userId: currentUserId)
  }

  private var responseStatus: PromiseResponseStatus {
    promise.responseStatus(currentUserId: currentUserId)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      // Host Section
      HStack(spacing: 10) {
        // Profile Image (placeholder - host info would need to be fetched separately)
        Circle()
          .fill(
            LinearGradient(
              colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 32, height: 32)
          .overlay(
            Text("H")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(.white)
          )

        VStack(alignment: .leading, spacing: 2) {
          Text(isHost ? "내가 만든 약속" : "약속")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)

          if isHost {
            Text("호스트")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.blue)
          }
        }

        Spacer()

        // Status Badge
        StatusBadge(status: responseStatus)
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

          // Description
          if let description = promise.description, !description.isEmpty {
            Text(description)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .lineLimit(2)
          }

          VStack(alignment: .leading, spacing: 6) {
            // Date & Time
            HStack(spacing: 6) {
              Image(systemName: "calendar")
                .font(.system(size: 13))
                .foregroundColor(.blue)
              Text("\(promise.dateText) \(promise.timeText)")
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)

            // Location (only if not "장소 미정")
            if !isLocationUndecided {
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
        }

        Spacer()
      }

      // Bottom Section - Vote counts
      HStack(spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: "person.2.fill")
            .font(.system(size: 11))
          Text("\(promise.votes.acceptedCount)/\(promise.minimumParticipants)명")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.secondary)

        Spacer()

        if let deadline = promise.deadlineText, responseStatus == .needResponse {
          HStack(spacing: 4) {
            Image(systemName: "clock.fill")
              .font(.system(size: 11))
            Text(deadline)
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundColor(.orange)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.orange.opacity(0.1))
          .clipShape(Capsule())
        }
      }

      // My response badge
      if myVoteStatus != .pending {
        ResponseBadge(status: myVoteStatus == .accepted ? .accepted : .declined)
      }
    }
    .padding(16)
    .adaptiveGlassCardBackground()
    .contextMenu {
      // 응답 변경 옵션
      if let onChangeResponse = onChangeResponse {
        Section("응답 변경") {
          if myVoteStatus != .accepted {
            Button(action: { onChangeResponse(.accepted) }) {
              Label("수락", systemImage: "checkmark.circle.fill")
            }
          }

          if myVoteStatus != .declined {
            Button(action: { onChangeResponse(.declined) }) {
              Label("거절", systemImage: "xmark.circle.fill")
            }
          }

          if myVoteStatus != .pending {
            Button(action: { onChangeResponse(.pending) }) {
              Label("미정으로 되돌리기", systemImage: "arrow.uturn.backward.circle.fill")
            }
          }
        }
      }

      // Host인 경우 삭제 옵션
      if isHost, let onDelete = onDelete {
        Button(role: .destructive, action: onDelete) {
          Label("약속 삭제", systemImage: "trash")
        }
      }

      // 항상 표시되는 옵션들
      Button(action: {}) {
        Label("상세 보기", systemImage: "info.circle")
      }

      Button(action: {}) {
        Label("공유하기", systemImage: "square.and.arrow.up")
      }
    }
  }
}

// MARK: - Glass Effect Modifier

private extension View {
  func adaptiveGlassCardBackground() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .strokeBorder(.white.opacity(0.2), lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
      )
    } else {
      return AnyView(
        self
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color(.systemGray5), lineWidth: 1)
          )
      )
    }
  }
}

private struct ResponseBadge: View {
  let status: PromiseAttendanceStatus

  private var title: String {
    switch status {
    case .accepted:
      return "수락함"
    case .declined:
      return "거절함"
    case .pending:
      return ""
    }
  }

  private var color: Color {
    switch status {
    case .accepted:
      return .green
    case .declined:
      return .red
    case .pending:
      return .blue
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text("내 응답: \(title)")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(color)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(color.opacity(0.12))
    .clipShape(Capsule())
  }
}

private struct StatusBadge: View {
  let status: PromiseResponseStatus

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.iconName)
        .font(.system(size: 12, weight: .semibold))

      Text(status.displayText)
        .font(.system(size: 12, weight: .semibold))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(backgroundColor)
    .foregroundColor(foregroundColor)
    .clipShape(Capsule())
  }

  private var backgroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange.opacity(0.1)
    case .confirmed:
      return Color.green.opacity(0.1)
    case .sent:
      return Color.blue.opacity(0.1)
    }
  }

  private var foregroundColor: Color {
    switch status {
    case .needResponse:
      return Color.orange
    case .confirmed:
      return Color.green
    case .sent:
      return Color.blue
    }
  }
}

// MARK: - Extension

extension PromiseResponseStatus {
  var displayText: String {
    switch self {
    case .needResponse: return "답변 필요"
    case .confirmed: return "확정됨"
    case .sent: return "응답 대기"
    }
  }

  var iconName: String {
    switch self {
    case .needResponse: return "exclamationmark.circle.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .sent: return "paperplane.fill"
    }
  }
}
