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
  let trackingDurationMinutes: Int
  let currentUserId: String

  // 위치 기준 정렬 (뒤에 있는 사람이 먼저 그려지도록)
  private var sortedParticipants: [ParticipantState] {
    participants.sorted {
      $0.trackPosition(trackingDurationMinutes: trackingDurationMinutes) <
      $1.trackPosition(trackingDurationMinutes: trackingDurationMinutes)
    }
  }

  /// 현재 사용자의 진행률
  private var myProgress: Double {
    guard let me = participants.first(where: { $0.id == currentUserId }) else { return 0 }
    return me.progress(trackingDurationMinutes: trackingDurationMinutes)
  }

  /// 현재 사용자 진행률 기반 그라데이션
  private var progressColors: [Color] {
    ProgressColor.gradientColors(for: myProgress)
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
        .frame(width: max(usableWidth * myProgress, 4), height: 4)
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
      .frame(width: usableWidth * (1 - myProgress))
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
      let position = participant.trackPosition(trackingDurationMinutes: trackingDurationMinutes)
      let xPos = padding + (usableWidth * position)
      let isCurrentUser = participant.id == currentUserId

      CompactParticipantMarker(
        participant: participant,
        trackingDurationMinutes: trackingDurationMinutes,
        isCurrentUser: isCurrentUser
      )
      .position(x: xPos, y: centerY)
      .animation(.spring(response: 0.6, dampingFraction: 0.8), value: position)
    }
  }
}

// MARK: - Compact Participant Marker

/// 컴팩트한 참가자 마커
/// - 프로필 사진 또는 이모지 마커
/// - V5 디자인: 우측 하단 ETA 뱃지
struct CompactParticipantMarker: View {
  let participant: ParticipantState
  let trackingDurationMinutes: Int
  let isCurrentUser: Bool

  private var markerSize: CGFloat { 32 }

  /// 캐시된 프로필 이미지 로드 (id 기반)
  private var cachedProfileImage: UIImage? {
    LiveActivityImageStore.loadImage(userId: participant.id)
  }

  /// ETA 상태에 따른 뱃지 색상
  private var badgeColor: Color {
    guard let eta = participant.estimatedArrivalMinutes else {
      return .gray  // 대기
    }
    if eta == 0 {
      return .green  // 도착
    }
    return Color(red: 0.35, green: 0.34, blue: 0.84)  // pmindigo 계열 - 이동 중
  }

  /// ETA 상태에 따른 테두리 색상
  private var borderColor: Color {
    badgeColor
  }

  /// ETA 뱃지 텍스트
  private var badgeText: String? {
    guard let eta = participant.estimatedArrivalMinutes else {
      return nil  // 대기: 뱃지 없음
    }
    if eta == 0 {
      return "✓"  // 도착
    }
    return "\(eta)분"  // 이동 중
  }

  var body: some View {
    ZStack {
      if let profileImage = cachedProfileImage {
        profileImageMarker(image: profileImage)
      } else {
        emojiMarker
      }
    }
    // 상단: 이름 라벨 (4글자)
    .overlay(alignment: .top) {
      Text(participant.name.prefix(4))
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
    // 우측 하단: ETA 뱃지 (V5)
    .overlay(alignment: .bottomTrailing) {
      if let text = badgeText {
        Text(text)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(badgeColor)
          )
          .offset(x: 6, y: 6)
      }
    }
  }

  // MARK: - Marker Variants

  /// 프로필 이미지 마커
  private func profileImageMarker(image: UIImage) -> some View {
    Image(uiImage: image)
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: markerSize, height: markerSize)
      .clipShape(Circle())
      .overlay(
        Circle()
          .stroke(borderColor, lineWidth: 2)
      )
      .shadow(color: borderColor.opacity(0.5), radius: 4, y: 2)
  }

  /// 기존 이모지 마커
  private var emojiMarker: some View {
    ZStack {
      Circle()
        .fill(borderColor.gradient)
        .frame(width: markerSize, height: markerSize)
        .shadow(color: borderColor.opacity(0.5), radius: 4, y: 2)

      Text(participant.emoji)
        .font(.system(size: 14))
    }
  }
}

