import SwiftUI
import PromisoShared

struct PromiseGlassCard: View {
  let promise: PromiseModel
  let currentUserId: String
  let weather: WeatherInfo?
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

  // 투표 현황
  private var acceptedCount: Int { promise.votes.accepted.count }
  private var declinedCount: Int { promise.votes.declined.count }
  private var totalResponded: Int { acceptedCount + declinedCount }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 시간 + 확정 여부
        VStack(spacing: 4) {
          Text(timeText)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)

          if promise.isConfirmed {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
        .frame(width: 50)

        // 약속 내용
        VStack(alignment: .leading, spacing: 6) {
          // 제목
          HStack(spacing: 6) {
            Text(promise.displayEmoji)
              .font(.title3)

            Text(promise.title)
              .font(.system(size: 16, weight: .semibold))
              .lineLimit(1)
          }

          // 장소 + 날씨
          if let location = promise.location {
            HStack(spacing: 6) {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.caption2)

                Text(location.name)
                  .font(.caption)
                  .lineLimit(1)
              }
              .foregroundStyle(.secondary)

              if let weather = weather,
                 let forecast = weather.forecast(for: promise.startAt) {
                WeatherBadge(
                  forecast: forecast,
                  referenceTimeText: promise.startAt.formattedTime
                )
              }
            }
          }

          // 하단: 투표 상태 점 + 마감 정보
          HStack(spacing: 8) {
            // 투표 상태 점
            VoteDotsView(
              accepted: acceptedCount,
              declined: declinedCount,
              pending: 0  // pending 정보 없음
            )

            // 내 상태 + 마감
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
        }

        Spacer()

        // 우측: 투표 프로그레스 링
        if !promise.isConfirmed && totalResponded > 0 {
          CircularProgressView(
            current: acceptedCount,
            total: promise.minimumParticipants,
            size: 36,
            lineWidth: 3
          )
        }
      }
      .padding(14)
      .background(cardBackground)
      .adaptiveGlassCard(cornerRadius: 14)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Computed Properties

  private var timeText: String {
    promise.startAt.formattedTime
  }

  private var statusText: String {
    if myVoteStatus == .pending {
      let calendar = Calendar.current
      let daysLeft = calendar.dateComponents([.day], from: Date(), to: promise.votes.until).day ?? 0
      return "D-\(daysLeft)"
    } else {
      return myVoteStatus == .accepted ? "참여" : "불참"
    }
  }

  /// 카드 배경 - 확정/진행중 구분
  private var cardBackground: some ShapeStyle {
    if promise.isConfirmed {
      return Color.green.opacity(0.05)
    } else if myVoteStatus == .pending {
      return Color.orange.opacity(0.05)
    } else {
      return Color.clear
    }
  }
}
