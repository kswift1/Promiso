import SwiftUI
import PromisoShared

struct ScheduleGlassCard: View {
  let schedule: ScheduleModel
  let currentUserId: String
  let weather: WeatherInfo?
  let onTap: () -> Void

  private var myVoteStatus: VoteStatus {
    schedule.myVoteStatus(userId: currentUserId)
  }

  private var statusColor: Color {
    switch myVoteStatus {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .orange
    }
  }

  // 투표 현황
  private var acceptedCount: Int { schedule.votes.accepted.count }
  private var declinedCount: Int { schedule.votes.declined.count }
  private var totalResponded: Int { acceptedCount + declinedCount }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 시간 + 확정 여부
        VStack(spacing: 4) {
          Text(timeText)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.primary)

          if schedule.isConfirmed {
            Image(systemName: "checkmark.circle.fill")
              .font(.caption)
              .foregroundStyle(.green)
          }
        }
        .frame(width: 50)

        // 일정 내용
        VStack(alignment: .leading, spacing: 6) {
          // 제목
          HStack(spacing: 6) {
            Text(schedule.displayEmoji)
              .font(.title3)

            Text(schedule.title)
              .font(.system(size: 16, weight: .semibold))
              .lineLimit(1)
          }

          // 장소
          if let location = schedule.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.caption2)

              Text(location.name)
                .font(.caption)
                .lineLimit(1)
            }
            .foregroundStyle(.secondary)
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
            if !schedule.isConfirmed {
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

          // 날씨
          if let weather = weather,
             let forecast = weather.forecast(for: schedule.startAt) {
            WeatherCardStrip(
              forecast: forecast,
              rangeForecasts: weather.forecasts(from: schedule.startAt, to: schedule.endAt),
              referenceTimeText: schedule.startAt.formattedMonthDayTime,
              forecastSource: weather.forecastSource(for: schedule.startAt)
            )
          }
        }

        Spacer()

        // 우측: 투표 프로그레스 링
        if !schedule.isConfirmed && totalResponded > 0 {
          CircularProgressView(
            current: acceptedCount,
            total: schedule.minimumParticipants,
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
    schedule.startAt.formattedTime
  }

  private var statusText: String {
    if myVoteStatus == .pending {
      let calendar = Calendar.scheduleDisplay
      let daysLeft = calendar.dateComponents([.day], from: Date(), to: schedule.votes.until).day ?? 0
      return "D-\(daysLeft)"
    } else {
      return myVoteStatus == .accepted ? LocalizedStrings.Home.accepted : LocalizedStrings.Home.declined
    }
  }

  /// 카드 배경 - 확정/진행중 구분
  private var cardBackground: some ShapeStyle {
    if schedule.isConfirmed {
      return Color.green.opacity(0.05)
    } else if myVoteStatus == .pending {
      return Color.orange.opacity(0.05)
    } else {
      return Color.clear
    }
  }
}
