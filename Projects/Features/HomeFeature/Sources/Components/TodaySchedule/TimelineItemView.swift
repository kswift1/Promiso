import SwiftUI
import PromisoShared

// MARK: - Timeline Item View

/// 오늘의 일정 타임라인 개별 아이템
struct TimelineItemView: View {
  let promise: PromiseModel
  let isFirst: Bool
  let isLast: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        // 타임라인 인디케이터
        timelineIndicator

        // 콘텐츠
        promiseContent

        Spacer(minLength: 0)

        // 시간
        timeLabel
      }
      .padding(.vertical, 10)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Timeline Indicator

  private var timelineIndicator: some View {
    VStack(spacing: 0) {
      // 상단 라인
      if !isFirst {
        Rectangle()
          .fill(Color.pmindigo.n300.opacity(0.3))
          .frame(width: 2, height: 8)
      } else {
        Color.clear
          .frame(width: 2, height: 8)
      }

      // 점
      Circle()
        .fill(isNow ? Color.pmindigo.n500 : Color.pmindigo.n300)
        .frame(width: 10, height: 10)
        .overlay {
          if isNow {
            Circle()
              .stroke(Color.pmindigo.n500.opacity(0.3), lineWidth: 3)
              .frame(width: 16, height: 16)
          }
        }

      // 하단 라인
      if !isLast {
        Rectangle()
          .fill(Color.pmindigo.n300.opacity(0.3))
          .frame(width: 2)
          .frame(maxHeight: .infinity)
      } else {
        Color.clear
          .frame(width: 2)
          .frame(maxHeight: .infinity)
      }
    }
    .frame(width: 20)
  }

  // MARK: - Promise Content

  private var promiseContent: some View {
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

      // 참여자
      participantsView
    }
  }

  // MARK: - Participants View

  private var participantsView: some View {
    HStack(spacing: 4) {
      Image(systemName: "person.2.fill")
        .font(.caption2)

      Text("\(promise.votes.accepted.count)명 참여")
        .font(.caption)
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(timeString)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if isNow {
        Text("NOW")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(Color.pmindigo.n500)
      }
    }
  }

  // MARK: - Computed Properties

  private var timeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: promise.startAt)
  }

  /// 현재 진행 중인 약속인지 (시작 30분 전 ~ 시작 후 2시간)
  private var isNow: Bool {
    let now = Date()
    let thirtyMinutesBefore = promise.startAt.addingTimeInterval(-1800)
    let twoHoursAfter = promise.startAt.addingTimeInterval(7200)
    return now >= thirtyMinutesBefore && now <= twoHoursAfter
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 0) {
    TimelineItemView(
      promise: PromiseModel.mock(
        id: "1",
        title: "점심 모임",
        startAt: Date().addingTimeInterval(1800)
      ),
      isFirst: true,
      isLast: false,
      onTap: {}
    )

    TimelineItemView(
      promise: PromiseModel.mock(
        id: "2",
        title: "카페 미팅",
        startAt: Date().addingTimeInterval(7200)
      ),
      isFirst: false,
      isLast: true,
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
