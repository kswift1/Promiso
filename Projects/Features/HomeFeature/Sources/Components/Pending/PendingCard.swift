import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Pending Card

/// 응답 필요 개별 카드 - 탭하면 해당 그룹 약속으로 이동
struct PendingCard: View {
  let promise: PromiseModel
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 10) {
        // 상단: D-day 배지
        HStack {
          dDayBadge
          Spacer()
        }

        // 중간: 이모지 + 제목
        HStack(spacing: 6) {
          Text(promise.displayEmoji)
            .font(.title3)

          Text(promise.title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
            .lineLimit(1)
        }

        // 날짜 + 시간
        HStack(spacing: 4) {
          ResourceKitAsset.calendarIcon.swiftUIImage
            .resizable()
            .renderingMode(.template)
            .frame(width: 12, height: 12)

          Text(dateTimeString)
            .font(.caption)
        }
        .foregroundStyle(.secondary)

        // 그룹 정보
        groupInfoView

        // 투표 현황
        voteProgressView
      }
      .padding(14)
      .frame(width: 160)
      .background(dDayColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
      .adaptiveGlassBackground(cornerRadius: 16)
    }
    .buttonStyle(.plain)
  }

  // MARK: - D-Day Badge

  private var dDayBadge: some View {
    Text(dDayText)
      .font(.caption)
      .fontWeight(.bold)
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(dDayColor)
      .clipShape(Capsule())
  }

  // MARK: - Group Info View

  @ViewBuilder
  private var groupInfoView: some View {
    if let group = promise.group {
      HStack(spacing: 4) {
        // 그룹 아이콘
        GroupThumbnailView(
          imageUrl: group.imageUrl,
          name: group.name,
          size: 14
        )

        Text(group.name)
          .font(.caption)
          .lineLimit(1)
      }
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Vote Progress View

  private var voteProgressView: some View {
    HStack(spacing: 6) {
      // 진행 바
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.gray.opacity(0.2))

          Capsule()
            .fill(progressColor)
            .frame(width: geometry.size.width * progressRatio)
        }
      }
      .frame(height: 4)

      // 참여자 수
      Text("\(promise.votes.accepted.count)/\(promise.minimumParticipants)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Computed Properties

  private var dDayText: String {
    let now = Date()
    let voteDate = promise.votes.until
    let hoursRemaining = voteDate.timeIntervalSince(now) / 3600

    // 24시간 이내면 시간/분 단위로 표시
    if hoursRemaining <= 0 {
      return LocalizedStrings.Home.closed
    } else if hoursRemaining < 1 {
      let minutes = max(1, Int(ceil(hoursRemaining * 60)))
      return LocalizedStrings.Home.minutesRemaining(minutes)
    } else if hoursRemaining <= 24 {
      let hours = Int(ceil(hoursRemaining))
      return LocalizedStrings.Home.hoursRemaining(hours)
    }

    // 그 외에는 D-day 표시
    let calendar = Calendar.current
    let nowDay = calendar.startOfDay(for: now)
    let voteDay = calendar.startOfDay(for: voteDate)
    let days = calendar.dateComponents([.day], from: nowDay, to: voteDay).day ?? 0

    if days == 0 {
      return "D-DAY"
    } else {
      return "D-\(days)"
    }
  }

  private var dDayColor: Color {
    let now = Date()
    let voteDate = promise.votes.until
    let hoursRemaining = voteDate.timeIntervalSince(now) / 3600

    // 24시간 이내면 빨강
    if hoursRemaining <= 24 {
      return .red
    }

    let calendar = Calendar.current
    let nowDay = calendar.startOfDay(for: now)
    let voteDay = calendar.startOfDay(for: voteDate)
    let days = calendar.dateComponents([.day], from: nowDay, to: voteDay).day ?? 0

    if days <= 1 {
      return .red
    } else if days <= 3 {
      return .orange
    } else {
      return Color.pmindigo.n500
    }
  }

  private var dateTimeString: String {
    LocalizedDateFormatters.shortDateTime.string(from: promise.startAt)
  }

  private var progressRatio: CGFloat {
    guard promise.minimumParticipants > 0 else { return 0 }
    return min(1.0, CGFloat(promise.votes.accepted.count) / CGFloat(promise.minimumParticipants))
  }

  private var progressColor: Color {
    if progressRatio >= 1.0 {
      return .green
    } else if progressRatio >= 0.5 {
      return .orange
    } else {
      return Color.pmindigo.n500
    }
  }
}

// MARK: - Preview

#Preview {
  HStack {
    PendingCard(
      promise: PromiseModel.mock(id: "1", title: "저녁 모임"),
      onTap: {}
    )

    PendingCard(
      promise: PromiseModel.mock(id: "2", title: "주말 약속"),
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
