import ActivityKit
import PromisoShared
import SwiftUI
import WidgetKit

import ResourceKit

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
      SharedRacingTrackView(
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
        Text("\(attrs.emoji) \(attrs.title)")
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
        Text("약속 시간")
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

  private let etaOptions: [(title: String, minutes: Int)] = [
    ("완료", 0),
    ("5분", 5),
    ("10분", 10)
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
          Text(option.title)
            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
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

      // "직접 입력" 버튼 - 앱으로 이동 (항상 비선택 상태)
      if let url = URL(string: "promiso://promise/\(attrs.promiseId)/eta") {
        Link(destination: url) {
          Text("직접 입력")
            .font(.system(size: 11, weight: .medium))
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
