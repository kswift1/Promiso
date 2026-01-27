import SwiftUI
import PromisoShared

// MARK: - Upcoming Card

/// 다가오는 약속 개별 카드
struct UpcomingCard: View {
  let promise: PromiseModel
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 날짜 배지
        dateBadge

        // 약속 정보
        promiseInfo

        Spacer(minLength: 0)

        // 우측 화살표
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(Color.green.opacity(0.03))
      .adaptiveGlassCard(cornerRadius: 14)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Date Badge

  private var dateBadge: some View {
    VStack(spacing: 2) {
      Text(monthString)
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(Color.pmindigo.n500)

      Text(dayString)
        .font(.title3)
        .fontWeight(.bold)
        .foregroundStyle(.primary)

      Text(weekdayString)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(width: 44)
    .padding(.vertical, 6)
    .background(Color.pmindigo.n500.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  // MARK: - Promise Info

  private var promiseInfo: some View {
    VStack(alignment: .leading, spacing: 4) {
      // 이모지 + 제목
      HStack(spacing: 6) {
        Text(promise.displayEmoji)
          .font(.body)

        Text(promise.title)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      // 시간 + 장소
      HStack(spacing: 8) {
        // 시간
        HStack(spacing: 3) {
          Image(systemName: "clock")
            .font(.caption2)

          Text(timeString)
            .font(.caption)
        }

        // 장소
        if let location = promise.location {
          HStack(spacing: 3) {
            Image(systemName: "location.fill")
              .font(.caption2)

            Text(location.name)
              .font(.caption)
              .lineLimit(1)
          }
        }
      }
      .foregroundStyle(.secondary)

      // 그룹 · 참여자
      groupParticipantsView
    }
  }

  // MARK: - Group & Participants View

  private var groupParticipantsView: some View {
    HStack(spacing: 4) {
      // 그룹 아이콘
      GroupThumbnailView(
        imageUrl: promise.group?.imageUrl,
        name: promise.group?.name ?? "",
        size: 14
      )

      // 그룹명 · 참여자
      if let groupName = promise.group?.name {
        Text("\(groupName) · \(promise.votes.accepted.count)명 참여 확정")
          .font(.caption)
      } else {
        Text("\(promise.votes.accepted.count)명 참여 확정")
          .font(.caption)
      }
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Computed Properties

  private var monthString: String {
    KoreanDateFormatters.month.string(from: promise.startAt)
  }

  private var dayString: String {
    KoreanDateFormatters.day.string(from: promise.startAt)
  }

  private var weekdayString: String {
    KoreanDateFormatters.weekday.string(from: promise.startAt)
  }

  private var timeString: String {
    promise.startAt.formattedTime
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 10) {
    UpcomingCard(
      promise: PromiseModel.mock(
        id: "1",
        title: "팀 미팅",
        startAt: Date().addingTimeInterval(86400)
      ),
      onTap: {}
    )

    UpcomingCard(
      promise: PromiseModel.mock(
        id: "2",
        title: "저녁 식사",
        startAt: Date().addingTimeInterval(172800)
      ),
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
