import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Personal Event Timeline Item View

/// 오늘의 일정 타임라인 개별 아이템 (개인 일정)
/// - 약속(Promise) 카드와 시각적으로 차별화: 라운드 사각형 인디케이터 + 보라 색상
/// - 컴팩트한 정보 레이아웃: 캡슐 배지, 장소, 알림, 메모 프리뷰
/// - 종료 일정: opacity 감소 + 취소선
struct PersonalEventTimelineItemView: View {
  let event: PersonalEventModel
  let isFirst: Bool
  let isLast: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 0) {
        // 타임라인 인디케이터 (라운드 사각형으로 약속과 차별화)
        timelineIndicator

        // 시간 + 콘텐츠 + Divider
        VStack(spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            timeLabel
              .frame(width: 80, alignment: .center)
              .padding(.leading, 8)

            eventContent
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
      .opacity(isPast ? 0.5 : 1.0)
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

  // MARK: - Event Content

  private var eventContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Row 1: 이모지 + 제목
      HStack(spacing: 6) {
        Text(event.displayEmoji)
          .font(.pmTitle3)

        Text(event.title)
          .font(.pmBodySemibold)
          .foregroundStyle(.primary)
          .strikethrough(isPast)
          .lineLimit(1)
      }

      // Row 2: 캡슐 배지 + 장소
      HStack(spacing: 6) {
        // "개인" 캡슐 배지
        HStack(spacing: 3) {
          Image(systemName: "person.fill")
            .font(.system(size: 9))

          Text("개인")
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.pmindigo.n500)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.pmindigo.n500.opacity(0.1))
        .clipShape(Capsule())

        // 장소
        if let location = event.location {
          HStack(spacing: 3) {
            ResourceKitAsset.locationIcon.swiftUIImage
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 12, height: 12)

            Text(location.name)
              .font(.pmCaption)
              .lineLimit(1)
          }
          .foregroundStyle(.secondary)
        }
      }

      // Row 3: 알림 + 메모 프리뷰 (있을 때만)
      if event.reminderMinutesBefore != nil || hasDescription {
        HStack(spacing: 8) {
          if let minutes = event.reminderMinutesBefore {
            HStack(spacing: 3) {
              Image(systemName: "bell.fill")
                .font(.system(size: 10))

              Text(reminderText(minutes: minutes))
                .font(.pmCaption)
            }
            .foregroundStyle(.secondary)
          }

          if hasDescription {
            Text(event.description ?? "")
              .font(.pmCaption)
              .foregroundStyle(.tertiary)
              .lineLimit(1)
          }
        }
      }
    }
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .center, spacing: 2) {
      Text(startTimeString)
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if let endAt = event.endAt {
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
    event.startAt.formattedTime
  }

  private func endTimeString(_ endAt: Date) -> String {
    KoreanDateFormatters.endTimeString(from: endAt)
  }

  private func reminderText(minutes: Int) -> String {
    if minutes == 0 { return "이벤트 시점" }
    if minutes >= 10080 && minutes % (1440 * 7) == 0 {
      let weeks = minutes / (1440 * 7)
      return "\(weeks)주 전"
    }
    if minutes >= 1440 {
      let days = minutes / 1440
      return "\(days)일 전"
    }
    if minutes >= 60 {
      return "\(minutes / 60)시간 전"
    }
    return "\(minutes)분 전"
  }

  private var hasDescription: Bool {
    guard let description = event.description else { return false }
    return !description.isEmpty
  }

  /// 현재 진행 중인 일정인지
  private var isNow: Bool {
    let now = Date()
    return now >= event.startAt && now <= event.effectiveEndAt
  }

  /// 이미 종료된 일정인지
  var isPast: Bool {
    Date() > event.effectiveEndAt
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

#Preview("기본") {
  VStack(spacing: 0) {
    PersonalEventTimelineItemView(
      event: PersonalEventModel.mock(
        id: "1",
        title: "아침 운동",
        emoji: "🏃",
        description: "한강 러닝 5km",
        startAt: Date().addingTimeInterval(1800),
        endAt: Date().addingTimeInterval(5400),
        location: LocationInfoModel(name: "여의도 한강공원"),
        reminderMinutesBefore: 30
      ),
      isFirst: true,
      isLast: false,
      onTap: {}
    )

    PersonalEventTimelineItemView(
      event: PersonalEventModel.mock(
        id: "2",
        title: "카페에서 공부",
        emoji: "☕️",
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

#Preview("종료된 일정") {
  VStack(spacing: 0) {
    PersonalEventTimelineItemView(
      event: PersonalEventModel.mock(
        id: "1",
        title: "아침 운동",
        emoji: "🏃",
        startAt: Date().addingTimeInterval(-7200),
        endAt: Date().addingTimeInterval(-3600),
        location: LocationInfoModel(name: "여의도 한강공원")
      ),
      isFirst: true,
      isLast: true,
      onTap: {}
    )
  }
  .padding()
  .auroraBackground()
}
