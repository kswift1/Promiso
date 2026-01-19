//
//  LivePromiseExpandedView.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ComposableArchitecture
import SwiftUI
import PromisoShared

// MARK: - LivePromise.ExpandedView

extension LivePromise {
  /// 약속 추적 확장 뷰 (전체 화면)
  /// 약속 상세 정보, 레이싱 트랙, 참가자 리스트, ETA 버튼을 표시합니다.
  public struct ExpandedView: View {
    @Bindable var store: StoreOf<Detail>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<Detail>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ZStack {
          // Background
          Color(UIColor.systemBackground)
            .ignoresSafeArea()

          ScrollView {
            VStack(spacing: 24) {
              // Drag Indicator
              dragIndicator

              // Header Section (약속 정보)
              headerSection
                .padding(.top, 8)

              // Racing Track Section (큰 레이싱 트랙)
              racingTrackSection
                .padding(.horizontal, 16)

              // Participants List
              participantsList
                .padding(.horizontal, 16)

              // ETA Buttons
              etaButtonsSection
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
          }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            closeButton
          }
        }
      }
    }
  }
}

// MARK: - Subviews

private extension LivePromise.ExpandedView {

  // MARK: Drag Indicator

  var dragIndicator: some View {
    RoundedRectangle(cornerRadius: 2.5)
      .fill(Color(UIColor.tertiaryLabel))
      .frame(width: 36, height: 5)
      .padding(.top, 8)
  }

  // MARK: Close Button

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

  // MARK: Header Section

  var headerSection: some View {
    VStack(spacing: 8) {
      // Emoji + Title
      HStack(spacing: 8) {
        Text(store.emoji)
          .font(.largeTitle)

        Text(store.title)
          .font(.title2.weight(.bold))
          .foregroundStyle(.primary)
      }

      // Location
      if let location = store.location {
        HStack(spacing: 6) {
          Image(systemName: "mappin.circle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)

          Text(location)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }

      // Time
      if let scheduledTime = store.scheduledTime {
        HStack(spacing: 6) {
          Image(systemName: "clock.fill")
            .font(.callout)
            .foregroundStyle(.secondary)

          Text(formatTime(scheduledTime))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
  }

  // MARK: Racing Track Section

  var racingTrackSection: some View {
    VStack(spacing: 16) {
      Text("도착 현황")
        .font(.headline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)

      // Simple progress track
      simpleProgressTrack
        .frame(height: 100)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(UIColor.secondarySystemBackground))
    )
  }

  var simpleProgressTrack: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Track background
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(UIColor.systemGray5))
          .frame(height: 40)

        // Finish line
        HStack {
          Spacer()
          Image(systemName: "flag.checkered")
            .font(.title2)
            .foregroundStyle(.red)
            .padding(.trailing, 8)
        }
        .frame(height: 40)

        // Participants markers
        ForEach(store.participants) { participant in
          participantMarker(participant, trackWidth: geometry.size.width - 32)
        }
      }
      .frame(height: 80)
    }
  }

  func participantMarker(_ participant: ParticipantState, trackWidth: CGFloat) -> some View {
    let position = participant.trackPosition(trackingDurationMinutes: store.trackingDurationMinutes)
    let xOffset = position * trackWidth

    return VStack(spacing: 4) {
      Circle()
        .fill(
          LinearGradient(
            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 32, height: 32)
        .overlay {
          Text(String(participant.name.prefix(1)))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

      Text(participant.name)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .offset(x: xOffset)
  }

  // MARK: Participants List

  var participantsList: some View {
    VStack(spacing: 16) {
      Text("참가자 상세")
        .font(.headline)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)

      VStack(spacing: 8) {
        ForEach(store.participants) { participant in
          participantRow(participant)
        }
      }
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(UIColor.secondarySystemBackground))
    )
  }

  func participantRow(_ participant: ParticipantState) -> some View {
    HStack(spacing: 16) {
      // Avatar
      Circle()
        .fill(
          LinearGradient(
            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
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

      // Name
      Text(participant.name)
        .font(.body.weight(.medium))
        .foregroundStyle(.primary)

      Spacer()

      // Status Badge
      statusBadge(for: participant)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
  }

  func statusBadge(for participant: ParticipantState) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(statusColor(for: participant))
        .frame(width: 8, height: 8)

      Text(statusText(for: participant))
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(statusColor(for: participant).opacity(0.15))
    )
  }

  // MARK: ETA Buttons Section

  var etaButtonsSection: some View {
    VStack(spacing: 16) {
      Text("예상 도착 시간 업데이트")
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)

      HStack(spacing: 16) {
        etaButton(title: "완료", minutes: 0)
        etaButton(title: "5분", minutes: 5)
        etaButton(title: "10분", minutes: 10)
      }
    }
  }

  func etaButton(title: String, minutes: Int) -> some View {
    let isSelected = store.currentUserETA == minutes

    return Button {
      store.send(.etaButtonTapped(minutes))
    } label: {
      Text(title)
        .font(.body.weight(.semibold))
        .foregroundStyle(isSelected ? .white : .primary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemBackground))
        )
    }
    .disabled(store.isProcessingETAUpdate)
  }
}

// MARK: - Helper Functions

private extension LivePromise.ExpandedView {

  func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "a h:mm"
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: date)
  }

  func statusColor(for participant: ParticipantState) -> Color {
    if let eta = participant.estimatedArrivalMinutes {
      if eta == 0 {
        return .green // 도착 완료
      } else if eta <= 5 {
        return .yellow // 곧 도착
      } else {
        return .orange // 이동 중
      }
    } else {
      return .gray // 대기 중
    }
  }

  func statusText(for participant: ParticipantState) -> String {
    if let eta = participant.estimatedArrivalMinutes {
      if eta == 0 {
        return "도착 완료"
      } else {
        return "\(eta)분 후"
      }
    } else {
      return "대기 중"
    }
  }
}

// MARK: - Preview

#Preview("LivePromise.ExpandedView") {
  LivePromise.ExpandedView(
    store: Store(
      initialState: LivePromise.Detail.State(
        emoji: "🎂",
        title: "생일 파티",
        location: "강남역 11번 출구",
        scheduledTime: Date().addingTimeInterval(3600),
        participants: [
          ParticipantState(id: "1", name: "홍길동", estimatedArrivalMinutes: 0),
          ParticipantState(id: "2", name: "김철수", estimatedArrivalMinutes: 5),
          ParticipantState(id: "3", name: "이영희", estimatedArrivalMinutes: nil)
        ],
        currentUserId: "2",
        trackingDurationMinutes: 30
      )
    ) {
      LivePromise.Detail()
    }
  )
}
