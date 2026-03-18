import SwiftUI
import Clients
import PromisoShared

// MARK: - Swipe Action Config

private struct SwipeActionConfig {
  let title: String
  let systemImage: String
  let color: Color
  let action: () -> Void
}

struct ScheduleTimelineView: View {
  let schedulesState: LoadingState<[ScheduleModel]>
  let selectedFilter: StatusFilter
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let respondingStates: [String: GroupMain.RespondingState]
  let onTap: (ScheduleModel) -> Void
  let onAccept: (String) -> Void
  let onReject: (String) -> Void
  let onEdit: ((ScheduleModel) -> Void)?
  let onDelete: ((String) -> Void)?
  let onChangeResponse: ((String, ScheduleAttendanceStatus) -> Void)?
  let onShare: ((String) -> Void)?

  private var schedules: [ScheduleModel] {
    schedulesState.value ?? []
  }

  private var filteredSchedules: [ScheduleModel] {
    let totalMembers = groupMembers?.count
    // 과거 일정 제외 (isPast: endAt 또는 startAt 기준)
    let activeSchedules = schedules.filter { !$0.isPast }

    switch selectedFilter {
    case .all:
      return activeSchedules
    case .needResponse:
      return activeSchedules.filter {
        $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: totalMembers) == .needResponse
      }
    case .responded:
      return activeSchedules.filter {
        let status = $0.responseStatus(currentUserId: currentUserId, totalGroupMembers: totalMembers)
        return status == .responded || status == .confirmed
      }
    case .confirmed:
      return activeSchedules.filter { $0.isConfirmed }
    }
  }

  private var groupedSchedules: [(day: Date, title: String, schedules: [ScheduleModel])] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: filteredSchedules) { schedule in
      calendar.startOfDay(for: schedule.startAt)
    }

    return grouped
      .sorted { $0.key < $1.key }
      .map { day, schedules in
        let title: String
        if calendar.isDateInToday(day) {
          title = LocalizedStrings.DateFormat.today
        } else if calendar.isDateInTomorrow(day) {
          title = LocalizedStrings.DateFormat.tomorrow
        } else {
          title = LocalizedDateFormatters.monthDayString(from: day)
        }
        return (day: day, title: title, schedules: schedules.sorted { $0.startAt < $1.startAt })
      }
  }

  var body: some View {
    switch schedulesState {
    case .idle, .loading:
      loadingView

    case .loaded:
      let sections = groupedSchedules
      if sections.isEmpty {
        emptyStateScrollView
      } else {
        schedulesListView(sections: sections)
      }

    case .failed(let error):
      errorStateScrollView(error: error)
    }
  }

  private var emptyStateScrollView: some View {
    ScrollView {
      EmptySchedulesView(filter: selectedFilter)
        .padding(.top, 60)
    }
  }

  private func errorStateScrollView(error: Error) -> some View {
    ScrollView {
      ErrorView(message: (error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)
        .padding(.top, 60)
    }
  }

  private var loadingView: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        ForEach(0..<3, id: \.self) { _ in
          ScheduleCardSkeleton()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 20)
      .padding(.bottom, 40)
    }
  }

  private func schedulesListView(sections: [(day: Date, title: String, schedules: [ScheduleModel])]) -> some View {
    let animationKey = sections.flatMap { section in
      [String(Int(section.day.timeIntervalSince1970))] + section.schedules.map(\.id)
    }

    return List {
      ForEach(sections, id: \.day) { section in
        Section {
          ForEach(section.schedules) { schedule in
            ScheduleRow(
              schedule: schedule,
              currentUserId: currentUserId,
              groupMembers: groupMembers,
              respondingState: respondingStates[schedule.id] ?? .idle,
              onTap: { onTap(schedule) },
              onAccept: onAccept,
              onReject: onReject,
              onEdit: onEdit.map { edit in { edit(schedule) } },
              onDelete: onDelete,
              onChangeResponse: onChangeResponse,
              onShare: onShare
            )
          }
        } header: {
          sectionHeader(for: section.title, isFirst: section.day == sections.first?.day)
        }
        .listSectionSeparator(.hidden)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: animationKey)
  }

  @ViewBuilder
  private func sectionHeader(for title: String, isFirst: Bool) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.primary)
        .textCase(nil)

      Rectangle()
        .fill(Color(.systemGray4))
        .frame(height: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, isFirst ? 12 : 24)
    .padding(.bottom, 12)
  }
}

private struct ScheduleRow: View {
  let schedule: ScheduleModel
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let respondingState: GroupMain.RespondingState
  let onTap: () -> Void
  let onAccept: (String) -> Void
  let onReject: (String) -> Void
  let onEdit: (() -> Void)?
  let onDelete: ((String) -> Void)?
  let onChangeResponse: ((String, ScheduleAttendanceStatus) -> Void)?
  let onShare: ((String) -> Void)?

  @State private var shakeOffset: CGFloat = 0

  private var myVoteStatus: VoteStatus {
    schedule.myVoteStatus(userId: currentUserId)
  }

  // Leading swipe action (왼쪽 → 오른쪽)
  private var leadingAction: SwipeActionConfig {
    switch myVoteStatus {
    case .accepted:
      // 이미 수락한 경우 → 되돌리기
      return SwipeActionConfig(
        title: LocalizedStrings.GroupMain.undo,
        systemImage: "arrow.uturn.backward.circle.fill",
        color: .blue,
        action: { onChangeResponse?(schedule.id, .pending) }
      )
    case .declined, .pending:
      // 거절했거나 미응답 → 수락
      return SwipeActionConfig(
        title: LocalizedStrings.GroupMain.accept,
        systemImage: "checkmark.circle.fill",
        color: .green,
        action: { onAccept(schedule.id) }
      )
    }
  }

  // Trailing swipe action (오른쪽 → 왼쪽)
  private var trailingAction: SwipeActionConfig {
    switch myVoteStatus {
    case .declined:
      // 이미 거절한 경우 → 되돌리기
      return SwipeActionConfig(
        title: LocalizedStrings.GroupMain.undo,
        systemImage: "arrow.uturn.backward.circle.fill",
        color: .blue,
        action: { onChangeResponse?(schedule.id, .pending) }
      )
    case .accepted, .pending:
      // 수락했거나 미응답 → 거절
      return SwipeActionConfig(
        title: LocalizedStrings.GroupMain.reject,
        systemImage: "xmark.circle.fill",
        color: .red,
        action: { onReject(schedule.id) }
      )
    }
  }

  var body: some View {
    ZStack {
      // 배경 힌트 레이어 - 리스트 행 전체 영역
      swipeHintBackground

      // 실제 카드
      ScheduleCard(
        schedule: schedule,
        currentUserId: currentUserId,
        groupMembers: groupMembers,
        respondingState: respondingState,
        onTap: onTap,
        onAccept: { onAccept(schedule.id) },
        onReject: { onReject(schedule.id) },
        onEdit: onEdit,
        onDelete: onDelete.map { delete in { delete(schedule.id) } },
        onChangeResponse: onChangeResponse.map { change in { status in change(schedule.id, status) } },
        onShare: onShare.map { share in { share(schedule.id) } },
        onDirections: nil
      )
      .contentShape(Rectangle())
      .onTapGesture(perform: onTap)
      .offset(x: shakeOffset)
    }
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    .swipeActions(edge: .leading, allowsFullSwipe: !schedule.isRealtimeShareable) {
      if !schedule.isRealtimeShareable {
        Button(action: leadingAction.action) {
          Label(leadingAction.title, systemImage: leadingAction.systemImage)
        }
        .tint(leadingAction.color)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: !schedule.isRealtimeShareable) {
      if !schedule.isRealtimeShareable {
        Button(action: trailingAction.action) {
          Label(trailingAction.title, systemImage: trailingAction.systemImage)
        }
        .tint(trailingAction.color)
      }
    }
    .transition(
      .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .opacity
      )
    )
  }

  @ViewBuilder
  private var swipeHintBackground: some View {
    ZStack {
      // Leading
      HStack {
        let progress = clamp((shakeOffset - 8) / 40)
        swipeHintBubble(
          title: leadingAction.title,
          systemImage: leadingAction.systemImage,
          fillColor: leadingAction.color,
          progress: progress
        )
        .opacity(progress)
        .scaleEffect(0.3 + progress * 0.7)
        .offset(x: -4)

        Spacer()
      }
      .padding(.leading, 0)

      // Trailing
      HStack {
        Spacer()

        let progress = clamp((abs(shakeOffset) - 8) / 40)
        swipeHintBubble(
          title: trailingAction.title,
          systemImage: trailingAction.systemImage,
          fillColor: trailingAction.color,
          progress: progress
        )
        .opacity(progress)
        .scaleEffect(0.3 + progress * 0.7)
        .offset(x: 4)
      }
      .padding(.trailing, 0)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 100)
  }

  private func swipeHintBubble(
    title: String,
    systemImage: String,
    fillColor: Color,
    progress: CGFloat
  ) -> some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(fillColor)
          .frame(width: 48, height: 48)

        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .bold))
          .tint(.white)
          .foregroundStyle(.white)
      }

      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  private func clamp(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
  }
}

private struct ErrorView: View {
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 60))
        .foregroundColor(.orange)

      Text(LocalizedStrings.GroupComponents.errorOccurred)
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.primary)

      Text(message)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 32)
  }
}

private struct EmptySchedulesView: View {
  let filter: StatusFilter

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: iconName)
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text(message)
        .font(.system(size: 16))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var iconName: String {
    switch filter {
    case .all:
      return "calendar.badge.clock"
    case .needResponse:
      return "exclamationmark.bubble"
    case .responded:
      return "checkmark.circle"
    case .confirmed:
      return "checkmark.seal"
    }
  }

  private var message: String {
    switch filter {
    case .all:
      return LocalizedStrings.GroupComponents.emptyAll
    case .needResponse:
      return LocalizedStrings.GroupComponents.emptyNeedResponse
    case .responded:
      return LocalizedStrings.GroupComponents.emptyResponded
    case .confirmed:
      return LocalizedStrings.GroupComponents.emptyConfirmed
    }
  }
}
