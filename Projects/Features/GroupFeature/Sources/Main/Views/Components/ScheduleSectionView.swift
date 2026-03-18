import Clients
import PromisoShared
import SwiftUI

// MARK: - ScheduleSectionView

/// 일정 섹션 뷰 (응답 필요 / 확정 일정 등)
struct ScheduleSectionView: View {
  let title: String
  let icon: String
  let schedules: [ScheduleModel]
  let maxDisplay: Int
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let respondingStates: [String: GroupMain.RespondingState]

  // 콜백
  let onScheduleTap: (ScheduleModel) -> Void
  let onMoreTap: (() -> Void)?
  let onAccept: ((ScheduleModel) -> Void)?
  let onReject: ((ScheduleModel) -> Void)?
  let onChangeResponse: ((ScheduleModel, ScheduleAttendanceStatus) -> Void)?
  let onEdit: ((ScheduleModel) -> Void)?
  let onDelete: ((ScheduleModel) -> Void)?
  let onShare: ((ScheduleModel) -> Void)?

  init(
    title: String,
    icon: String,
    schedules: [ScheduleModel],
    maxDisplay: Int = 3,
    currentUserId: String,
    groupMembers: [UserPublicModel]? = nil,
    respondingStates: [String: GroupMain.RespondingState] = [:],
    onScheduleTap: @escaping (ScheduleModel) -> Void,
    onMoreTap: (() -> Void)? = nil,
    onAccept: ((ScheduleModel) -> Void)? = nil,
    onReject: ((ScheduleModel) -> Void)? = nil,
    onChangeResponse: ((ScheduleModel, ScheduleAttendanceStatus) -> Void)? = nil,
    onEdit: ((ScheduleModel) -> Void)? = nil,
    onDelete: ((ScheduleModel) -> Void)? = nil,
    onShare: ((ScheduleModel) -> Void)? = nil
  ) {
    self.title = title
    self.icon = icon
    self.schedules = schedules
    self.maxDisplay = maxDisplay
    self.currentUserId = currentUserId
    self.groupMembers = groupMembers
    self.respondingStates = respondingStates
    self.onScheduleTap = onScheduleTap
    self.onMoreTap = onMoreTap
    self.onAccept = onAccept
    self.onReject = onReject
    self.onChangeResponse = onChangeResponse
    self.onEdit = onEdit
    self.onDelete = onDelete
    self.onShare = onShare
  }

  private var displaySchedules: [ScheduleModel] {
    Array(schedules.prefix(maxDisplay))
  }

  private var remainingCount: Int {
    max(0, schedules.count - maxDisplay)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 일정 카드들
      VStack(spacing: 12) {
        ForEach(displaySchedules) { schedule in
          ScheduleCard(
            schedule: schedule,
            currentUserId: currentUserId,
            groupMembers: groupMembers,
            respondingState: respondingStates[schedule.id] ?? .idle,
            onTap: { onScheduleTap(schedule) },
            onAccept: { onAccept?(schedule) },
            onReject: { onReject?(schedule) },
            onEdit: onEdit != nil ? { onEdit?(schedule) } : nil,
            onDelete: onDelete != nil ? { onDelete?(schedule) } : nil,
            onChangeResponse: onChangeResponse != nil ? { status in
              onChangeResponse?(schedule, status)
            } : nil,
            onShare: onShare != nil ? { onShare?(schedule) } : nil,
            onDirections: nil
          )
          .onTapGesture {
            onScheduleTap(schedule)
          }
        }
      }
      .padding(.horizontal, 16)

      // 더보기 버튼
      if remainingCount > 0, let onMore = onMoreTap {
        moreButton(count: remainingCount, action: onMore)
      }
    }
    .padding(.vertical, 16)
  }

  // MARK: - Subviews

  private var sectionHeader: some View {
    HStack {
      Label(title, systemImage: icon)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.primary)

      Spacer()

      Text("\(schedules.count)")
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.pmgray.n100)
        .clipShape(Capsule())
    }
    .padding(.horizontal, 16)
  }

  private func moreButton(count: Int, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Text(LocalizedStrings.GroupComponents.seeMoreCount(count))
          .font(.system(size: 14, weight: .medium))
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
    }
    .buttonStyle(.scale)
    .padding(.horizontal, 16)
    .padding(.top, 4)
  }
}

// MARK: - Preview

#Preview("ScheduleSectionView - 응답 필요") {
  ScrollView {
    ScheduleSectionView(
      title: "응답 필요",
      icon: "envelope.badge",
      schedules: ScheduleModel.needResponseExamples(),
      maxDisplay: 2,
      currentUserId: ScheduleModel.previewCurrentUserId,
      onScheduleTap: { _ in },
      onMoreTap: { },
      onAccept: { _ in },
      onReject: { _ in }
    )
  }
  .background(Color(.systemGroupedBackground))
}

#Preview("ScheduleSectionView - 확정 일정") {
  ScrollView {
    ScheduleSectionView(
      title: "다가오는 확정 일정",
      icon: "checkmark.circle",
      schedules: ScheduleModel.confirmedExamples,
      maxDisplay: 2,
      currentUserId: ScheduleModel.previewCurrentUserId,
      onScheduleTap: { _ in },
      onMoreTap: nil
    )
  }
  .background(Color(.systemGroupedBackground))
}
