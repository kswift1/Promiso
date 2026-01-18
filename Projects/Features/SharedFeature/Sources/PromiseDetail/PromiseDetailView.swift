import SwiftUI
import UIKit
import ComposableArchitecture
import Clients
import PromisoShared

extension PromiseDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection
          participantsSection
          responseSection
          liveActivitySection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          store.send(.view(.checkPendingIntents))
        }
      }
      .sheet(
        item: Binding(
          get: { store.memberSheet },
          set: { _ in store.send(.view(.memberSheetDismissed)) }
        )
      ) { sheetState in
        MemberListSheet(
          title: sheetState.title,
          members: sheetState.members,
          colorType: sheetState.colorType
        )
      }
      .sheet(
        store: store.scope(state: \.$editPromise, action: \.editPromise)
      ) { editStore in
        EditPromise.RootView(store: editStore)
      }
      .alert(store: store.scope(state: \.$alert, action: \.alert))
      .sheet(isPresented: Binding(
        get: { store.showShareSheet },
        set: { _ in store.send(.view(.shareSheetDismissed)) }
      )) {
        ShareSheet(items: [store.promise.shareText])
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      VStack(spacing: 16) {
        // 이모지
        Text(store.promise.displayEmoji)
          .font(.system(size: 64))

        // 제목
        Text(store.promise.title)
          .font(.system(size: 24, weight: .bold))
          .multilineTextAlignment(.center)

        // 설명
        if let description = store.promise.description, !description.isEmpty {
          ExpandableText(text: description, isExpanded: $isDescriptionExpanded)
        }

        // 상태 배지
        StatusBadgeView(status: store.responseStatus)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        SectionHeader(title: "일정")

        VStack(spacing: 0) {
          // 날짜 & 시간
          EmojiInfoRow(
            emoji: "📅",
            title: "날짜",
            value: formatFullDate(store.promise.startAt)
          )

          Divider().padding(.leading, 44)

          EmojiInfoRow(
            emoji: "⏰",
            title: "시간",
            value: store.promise.timeText
          )

          // 장소
          if store.promise.location != nil {
            Divider().padding(.leading, 44)

            EmojiInfoRow(
              emoji: "📍",
              title: "장소",
              value: store.promise.locationText
            )
          }

          // 투표 마감
          if let deadline = store.promise.deadlineText {
            Divider().padding(.leading, 44)

            EmojiInfoRow(
              emoji: "⏳",
              title: "투표 마감",
              value: deadline
            )
          }
        }
        .glassCard()
      }
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
      VStack(spacing: 0) {
        SectionHeader(
          title: "참여자",
          trailing: "\(store.promise.votes.acceptedCount)/\(store.promise.minimumParticipants)명"
        )

        VStack(spacing: 12) {
          // 수락
          if !store.promise.votes.accepted.isEmpty {
            ParticipantGroupRow(
              title: "참여",
              count: store.promise.votes.acceptedCount,
              userIds: store.promise.votes.accepted,
              members: store.groupMembers,
              colorType: .accepted
            ) {
              store.send(.view(.participantGroupTapped(
                title: "참여",
                userIds: store.promise.votes.accepted,
                colorType: .accepted
              )))
            }
          }

          // 거절
          if !store.promise.votes.declined.isEmpty {
            ParticipantGroupRow(
              title: "불참",
              count: store.promise.votes.declinedCount,
              userIds: store.promise.votes.declined,
              members: store.groupMembers,
              colorType: .declined
            ) {
              store.send(.view(.participantGroupTapped(
                title: "불참",
                userIds: store.promise.votes.declined,
                colorType: .declined
              )))
            }
          }

          // 대기 (그룹 멤버 - 수락 - 거절)
          if let members = store.groupMembers {
            let respondedIds = Set(store.promise.votes.accepted + store.promise.votes.declined)
            let pendingUserIds = members.filter { !respondedIds.contains($0.userId) }.map(\.userId)

            if !pendingUserIds.isEmpty {
              ParticipantGroupRow(
                title: "미응답",
                count: pendingUserIds.count,
                userIds: pendingUserIds,
                members: members,
                colorType: .pending
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

    // MARK: - Response Section

    private var responseSection: some View {
      VStack(spacing: 12) {
        SectionHeader(title: "내 응답")

        HStack(spacing: 12) {
          // 수락 버튼
          ResponseButton(
            title: "참여",
            icon: "checkmark.circle.fill",
            color: .green,
            isSelected: store.myVoteStatus == .accepted,
            isLoading: store.respondingState == .accepting
          ) {
            store.send(.view(.acceptTapped))
          }

          // 거절 버튼
          ResponseButton(
            title: "불참",
            icon: "xmark.circle.fill",
            color: .red,
            isSelected: store.myVoteStatus == .declined,
            isLoading: store.respondingState == .rejecting
          ) {
            store.send(.view(.rejectTapped))
          }
        }

        // 되돌리기 버튼
        if store.myVoteStatus != .pending {
          Button {
            store.send(.view(.resetTapped))
          } label: {
            HStack(spacing: 6) {
              if store.respondingState == .resetting {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                  .scaleEffect(0.8)
              }
              Text("미정으로 되돌리기")
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.secondary)
          }
          .disabled(store.respondingState != .idle)
          .padding(.top, 4)
        }
      }
    }

    // MARK: - Live Activity Section

    @ViewBuilder
    private var liveActivitySection: some View {
      #if DEBUG
      // DEBUG: 목 테스트 섹션 (항상 표시)
      LiveActivityMockSection()
      #else
      // 조건: 확정됨 + 30분 이내 + 내가 참여 중
      if store.promise.isConfirmed && store.promise.isRealtimeShareable && store.isParticipating {
        VStack(spacing: 12) {
          SectionHeader(title: "실시간 공유")

          if store.isLiveActivityActive {
            // 활성화 상태: 도착 버튼 + 종료 버튼
            VStack(spacing: 12) {
              Button {
                store.send(.view(.markArrivedTapped))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                  Text("도착 완료")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }

              Button {
                store.send(.view(.liveActivityStopTapped))
              } label: {
                HStack(spacing: 8) {
                  Image(systemName: "stop.circle")
                    .font(.system(size: 18))
                  Text("실시간 공유 종료")
                    .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
            }
          } else {
            // 비활성화 상태: 시작 버튼
            Button {
              store.send(.view(.liveActivityStartTapped))
            } label: {
              HStack(spacing: 8) {
                if store.isStartingLiveActivity {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                } else {
                  Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18))
                }
                Text("실시간 공유 시작")
                  .font(.system(size: 16, weight: .semibold))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(Color.pmindigo.n500)
              .foregroundStyle(.white)
              .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(store.isStartingLiveActivity)

            Text("Dynamic Island에서 도착 현황을 확인할 수 있어요")
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
        }
      }
      #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        ToolbarButton(imageName: "square.and.arrow.up") {
          store.send(.view(.shareTapped))
        }
      }

      if store.isHost {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if store.canEdit {
              Button {
                store.send(.view(.editTapped))
              } label: {
                Label("약속 수정", systemImage: "pencil")
              }
            }

            Button(role: .destructive) {
              store.send(.view(.deleteTapped))
            } label: {
              Label("약속 삭제", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
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
  }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
  let title: String
  var trailing: String? = nil

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Spacer()

      if let trailing {
        Text(trailing)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 8)
  }
}

private struct ExpandableText: View {
  let text: String
  @Binding var isExpanded: Bool
  @State private var isTruncated = false
  private let lineLimit = 3

  var body: some View {
    VStack(spacing: 4) {
      Text(text)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(isExpanded ? nil : lineLimit)
        .background(
          GeometryReader { geometry in
            Color.clear.onAppear {
              checkTruncation(geometry: geometry)
            }
          }
        )

      if isTruncated || isExpanded {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        } label: {
          Text(isExpanded ? "접기" : "더보기")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.blue)
        }
      }
    }
  }

  private func checkTruncation(geometry: GeometryProxy) {
    let font = UIFont.systemFont(ofSize: 15)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let size = CGSize(width: geometry.size.width, height: .greatestFiniteMagnitude)
    let boundingRect = (text as NSString).boundingRect(
      with: size,
      options: [.usesLineFragmentOrigin, .usesFontLeading],
      attributes: attributes,
      context: nil
    )
    let lineHeight = font.lineHeight
    let numberOfLines = Int(ceil(boundingRect.height / lineHeight))
    isTruncated = numberOfLines > lineLimit
  }
}

private struct EmojiInfoRow: View {
  let emoji: String
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 10) {
      Text(emoji)
        .font(.system(size: 18))
        .frame(width: 28)

      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.system(size: 15, weight: .medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct ParticipantGroupRow: View {
  let title: String
  let count: Int
  let userIds: [String]
  let members: [UserPublicModel]?
  let colorType: PromiseDetail.Feature.ParticipantColorType
  let onTap: () -> Void

  private var color: Color {
    switch colorType {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .gray
    }
  }

  var body: some View {
    Button(action: onTap) {
      HStack {
        Circle()
          .fill(color)
          .frame(width: 8, height: 8)

        Text(title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)

        Text("\(count)명")
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Spacer()

        // 참여자 아바타 (최대 5명)
        HStack(spacing: -8) {
          ForEach(userIds.prefix(5), id: \.self) { userId in
            if let member = members?.first(where: { $0.userId == userId }) {
              ProfileAvatarView(
                profileImageUrl: member.profileImageUrl,
                displayName: member.displayName,
                size: 28
              )
            } else {
              ProfileAvatarView(
                profileImageUrl: nil,
                displayName: "?",
                size: 28
              )
            }
          }

          if userIds.count > 5 {
            Text("+\(userIds.count - 5)")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.white)
              .frame(width: 28, height: 28)
              .background(
                LinearGradient(
                  colors: [Color(red: 0.6, green: 0.6, blue: 0.65), Color(red: 0.45, green: 0.45, blue: 0.5)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .clipShape(Circle())
              .overlay(
                Circle()
                  .stroke(Color.white, lineWidth: 2)
              )
          }
        }

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .glassCard()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Member List Sheet

private struct MemberListSheet: View {
  let title: String
  let members: [UserPublicModel]
  let colorType: PromiseDetail.Feature.ParticipantColorType

  private var color: Color {
    switch colorType {
    case .accepted: return .green
    case .declined: return .red
    case .pending: return .gray
    }
  }

  var body: some View {
    NavigationView {
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(members) { member in
            MemberRow(member: member, color: color)

            if member.id != members.last?.id {
              Divider()
                .padding(.leading, 72)
            }
          }
        }
        .padding(.vertical, 8)
      }
      .navigationTitle("\(title) (\(members.count)명)")
      .navigationBarTitleDisplayMode(.inline)
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
  }
}

private struct MemberRow: View {
  let member: UserPublicModel
  let color: Color

  var body: some View {
    HStack(spacing: 16) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        size: 48,
        borderWidth: 0
      )

      VStack(alignment: .leading, spacing: 4) {
        Text(member.displayName)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(.primary)

        if !member.nickname.isEmpty && member.nickname != member.displayName {
          Text("@\(member.nickname)")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      Circle()
        .fill(color)
        .frame(width: 10, height: 10)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }
}

private struct ResponseButton: View {
  let title: String
  let icon: String
  let color: Color
  let isSelected: Bool
  let isLoading: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: isSelected ? .white : color))
            .scaleEffect(0.8)
        } else {
          Image(systemName: icon)
            .font(.system(size: 18))
        }

        Text(title)
          .font(.system(size: 16, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(isSelected ? color : color.opacity(0.1))
      .foregroundStyle(isSelected ? .white : color)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabled(isLoading || isSelected)
  }
}

private struct StatusBadgeView: View {
  let status: PromiseResponseStatus

  private var displayText: String {
    switch status {
    case .needResponse:
      return "응답 필요"
    case .responded:
      return "확정 대기"
    case .confirmed:
      return "확정됨"
    case .failed:
      return "미성사"
    }
  }

  private var color: Color {
    switch status {
    case .needResponse:
      return .orange
    case .responded:
      return .blue
    case .confirmed:
      return .green
    case .failed:
      return .gray
    }
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: status.iconName)
        .font(.system(size: 12))
      Text(displayText)
        .font(.system(size: 13, weight: .semibold))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(color.opacity(0.15))
    .foregroundStyle(color)
    .clipShape(Capsule())
  }
}

// MARK: - Glass Card Modifier

private extension View {
  func glassCard() -> some View {
    self
      .background(Color(.systemBackground).opacity(0.8))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(.systemGray5), lineWidth: 1)
      )
  }
}

// MARK: - Live Activity Debug View

#if DEBUG
private struct LiveActivityDebugView: View {
  @State private var debugInfo: [String: String] = [:]
  private let defaults = UserDefaults(suiteName: "group.com.promiso.shared")

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("🔍 Debug Info")
          .font(.system(size: 14, weight: .bold))
        Spacer()
        Button("새로고침") {
          loadDebugInfo()
        }
        .font(.system(size: 12))
      }

      ForEach(Array(debugInfo.keys.sorted()), id: \.self) { key in
        HStack(alignment: .top) {
          Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
          Spacer()
          Text(debugInfo[key] ?? "-")
            .font(.system(size: 11, design: .monospaced))
            .multilineTextAlignment(.trailing)
        }
      }

      if debugInfo.isEmpty {
        Text("버튼을 누른 후 새로고침하세요")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }
    .padding(12)
    .background(Color.yellow.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
    )
    .onAppear {
      loadDebugInfo()
    }
  }

  private func loadDebugInfo() {
    var info: [String: String] = [:]

    // Last Intent
    if let intentData = defaults?.dictionary(forKey: "liveActivity.debug.lastIntent") {
      if let count = intentData["activitiesCount"] as? Int {
        info["activitiesCount"] = "\(count)"
      }
      if let promiseId = intentData["promiseId"] as? String {
        info["promiseId"] = String(promiseId.prefix(8)) + "..."
      }
      if let oderId = intentData["participantId"] as? String {
        info["participantId"] = String(oderId.prefix(8)) + "..."
      }
      if let eta = intentData["estimatedArrivalMinutes"] as? Int {
        let etaText = eta == -1 ? "대기" : (eta == 0 ? "도착" : "\(eta)분")
        info["ETA"] = etaText
      }
      if let timestamp = intentData["timestamp"] as? Double {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        info["timestamp"] = formatter.string(from: date)
      }
    }

    // Error
    if let error = defaults?.string(forKey: "liveActivity.debug.error") {
      info["❌ error"] = error
    }

    // Participant IDs
    if let ids = defaults?.array(forKey: "liveActivity.debug.participantIds") as? [String] {
      info["participantIds"] = ids.map { String($0.prefix(6)) }.joined(separator: ", ")
    }

    // Result
    if let result = defaults?.string(forKey: "liveActivity.debug.result") {
      info["✅ result"] = result
    }

    debugInfo = info
  }
}

// MARK: - Live Activity Mock Section

import ActivityKit

/// 라이브액티비티 테스트용 목 섹션
private struct LiveActivityMockSection: View {
  @State private var activityId: String?
  @State private var currentState: PromiseActivityAttributes.ContentState?
  @State private var isActive = false
  @State private var statusMessage = ""

  // 목 참가자 ID (updateParticipant와 일치해야 함)
  private static let mockUserId1 = "KrALQyaaUScWRFCUTpWN2XDHnpm1"
  private static let mockUserId2 = "kWJYVOGRMWX65UyQOcznRti3lMR2"
  private static let mockUserId3 = "user-3"
  private static let mockUserId4 = "user-4"

  private let mockParticipants = [
    ParticipantState(id: mockUserId1, name: "일이삼사오육칠", estimatedArrivalMinutes: nil),
    ParticipantState(id: mockUserId2, name: "가나다라마바사", estimatedArrivalMinutes: nil),
    ParticipantState(id: mockUserId3, name: "지현", estimatedArrivalMinutes: nil),
    ParticipantState(id: mockUserId4, name: "서연", estimatedArrivalMinutes: nil)
  ]

  var body: some View {
    VStack(spacing: 12) {
      SectionHeader(title: "🧪 라이브액티비티 테스트")

      // 상태 표시
      if !statusMessage.isEmpty {
        Text(statusMessage)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.gray.opacity(0.1))
          .clipShape(Capsule())
      }

      if isActive {
        // 활성 상태: 업데이트 버튼들
        VStack(spacing: 12) {
          // MARK: - 개별 참가자 ETA 설정
          Text("개별 ETA 설정")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)

          VStack(spacing: 6) {
            participantETARow(name: "나", id: Self.mockUserId1)
            participantETARow(name: "민수", id: Self.mockUserId2)
            participantETARow(name: "지현", id: Self.mockUserId3)
            participantETARow(name: "서연", id: Self.mockUserId4)
          }

          Divider().padding(.vertical, 4)

          // MARK: - 시나리오 테스트
          Text("시나리오 테스트")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)

          LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
          ], spacing: 8) {
            MockStatusButton(title: "모두 대기", color: .gray) {
              updateAllParticipants(estimatedArrivalMinutes: nil)
            }
            MockStatusButton(title: "모두 출발(15분)", color: .indigo) {
              updateAllParticipants(estimatedArrivalMinutes: 15)
            }
            MockStatusButton(title: "모두 도착", color: .green) {
              updateAllParticipants(estimatedArrivalMinutes: 0)
            }
            MockStatusButton(title: "그룹화 테스트", color: .orange) {
              // 같은 ETA로 그룹화 테스트
              updateParticipant(id: Self.mockUserId1, estimatedArrivalMinutes: 10)
              updateParticipant(id: Self.mockUserId2, estimatedArrivalMinutes: 10)
              updateParticipant(id: Self.mockUserId3, estimatedArrivalMinutes: 5)
              updateParticipant(id: Self.mockUserId4, estimatedArrivalMinutes: nil)
            }
            MockStatusButton(title: "순차 도착", color: .blue) {
              // 1초 간격 순차 도착 시뮬레이션
              sequentialArrival()
            }
            MockStatusButton(title: "혼합 상태", color: .purple) {
              updateParticipant(id: Self.mockUserId1, estimatedArrivalMinutes: 0)
              updateParticipant(id: Self.mockUserId2, estimatedArrivalMinutes: 5)
              updateParticipant(id: Self.mockUserId3, estimatedArrivalMinutes: 15)
              updateParticipant(id: Self.mockUserId4, estimatedArrivalMinutes: nil)
            }
          }

          Divider().padding(.vertical, 4)

          // 종료 버튼
          Button {
            endActivity()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "stop.circle.fill")
              Text("라이브액티비티 종료")
            }
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }
        }
      } else {
        // 비활성 상태: 시작 버튼
        Button {
          startActivity()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "play.circle.fill")
            Text("목 라이브액티비티 시작")
          }
          .font(.system(size: 16, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.purple)
          .foregroundStyle(.white)
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        Text("30분 후 약속, 4명 참가자 목 데이터로 시작")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }

      // 디버그 정보
      LiveActivityDebugView()
    }
    .padding(16)
    .background(Color.purple.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.purple.opacity(0.2), lineWidth: 1)
    )
    .onAppear {
      checkExistingActivity()
    }
  }

  // MARK: - Actions

  private func startActivity() {
    // 디버그: 캐시된 프로필 이미지 파일 목록 출력
    let cachedFiles = LiveActivityImageStore.listCachedFiles()
    AppLogger.liveActivity.debug("캐시된 파일: \(cachedFiles)")

    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      statusMessage = "라이브액티비티가 비활성화됨"
      return
    }

    let attributes = PromiseActivityAttributes(
      promiseId: "mock-\(UUID().uuidString.prefix(8))",
      currentUserId: "KrALQyaaUScWRFCUTpWN2XDHnpm1",  // 캐시된 유저 ID
      emoji: "🍜",
      title: "점심 모임",
      location: "강남역 11번 출구",
      scheduledTime: Date().addingTimeInterval(1800) // 30분 후
    )

    let initialState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 30,
      participants: mockParticipants
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: initialState, staleDate: nil),
        pushType: nil
      )
      activityId = activity.id
      currentState = initialState
      isActive = true
      statusMessage = "시작됨: \(activity.id.prefix(8))..."
    } catch {
      statusMessage = "시작 실패: \(error.localizedDescription)"
    }
  }

  private func updateParticipant(id: String, estimatedArrivalMinutes: Int?) {
    guard let activityId = activityId,
          let state = currentState else { return }

    let updatedState = state.updating(participantId: id, estimatedArrivalMinutes: estimatedArrivalMinutes)
    updateActivity(with: updatedState)
    let etaText = estimatedArrivalMinutes.map { $0 == 0 ? "도착" : "\($0)분" } ?? "대기"
    statusMessage = "\(id) → \(etaText)"
  }

  private func updateAllParticipants(estimatedArrivalMinutes: Int?) {
    guard let activityId = activityId,
          let state = currentState else { return }

    var participants = state.participants
    for i in participants.indices {
      participants[i] = participants[i].with(estimatedArrivalMinutes: estimatedArrivalMinutes)
    }
    let updatedState = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: state.trackingDurationMinutes,
      participants: participants
    )
    updateActivity(with: updatedState)
    let etaText = estimatedArrivalMinutes.map { $0 == 0 ? "도착" : "\($0)분" } ?? "대기"
    statusMessage = "모두 → \(etaText)"
  }

  /// 개별 참가자 ETA 설정 행
  @ViewBuilder
  private func participantETARow(name: String, id: String) -> some View {
    HStack(spacing: 6) {
      Text(name)
        .font(.system(size: 12, weight: .medium))
        .frame(width: 36, alignment: .leading)

      ForEach(etaOptions, id: \.value) { option in
        Button {
          updateParticipant(id: id, estimatedArrivalMinutes: option.value)
        } label: {
          Text(option.label)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(option.color.opacity(0.15))
            .foregroundStyle(option.color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
      }
    }
  }

  /// ETA 옵션 목록
  private var etaOptions: [(label: String, value: Int?, color: Color)] {
    [
      ("대기", nil, .gray),
      ("30분", 30, .orange),
      ("15분", 15, .yellow),
      ("10분", 10, .blue),
      ("5분", 5, .indigo),
      ("도착", 0, .green)
    ]
  }

  /// 순차 도착 시뮬레이션 (1초 간격)
  private func sequentialArrival() {
    let userIds = [Self.mockUserId1, Self.mockUserId2, Self.mockUserId3, Self.mockUserId4]
    let etaSequence: [Int?] = [15, 10, 5, 0]  // 출발 → 도착 순서

    Task {
      for (index, userId) in userIds.enumerated() {
        try? await Task.sleep(for: .seconds(1.5))
        await MainActor.run {
          updateParticipantImmediate(id: userId, estimatedArrivalMinutes: etaSequence[index])
        }
      }
    }
  }

  /// 즉시 업데이트 (딜레이 없이)
  private func updateParticipantImmediate(id: String, estimatedArrivalMinutes: Int?) {
    guard let activityId = activityId,
          let state = currentState else { return }

    let updatedState = state.updating(participantId: id, estimatedArrivalMinutes: estimatedArrivalMinutes)

    Task {
      if let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.id == activityId }) {
        await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        await MainActor.run {
          currentState = updatedState
          let etaText = estimatedArrivalMinutes.map { $0 == 0 ? "도착" : "\($0)분" } ?? "대기"
          statusMessage = "\(id.prefix(8)) → \(etaText)"
        }
      }
    }
  }

  private func updateActivity(with state: PromiseActivityAttributes.ContentState) {
    guard let activityId = activityId else { return }

    Task {
      // 1초 딜레이 후 업데이트 (애니메이션 테스트용)
      try? await Task.sleep(for: .seconds(1))

      if let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.id == activityId }) {
        await activity.update(ActivityContent(state: state, staleDate: nil))
        await MainActor.run {
          currentState = state
        }
      }
    }
  }

  private func endActivity() {
    guard let activityId = activityId else { return }

    Task {
      if let activity = Activity<PromiseActivityAttributes>.activities
        .first(where: { $0.id == activityId }) {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      await MainActor.run {
        self.activityId = nil
        self.currentState = nil
        self.isActive = false
        self.statusMessage = "종료됨"
      }
    }
  }

  private func checkExistingActivity() {
    if let activity = Activity<PromiseActivityAttributes>.activities.first {
      activityId = activity.id
      currentState = activity.content.state
      isActive = true
      statusMessage = "기존 활동: \(activity.id.prefix(8))..."
    }
  }
}

/// 목 상태 변경 버튼
private struct MockStatusButton: View {
  let title: String
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .foregroundStyle(color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }
}
#endif


