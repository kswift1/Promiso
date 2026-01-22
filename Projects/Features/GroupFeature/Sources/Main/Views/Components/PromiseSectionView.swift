import Clients
import PromisoShared
import SwiftUI

// MARK: - PromiseSectionView

/// 약속 섹션 뷰 (응답 필요 / 확정 약속 등)
struct PromiseSectionView: View {
  let title: String
  let icon: String
  let promises: [PromiseModel]
  let maxDisplay: Int
  let currentUserId: String
  let groupMembers: [UserPublicModel]?
  let respondingStates: [String: GroupMain.RespondingState]

  // 콜백
  let onPromiseTap: (PromiseModel) -> Void
  let onMoreTap: (() -> Void)?
  let onAccept: ((PromiseModel) -> Void)?
  let onReject: ((PromiseModel) -> Void)?
  let onChangeResponse: ((PromiseModel, PromiseAttendanceStatus) -> Void)?
  let onEdit: ((PromiseModel) -> Void)?
  let onDelete: ((PromiseModel) -> Void)?
  let onShare: ((PromiseModel) -> Void)?

  init(
    title: String,
    icon: String,
    promises: [PromiseModel],
    maxDisplay: Int = 3,
    currentUserId: String,
    groupMembers: [UserPublicModel]? = nil,
    respondingStates: [String: GroupMain.RespondingState] = [:],
    onPromiseTap: @escaping (PromiseModel) -> Void,
    onMoreTap: (() -> Void)? = nil,
    onAccept: ((PromiseModel) -> Void)? = nil,
    onReject: ((PromiseModel) -> Void)? = nil,
    onChangeResponse: ((PromiseModel, PromiseAttendanceStatus) -> Void)? = nil,
    onEdit: ((PromiseModel) -> Void)? = nil,
    onDelete: ((PromiseModel) -> Void)? = nil,
    onShare: ((PromiseModel) -> Void)? = nil
  ) {
    self.title = title
    self.icon = icon
    self.promises = promises
    self.maxDisplay = maxDisplay
    self.currentUserId = currentUserId
    self.groupMembers = groupMembers
    self.respondingStates = respondingStates
    self.onPromiseTap = onPromiseTap
    self.onMoreTap = onMoreTap
    self.onAccept = onAccept
    self.onReject = onReject
    self.onChangeResponse = onChangeResponse
    self.onEdit = onEdit
    self.onDelete = onDelete
    self.onShare = onShare
  }

  private var displayPromises: [PromiseModel] {
    Array(promises.prefix(maxDisplay))
  }

  private var remainingCount: Int {
    max(0, promises.count - maxDisplay)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 약속 카드들
      VStack(spacing: 12) {
        ForEach(displayPromises) { promise in
          PromiseCard(
            promise: promise,
            currentUserId: currentUserId,
            groupMembers: groupMembers,
            respondingState: respondingStates[promise.id] ?? .idle,
            onTap: { onPromiseTap(promise) },
            onAccept: { onAccept?(promise) },
            onReject: { onReject?(promise) },
            onEdit: onEdit != nil ? { onEdit?(promise) } : nil,
            onDelete: onDelete != nil ? { onDelete?(promise) } : nil,
            onChangeResponse: onChangeResponse != nil ? { status in
              onChangeResponse?(promise, status)
            } : nil,
            onShare: onShare != nil ? { onShare?(promise) } : nil
          )
          .onTapGesture {
            onPromiseTap(promise)
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

      Text("\(promises.count)")
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
        Text("\(count)개 더 보기")
          .font(.system(size: 14, weight: .medium))
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
    }
    .padding(.horizontal, 16)
    .padding(.top, 4)
  }
}

// MARK: - Preview

#Preview("PromiseSectionView - 응답 필요") {
  ScrollView {
    PromiseSectionView(
      title: "응답 필요",
      icon: "envelope.badge",
      promises: PromiseModel.needResponseExamples(),
      maxDisplay: 2,
      currentUserId: PromiseModel.previewCurrentUserId,
      onPromiseTap: { _ in },
      onMoreTap: { print("More tapped") },
      onAccept: { _ in print("Accept") },
      onReject: { _ in print("Reject") }
    )
  }
  .background(Color(.systemGroupedBackground))
}

#Preview("PromiseSectionView - 확정 약속") {
  ScrollView {
    PromiseSectionView(
      title: "다가오는 확정 약속",
      icon: "checkmark.circle",
      promises: PromiseModel.confirmedExamples,
      maxDisplay: 2,
      currentUserId: PromiseModel.previewCurrentUserId,
      onPromiseTap: { _ in },
      onMoreTap: nil
    )
  }
  .background(Color(.systemGroupedBackground))
}
