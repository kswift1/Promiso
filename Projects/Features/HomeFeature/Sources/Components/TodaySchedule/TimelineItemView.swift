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
      HStack(alignment: .top, spacing: 0) {
        // 타임라인 인디케이터 (가장 왼쪽, 패딩 영향 없음)
        timelineIndicator

        // 시간 + 콘텐츠 + 뱃지 (패딩 적용)
        HStack(alignment: .top, spacing: 0) {
          timeLabel
            .frame(width: 56, alignment: .leading)
            .padding(.leading, 12)

          promiseContent
            .padding(.leading, 8)

          Spacer(minLength: 0)

          if promise.group != nil {
            groupBadge
          }
        }
        .padding(.vertical, 5)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Timeline Indicator

  private var timelineIndicator: some View {
    VStack(spacing: 0) {
      // 상단 라인 (첫 번째가 아니면 표시)
      Rectangle()
        .fill(isFirst ? Color.clear : Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2, height: 10)

      // 점 (항상 시간 위치에 맞춤)
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

      // 하단 라인 (마지막이 아니면 표시, 남은 공간 채움)
      Rectangle()
        .fill(isLast ? Color.clear : Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }
    .frame(width: 16)
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

      // 참여자 수
      Text("\(promise.votes.accepted.count)명 참여")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Group Badge

  private var groupBadge: some View {
    HStack(spacing: 6) {
      GroupThumbnailView(
        imageUrl: promise.group?.imageUrl,
        name: promise.group?.name ?? "",
        size: 20
      )

      if let groupName = promise.group?.name {
        Text(groupName)
          .font(.caption)
          .fontWeight(.medium)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.pmindigo.n500.opacity(0.1))
    .foregroundStyle(Color.pmindigo.n600)
    .clipShape(Capsule())
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(startTimeString)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if let endAt = promise.endAt {
        Text("~ \(endTimeString(endAt))")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if isNow {
        Text("NOW")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(Color.pmindigo.n500)
      }
    }
  }

  // MARK: - Computed Properties

  private var startTimeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: promise.startAt)
  }

  private func endTimeString(_ endAt: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: endAt)
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
