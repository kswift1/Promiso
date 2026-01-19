//
//  LivePromiseExpandedView.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ComposableArchitecture
import SwiftUI
import UIKit
import PromisoShared

// MARK: - LivePromise.ExpandedView

extension LivePromise {
  /// 약속 추적 확장 뷰 (전체 화면)
  public struct ExpandedView: View {
    @Bindable var store: StoreOf<Detail>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreOf<Detail>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        // Drag Indicator
        dragIndicator

        // Close Button Row
        HStack {
          Spacer()
          closeButton
        }
        .padding(.horizontal, 16)

        // Header Section
        headerSection
          .padding(.top, 8)
          .padding(.horizontal, 16)

        // Action Buttons
        actionButtons
          .padding(.top, 16)
          .padding(.horizontal, 16)

        // Tab Bar
        tabBar
          .padding(.top, 20)

        // Tab Content
        tabContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .background(backgroundColor)
    }

    // MARK: - Colors

    private var backgroundColor: Color {
      colorScheme == .dark ? Color(hex: "1C1C1E") : Color(UIColor.systemBackground)
    }

    private var cardBackgroundColor: Color {
      colorScheme == .dark ? Color(hex: "2C2C2E") : Color(UIColor.secondarySystemBackground)
    }
  }
}

// MARK: - Header Components

private extension LivePromise.ExpandedView {

  var dragIndicator: some View {
    Capsule()
      .fill(Color(UIColor.tertiaryLabel))
      .frame(width: 36, height: 5)
      .padding(.top, 8)
  }

  var closeButton: some View {
    Button {
      dismiss()
    } label: {
      Image(systemName: "xmark.circle.fill")
        .font(.title2)
        .foregroundStyle(.secondary)
        .symbolRenderingMode(.hierarchical)
    }
  }

  var headerSection: some View {
    HStack(spacing: 12) {
      // Emoji (52px)
      Text(store.data.emoji)
        .font(.system(size: 44))

      // Promise Info
      VStack(alignment: .leading, spacing: 4) {
        // Title (18px)
        Text(store.data.title)
          .font(.title3.weight(.bold))
          .foregroundStyle(.primary)

        // Location + Participants
        HStack(spacing: 6) {
          if let location = store.data.location {
            Text("📍")
              .font(.caption)
            Text(location)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Text("•")
            .font(.caption)
            .foregroundStyle(.tertiary)

          Text("\(store.data.participants.count)명")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("참여")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      // Time (24px)
      if let time = store.data.scheduledTime {
        VStack(alignment: .trailing, spacing: 0) {
          Text(formatTime(time))
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(.primary)

          Text(formatPeriod(time))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  var actionButtons: some View {
    HStack(spacing: 12) {
      actionButton(icon: "doc.on.doc", title: "복사") {
        store.send(.copyButtonTapped)
      }

      actionButton(icon: "bell", title: "알림") {
        store.send(.notificationButtonTapped)
      }

      actionButton(icon: "ellipsis", title: "더보기") {
        store.send(.moreButtonTapped)
      }
    }
  }

  func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.subheadline)
        Text(title)
          .font(.subheadline)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 10))
    }
  }
}

// MARK: - Tab Bar

private extension LivePromise.ExpandedView {

  var tabBar: some View {
    HStack(spacing: 0) {
      ForEach(LivePromise.DetailTab.allCases, id: \.self) { tab in
        tabButton(tab)
      }
    }
    .padding(4)
    .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, 16)
  }

  func tabButton(_ tab: LivePromise.DetailTab) -> some View {
    let isSelected = store.selectedTab == tab

    return Button {
      let impactFeedback = UIImpactFeedbackGenerator(style: .light)
      impactFeedback.impactOccurred()
      store.send(.tabSelected(tab))
    } label: {
      Text(tab.rawValue)
        .font(.subheadline.weight(isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? .white : .secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
          isSelected
            ? Color.pmindigo.n500
            : Color.clear,
          in: RoundedRectangle(cornerRadius: 8)
        )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Tab Content

private extension LivePromise.ExpandedView {

  @ViewBuilder
  var tabContent: some View {
    switch store.selectedTab {
    case .status:
      statusTabContent
    case .map:
      mapTabContent
    case .chat:
      chatTabContent
    }
  }

  // MARK: - Status Tab

  var statusTabContent: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Racing Track (Horizontal Scroll)
        racingTrackSection

        // Participants List
        participantsListSection

        // ETA Buttons
        etaButtonsSection
      }
      .padding(.top, 16)
      .padding(.bottom, 32)
    }
  }

  var racingTrackSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("이동 현황")
        .font(.headline)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(store.data.participants) { participant in
            participantTrackItem(participant)
          }
        }
        .padding(.horizontal, 16)
      }
    }
  }

  func participantTrackItem(_ participant: ParticipantState) -> some View {
    let isArrived = participant.estimatedArrivalMinutes == 0
    let isCurrentUser = participant.id == store.data.currentUserId

    return VStack(spacing: 8) {
      // Avatar with status ring
      ZStack {
        Circle()
          .stroke(statusColor(for: participant), lineWidth: 3)
          .frame(width: 56, height: 56)

        Circle()
          .fill(
            LinearGradient(
              colors: isCurrentUser
                ? [Color.pmindigo.n400, Color.pmindigo.n600]
                : [Color.pmgray.n400, Color.pmgray.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 48, height: 48)
          .overlay {
            Text(String(participant.name.prefix(1)))
              .font(.title3.weight(.bold))
              .foregroundStyle(.white)
          }

        // Checkmark for arrived
        if isArrived {
          Circle()
            .fill(Color.green)
            .frame(width: 20, height: 20)
            .overlay {
              Image(systemName: "checkmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
            }
            .offset(x: 18, y: 18)
        }
      }

      // Name
      Text(isCurrentUser ? "나" : participant.name)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)
    }
  }

  var participantsListSection: some View {
    VStack(spacing: 0) {
      ForEach(store.data.participants) { participant in
        participantRow(participant)

        if participant.id != store.data.participants.last?.id {
          Divider()
            .padding(.horizontal, 16)
        }
      }
    }
    .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16)
  }

  func participantRow(_ participant: ParticipantState) -> some View {
    let isCurrentUser = participant.id == store.data.currentUserId

    return HStack(spacing: 12) {
      // Avatar
      Circle()
        .fill(
          LinearGradient(
            colors: isCurrentUser
              ? [Color.pmindigo.n400, Color.pmindigo.n600]
              : [Color.pmgray.n400, Color.pmgray.n500],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 40, height: 40)
        .overlay {
          Text(String(participant.name.prefix(1)))
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
        }

      // Name + Status
      VStack(alignment: .leading, spacing: 2) {
        Text(isCurrentUser ? "나" : participant.name)
          .font(.body.weight(.medium))
          .foregroundStyle(.primary)

        Text(statusDescription(for: participant))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // ETA Badge
      etaBadge(for: participant)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  func etaBadge(for participant: ParticipantState) -> some View {
    Group {
      if let eta = participant.estimatedArrivalMinutes {
        if eta == 0 {
          HStack(spacing: 4) {
            Image(systemName: "checkmark")
              .font(.caption.weight(.bold))
            Text("도착")
              .font(.subheadline.weight(.semibold))
          }
          .foregroundStyle(.green)
        } else {
          Text("\(eta)분")
            .font(.title3.weight(.bold))
            .foregroundStyle(etaColor(for: eta))
        }
      } else {
        Text("대기")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  var etaButtonsSection: some View {
    VStack(spacing: 12) {
      Text("내 상태 변경")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(spacing: 12) {
        etaButton(icon: "checkmark.circle.fill", title: "도착", minutes: 0, color: .green)
        etaButton(icon: "clock", title: "+5분", minutes: 5, color: .orange)
        etaButton(icon: "clock", title: "+10분", minutes: 10, color: .red)
      }
      .padding(.horizontal, 16)
    }
  }

  func etaButton(icon: String, title: String, minutes: Int, color: Color) -> some View {
    let isSelected = store.data.currentUserETA == minutes

    return Button {
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
      store.send(.etaButtonTapped(minutes))
    } label: {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(isSelected ? .white : color)

        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? .white : .primary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        isSelected ? color : cardBackgroundColor,
        in: RoundedRectangle(cornerRadius: 16)
      )
    }
    .disabled(store.data.isProcessingETAUpdate)
  }

  // MARK: - Map Tab

  var mapTabContent: some View {
    VStack {
      Spacer()
      Text("지도 기능 준비 중")
        .font(.headline)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  // MARK: - Chat Tab

  var chatTabContent: some View {
    VStack {
      Spacer()
      Text("채팅 기능 준비 중")
        .font(.headline)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }
}

// MARK: - Helper Functions

private extension LivePromise.ExpandedView {

  func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm"
    return formatter.string(from: date)
  }

  func formatPeriod(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "a"
    formatter.locale = Locale(identifier: "en_US")
    return formatter.string(from: date)
  }

  func statusColor(for participant: ParticipantState) -> Color {
    if let eta = participant.estimatedArrivalMinutes {
      if eta == 0 { return .green }
      if eta <= 5 { return .yellow }
      return .orange
    }
    return .gray
  }

  func statusDescription(for participant: ParticipantState) -> String {
    if let eta = participant.estimatedArrivalMinutes {
      if eta == 0 { return "도착 완료" }
      if eta <= 3 { return "거의 도착" }
      return "이동 중"
    }
    return "아직 출발 전"
  }

  func etaColor(for eta: Int) -> Color {
    if eta <= 3 { return .green }
    if eta <= 5 { return .yellow }
    if eta <= 10 { return .orange }
    return .red
  }
}

// MARK: - Color Hex Extension

private extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3:
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

// MARK: - Preview

#Preview("LivePromise.ExpandedView") {
  LivePromise.ExpandedView(
    store: Store(
      initialState: LivePromise.Detail.State(
        data: Shared(value: LivePromise.Data(
          emoji: "🍜",
          title: "점심 모임",
          location: "강남역 11번 출구",
          scheduledTime: Calendar.current.date(
            bySettingHour: 12,
            minute: 30,
            second: 0,
            of: Date()
          ),
          participants: [
            ParticipantState(id: "1", name: "나", estimatedArrivalMinutes: 0),
            ParticipantState(id: "2", name: "민수", estimatedArrivalMinutes: 3),
            ParticipantState(id: "3", name: "지현", estimatedArrivalMinutes: 8),
            ParticipantState(id: "4", name: "서연", estimatedArrivalMinutes: nil)
          ],
          currentUserId: "1",
          trackingDurationMinutes: 30
        ))
      )
    ) {
      LivePromise.Detail()
    }
  )
  .preferredColorScheme(.dark)
}
