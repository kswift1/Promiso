// MARK: - BenefitLiveView.swift
// Screen 5: Benefit 3 - "지금 어디야?" 안 물어도 되는 약속

import PromisoShared
import SwiftUI

struct BenefitLiveView: View {
  let onAnimationComplete: () -> Void

  @State private var showLiveActivity: Bool = false
  @State private var participantStatuses: [ParticipantStatus] = [
    .init(name: "민수", status: .arrived),
    .init(name: "지훈", status: .moving),
    .init(name: "수진", status: .preparing),
  ]
  @State private var statusUpdateStep: Int = 0
  @State private var showCopy: Bool = false

  enum ArrivalStatus: Equatable {
    case preparing
    case moving
    case arrived

    var emoji: String {
      switch self {
      case .preparing: return "🔴"
      case .moving: return "🟡"
      case .arrived: return "🟢"
      }
    }

    var label: String {
      switch self {
      case .preparing: return "준비중"
      case .moving: return "이동중"
      case .arrived: return "도착"
      }
    }
  }

  struct ParticipantStatus: Equatable {
    let name: String
    var status: ArrivalStatus
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 잠금화면 프레임
      if showLiveActivity {
        liveActivityCard
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }

      Spacer()
        .frame(height: 32)

      // 하단 카피
      if showCopy {
        VStack(spacing: 8) {
          Text("\"지금 어디야?\" 대신")
            .font(.title3.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("탭 한 번이면 돼요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .padding(.horizontal, 24)
    .task {
      await runAnimationSequence()
    }
  }

  // MARK: - Live Activity Card

  private var liveActivityCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더
      HStack {
        Text("🍕")
          .font(.system(size: 22))
        VStack(alignment: .leading, spacing: 2) {
          Text("대학 동기 모임")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)
          Text("시작까지 32분")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmtext.secondary)
        }
        Spacer()
        Image(systemName: "location.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmindigo.n500)
      }
      .padding(.bottom, 16)

      // 참가자 상태
      VStack(spacing: 10) {
        ForEach(0..<participantStatuses.count, id: \.self) { index in
          participantRow(participant: participantStatuses[index])
        }
      }
      .padding(.bottom, 16)

      // 상태 공유 버튼
      HStack {
        Spacer()
        Text("나도 상태 공유하기")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background {
            Capsule()
              .strokeBorder(Color.pmindigo.n500.opacity(0.3), lineWidth: 1)
          }
        Spacer()
      }
    }
    .padding(20)
    .background { glassCardBackground }
  }

  private func participantRow(participant: ParticipantStatus) -> some View {
    HStack(spacing: 10) {
      Text(participant.status.emoji)
        .font(.system(size: 16))

      Text(participant.name)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.pmtext.primary)

      Spacer()

      Text(participant.status.label)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(statusColor(participant.status))
    }
    .contentTransition(.interpolate)
  }

  private func statusColor(_ status: ArrivalStatus) -> Color {
    switch status {
    case .arrived: return .green
    case .moving: return .orange
    case .preparing: return .red.opacity(0.8)
    }
  }

  @ViewBuilder
  private var glassCardBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear
        .glassEffect(
          .regular.tint(.white.opacity(0.08)),
          in: .rect(cornerRadius: 20)
        )
    } else {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
  }

  // MARK: - Animation Sequence

  private func runAnimationSequence() async {
    // LiveActivity 카드 등장
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
      showLiveActivity = true
    }

    // 상태 변경 1: 수진 준비중 → 이동중
    try? await Task.sleep(for: .seconds(1.0))
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      participantStatuses[2].status = .moving
    }

    // 상태 변경 2: 지훈 이동중 → 도착
    try? await Task.sleep(for: .seconds(0.8))
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
      participantStatuses[1].status = .arrived
    }

    // 하단 카피
    try? await Task.sleep(for: .seconds(0.5))
    withAnimation(.easeOut(duration: 0.4)) {
      showCopy = true
    }

    try? await Task.sleep(for: .seconds(0.3))
    onAnimationComplete()
  }
}
