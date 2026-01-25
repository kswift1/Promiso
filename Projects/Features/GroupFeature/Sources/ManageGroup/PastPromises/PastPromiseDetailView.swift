import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import UIKit
import SharedFeature

extension PastPromiseDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection
          participantsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .scrollDismissesKeyboard(.interactively)
      .onTapGesture {
        dismissKeyboard()
      }
      .auroraBackground()
      .navigationTitle("지난 약속")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(
        item: Binding(
          get: { store.memberSheet },
          set: { _ in store.send(.view(.memberSheetDismissed)) }
        )
      ) { sheetState in
        PromiseDetailMemberListSheet(
          title: sheetState.title,
          members: sheetState.members,
          color: participantColor(sheetState.colorType)
        )
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      HStack(alignment: .top, spacing: 12) {
        // 이모지
        Text(store.promise.displayEmoji)
          .font(.system(size: 44))

        // 제목 + 설명
        VStack(alignment: .leading, spacing: 6) {
          Text(store.promise.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)

          if let description = store.promise.description, !description.isEmpty {
            PromiseDetailExpandableText(text: description, isExpanded: $isDescriptionExpanded)
          }
        }

        Spacer()

        // 상태 배지 (우측 상단)
        PromiseDetailStatusBadgeView(status: pastStatus)
      }
      .padding(16)
      .adaptiveGlassCard(cornerRadius: 16)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        PromiseDetailSectionHeader(title: "일정")

        VStack(spacing: 0) {
          PromiseDetailEmojiInfoRow(
            emoji: "📅",
            title: "날짜",
            value: formatFullDate(store.promise.startAt)
          )

          Divider().padding(.leading, 44)

          PromiseDetailEmojiInfoRow(
            emoji: "⏰",
            title: "시간",
            value: store.promise.timeText
          )

          if let location = store.promise.location {
            Divider().padding(.leading, 44)

            PromiseDetailLocationInfoRow(
              location: location,
              onDirectionsTapped: { }
            )

            if let latitude = location.latitude,
               let longitude = location.longitude {
              Divider().padding(.leading, 44)

              PromiseDetailLocationMapPreview(
                latitude: latitude,
                longitude: longitude,
                placeName: location.name
              )
            }
          }

          if let deadline = store.promise.deadlineText {
            Divider().padding(.leading, 44)

            PromiseDetailEmojiInfoRow(
              emoji: "⏳",
              title: "투표 마감",
              value: deadline
            )
          }

          Divider().padding(.leading, 44)

          PromiseDetailEmojiInfoRow(
            emoji: "👥",
            title: "최소 확정 인원",
            value: "\(store.promise.minimumParticipants)명"
          )
        }
        .adaptiveGlassCard(cornerRadius: 12)
      }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
      VStack(spacing: 0) {
        PromiseDetailSectionHeader(
          title: "참여자",
          trailing: "\(store.promise.votes.acceptedCount)/\(store.groupMembers?.count ?? 0)명 참여"
        )

        VStack(spacing: 12) {
          if !store.promise.votes.accepted.isEmpty {
            PromiseDetailParticipantGroupRow(
              title: "참여",
              count: store.promise.votes.acceptedCount,
              userIds: store.promise.votes.accepted,
              members: store.groupMembers,
              color: participantColor(.accepted)
            ) {
              store.send(.view(.participantGroupTapped(
                title: "참여",
                userIds: store.promise.votes.accepted,
                colorType: .accepted
              )))
            }
          }

          if !store.promise.votes.declined.isEmpty {
            PromiseDetailParticipantGroupRow(
              title: "불참",
              count: store.promise.votes.declinedCount,
              userIds: store.promise.votes.declined,
              members: store.groupMembers,
              color: participantColor(.declined)
            ) {
              store.send(.view(.participantGroupTapped(
                title: "불참",
                userIds: store.promise.votes.declined,
                colorType: .declined
              )))
            }
          }

          if let members = store.groupMembers {
            let respondedIds = Set(store.promise.votes.accepted + store.promise.votes.declined)
            let pendingUserIds = members.filter { !respondedIds.contains($0.userId) }.map(\.userId)

            if !pendingUserIds.isEmpty {
              PromiseDetailParticipantGroupRow(
                title: "미응답",
                count: pendingUserIds.count,
                userIds: pendingUserIds,
                members: members,
                color: participantColor(.pending)
              ) {
                store.send(.view(.participantGroupTapped(
                  title: "미응답",
                  userIds: pendingUserIds,
                  colorType: .pending
                )))
              }
            }
          }
        }
      }
    }

    // MARK: - Helpers

    private func formatFullDate(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "M월 d일 (E)"
      return formatter.string(from: date)
    }

    private var pastStatus: PromiseResponseStatus {
      store.promise.isConfirmed ? .confirmed : .failed
    }

    private func participantColor(_ type: PastPromiseDetail.Feature.ParticipantColorType) -> Color {
      switch type {
      case .accepted:
        return .green
      case .declined:
        return .red
      case .pending:
        return .gray
      }
    }

    private func dismissKeyboard() {
      UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
      )
    }
  }
}

// MARK: - Supporting Views
