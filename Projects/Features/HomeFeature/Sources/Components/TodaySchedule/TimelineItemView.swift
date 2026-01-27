import SwiftUI
import PromisoShared
import ResourceKit

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

        // 시간 + 콘텐츠 + Divider (패딩 적용)
        VStack(spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            timeLabel
              .frame(width: 72, alignment: .center)
              .padding(.leading, 8)

            promiseContent
              .padding(.leading, 8)

            Spacer(minLength: 0)
          }
          .padding(.vertical, 8)

          // Divider (마지막 아이템 제외)
          if !isLast {
            Rectangle()
              .fill(Color.pmgray.n200)
              .frame(height: 0.5)
              .padding(.leading, 8)
              .padding(.trailing, 16)
          }
        }
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
          .font(.title3)

        Text(promise.title)
          .font(.body)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      // 장소
      if let location = promise.location {
        HStack(spacing: 4) {
          ResourceKitAsset.locationLogo.swiftUIImage
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)

          Text(location.name)
            .font(.caption)
            
            .lineLimit(1)
        }
        .foregroundStyle(.secondary)
      }

      // 그룹 + 참여자 수 + 확정
      HStack(spacing: 4) {
        if let group = promise.group {
          GroupThumbnailView(
            imageUrl: group.imageUrl,
            name: group.name,
            size: 18
          )

          Text(group.name)
            .font(.caption)
            .lineLimit(1)

          Text("·")
            .font(.caption)
        }

        Text("\(promise.votes.accepted.count)명 참여 확정")
          .font(.caption)
      }
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .center, spacing: 2) {
      Text(startTimeString)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if let endAt = promise.endAt {
        VStack(alignment: .center, spacing: 0) {
          Text("~")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(endTimeString(endAt))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
    promise.startAt.formattedTime
  }

  private func endTimeString(_ endAt: Date) -> String {
    KoreanDateFormatters.endTimeString(from: endAt)
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
