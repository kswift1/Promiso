//
//  LivePromiseExpandedView.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import Clients
import ComposableArchitecture
import Lottie
import ResourceKit
import SwiftUI
import PromisoShared

// MARK: - LivePromise.ExpandedView

extension LivePromise {
  /// 약속 추적 확장 뷰 (전체 화면) - DetailSpec v5 기준
  /// 4단 구조: 헤더 / Racing View / 참가자 현황 / 상태 변경
  public struct ExpandedView: View {
    @Bindable var store: StoreOf<Detail>
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isMinuteInputFocused: Bool

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
      Color(.systemBackground)
    }

    private var cardBackgroundColor: Color {
      colorScheme == .dark
        ? Color.white.opacity(0.08)
        : Color(.secondarySystemBackground)
    }

    private var primaryTextColor: Color {
      colorScheme == .dark ? .white : Color.pmgray.n900
    }

    private var secondaryTextColor: Color {
      colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 0) {
          // 1. 헤더 섹션 (CompactView 스타일)
          headerSection
            .padding(.top, 8)

          // 2. Racing View
          racingViewSection
            .padding(.top, 24)

          // 3. 참가자 현황
          participantStatusSection
            .padding(.top, 24)

          // 4. 상태 변경 버튼 (시트 트리거)
          statusChangeButton
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 16)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.ultraThinMaterial)
      .safeAreaInset(edge: .top, spacing: 0) {
        // Drag Indicator
        VStack(spacing: 0) {
          Capsule()
            .fill(colorScheme == .dark ? .white.opacity(0.3) : .gray.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .navigationTransition(.zoom(sourceID: transitionID, in: animation))
      }
      .sheet(
        isPresented: Binding(
          get: { store.isETASheetPresented },
          set: { newValue in
            if !newValue {
              store.send(.view(.hideETASheet))
            }
          }
        )
      ) {
        etaChangeSheet
          .presentationDetents([.medium])
          .presentationDragIndicator(.visible)
      }
    }

    // MARK: - Computed Properties for Header (PromiseCard 동일)

    /// 약속 모델 (store에서 가져오거나 fallback)
    private var promise: PromiseModel? {
      store.promise
    }

    /// 호스트 정보
    private var host: UserPublicModel? {
      guard let promise = promise else { return nil }
      return store.groupMembers?.first { $0.userId == promise.hostId }
    }

    /// 현재 사용자가 호스트인지
    private var isHost: Bool {
      guard let promise = promise else { return false }
      return promise.isHost(userId: store.currentUserId)
    }

    /// 장소가 미정인지
    private var isLocationUndecided: Bool {
      promise?.locationText == "장소 미정"
    }

    // MARK: - 1. Header Section (PromiseCard와 동일 구조)

    private var headerSection: some View {
      VStack(alignment: .leading, spacing: 14) {
        // 1. Host Section (PromiseCard와 동일)
        HStack(spacing: 10) {
          ProfileAvatarView(
            profileImageUrl: host?.profileImageUrl,
            displayName: host?.displayName ?? "",
            isCurrentUser: isHost,
            size: 32
          )

          VStack(alignment: .leading, spacing: 2) {
            if isHost {
              Text("내 약속 제안")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            } else if let hostName = host?.displayName {
              Text("\(hostName)님의 약속 제안")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            } else {
              Text("약속 제안")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            }
          }

          Spacer()

          liveBadge  // StatusBadge 대신 liveBadge 유지
        }

        Divider()

        // 2. Main Content (PromiseCard와 동일)
        HStack(alignment: .top, spacing: 12) {
          Text(promise?.displayEmoji ?? store.data.emoji)
            .font(.system(size: 44))

          VStack(alignment: .leading, spacing: 10) {
            Text(promise?.title ?? store.data.title)
              .font(.system(size: 19, weight: .bold))
              .foregroundColor(.primary)

            // Description (PromiseCard와 동일)
            if let description = promise?.description, !description.isEmpty {
              Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
              // 시간 (PromiseCard와 동일)
              if let dateText = promise?.dateText, let timeText = promise?.timeText {
                HStack(spacing: 4) {
                  Text("⏰")
                    .font(.system(size: 14))
                  Text("\(dateText) \(timeText)")
                    .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.primary)
              } else if let time = store.data.scheduledTime {
                // Fallback: LivePromise.Data에서 가져오기
                HStack(spacing: 4) {
                  Text("⏰")
                    .font(.system(size: 14))
                  Text("\(formatDateText(time)) \(formatTimeText(time))")
                    .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.primary)
              }

              // 장소 (PromiseCard와 동일 - "장소 미정"이면 숨김)
              if !isLocationUndecided {
                if let locationText = promise?.locationText {
                  HStack(spacing: 4) {
                    Text("📍")
                      .font(.system(size: 14))
                    Text(locationText)
                      .font(.system(size: 14, weight: .medium))
                  }
                  .foregroundColor(.primary)
                } else if let location = store.data.location {
                  // Fallback: LivePromise.Data에서 가져오기
                  HStack(spacing: 4) {
                    Text("📍")
                      .font(.system(size: 14))
                    Text(location)
                      .font(.system(size: 14, weight: .medium))
                      .lineLimit(1)
                  }
                  .foregroundColor(.primary)
                }
              }
            }
          }

          Spacer()
        }
      }
      .padding(16)
      .adaptiveGlassCardBackground()
    }

    // MARK: - Participant Avatars

    private var participantAvatars: some View {
      let displayParticipants = Array(store.data.participants.prefix(4))
      let remainingCount = max(0, store.data.participants.count - 4)

      return HStack(spacing: -8) {
        ForEach(displayParticipants) { participant in
          participantAvatar(for: participant)
        }

        if remainingCount > 0 {
          Text("+\(remainingCount)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(
              LinearGradient(
                colors: [Color.pmgray.n400, Color.pmgray.n500],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
      }
    }

    private func participantAvatar(for participant: ParticipantState) -> some View {
      let isCurrentUser = participant.id == store.data.currentUserId

      return Group {
        if let image = LiveActivityImageStore.loadImage(userId: participant.id) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
        } else {
          Circle()
            .fill(
              LinearGradient(
                colors: isCurrentUser
                  ? [Color.pmindigo.n400, Color.pmindigo.n600]
                  : [Color.pmgray.n300, Color.pmgray.n400],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 24, height: 24)
            .overlay {
              Text(String(participant.name.prefix(1)))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
            }
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
        }
      }
    }

    private func formatDateText(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "M월 d일 (E)"
      return formatter.string(from: date)
    }

    private func formatTimeText(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "a h:mm"
      return formatter.string(from: date)
    }

    /// 남은 시간 계산 및 표시
    private func remainingTimeView(until date: Date) -> some View {
      let remaining = date.timeIntervalSinceNow
      let isOverdue = remaining < 0
      let absRemaining = abs(remaining)

      let hours = Int(absRemaining) / 3600
      let minutes = (Int(absRemaining) % 3600) / 60

      return HStack(spacing: 4) {
        if isOverdue {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmerror.n500)
        }

        if hours > 0 {
          Text("\(hours)시간 \(minutes)분")
            .font(.title3.weight(.bold).monospacedDigit())
        } else {
          Text("\(minutes)분")
            .font(.title3.weight(.bold).monospacedDigit())
        }

        if isOverdue {
          Text("지남")
            .font(.subheadline.weight(.medium))
        }
      }
      .foregroundStyle(isOverdue ? Color.pmerror.n500 : Color.pmindigo.n500)
    }

    private var liveBadge: some View {
      HStack(spacing: 4) {
        LottieView(animation: LottieAsset.live.animation)
          .playing(loopMode: .loop)
          .frame(width: 14, height: 10)

        Text("실시간")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(colorScheme == .dark ? Color.pmindigo.n200 : Color.pmindigo.n600)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        colorScheme == .dark
          ? Color.pmindigo.n800.opacity(0.6)
          : Color.pmindigo.n100.opacity(0.8),
        in: Capsule()
      )
    }

    // MARK: - 2. Racing View Section

    private var racingViewSection: some View {
      SharedRacingTrackView(
        participants: store.data.participants,
        trackingDurationMinutes: store.data.trackingDurationMinutes,
        currentUserId: store.data.currentUserId
      )
      .frame(height: 50)
      .padding(.vertical, 16)
      .padding(.horizontal, 14)
      .background(Color.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
      .environment(\.colorScheme, .dark)
    }

    // MARK: - 3. Participant Status Section

    private var participantStatusSection: some View {
      VStack(spacing: 12) {
        // 헤더
        HStack {
          HStack(spacing: 6) {
            Circle()
              .fill(Color.pmindigo.n500)
              .frame(width: 8, height: 8)
            Text("참가자 현황")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(primaryTextColor)
          }

          Spacer()

          Text("\(store.data.arrivedCount)/\(store.data.participants.count) 도착")
            .font(.caption.weight(.medium))
            .foregroundStyle(secondaryTextColor)
        }
        .padding(.horizontal, 4)

        // 참가자 리스트
        VStack(spacing: 0) {
          ForEach(sortedParticipants) { participant in
            participantRow(participant)

            if participant.id != sortedParticipants.last?.id {
              Divider()
                .background(colorScheme == .dark ? .white.opacity(0.1) : .gray.opacity(0.2))
                .padding(.horizontal, 12)
            }
          }
        }
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
      }
    }

    /// 참가자 정렬: 도착 → 이동중 (ETA 오름차순) → 대기
    private var sortedParticipants: [ParticipantState] {
      store.data.participants.sorted { p1, p2 in
        let eta1 = p1.estimatedArrivalMinutes ?? Int.max
        let eta2 = p2.estimatedArrivalMinutes ?? Int.max
        return eta1 < eta2
      }
    }

    private func participantRow(_ participant: ParticipantState) -> some View {
      let isCurrentUser = participant.id == store.data.currentUserId
      let isArrived = participant.estimatedArrivalMinutes == 0
      let isLate = (participant.estimatedArrivalMinutes ?? 0) > 10

      return HStack(spacing: 12) {
        // 아바타
        avatarView(for: participant, isCurrentUser: isCurrentUser)

        // 이름 + 상태
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(isCurrentUser ? "나" : participant.name)
              .font(.body.weight(.medium))
              .foregroundStyle(primaryTextColor)

            if isCurrentUser {
              Text("나")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.pmindigo.n500)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                  colorScheme == .dark
                    ? Color.pmindigo.n800.opacity(0.6)
                    : Color.pmindigo.n100,
                  in: Capsule()
                )
            }
          }

          Text(statusText(for: participant))
            .font(.caption)
            .foregroundStyle(secondaryTextColor)
        }

        Spacer()

        // ETA 뱃지
        etaBadge(for: participant, isLate: isLate)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }

    private func avatarView(for participant: ParticipantState, isCurrentUser: Bool) -> some View {
      let isArrived = participant.estimatedArrivalMinutes == 0

      return ZStack {
        if let image = LiveActivityImageStore.loadImage(userId: participant.id) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
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
            .frame(width: 44, height: 44)
            .overlay {
              Text(assignedEmoji(for: participant.id))
                .font(.system(size: 20))
            }
        }

        // 도착 체크마크
        if isArrived {
          Circle()
            .fill(Color.pmsuccess.n500)
            .frame(width: 18, height: 18)
            .overlay {
              Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
            }
            .offset(x: 16, y: 16)
        }
      }
    }

    private func etaBadge(for participant: ParticipantState, isLate: Bool) -> some View {
      Group {
        if let eta = participant.estimatedArrivalMinutes {
          if eta == 0 {
            // 도착
            HStack(spacing: 4) {
              Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
              Text("도착")
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.pmsuccess.n500)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.pmsuccess.n500.opacity(0.15), in: Capsule())
          } else {
            // 이동 중
            HStack(spacing: 2) {
              if isLate {
                Circle()
                  .fill(Color.pmerror.n500)
                  .frame(width: 6, height: 6)
              } else {
                Circle()
                  .fill(Color.pmindigo.n500)
                  .frame(width: 6, height: 6)
              }
              Text("\(eta)분")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isLate ? Color.pmerror.n500 : Color.pmindigo.n500)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
              (isLate ? Color.pmerror.n500 : Color.pmindigo.n500).opacity(0.15),
              in: Capsule()
            )
          }
        } else {
          // 대기
          Text("대기")
            .font(.subheadline)
            .foregroundStyle(secondaryTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(cardBackgroundColor, in: Capsule())
        }
      }
    }

    // MARK: - 4. Status Change Button (시트 트리거)

    private var statusChangeButton: some View {
      Button {
        store.send(.view(.showETASheet))
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("내 상태")
              .font(.caption)
              .foregroundStyle(secondaryTextColor)

            if let currentETA = store.data.currentUserETA {
              HStack(spacing: 6) {
                Text(currentETA == 0 ? "🏁" : "🚗")
                  .font(.system(size: 16))
                Text(currentETA == 0 ? "도착 완료" : "\(currentETA)분 후 도착")
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(currentETA == 0 ? Color.pmsuccess.n500 : primaryTextColor)
              }
            } else {
              Text("상태를 설정해주세요")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(secondaryTextColor)
            }
          }

          Spacer()

          Text("변경")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.pmindigo.n500, in: Capsule())
        }
        .padding(16)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
      }
      .buttonStyle(.plain)
    }

    // MARK: - ETA Change Sheet

    private var etaChangeSheet: some View {
      VStack(spacing: 24) {
        // 헤더
        Text("도착 예정 시간 변경")
          .font(.headline.weight(.bold))
          .foregroundStyle(primaryTextColor)

        // ETA 버튼들
        VStack(spacing: 12) {
          HStack(spacing: 12) {
            etaSheetButton(title: "도착", emoji: "🏁", minutes: 0, color: Color.pmsuccess.n500)
            etaSheetButton(title: "5분", emoji: nil, minutes: 5, color: Color.pmindigo.n500)
          }

          HStack(spacing: 12) {
            etaSheetButton(title: "10분", emoji: nil, minutes: 10, color: Color.pmindigo.n500)
            etaSheetButton(title: "15분", emoji: nil, minutes: 15, color: Color.pmindigo.n500)
          }

          HStack(spacing: 12) {
            etaSheetButton(title: "20분", emoji: nil, minutes: 20, color: Color.pmwarning.n500)
            etaSheetButton(title: "30분", emoji: nil, minutes: 30, color: Color.pmerror.n500)
          }
        }

        // 직접 입력
        VStack(spacing: 8) {
          Text("직접 입력")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(secondaryTextColor)

          HStack(spacing: 12) {
            TextField("분", text: $store.customMinuteInput.sending(\.view.customMinuteInputChanged))
              .keyboardType(.numberPad)
              .multilineTextAlignment(.center)
              .font(.title2.weight(.bold))
              .frame(width: 80, height: 50)
              .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
              .focused($isMinuteInputFocused)

            Text("분 후 도착")
              .font(.body)
              .foregroundStyle(secondaryTextColor)

            Spacer()

            Button {
              store.send(.view(.submitCustomMinute))
            } label: {
              Text("확인")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 10))
            }
          }
        }
        .padding(.top, 8)

        Spacer()
      }
      .padding(24)
      .background(Color(.systemBackground))
    }

    private func etaSheetButton(title: String, emoji: String?, minutes: Int, color: Color) -> some View {
      let isSelected = store.data.currentUserETA == minutes

      return Button {
        store.send(.view(.etaButtonTapped(minutes)))
      } label: {
        HStack(spacing: 8) {
          if let emoji = emoji {
            Text(emoji)
              .font(.system(size: 20))
          }
          Text(title)
            .font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .foregroundStyle(isSelected ? .white : primaryTextColor)
        .background(isSelected ? color : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
      }
      .buttonStyle(.plain)
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
      return formatter.string(from: date).uppercased()
    }

    private func statusText(for participant: ParticipantState) -> String {
      guard let eta = participant.estimatedArrivalMinutes else {
        return "아직 출발 전"
      }
      if eta == 0 {
        return "도착 완료"
      }
      if eta <= 3 {
        return "거의 도착"
      }
      if eta > 10 {
        return "지각 예상"
      }
      return "이동 중"
    }

    private static let defaultEmojis = ["😀", "😊", "🙂", "😎", "🤗", "😇", "🥳", "🤩", "😺", "🐻"]

    private func assignedEmoji(for id: String) -> String {
      let index = abs(id.hashValue) % Self.defaultEmojis.count
      return Self.defaultEmojis[index]
    }
  }
}

// MARK: - Glass Effect Modifier (PromiseCard와 동일)

private extension View {
  func adaptiveGlassCardBackground() -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .strokeBorder(.white.opacity(0.2), lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
      )
    } else {
      return AnyView(
        self
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color(.systemGray5), lineWidth: 1)
          )
      )
    }
  }
}

