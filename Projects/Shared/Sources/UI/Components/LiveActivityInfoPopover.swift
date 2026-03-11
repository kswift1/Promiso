//
//  LiveActivityInfoPopover.swift
//  PromisoShared
//
//  실시간 공유(LiveActivity) 기능 설명 팝오버
//

import SwiftUI

// MARK: - LiveActivity Info Popover

public struct LiveActivityInfoPopover: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var animationProgress: Double = 0

  // 일정 정보 (nil이면 기본값 사용)
  private let emoji: String
  private let title: String
  private let location: String?
  private let scheduleTime: Date?

  public init(
    emoji: String? = nil,
    title: String? = nil,
    location: String? = nil,
    scheduleTime: Date? = nil
  ) {
    self.emoji = emoji ?? "🍕"
    self.title = title ?? "피자 일정"
    self.location = location
    self.scheduleTime = scheduleTime
  }

  // 표시용 문자열
  private var displayTitle: String {
    "\(emoji) \(title)"
  }

  private var displayLocation: String {
    location ?? "강남역 11번 출구"
  }

  private var displayTimeComponents: (ampm: String, time: String) {
    guard let date = scheduleTime else {
      return ("오후", "6:00")
    }
    let hour = Calendar.current.component(.hour, from: date)
    let minute = Calendar.current.component(.minute, from: date)
    let ampm = hour < 12 ? "오전" : "오후"
    let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
    let timeString = String(format: "%d:%02d", displayHour, minute)
    return (ampm, timeString)
  }

  public var body: some View {
    VStack(spacing: 16) {
      // 헤더
      VStack(spacing: 4) {
        Text("실시간 공유란?")
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.primary)

        Text("잠금화면과 다이나믹 아일랜드에서\n친구들의 도착 상황을 실시간으로 확인할 수 있어요")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      // LiveActivity 미리보기
      VStack(spacing: 12) {
        // Dynamic Island 스타일 미리보기
        dynamicIslandCompactPreview

        // 잠금화면 스타일 미리보기
        lockScreenPreview
      }

      // 안내 문구
      HStack(spacing: 6) {
        Image(systemName: "sparkles")
          .font(.system(size: 12))
          .foregroundColor(.purple)
        Text(LocalizedStrings.LiveSchedule.autoStartDescription)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }
      .padding(.top, 4)
    }
    .padding(20)
    .frame(width: 300)
    .presentationCompactAdaptation(.popover)
    .onAppear {
      // 팝오버 열릴 때 진행률 애니메이션 시작
      withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
        animationProgress = 1.0
      }
    }
  }

  // MARK: - Dynamic Island Compact Preview

  private var dynamicIslandCompactPreview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("다이나믹 아일랜드")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)

      // Dynamic Island Compact 모양 (실제 구현과 동일)
      HStack(spacing: 0) {
        // Leading: 뱃지 스타일
        Text(displayTitle)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white)
          .lineLimit(1)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.purple.opacity(0.3))
          .clipShape(Capsule())

        Spacer()

        // Trailing: PM 시간
        HStack(spacing: 2) {
          Text(displayTimeComponents.ampm)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.6))
          Text(displayTimeComponents.time)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.black, in: Capsule())

      HStack {
        Spacer()

        Text("* iPhone 14 Pro 이상부터 가능해요")
          .font(.system(size: 9, weight: .regular))
          .foregroundColor(.secondary)
      }
    }
  }

  // MARK: - Lock Screen Preview

  private var lockScreenPreview: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("잠금화면")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)

      VStack(spacing: 8) {
        // 헤더 (실제 구현과 동일)
        HStack {
          // 왼쪽: 일정 정보
          VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle)
              .font(.system(size: 13, weight: .bold))
              .foregroundColor(.white)
              .lineLimit(1)

            HStack(spacing: 3) {
              Text("📍")
                .font(.system(size: 9))
              Text(displayLocation)
                .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.6))
          }

          Spacer()

          // 오른쪽: 일정 시간
          VStack(alignment: .trailing, spacing: 1) {
            Text(LocalizedStrings.LiveSchedule.scheduleTime)
              .font(.system(size: 9))
              .foregroundColor(.white.opacity(0.6))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
              Text(displayTimeComponents.ampm)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

              Text(displayTimeComponents.time)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            }
          }
        }

        // 레이싱 트랙 (실제 구현과 유사)
        racingTrackPreview

        // ETA 버튼들 (실제 구현과 동일)
        etaButtonsPreview
      }
      .padding(10)
      .background(Color.black, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  // MARK: - Racing Track Preview

  private var racingTrackPreview: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let padding: CGFloat = 16
      let myProgress = 0.65 * animationProgress  // "나"만 애니메이션

      ZStack {
        // 트랙 배경 (줄무늬)
        Capsule()
          .fill(Color.white.opacity(0.06))
          .overlay {
            HStack(spacing: 0) {
              ForEach(0..<20, id: \.self) { i in
                Rectangle()
                  .fill(i % 2 == 0 ? Color.white.opacity(0.04) : Color.black.opacity(0.2))
                  .frame(width: 12)
              }
            }
            .clipShape(Capsule())
          }
          .overlay {
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
          }

        // 점선 (고정)
        Path { path in
          path.move(to: CGPoint(x: padding, y: geo.size.height / 2))
          path.addLine(to: CGPoint(x: width - padding, y: geo.size.height / 2))
        }
        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
        .foregroundColor(.white.opacity(0.15))

        // 진행률 트랙 ("나"만 애니메이션)
        Capsule()
          .fill(
            LinearGradient(
              colors: [Color.indigo, Color.purple],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max((width - padding * 2) * myProgress, 4), height: 3)
          .position(x: padding + max((width - padding * 2) * myProgress, 4) / 2, y: geo.size.height / 2)

        // 출발 마커
        Circle()
          .fill(Color.white.opacity(0.25))
          .frame(width: 5, height: 5)
          .position(x: padding, y: geo.size.height / 2)

        // 도착 깃발
        Text("🏁")
          .font(.system(size: 14))
          .position(x: width - padding + 2, y: geo.size.height / 2)

        // 참가자 마커들
        // 민수, 재윤은 고정 / "나"만 애니메이션
        participantMarker(name: "민수", emoji: "🐻", progress: 0.35, color: .orange, width: width, padding: padding, centerY: geo.size.height / 2, eta: "15분")
        participantMarker(name: "재윤", emoji: "🐰", progress: 0.85, color: .green, width: width, padding: padding, centerY: geo.size.height / 2, eta: nil)
        participantMarker(name: "나", emoji: "😀", progress: myProgress, color: .indigo, width: width, padding: padding, centerY: geo.size.height / 2, eta: "5분")
      }
    }
    .frame(height: 36)
  }

  private func participantMarker(name: String, emoji: String, progress: Double, color: Color, width: CGFloat, padding: CGFloat, centerY: CGFloat, eta: String?) -> some View {
    let xPos = padding + ((width - padding * 2) * progress)
    let isArrived = eta == nil

    return ZStack {
      // 마커
      Circle()
        .fill(color.gradient)
        .frame(width: 22, height: 22)
        .overlay {
          Text(emoji)
            .font(.system(size: 11))
        }
        .overlay(
          Circle().stroke(color, lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.4), radius: 3, y: 1)

      // 이름 라벨
      Text(name)
        .font(.system(size: 7, weight: .bold))
        .foregroundColor(.white.opacity(0.9))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
          Capsule().fill(isArrived ? color : Color.black.opacity(0.4))
        )
        .offset(y: -15)

      // ETA 뱃지
      if let eta = eta {
        Text(eta)
          .font(.system(size: 6, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 3)
          .padding(.vertical, 1)
          .background(Capsule().fill(color))
          .offset(x: 8, y: 8)
      } else {
        // 도착 체크
        Text("✓")
          .font(.system(size: 6, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 3)
          .padding(.vertical, 1)
          .background(Capsule().fill(Color.green))
          .offset(x: 8, y: 8)
      }
    }
    .position(x: xPos, y: centerY)
  }

  // MARK: - ETA Buttons Preview

  private var etaButtonsPreview: some View {
    HStack(spacing: 4) {
      // 라벨
      VStack(alignment: .leading, spacing: 1) {
        Text("도착까지")
          .font(.system(size: 8, weight: .medium))
          .foregroundColor(.white.opacity(0.4))
      }
      .frame(width: 32)

      // 버튼들
      HStack(spacing: 4) {
        etaButton(title: "완료", isSelected: false)
        etaButton(title: "5분", isSelected: true)
        etaButton(title: "10분", isSelected: false)
        etaButton(title: "직접", isSelected: false)
      }
      .padding(3)
      .background(Color.black.opacity(0.3))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
      )
    }
  }

  private func etaButton(title: String, isSelected: Bool) -> some View {
    Text(title)
      .font(.system(size: 9, weight: isSelected ? .bold : .medium))
      .foregroundColor(isSelected ? .white : .white.opacity(0.5))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 5)
      .background(
        Group {
          if isSelected {
            LinearGradient(
              colors: [Color.indigo, Color.purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          } else {
            Color.white.opacity(0.08)
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 5))
  }
}

// MARK: - Preview

#Preview {
  Color.clear
    .popover(isPresented: .constant(true)) {
      LiveActivityInfoPopover()
    }
}
