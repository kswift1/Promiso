import SwiftUI
import UIKit
import ComposableArchitecture
import Clients
import PromisoShared

extension ScheduleDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false
    @State private var selectedImageIndex: Int?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection

          // 날씨 섹션
          if let weatherInfo = store.weatherInfo {
            ScheduleDetailWeatherSection(
              weatherInfo: weatherInfo,
              startAt: store.schedule.startAt,
              endAt: store.schedule.endAt
            )
          }

          // 이미지 갤러리
          if !store.schedule.imageUrls.isEmpty {
            imageGallerySection
          }

          if !store.schedule.isPast {
            responseSection
          }
          participantsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .analyticsScreen(
        name: AnalyticsClient.ScreenName.scheduleDetail.rawValue,
        class: "ScheduleDetailView",
        extraParameters: [
          AnalyticsClient.ParameterKey.scheduleID: store.schedule.id
        ]
      )
      .onAppear {
        store.send(.view(.onAppear))
      }
      .sheet(
        item: Binding(
          get: { store.memberSheet },
          set: { _ in store.send(.view(.memberSheetDismissed)) }
        )
      ) { sheetState in
        ScheduleDetailMemberListSheet(
          title: sheetState.title,
          members: sheetState.members,
          color: participantColor(sheetState.colorType)
        )
      }
      .sheet(
        store: store.scope(state: \.$editSchedule, action: \.editSchedule)
      ) { editStore in
        EditSchedule.RootView(store: editStore)
      }
      .alert(store: store.scope(state: \.$alert, action: \.alert))
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
      .sheet(isPresented: Binding(
        get: { store.showShareSheet },
        set: { _ in store.send(.view(.shareSheetDismissed)) }
      )) {
        ScheduleShareSheet(
          schedule: store.schedule,
          isKakaoSharing: store.isKakaoSharing,
          onKakaoShareTapped: {
            store.send(.view(.kakaoShareTapped))
          },
          onSystemShareTapped: {
            store.send(.view(.systemShareTapped))
          }
        )
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
      }
      .sheet(item: Binding(
        get: { store.systemShareText.map { ShareTextItem(text: $0) } },
        set: { _ in store.send(.view(.systemShareSheetDismissed)) }
      )) { item in
        ShareSheet(items: [item.text])
      }
      .navigationDestination(isPresented: Binding(
        get: { store.showMapDetail },
        set: { _ in store.send(.view(.mapDetailDismissed)) }
      )) {
        if let location = store.schedule.location {
          LocationDetailMapView(
            location: location,
            onDirectionsTapped: {
              store.send(.view(.directionsTapped))
            }
          )
        }
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      HStack(alignment: .top, spacing: 12) {
        // 이모지
        Text(store.schedule.displayEmoji)
          .font(.system(size: 44))

        // 제목 + 설명
        VStack(alignment: .leading, spacing: 6) {
          Text(store.schedule.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)

          if !store.schedule.descriptionBlocks.isEmpty {
            DescriptionBlockRenderer(
              blocks: store.schedule.descriptionBlocks,
              isExpanded: $isDescriptionExpanded,
              onChecklistToggle: { blockId, itemId in
                store.send(.view(.toggleChecklist(blockId: blockId, itemId: itemId)))
              }
            )
          } else if let description = store.schedule.description, !description.isEmpty {
            ScheduleDetailExpandableText(text: description, isExpanded: $isDescriptionExpanded)
          }
        }

        Spacer()

        // 상태 배지 (우측 상단)
        ScheduleDetailStatusBadgeView(status: store.responseStatus)
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.schedule)

        VStack(spacing: 0) {
          // 날짜 & 시간
          ScheduleDetailEmojiInfoRow(
            emoji: "📅",
            title: LocalizedStrings.Common.date,
            value: formatFullDate(store.schedule.startAt)
          )

          Divider().padding(.leading, 44)

          ScheduleDetailEmojiInfoRow(
            emoji: "⏰",
            title: LocalizedStrings.Common.time,
            value: store.schedule.timeRangeText
          )

          // 장소
          if let location = store.schedule.location {
            Divider().padding(.leading, 44)

            ScheduleDetailLocationInfoRow(
              location: location
            )

            // 지도 미리보기 (좌표가 있는 경우)
            if let latitude = location.latitude,
               let longitude = location.longitude {
              Divider().padding(.leading, 44)

              ScheduleDetailLocationMapPreview(
                latitude: latitude,
                longitude: longitude,
                placeName: location.name,
                onTap: {
                  store.send(.view(.mapTapped))
                }
              )

              Button {
                store.send(.view(.directionsTapped))
              } label: {
                HStack(spacing: 6) {
                  Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.system(size: 14))
                  Text(LocalizedStrings.Common.directions)
                    .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.pmindigo.n500)
                .clipShape(RoundedRectangle(cornerRadius: 10))
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
            }
          }

          // 투표 마감
          if let deadline = store.schedule.deadlineText {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "⏳",
              title: LocalizedStrings.Shared.voteDeadline,
              value: deadline
            )
          }

          Divider().padding(.leading, 44)

          // 최소 확정 인원
          ScheduleDetailEmojiInfoRow(
            emoji: "👥",
            title: LocalizedStrings.Shared.minimumConfirmMembers,
            value: LocalizedStrings.Shared.membersCount(store.schedule.minimumParticipants)
          )
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Image Gallery Section

    @ViewBuilder
    private var imageGallerySection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.photo)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Array(store.schedule.imageUrls.enumerated()), id: \.offset) { index, url in
              GalleryImageThumbnail(url: url)
                .onTapGesture { selectedImageIndex = index }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .adaptiveGlassCard()
      }
      .fullScreenCover(isPresented: Binding(
        get: { selectedImageIndex != nil },
        set: { if !$0 { selectedImageIndex = nil } }
      )) {
        if let index = selectedImageIndex {
          PhotoGalleryViewer(
            imageUrls: store.schedule.imageUrls,
            initialIndex: index,
            onDismiss: { selectedImageIndex = nil }
          )
        }
      }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(
          title: LocalizedStrings.Shared.participantsSection,
          trailing: store.isLoadingMembers
            ? nil
            : LocalizedStrings.Shared.participantsJoined(
              store.schedule.votes.acceptedCount,
              store.groupMembers?.count ?? 0
            )
        )

        if store.isLoadingMembers {
          // 스켈레톤 UI
          VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
              HStack(spacing: 12) {
                // 아바타 스켈레톤
                Circle()
                  .fill(Color(.systemGray5))
                  .frame(width: 36, height: 36)

                // 텍스트 스켈레톤
                VStack(alignment: .leading, spacing: 6) {
                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 14)

                  RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(width: 40, height: 12)
                }

                Spacer()

                // 카운트 스켈레톤
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color(.systemGray5))
                  .frame(width: 32, height: 24)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color(.secondarySystemBackground).opacity(0.5))
              )
            }
          }
          .shimmer()
        } else {
          VStack(spacing: 12) {
            // 수락
            if !store.schedule.votes.accepted.isEmpty {
              ScheduleDetailParticipantGroupRow(
                title: LocalizedStrings.Shared.responseAccepted,
                count: store.schedule.votes.acceptedCount,
                userIds: store.schedule.votes.accepted,
                members: store.groupMembers,
                color: participantColor(.accepted)
              ) {
                store.send(.view(.participantGroupTapped(
                  title: LocalizedStrings.Shared.responseAccepted,
                  userIds: store.schedule.votes.accepted,
                  colorType: .accepted
                )))
              }
            }

            // 거절
            if !store.schedule.votes.declined.isEmpty {
              ScheduleDetailParticipantGroupRow(
                title: LocalizedStrings.Shared.responseDeclined,
                count: store.schedule.votes.declinedCount,
                userIds: store.schedule.votes.declined,
                members: store.groupMembers,
                color: participantColor(.declined)
              ) {
                store.send(.view(.participantGroupTapped(
                  title: LocalizedStrings.Shared.responseDeclined,
                  userIds: store.schedule.votes.declined,
                  colorType: .declined
                )))
              }
            }

            // 대기 (그룹 멤버 - 수락 - 거절)
            if let members = store.groupMembers {
              let respondedIds = Set(store.schedule.votes.accepted + store.schedule.votes.declined)
              let pendingUserIds = members.filter { !respondedIds.contains($0.userId) }.map(\.userId)

              if !pendingUserIds.isEmpty {
                ScheduleDetailParticipantGroupRow(
                  title: LocalizedStrings.Shared.responseNoAnswer,
                  count: pendingUserIds.count,
                  userIds: pendingUserIds,
                  members: members,
                  color: participantColor(.pending)
                ) {
                  store.send(.view(.participantGroupTapped(
                    title: LocalizedStrings.Shared.responseNoAnswer,
                    userIds: pendingUserIds,
                    colorType: .pending
                  )))
                }
              }
            }
          }
        }
      }
    }

    // MARK: - Response Section

    private var responseSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Shared.myResponse)

        ResponseBubblePicker(
          currentStatus: store.myVoteStatus,
          respondingState: store.respondingState,
          onAccept: { store.send(.view(.acceptTapped)) },
          onPending: { store.send(.view(.resetTapped)) },
          onDecline: { store.send(.view(.rejectTapped)) }
        )
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Directions Section (Live 상태일 때)

    private var directionsSection: some View {
      Button {
        store.send(.view(.directionsTapped))
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
            .font(.system(size: 16))
          Text(LocalizedStrings.Common.directions)
            .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.pmindigo.n500)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      if !store.schedule.isPast {
        ToolbarItem(placement: .topBarTrailing) {
          ToolbarButton(imageName: "square.and.arrow.up") {
            store.send(.view(.shareTapped))
          }
        }
      }

      if store.canManage {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if store.canEdit {
              Button {
                store.send(.view(.editTapped))
              } label: {
                Label(LocalizedStrings.Shared.editSchedule, systemImage: "pencil")
              }
            }

            // 투표 마감 버튼 (호스트만)
            if store.isHost {
              Button(role: .destructive) {
                store.send(.view(.closeVoteTapped))
              } label: {
                Label(LocalizedStrings.Shared.voteDeadline, systemImage: "stop.circle")
              }
            }

            Button(role: .destructive) {
              store.send(.view(.deleteTapped))
            } label: {
              Label(LocalizedStrings.Shared.deleteSchedule, systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
    }

    // MARK: - Helpers

    private func formatFullDate(_ date: Date) -> String {
      LocalizedDateFormatters.sectionHeader.string(from: date)
    }

    private func participantColor(_ type: ScheduleDetail.Feature.ParticipantColorType) -> Color {
      switch type {
      case .accepted:
        return .green
      case .declined:
        return .red
      case .pending:
        return .gray
      }
    }
  }
}

// MARK: - Supporting Views


// MARK: - Response Bubble Picker

private struct ResponseBubblePicker: View {
  let currentStatus: VoteStatus
  let respondingState: ScheduleDetail.Feature.RespondingState
  let onAccept: () -> Void
  let onPending: () -> Void
  let onDecline: () -> Void

  @State private var isExpanded = false
  private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
  private let selectionFeedback = UIImpactFeedbackGenerator(style: .heavy)

  private var isLoading: Bool {
    respondingState != .idle
  }

  private var statusColor: Color {
    switch currentStatus {
    case .accepted: return .green
    case .pending: return Color(.systemGray)
    case .declined: return .red
    }
  }

  private var statusIcon: String {
    switch currentStatus {
    case .accepted: return "checkmark"
    case .pending: return "minus"
    case .declined: return "xmark"
    }
  }

  private var statusText: String {
    switch currentStatus {
    case .accepted: return LocalizedStrings.Shared.responseAccepted
    case .pending: return LocalizedStrings.Shared.undetermined
    case .declined: return LocalizedStrings.Shared.responseDeclined
    }
  }

  var body: some View {
    // 현재 상태 버튼
    Button {
      guard !isLoading else { return }
      feedbackGenerator.impactOccurred()
      isExpanded = true
    } label: {
      HStack(spacing: 10) {
        ZStack {
          Circle()
            .fill(statusColor)
            .frame(width: 32, height: 32)

          if isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.7)
          } else {
            Image(systemName: statusIcon)
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
          }
        }

        Text(statusText)
          .font(.system(size: 16, weight: .semibold))

        Spacer()

        Text(LocalizedStrings.Common.change)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.secondarySystemBackground))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(isLoading)
    .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
      ResponsePopoverContent(
        currentStatus: currentStatus,
        respondingState: respondingState,
        onSelect: { status in
          selectOption(status)
        }
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  private func selectOption(_ status: VoteStatus) {
    guard currentStatus != status else {
      isExpanded = false
      return
    }

    selectionFeedback.impactOccurred()

    switch status {
    case .accepted:
      onAccept()
    case .pending:
      onPending()
    case .declined:
      onDecline()
    }

    isExpanded = false
  }
}

private struct ResponsePopoverContent: View {
  let currentStatus: VoteStatus
  let respondingState: ScheduleDetail.Feature.RespondingState
  let onSelect: (VoteStatus) -> Void

  var body: some View {
    HStack(spacing: 20) {
      PopoverBubble(
        icon: "checkmark",
        title: LocalizedStrings.Shared.responseAccepted,
        color: .green,
        isSelected: currentStatus == .accepted,
        isLoading: respondingState == .accepting
      ) {
        onSelect(.accepted)
      }

      PopoverBubble(
        icon: "minus",
        title: LocalizedStrings.Shared.undetermined,
        color: Color(.systemGray),
        isSelected: currentStatus == .pending,
        isLoading: respondingState == .resetting
      ) {
        onSelect(.pending)
      }

      PopoverBubble(
        icon: "xmark",
        title: LocalizedStrings.Shared.responseDeclined,
        color: .red,
        isSelected: currentStatus == .declined,
        isLoading: respondingState == .rejecting
      ) {
        onSelect(.declined)
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }
}

private struct PopoverBubble: View {
  let icon: String
  let title: String
  let color: Color
  let isSelected: Bool
  let isLoading: Bool
  let action: () -> Void

  private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      feedbackGenerator.impactOccurred()
      action()
    } label: {
      VStack(spacing: 8) {
        ZStack {
          Circle()
            .fill(isSelected ? color : color.opacity(0.15))
            .frame(width: 56, height: 56)

          if isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : color))
              .scaleEffect(0.9)
          } else {
            Image(systemName: icon)
              .font(.system(size: 22, weight: .bold))
              .foregroundStyle(isSelected ? .white : color)
          }
        }
        .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, y: 3)

        Text(title)
          .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
          .foregroundStyle(isSelected ? color : .secondary)
      }
    }
    .disabled(isLoading)
    .scaleEffect(isSelected ? 1.05 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
  }
}
