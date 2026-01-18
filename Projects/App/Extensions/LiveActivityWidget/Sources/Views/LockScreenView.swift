import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

import ResourceKit


// MARK: - Progress Color

/// 진행률 기반 색상 시스템 (앱 브랜드 톤 적용)
enum ProgressColor {
  /// 진행률에 따른 단일 색상
  static func forProgress(_ progress: Double) -> Color {
    switch progress {
    case 0.75...:
      return Color.pmindigo.n500
    case 0.50..<0.75:
      return Color.pmpurple.n500
    case 0.25..<0.50:
      return .orange
    default:
      return .gray
    }
  }

  /// 진행률에 따른 그라데이션 색상
  static func gradientColors(for progress: Double) -> [Color] {
    switch progress {
    case 0.75...:
      return [Color.pmindigo.n500, Color.pmpurple.n500]
    case 0.50..<0.75:
      return [Color.pmpurple.n500, Color.pmpurple.n400]
    case 0.25..<0.50:
      return [.orange, Color.pmpurple.n400]
    default:
      return [.gray, .orange]
    }
  }
}

// MARK: - Lock Screen Banner View

/// 잠금화면 라이브액티비티 배너 뷰
struct LockScreenBannerView: View {
  let context: ActivityViewContext<PromiseActivityAttributes>

  private var state: PromiseActivityAttributes.ContentState { context.state }
  private var attrs: PromiseActivityAttributes { context.attributes }

  private var trackingDuration: Int { state.trackingDurationMinutes }
  private var amPm: String { Calendar.current.component(.hour, from: attrs.scheduledTime) >= 12 ? "PM" : "AM" }
  private var timeText: String { attrs.scheduledTime.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute()) }

  /// 현재 사용자의 ETA
  private var myETA: Int? {
    state.participants.first { $0.id == attrs.currentUserId }?.estimatedArrivalMinutes
  }

  var body: some View {
    VStack(spacing: 10) {
      // MARK: - 헤더
      headerSection

      // MARK: - 레이싱 트랙
      RacingTrackView(
        participants: state.participants,
        trackingDurationMinutes: trackingDuration,
        currentUserId: attrs.currentUserId
      )
      .frame(height: 44)

      // MARK: - ETA 버튼
      etaButtonSection
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .foregroundStyle(.white)
    .activityBackgroundTint(.black)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack {
      // 왼쪽: 약속 정보
      VStack(alignment: .leading, spacing: 6) {
        Text(attrs.title)
          .font(.subheadline.weight(.bold))
          .lineLimit(1)

        if let location = attrs.location {
          HStack(spacing: 4) {
            Text("📍")
              .font(.caption2)
            Text(location)
              .font(.caption)
          }
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
        }
      }

      Spacer()

      // 오른쪽: 약속 시간
      VStack(alignment: .trailing, spacing: 2) {
        Text("약속")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.6))

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(amPm)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.6))

          Text(timeText)
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
        }
      }
    }
  }

  /// 직접 입력 여부 (0, 5, 10 외의 값)
  private var isCustomETA: Bool {
    guard let eta = myETA else { return false }
    return ![0, 5, 10].contains(eta)
  }

  // MARK: - ETA Button Section

  private var etaButtonSection: some View {
    HStack(spacing: 8) {
      // 라벨 (고정 너비 - 가장 긴 케이스 "도착까지" 기준: )
      VStack(alignment: .leading, spacing: 2) {
        Text(myETA == 0 ? "도착" : "도착까지")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.white.opacity(0.4))

        if isCustomETA, let eta = myETA {
          Text("\(eta)분")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white.opacity(0.8))
        }
      }
      .frame(width: 40, alignment: .center)

      // Segmented Control
      ETASegmentedControl(
        selectedMinutes: myETA,
        context: context
      )
    }
  }
}

// MARK: - ETA Segmented Control

// TODO: n분 버튼 커스텀 가능하게 추후 구현
struct ETASegmentedControl: View {
  let selectedMinutes: Int?
  let context: ActivityViewContext<PromiseActivityAttributes>

  private var attrs: PromiseActivityAttributes { context.attributes }

  private let etaOptions: [(title: String, icon: String?, minutes: Int)] = [
    ("완료", "checkmark", 0),
    ("5분", nil, 5),
    ("10분", nil, 10)
  ]

  var body: some View {
    HStack(spacing: 6) {
      // ETA 옵션 버튼들
      ForEach(Array(etaOptions.enumerated()), id: \.offset) { _, option in
        let isSelected = selectedMinutes == option.minutes

        Button(intent: UpdateETAIntent(
          promiseId: attrs.promiseId,
          userId: attrs.currentUserId,
          estimatedMinutes: option.minutes
        )) {
          HStack(spacing: 4) {
            if let icon = option.icon {
              Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            }
            Text(option.title)
              .font(.system(size: 11, weight: isSelected ? .bold : .medium))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(
            Group {
              if isSelected {
                LinearGradient(
                  colors: [Color.pmindigo.n500, Color.pmpurple.n500],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              } else {
                Color.white.opacity(0.08)
              }
            }
          )
          .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(
                isSelected
                  ? Color.white.opacity(0.2)
                  : Color.white.opacity(0.1),
                lineWidth: 0.5
              )
          )
        }
        .buttonStyle(.plain)
      }

      // "직접" 버튼 - 앱으로 이동 (항상 비선택 상태)
      Link(destination: URL(string: "promiso://promise/\(attrs.promiseId)/eta")!) {
        HStack(spacing: 4) {
          Image(systemName: "pencil")
            .font(.system(size: 10, weight: .medium))
          Text("직접")
            .font(.system(size: 11, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .foregroundStyle(.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
      }
    }
    .padding(4)
    .background(Color.black.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
    )
  }
}

// MARK: - Preview Attributes

private let previewAttributes = PromiseActivityAttributes(
  promiseId: "preview-123",
  currentUserId: "user-1",
  title: "🍜 점심 모임",
  location: "강남역 11번 출구",
  scheduledTime: Date().addingTimeInterval(1080),
  trackingDurationMinutes: 30
)

// MARK: - Preview States

/// 1. 초기 상태 - 모두 대기
private let stateInitial = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: nil),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

/// 2. 진행 중 - 일부 출발
private let stateInProgress = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 10),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 15),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 30),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

/// 3. 긴급 상태 - 거의 도착
private let stateUrgent = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 5),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 15),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 10)
  ]
)

/// 4. 거의 완료 - 대부분 도착
private let stateAlmostDone = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 5),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 0)
  ]
)

/// 5. 완료 - 모두 도착
private let stateCompleted = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: 0)
  ]
)

/// 6. 다양한 진행률
private let stateMixed = PromiseActivityAttributes.ContentState(
  trackingDurationMinutes: 30,
  participants: [
    ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: 0),
    ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: 10),
    ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: 20),
    ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
  ]
)

// MARK: - Previews

#Preview("1. 초기 상태 (30분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInitial
}

#Preview("2. 진행 중 (18분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("3. 긴급 (8분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateUrgent
}

#Preview("4. 거의 완료 (3분)", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateAlmostDone
}

#Preview("5. 완료", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateCompleted
}

#Preview("6. 다양한 진행률", as: .content, using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateMixed
}

// MARK: - Dynamic Island Previews

#Preview("DI - Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Compact (Urgent)", as: .dynamicIsland(.compact), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateUrgent
}

#Preview("DI - Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
  PromiseLiveActivity()
} contentStates: {
  stateInProgress
}
