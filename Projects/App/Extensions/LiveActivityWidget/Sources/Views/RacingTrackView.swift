import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

import ResourceKit

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
    let groups = groupParticipantsByPosition()

    return ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
      let position = group.position
      let xPos = padding + (usableWidth * position)

      // 그룹 대표 참가자 (나 > 첫 번째)
      let representative = group.participants.first { $0.id == currentUserId } ?? group.participants[0]
      let isCurrentUser = representative.id == currentUserId
      let extraCount = group.participants.count - 1

      CompactParticipantMarker(
        participant: representative,
        trackingDurationMinutes: trackingDurationMinutes,
        isCurrentUser: isCurrentUser,
        groupCount: extraCount
      )
      .position(x: xPos, y: centerY)
      .zIndex(isCurrentUser ? 100 : Double(index))
      .animation(.spring(response: 0.6, dampingFraction: 0.8), value: position)
    }
  }

  /// ETA 기준으로 참가자들을 그룹화
  private func groupParticipantsByPosition() -> [(position: Double, participants: [ParticipantState])] {
    // ETA별로 그룹화 (nil, 0, 5, 10... 각각 별도 그룹)
    var etaGroups: [Int?: [ParticipantState]] = [:]

    for participant in participants {
      let eta = participant.estimatedArrivalMinutes
      etaGroups[eta, default: []].append(participant)
    }

    // 그룹별 position 계산 후 반환
    return etaGroups.map { (eta, participants) in
      let position = participants[0].trackPosition(trackingDurationMinutes: trackingDurationMinutes)
      return (position: position, participants: participants)
    }.sorted { $0.position < $1.position }
  }
}

// MARK: - Compact Participant Marker

/// 컴팩트한 참가자 마커
/// - 프로필 사진 또는 이모지 마커
/// - V5 디자인: 우측 하단 ETA 뱃지
/// - 그룹화: 좌측 상단 "+N" 뱃지
struct CompactParticipantMarker: View {
  let participant: ParticipantState
  let trackingDurationMinutes: Int
  let isCurrentUser: Bool
  var groupCount: Int = 0  // 추가 인원 수 (0이면 뱃지 없음)

  private var markerSize: CGFloat { 32 }

  /// 캐시된 프로필 이미지 로드 (id 기반)
  private var cachedProfileImage: UIImage? {
    LiveActivityImageStore.loadImage(userId: participant.id)
  }

  /// ETA 상태에 따른 뱃지 색상
  private var badgeColor: Color {
    guard let eta = participant.estimatedArrivalMinutes else {
      return Color.pmgray.n500  // 대기
    }
    if eta == 0 {
      return Color.pmsuccess.n500  // 도착
    }
    return Color.pmindigo.n500  // 이동 중
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

  /// 도착 여부
  private var hasArrived: Bool {
    participant.estimatedArrivalMinutes == 0
  }

  var body: some View {
    ZStack {
      if hasArrived {
        // 도착: 이름 라벨만 (마커 숨김)
        arrivedLabel
      } else {
        // 이동 중/대기: 마커 + 라벨 + ETA 뱃지
        markerWithLabels
      }
    }
  }

  /// 도착 시 이름 라벨만 (마커 상단 위치 유지)
  private var arrivedLabel: some View {
    // 마커 크기만큼 투명 공간 확보 후 상단에 라벨 배치
    Color.clear
      .frame(width: markerSize, height: markerSize)
      .overlay(alignment: .top) {
        Text(nameLabel)
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .fixedSize()
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(Color.pmsuccess.n500)
          )
          .offset(y: -18)
      }
  }

  /// 마커 + 이름 라벨 + ETA 뱃지
  private var markerWithLabels: some View {
    ZStack {
      if let profileImage = cachedProfileImage {
        profileImageMarker(image: profileImage)
      } else {
        defaultProfileMarker
      }
    }
    // 상단: 이름 라벨 (4글자 + 외N명)
    .overlay(alignment: .top) {
      Text(nameLabel)
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
          Capsule()
            .fill(.black.opacity(0.4))
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

  /// 이름 라벨 (그룹화 시 "외N명" 포함)
  private var nameLabel: String {
    let name = String(participant.name.prefix(4))
    if groupCount > 0 {
      return "\(name) 외\(groupCount)명"
    }
    return name
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

  /// 디폴트 이모지 목록 (프로필 없을 때 할당)
  private static let defaultEmojis = ["😀", "😊", "🙂", "😎", "🤗", "😇", "🥳", "🤩", "😺", "🐻"]

  /// userId 기반 고정 이모지
  private var assignedEmoji: String {
    let index = abs(participant.id.hashValue) % Self.defaultEmojis.count
    return Self.defaultEmojis[index]
  }

  /// 디폴트 프로필 마커 (이미지 없을 때 - 이모지 아바타)
  private var defaultProfileMarker: some View {
    ZStack {
      Circle()
        .fill(borderColor.gradient)
        .frame(width: markerSize, height: markerSize)

      Text(assignedEmoji)
        .font(.system(size: 16))
    }
    .overlay(
      Circle()
        .stroke(borderColor, lineWidth: 2)
    )
    .shadow(color: borderColor.opacity(0.5), radius: 4, y: 2)
  }
}

