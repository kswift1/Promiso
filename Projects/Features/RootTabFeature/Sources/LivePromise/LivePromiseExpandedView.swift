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
  /// - `store`: LivePromise.Detail 스토어 (탭, 액션, @Shared data 포함)
  /// - `animation`: matchedTransitionSource와 연결을 위한 Namespace.ID
  /// - `transitionID`: 트랜지션 식별자
  /// - dismiss는 스와이프 제스처로만 처리 (부모 View에서 onChange로 감지)
  public struct ExpandedView: View {
    @Bindable var store: StoreOf<Detail>
    var animation: Namespace.ID
    var transitionID: String

    public init(
      store: StoreOf<Detail>,
      animation: Namespace.ID,
      transitionID: String
    ) {
      self.store = store
      self.animation = animation
      self.transitionID = transitionID
    }

    // MARK: - Colors

    private var backgroundColor: Color {
      Color(UIColor.systemBackground)
    }

    private var cardBackgroundColor: Color {
      Color(UIColor.secondarySystemBackground)
    }

    // MARK: - Body

    public var body: some View {
      detailTabContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .safeAreaInset(edge: .top, spacing: 0) {
          VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
              .fill(.primary.secondary)
              .frame(width: 35, height: 3)
              .padding(.vertical, 10)

            // Header Content
            livePromiseHeader(data: store.data)
              .padding(.top, 8)
              .padding(.horizontal, 16)

            // Action Buttons
            actionButtons
              .padding(.top, 16)
              .padding(.horizontal, 16)

            // Tab Bar
            detailTabBar
              .padding(.top, 20)
              .padding(.bottom, 8)
          }
          .background(backgroundColor)
          .navigationTransition(.zoom(sourceID: transitionID, in: animation))
        }
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Header

    @ViewBuilder
    private func livePromiseHeader(data: LivePromise.Data) -> some View {
      HStack(spacing: 12) {
        // Emoji
        Text(data.emoji)
          .font(.system(size: 44))

        // Info
        VStack(alignment: .leading, spacing: 4) {
          Text(data.title)
            .font(.title3.weight(.bold))

          HStack(spacing: 6) {
            if let location = data.location {
              Text("📍")
                .font(.caption)
              Text(location)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Text("•")
              .font(.caption)
              .foregroundStyle(.tertiary)
            Text("\(data.participants.count)명 참여")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 0)

        // Time
        if let time = data.scheduledTime {
          VStack(alignment: .trailing, spacing: 0) {
            Text(formatTime(time))
              .font(.title2.weight(.bold).monospacedDigit())
            Text(formatPeriod(time))
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
          }
        }
      }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
      HStack(spacing: 12) {
        actionButton(icon: "doc.on.doc", title: "복사") {
          store.send(.view(.copyButtonTapped))
        }
        actionButton(icon: "bell", title: "알림") {
          store.send(.view(.notificationButtonTapped))
        }
        actionButton(icon: "ellipsis", title: "더보기") {
          store.send(.view(.moreButtonTapped))
        }
      }
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
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

    // MARK: - Detail Tab Bar

    private var detailTabBar: some View {
      HStack(spacing: 0) {
        ForEach(LivePromise.DetailTab.allCases, id: \.self) { tab in
          detailTabButton(tab)
        }
      }
      .padding(4)
      .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 16)
    }

    private func detailTabButton(_ tab: LivePromise.DetailTab) -> some View {
      let isSelected = store.selectedTab == tab

      return Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.send(.view(.tabSelected(tab)))
      } label: {
        Text(tab.rawValue)
          .font(.subheadline.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .white : .secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(
            isSelected ? Color.pmindigo.n500 : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
          )
      }
      .buttonStyle(.plain)
    }

    // MARK: - Detail Tab Content

    @ViewBuilder
    private var detailTabContent: some View {
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

    private var statusTabContent: some View {
      ScrollView {
        VStack(spacing: 20) {
          // Racing Track (Horizontal Scroll)
          racingTrackSection(data: store.data)

          // Participants List
          participantsListSection(data: store.data)

          // ETA Buttons
          etaButtonsSection
        }
        .padding(.top, 16)
        .padding(.bottom, 32)
      }
    }

    private func racingTrackSection(data: LivePromise.Data) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("이동 현황")
          .font(.headline)
          .foregroundStyle(.primary)
          .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(data.participants) { participant in
              participantTrackItem(participant, data: data)
            }
          }
          .padding(.horizontal, 16)
        }
      }
    }

    private func participantTrackItem(_ participant: ParticipantState, data: LivePromise.Data) -> some View {
      let isArrived = participant.estimatedArrivalMinutes == 0
      let isCurrentUser = participant.id == data.currentUserId

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

    private func participantsListSection(data: LivePromise.Data) -> some View {
      VStack(spacing: 0) {
        ForEach(data.participants) { participant in
          participantRow(participant, data: data)

          if participant.id != data.participants.last?.id {
            Divider()
              .padding(.horizontal, 16)
          }
        }
      }
      .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
      .padding(.horizontal, 16)
    }

    private func participantRow(_ participant: ParticipantState, data: LivePromise.Data) -> some View {
      let isCurrentUser = participant.id == data.currentUserId

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

    private func etaBadge(for participant: ParticipantState) -> some View {
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

    private var etaButtonsSection: some View {
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

    private func etaButton(icon: String, title: String, minutes: Int, color: Color) -> some View {
      let currentETA = store.data.currentUserETA
      let isSelected = currentETA == minutes

      return Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.send(.view(.etaButtonTapped(minutes)))
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
    }

    // MARK: - Map Tab

    private var mapTabContent: some View {
      VStack {
        Spacer()
        Text("지도 기능 준비 중")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }

    // MARK: - Chat Tab

    private var chatTabContent: some View {
      VStack {
        Spacer()
        Text("채팅 기능 준비 중")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }

    // MARK: - Helper Functions

    private func formatTime(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "h:mm"
      return formatter.string(from: date)
    }

    private func formatPeriod(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "a"
      formatter.locale = Locale(identifier: "en_US")
      return formatter.string(from: date)
    }

    private func statusColor(for participant: ParticipantState) -> Color {
      if let eta = participant.estimatedArrivalMinutes {
        if eta == 0 { return .green }
        if eta <= 5 { return .yellow }
        return .orange
      }
      return .gray
    }

    private func statusDescription(for participant: ParticipantState) -> String {
      if let eta = participant.estimatedArrivalMinutes {
        if eta == 0 { return "도착 완료" }
        if eta <= 3 { return "거의 도착" }
        return "이동 중"
      }
      return "아직 출발 전"
    }

    private func etaColor(for eta: Int) -> Color {
      if eta <= 3 { return .green }
      if eta <= 5 { return .yellow }
      if eta <= 10 { return .orange }
      return .red
    }
  }
}
