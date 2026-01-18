import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Vertical Stripes Pattern

/// 세로 줄무늬 패턴 (회색/검정 교대)
struct VerticalStripes: View {
  let stripeWidth: CGFloat

  init(stripeWidth: CGFloat = 4) {
    self.stripeWidth = stripeWidth
  }

  var body: some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        ForEach(0..<Int(geo.size.width / stripeWidth) + 1, id: \.self) { i in
          Rectangle()
            .fill(i % 2 == 0 ? Color.white.opacity(0.06) : Color.black.opacity(0.3))
            .frame(width: stripeWidth)
        }
      }
    }
  }
}

// MARK: - Racing Track View

/// 레이싱 트랙 UI - 참가자들이 출발점에서 도착점으로 이동하는 시각화
struct RacingTrackView: View {
  let participants: [ParticipantState]
  let baseProgress: Double
  let remainingMinutes: Int

  private var isUrgent: Bool { remainingMinutes < 10 }

  // 위치 기준 정렬 (뒤에 있는 사람이 먼저 그려지도록)
  private var sortedParticipants: [ParticipantState] {
    participants.sorted {
      $0.trackPosition(baseProgress: baseProgress) < $1.trackPosition(baseProgress: baseProgress)
    }
  }

  private var progressColors: [Color] {
    TimeColor.gradientColors(for: remainingMinutes)
  }

  var body: some View {
    GeometryReader { geo in
      let trackWidth = geo.size.width
      let trackHeight = geo.size.height
      let trackPadding: CGFloat = 20
      let usableWidth = trackWidth - (trackPadding * 2)

      ZStack {
        // MARK: - 트랙 배경
        trackBackground(height: trackHeight)

        // MARK: - 진행률 트랙
        progressTrack(usableWidth: usableWidth, padding: trackPadding)

        // MARK: - 출발 마커
        startMarker(padding: trackPadding, centerY: trackHeight / 2)

        // MARK: - 도착 깃발
        finishFlag(trackWidth: trackWidth, padding: trackPadding, centerY: trackHeight / 2)

        // MARK: - 참가자들
        participantMarkers(
          usableWidth: usableWidth,
          padding: trackPadding,
          centerY: trackHeight / 2
        )
      }
    }
  }

  // MARK: - Track Components

  private func trackBackground(height: CGFloat) -> some View {
    Capsule()
      .fill(.white.opacity(0.06))
      .frame(height: height)
      .overlay {
        // 세로 줄무늬
        VerticalStripes(stripeWidth: 18)
          .clipShape(Capsule())
      }
      .overlay {
        Capsule().stroke(.white.opacity(0.3), lineWidth: 0.5)
      }
  }

  private func progressTrack(usableWidth: CGFloat, padding: CGFloat) -> some View {
    HStack(spacing: 0) {
      // 진행된 부분
      Capsule()
        .fill(
          LinearGradient(
            colors: progressColors,
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: max(usableWidth * baseProgress, 4), height: 4)
        .shadow(color: progressColors.first?.opacity(0.4) ?? .clear, radius: 6)

      // 남은 부분 (점선)
      GeometryReader { remainingGeo in
        Path { path in
          path.move(to: CGPoint(x: 0, y: remainingGeo.size.height / 2))
          path.addLine(to: CGPoint(x: remainingGeo.size.width, y: remainingGeo.size.height / 2))
        }
        .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
        .foregroundStyle(.white.opacity(0.15))
      }
      .frame(width: usableWidth * (1 - baseProgress))
    }
    .padding(.horizontal, padding)
  }

  private func startMarker(padding: CGFloat, centerY: CGFloat) -> some View {
    Circle()
      .fill(.white.opacity(0.25))
      .frame(width: 6, height: 6)
      .position(x: padding, y: centerY)
  }

  private func finishFlag(trackWidth: CGFloat, padding: CGFloat, centerY: CGFloat) -> some View {
    Text("🏁")
      .font(.system(size: 18))
      .position(x: trackWidth - padding + 4, y: centerY)
  }

  private func participantMarkers(usableWidth: CGFloat, padding: CGFloat, centerY: CGFloat) -> some View {
    ForEach(sortedParticipants) { participant in
      let position = participant.trackPosition(baseProgress: baseProgress)
      let xPos = padding + (usableWidth * position)

      CompactParticipantMarker(
        participant: participant,
        isUrgent: isUrgent
      )
      .position(x: xPos, y: centerY)
      .animation(.spring(response: 0.6, dampingFraction: 0.8), value: position)
    }
  }
}

// MARK: - Compact Participant Marker

/// 컴팩트한 참가자 마커
struct CompactParticipantMarker: View {
  let participant: ParticipantState
  let isUrgent: Bool

  private var markerSize: CGFloat { 32 }

  var body: some View {
    ZStack {
      // 배경 원 + 그림자
      Circle()
        .fill(participant.status.color.gradient)
        .frame(width: markerSize, height: markerSize)
        .shadow(color: participant.status.color.opacity(0.5), radius: 4, y: 2)

      // 이모지
      Text(participant.status.emoji)
        .font(.system(size: 14))
    }
    // 이름 라벨
    .overlay(alignment: .top) {
      Text(participant.name.prefix(2))
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
          Capsule()
            .fill(.black.opacity(0.7))
        )
        .offset(y: -18)
    }
    // 지각 표시 (상태가 late일 때)
    .overlay(alignment: .bottomTrailing) {
      if participant.status == .late {
        Circle()
          .fill(.orange)
          .frame(width: 10, height: 10)
          .overlay {
            Text("!")
              .font(.system(size: 7, weight: .black))
              .foregroundStyle(.white)
          }
          .offset(x: 2, y: 2)
      }
    }
  }
}

// MARK: - Expanded Racing Track View (Dynamic Island용)

/// Dynamic Island Expanded 영역용 컴팩트 트랙 뷰
struct ExpandedRacingTrackView: View {
  let context: ActivityViewContext<PromiseActivityAttributes>

  private var state: PromiseActivityAttributes.ContentState { context.state }
  private var remainingMinutes: Int { state.remainingSeconds / 60 }

  private var sortedParticipants: [ParticipantState] {
    state.participants.sorted {
      $0.trackPosition(baseProgress: state.baseProgress) < $1.trackPosition(baseProgress: state.baseProgress)
    }
  }

  var body: some View {
    VStack(spacing: 6) {
      // 미니 트랙
      GeometryReader { geo in
        let trackWidth = geo.size.width
        let padding: CGFloat = 12
        let usableWidth = trackWidth - (padding * 2)

        ZStack {
          // 트랙 배경
          Capsule()
            .fill(.white.opacity(0.08))
            .frame(height: 28)

          // 참가자들
          ForEach(sortedParticipants) { participant in
            let position = participant.trackPosition(baseProgress: state.baseProgress)
            let xPos = padding + (usableWidth * position)

            Circle()
              .fill(participant.status.color.gradient)
              .frame(width: 22, height: 22)
              .overlay {
                Text(participant.status.emoji)
                  .font(.system(size: 10))
              }
              .position(x: xPos, y: 14)
          }

          // 도착 깃발
          Text("🏁")
            .font(.system(size: 14))
            .position(x: trackWidth - 6, y: 14)
        }
      }
      .frame(height: 28)

      // 참가자 범례 (2명까지만 표시)
      HStack(spacing: 10) {
        ForEach(sortedParticipants.prefix(4)) { p in
          HStack(spacing: 3) {
            Text(p.status.emoji)
              .font(.system(size: 10))
            Text(p.name.prefix(2))
              .font(.system(size: 10))
              .foregroundStyle(.white.opacity(0.7))
          }
        }
      }
    }
  }
}
