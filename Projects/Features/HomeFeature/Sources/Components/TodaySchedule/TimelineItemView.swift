import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Timeline Item View

/// 오늘의 일정 타임라인 개별 아이템
struct TimelineItemView: View {
  let promise: PromiseModel
  let isFirst: Bool
  let isLast: Bool
  let weather: WeatherInfo?
  let onTap: () -> Void

  @State private var showLiveActivityInfo = false

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 0) {
        // 타임라인 인디케이터 (가장 왼쪽, 패딩 영향 없음)
        timelineIndicator

        // 시간 + 콘텐츠 + Divider (패딩 적용)
        VStack(spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            timeLabel
              .frame(width: 80, alignment: .center)
              .padding(.leading, 8)

            promiseContent
              .padding(.leading, 8)

            Spacer(minLength: 0)
          }
          .padding(.vertical, 8)

          // 날씨
          if let weather = weather,
             let forecast = weather.forecast(for: promise.startAt) {
            WeatherCardStrip(
              forecast: forecast,
              rangeForecasts: weather.forecasts(from: promise.startAt, to: promise.endAt),
              referenceTimeText: promise.startAt.formattedMonthDayTime,
              forecastSource: weather.forecastSource(for: promise.startAt)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
          }

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

      // 점 (상태에 따라 색상 변경)
      Circle()
        .fill(dotColor)
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
          .font(.pmTitle3)

        Text(promise.title)
          .font(.pmBodySemibold)
          .foregroundStyle(.primary)
          .lineLimit(1)
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
            .font(.pmCaption)
            .lineLimit(1)

          Text("·")
            .font(.pmCaption)
        }

        Text("\(promise.votes.accepted.count)명 참여 확정")
          .font(.pmCaption)
      }
      .foregroundStyle(.secondary)

      // 장소 + 날씨
      if let location = promise.location {
        HStack(spacing: 4) {
          ResourceKitAsset.locationIcon.swiftUIImage
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 14, height: 14)

          Text(location.name)
            .font(.pmCaption)
            .lineLimit(1)
        }
        .foregroundStyle(.secondary)
      }

      // 실시간 공유 시작 시간
      if let minutes = promise.trackingStartMinutesBefore {
        HStack(spacing: 4) {
          Image(systemName: "antenna.radiowaves.left.and.right")
            .font(.pmCaption2)

          Text(liveStartTimeString(minutes: minutes))
            .font(.pmCaption)

          Button {
            showLiveActivityInfo = true
          } label: {
            Image(systemName: "info.circle")
              .font(.pmCaption2)
          }
          .popover(isPresented: $showLiveActivityInfo, arrowEdge: .top) {
            LiveActivityInfoPopover(
              emoji: promise.displayEmoji,
              title: promise.title,
              location: promise.location?.name,
              promiseTime: promise.startAt
            )
          }
        }
        .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .center, spacing: 2) {
      Text(startTimeString)
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if let endAt = promise.endAt {
        VStack(alignment: .center, spacing: 0) {
          Text("~")
            .font(.pmCaption)
            .foregroundStyle(.secondary)
          Text(endTimeString(endAt))
            .font(.pmCaption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else if isNow {
        Text("NOW")
          .font(.pmCaption2Semibold)
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

  /// 실시간 공유 시작 시간 문자열
  private func liveStartTimeString(minutes: Int) -> String {
    let liveStartTime = promise.startAt.addingTimeInterval(-Double(minutes * 60))
    return "\(liveStartTime.formattedTime) 실시간 공유 시작"
  }

  /// 현재 진행 중인 약속인지 (종료시간 없으면 단발성 = 시작 즉시 종료)
  private var isNow: Bool {
    let now = Date()
    return now >= promise.startAt && now <= promise.effectiveEndAt
  }

  /// 이미 종료된 약속인지
  var isPast: Bool {
    Date() > promise.effectiveEndAt
  }

  /// 아직 시작 전인 약속인지
  var isFuture: Bool {
    let now = Date()
    return now < promise.startAt
  }

  /// dot 색상 (진행 중: 파랑, 종료: 회색, 대기: 연한 파랑)
  private var dotColor: Color {
    if isNow {
      return Color.pmindigo.n500
    } else if isPast {
      return Color.pmgray.n400
    } else {
      return Color.pmindigo.n300
    }
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
      weather: nil,
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
      weather: nil,
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
