// MARK: - BenefitLiveView.swift
// Screen 5: Benefit 3 - "지금 어디야?" 안 물어도 되는 일정

import Lottie
import PromisoShared
import ResourceKit
import SwiftUI

struct BenefitLiveView: View {
  let onAnimationComplete: () -> Void
  let onInteractionComplete: () -> Void

  @Environment(\.verticalSizeClass) private var verticalSizeClass

  private var isCompactHeight: Bool {
    UIScreen.main.bounds.height < 700
  }

  // MARK: - Mock Data

  private struct MockParticipant: Equatable, Identifiable {
    let id: Int
    let emoji: String
    let name: String
    var progress: Double // 0.0 ~ 1.0
    var eta: Int? // nil = 대기, 0 = 도착, N = N분
    var isCurrentUser: Bool = false
  }

  @State private var showCard: Bool = false
  @State private var participants: [MockParticipant] = [
    .init(id: 0, emoji: "🧑‍💻", name: "민수", progress: 0.45, eta: 10, isCurrentUser: true),
    .init(id: 1, emoji: "😎", name: "지훈", progress: 1.0, eta: 0),
    .init(id: 2, emoji: "🐰", name: "재윤", progress: 0.9, eta: 3),
    .init(id: 3, emoji: "🎧", name: "예은", progress: 0.1, eta: 25),
  ]
  @State private var showETAButtons: Bool = false
  @State private var hasArrived: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      if showCard {
        racingCard
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      // ETA 버튼
      if showETAButtons {
        etaButtonRow
          .padding(.top, 16)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .padding(.horizontal, 24)
    .onAppear {
      Task {
        await runAnimationSequence()
      }
    }
  }

  // MARK: - ETA Buttons

  private var etaButtonRow: some View {
    VStack(spacing: 16) {
      // Glass 컨테이너: ETA 버튼 + 유도 문구
      VStack(spacing: 10) {
        HStack(spacing: 8) {
          etaSelectButton(title: "20분", eta: 20, progress: 0.2)
          etaSelectButton(title: "10분", eta: 10, progress: 0.55)
          etaSelectButton(title: "5분", eta: 5, progress: 0.8)
          etaSelectButton(title: "도착", emoji: "🏁", eta: 0, progress: 1.0)
        }

        HStack(spacing: 4) {
          Image(systemName: "hand.tap.fill")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmindigo.n500)
          Text("도착 예정 시간을 눌러보세요")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary.opacity(0.8))
        }
      }
      .padding(14)
      .adaptiveGlassCard(cornerRadius: 16)

      // 카피
      VStack(spacing: 6) {
        Text("약속 당일엔, 이런 것까지")
          .font(.title3.bold())
          .foregroundStyle(Color.pmtext.primary)
          .minimumScaleFactor(0.8)
        Text("각자 상태만 공유하면\n잠금화면에서도 확인돼요")
          .font(.subheadline)
          .foregroundStyle(Color.pmtext.secondary)
          .minimumScaleFactor(0.8)
      }
      .multilineTextAlignment(.center)
    }
  }

  private func etaSelectButton(
    title: String,
    emoji: String? = nil,
    eta: Int,
    progress: Double
  ) -> some View {
    let isSelected = participants[0].eta == eta
    let buttonColor: Color = eta == 0 ? .green : Color.pmindigo.n500

    return Button {
      withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
        participants[0].progress = progress
        participants[0].eta = eta
      }

      if eta == 0, !hasArrived {
        hasArrived = true
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          onInteractionComplete()
        }
      }
    } label: {
      VStack(spacing: 2) {
        if let emoji {
          Text(emoji).font(.system(size: 18))
          Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.pmtext.secondary)
        } else {
          Text("\(eta)")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(isSelected ? .white : buttonColor)
          + Text("분")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? .white.opacity(0.8) : Color.pmtext.secondary)
        }
      }
      .frame(maxWidth: .infinity, minHeight: isCompactHeight ? 36 : 44)
      .background {
        if isSelected {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(buttonColor)
            .shadow(color: buttonColor.opacity(0.4), radius: 8, y: 2)
        } else {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.pmgray.n300.opacity(0.4), lineWidth: 1)
            )
        }
      }
      .scaleEffect(isSelected ? 1.05 : 1.0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Racing Card

  private var racingCard: some View {
    VStack(spacing: 0) {
      // 헤더
      cardHeader
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)

      // 레이싱 트랙
      mockRacingTrack
        .frame(height: 50)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)

      Divider()
        .background(Color.white.opacity(0.15))
        .padding(.horizontal, 12)

      // 참가자 리스트
      VStack(spacing: 0) {
        ForEach(participants) { participant in
          participantRow(participant)

          if participant.id != participants.last?.id {
            Divider()
              .background(Color.white.opacity(0.15))
              .padding(.leading, 58)
          }
        }
      }
      .padding(.vertical, 4)
      .padding(.bottom, 6)
    }
    .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
    .environment(\.colorScheme, .dark)
  }

  private var cardHeader: some View {
    HStack(spacing: 10) {
      Text("🎓")
        .font(.system(size: 22))

      VStack(alignment: .leading, spacing: 2) {
        Text("대학 동기 모임")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
        Text("일정 시간까지 15분 남았어요")
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.6))
      }

      Spacer()

      // 실시간 뱃지
      HStack(spacing: 4) {
        LottieView(animation: LottieAsset.live.animation)
          .playing(loopMode: .loop)
          .frame(width: 14, height: 10)
        Text("실시간")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.pmindigo.n200)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.pmindigo.n800.opacity(0.6), in: Capsule())
    }
  }

  // MARK: - Mock Racing Track

  private var mockRacingTrack: some View {
    GeometryReader { geo in
      let trackWidth = geo.size.width
      let trackHeight = geo.size.height
      let padding: CGFloat = 16
      let usableWidth = trackWidth - (padding * 2)
      let myProgress = participants.first(where: { $0.isCurrentUser })?.progress ?? 0

      ZStack {
        // 트랙 배경 (줄무늬)
        Capsule()
          .fill(.white.opacity(0.06))
          .frame(height: trackHeight)
          .overlay {
            HStack(spacing: 0) {
              ForEach(0..<Int(trackWidth / 18) + 1, id: \.self) { i in
                Rectangle()
                  .fill(i % 2 == 0 ? Color.white.opacity(0.04) : Color.black.opacity(0.2))
                  .frame(width: 18)
              }
            }
            .clipShape(Capsule())
          }
          .overlay {
            Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5)
          }

        // 진행률 라인 (내 진행률 기준)
        HStack(spacing: 0) {
          Capsule()
            .fill(
              LinearGradient(
                colors: progressGradient(for: myProgress),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(usableWidth * myProgress, 4), height: 4)
            .shadow(color: Color.pmindigo.n500.opacity(0.4), radius: 6)

          Spacer(minLength: 0)
        }
        .padding(.horizontal, padding)

        // 출발 마커
        Circle()
          .fill(.white.opacity(0.25))
          .frame(width: 6, height: 6)
          .position(x: padding, y: trackHeight / 2)

        // 도착 깃발
        Text("🏁")
          .font(.system(size: 14))
          .position(x: trackWidth - padding + 4, y: trackHeight / 2)

        // 참가자 마커
        ForEach(participants) { participant in
          let xPos = padding + (usableWidth * participant.progress)

          VStack(spacing: 1) {
            // 이름 라벨
            Text(participant.name)
              .font(.system(size: 7, weight: .bold))
              .foregroundStyle(.white.opacity(0.9))
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(
                Capsule()
                  .fill(participant.eta == 0 ? Color.green.opacity(0.8) : .black.opacity(0.5))
              )

            // 이모지 마커
            ZStack {
              Circle()
                .fill(markerColor(for: participant).gradient)
                .frame(width: 24, height: 24)
              Text(participant.emoji)
                .font(.system(size: 12))
            }
            .overlay(
              Circle()
                .stroke(markerColor(for: participant), lineWidth: 1.5)
                .frame(width: 24, height: 24)
            )

            // ETA 뱃지 (이동 중인 경우)
            if let eta = participant.eta, eta > 0 {
              Text("\(eta)분")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(
                  Capsule().fill(Color.pmindigo.n500)
                )
            }
          }
          .position(x: xPos, y: trackHeight / 2)
          .animation(.spring(response: 0.5, dampingFraction: 0.7), value: participant.progress)
          .zIndex(participant.isCurrentUser ? 100 : Double(50 - participant.id))
        }
      }
    }
  }

  private func progressGradient(for progress: Double) -> [Color] {
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

  private func markerColor(for participant: MockParticipant) -> Color {
    if participant.eta == 0 { return .green }
    if participant.eta != nil { return Color.pmindigo.n500 }
    return Color.pmgray.n500
  }

  // MARK: - Participant Row

  private func participantRow(_ participant: MockParticipant) -> some View {
    HStack(spacing: 10) {
      // 아바타
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: participant.isCurrentUser
                ? [Color.pmindigo.n400, Color.pmindigo.n600]
                : [Color.pmgray.n400, Color.pmgray.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 36, height: 36)

        Text(participant.emoji)
          .font(.system(size: 16))

        // 도착 체크마크
        if participant.eta == 0 {
          Circle()
            .fill(Color.green)
            .frame(width: 14, height: 14)
            .overlay {
              Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.white)
            }
            .offset(x: 13, y: 13)
        }
      }

      // 이름 + 상태
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 5) {
          Text(participant.name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)

          if participant.isCurrentUser {
            Text("나")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(Color.pmindigo.n500, in: Capsule())
          }
        }

        Text(statusText(for: participant))
          .font(.system(size: 11))
          .foregroundStyle(.white.opacity(0.6))
      }

      Spacer()

      // ETA 뱃지
      etaBadge(for: participant)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .contentTransition(.interpolate)
  }

  private func statusText(for participant: MockParticipant) -> String {
    guard let eta = participant.eta else { return "아직 출발 전" }
    if eta == 0 { return "도착 완료" }
    if eta <= 3 { return "거의 도착" }
    if eta > 15 { return "지각 예상" }
    return "이동 중"
  }

  @ViewBuilder
  private func etaBadge(for participant: MockParticipant) -> some View {
    if let eta = participant.eta {
      if eta == 0 {
        HStack(spacing: 3) {
          Image(systemName: "checkmark")
            .font(.system(size: 9, weight: .bold))
          Text("도착")
            .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.15), in: Capsule())
      } else {
        HStack(spacing: 3) {
          Circle()
            .fill(eta > 10 ? Color.orange : Color.pmindigo.n500)
            .frame(width: 5, height: 5)
          Text("\(eta)분")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(eta > 10 ? Color.orange : Color.pmindigo.n500)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          (eta > 10 ? Color.orange : Color.pmindigo.n500).opacity(0.15),
          in: Capsule()
        )
      }
    } else {
      Text("대기")
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // 카드 등장
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
      showCard = true
    }

    // ETA 버튼 등장
    try? await Task.sleep(for: .seconds(1.0))
    withAnimation(.easeOut(duration: 0.6)) {
      showETAButtons = true
    }

    // 다음 버튼 표시 (disabled 상태)
    try? await Task.sleep(for: .seconds(0.5))
    onAnimationComplete()
    // 도착 버튼 탭 시 onInteractionComplete → 다음 버튼 활성화
  }
}
