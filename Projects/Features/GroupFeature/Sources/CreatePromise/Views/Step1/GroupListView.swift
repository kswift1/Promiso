import Clients
import Nuke
import PromisoShared
import ResourceKit
import SwiftUI

/// 그룹 리스트 뷰
struct GroupListView: View {
  let groupListState: LoadingState<[GroupModel]>
  let selectedGroupId: String?
  let groupPromiseCounts: [String: Int]
  let maxActivePromises: Int
  let onGroupSelected: (GroupModel) -> Void
  let onRetry: () -> Void
  let onCreateGroup: () -> Void
  @FocusState.Binding var isFocused: Bool
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // LoadingState에 따른 UI
      switch groupListState {
      case .idle:
        EmptyView()
        
      case .loading:
        loadingView
        
      case .loaded(let groups):
        if groups.isEmpty {
          emptyStateView
        } else {
          groupsListView(groups: groups)
        }
        
      case .failed(let error):
        errorView(error: error)
      }
    }
  }
  
  // MARK: - Loading View
  
  private var loadingView: some View {
    VStack(spacing: 12) {
      ForEach(0..<3, id: \.self) { _ in
        GroupSkeletonCard()
      }
    }
  }
  
  // MARK: - Groups List View
  
  private func groupsListView(groups: [GroupModel]) -> some View {
    VStack(spacing: 12) {
      ForEach(groups) { group in
        GroupCard(
          model: group,
          isSelected: selectedGroupId == group.id,
          activePromiseCount: groupPromiseCounts[group.id],
          maxActivePromises: maxActivePromises
        ) {
          isFocused = false
          onGroupSelected(group)
        }
      }
    }
  }
  
  // MARK: - Empty State View
  
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.pmindigo.n100, Color.pmpurple.n100],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 96, height: 96)

        Image(systemName: "person.2.slash")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      Text(LocalizedStrings.CreatePromise.noGroupsTitle)
        .font(.headline)
        .foregroundColor(.primary)

      Text(LocalizedStrings.CreatePromise.noGroupsSubtitle)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      CreateGroupButton(action: onCreateGroup)
    }
    .padding(.vertical, 32)
    .frame(maxWidth: .infinity)
  }

  // MARK: - Error View

  private func errorView(error: Error) -> some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.pmwarning.n100, Color.pmerror.n100],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 96, height: 96)

        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmwarning.n500, Color.pmerror.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      Text(LocalizedStrings.CreatePromise.loadGroupsFailed)
        .font(.headline)
        .foregroundColor(.primary)

      Text((error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      RetryButton(action: onRetry)
    }
    .padding(.vertical, 32)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Interactive Buttons

private struct CreateGroupButton: View {
  let action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 18))
        Text(LocalizedStrings.CreatePromise.createNewGroup)
          .font(.headline)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(
        LinearGradient(
          colors: [Color.pmindigo.n500, Color.pmpurple.n500],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .shadow(
        color: Color.pmindigo.n500.opacity(AppConstants.UI.selectionOpacity),
        radius: 10,
        x: 0,
        y: 5
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

private struct RetryButton: View {
  let action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      HStack(spacing: 8) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 18))
        Text(LocalizedStrings.CreatePromise.retryButton)
          .font(.headline)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 50)
      .background(
        LinearGradient(
          colors: [Color.pmindigo.n500, Color.pmpurple.n500],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .shadow(
        color: Color.pmindigo.n500.opacity(AppConstants.UI.selectionOpacity),
        radius: 10,
        x: 0,
        y: 5
      )
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Group Card
struct GroupCard: View {
  let model: GroupModel
  let isSelected: Bool
  let activePromiseCount: Int?
  let maxActivePromises: Int
  let action: () -> Void
  @State private var loadedImage: UIImage?

  init(
    model: GroupModel,
    isSelected: Bool,
    activePromiseCount: Int? = nil,
    maxActivePromises: Int = 10,
    action: @escaping () -> Void
  ) {
    self.model = model
    self.isSelected = isSelected
    self.activePromiseCount = activePromiseCount
    self.maxActivePromises = maxActivePromises
    self.action = action
  }

  private var isAtLimit: Bool {
    guard let count = activePromiseCount else { return false }
    return count >= maxActivePromises
  }

  private var hasTooFewMembers: Bool {
    model.memberIds.isEmpty
  }

  private var isDisabled: Bool {
    hasTooFewMembers || isAtLimit
  }

  private var disabledReason: String? {
    if hasTooFewMembers {
      return LocalizedStrings.CreatePromise.noMembersInGroup
    } else if isAtLimit {
      return LocalizedStrings.CreatePromise.activePromisesAtLimit(maxActivePromises)
    }
    return nil
  }

  @ViewBuilder
  private var groupImageView: some View {
    Group {
      if let loadedImage {
        Image(uiImage: loadedImage)
          .resizable()
          .scaledToFill()
      } else {
        defaultGroupIcon
      }
    }
    .frame(width: 48, height: 48)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .task(id: model.imageUrl) {
      await loadImage()
    }
  }

  private var defaultGroupIcon: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.pmindigo.n100)
      Image(systemName: "person.2.fill")
        .font(.system(size: 20))
        .foregroundStyle(Color.pmindigo.n400)
    }
    .frame(width: 48, height: 48)
  }

  private func loadImage() async {
    guard let urlString = model.imageUrl,
          let url = URL(string: urlString) else {
      loadedImage = nil
      return
    }
    do {
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }

  var body: some View {
    Button(action: {
      if !isDisabled {
        action()
      }
    }) {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          // 그룹 이미지
          groupImageView
            .opacity(isDisabled ? 0.5 : 1.0)

          // 그룹 정보
          VStack(alignment: .leading, spacing: 4) {
            Text(model.name)
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(isDisabled ? .secondary : .primary)

            Text(LocalizedStrings.CreatePromise.memberCount(model.memberIds.count))
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }

          Spacer()

          // 선택 표시 또는 경고 아이콘
          if isDisabled {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 16))
              .foregroundColor(Color.pmwarning.n500)
          } else {
            Image(systemName: "chevron.right")
              .font(.system(size: 13))
              .foregroundColor(isSelected ? Color.pmindigo.n500 : Color(.systemGray4))
          }
        }
        .padding(16)

        // 비활성화 사유 메시지
        if let reason = disabledReason {
          HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
              .font(.system(size: 12))
              .foregroundColor(Color.pmwarning.n600)

            Text(reason)
              .font(.system(size: 12))
              .foregroundColor(.secondary)

            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 12)
          .background(Color.pmwarning.n50)
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(
            isDisabled
            ? Color(.systemGray6).opacity(0.5)
            : (isSelected ? Color.pmindigo.n50 : Color(.systemGray6))
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isDisabled
            ? Color(.systemGray4)
            : (isSelected ? Color.pmindigo.n500 : Color.clear),
            lineWidth: isDisabled ? 1 : 2
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
    .sensoryFeedback(.selection, trigger: isSelected)
    .disabled(isDisabled)
  }
}

// MARK: - Skeleton Card

private struct GroupSkeletonCard: View {
  var body: some View {
    HStack(spacing: 12) {
      // 이모지 스켈레톤
      SkeletonView(cornerRadius: 12)
        .frame(width: 56, height: 56)
      
      // 텍스트 스켈레톤
      VStack(alignment: .leading, spacing: 8) {
        SkeletonView()
          .frame(width: 120, height: 16)
        
        SkeletonView()
          .frame(width: 60, height: 14)
      }
      
      Spacer()
      
      // 체크박스 스켈레톤
      SkeletonView(cornerRadius: 12)
        .frame(width: 24, height: 24)
    }
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
  }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
  }
}

// MARK: - Preview

#Preview("Loading") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .loading,
    selectedGroupId: nil,
    groupPromiseCounts: [:],
    maxActivePromises: 10,
    onGroupSelected: { _ in },
    onRetry: {},
    onCreateGroup: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Loaded") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .loaded([
      .init(id: "g1", name: "지민과 나", maxMembers: 2, inviteCode: "ABC123", createdBy: "preview"),
      .init(id: "g2", name: "회사 동료들", maxMembers: 10, inviteCode: "DEF456", createdBy: "preview"),
      .init(id: "g3", name: "대학 친구들", maxMembers: 10, inviteCode: "GHI789", createdBy: "preview"),
      .init(id: "g4", name: "가족", maxMembers: 5, inviteCode: "JKL012", createdBy: "preview")
    ]),
    selectedGroupId: "g2",
    groupPromiseCounts: ["g2": 5, "g3": 10], // g3 is at limit
    maxActivePromises: 10,
    onGroupSelected: { group in print("Selected: \(group.name)") },
    onRetry: {},
    onCreateGroup: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Empty") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .loaded([]),
    selectedGroupId: nil,
    groupPromiseCounts: [:],
    maxActivePromises: 10,
    onGroupSelected: { _ in },
    onRetry: {},
    onCreateGroup: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Error") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .failed(GroupClientError.networkError),
    selectedGroupId: nil,
    groupPromiseCounts: [:],
    maxActivePromises: 10,
    onGroupSelected: { _ in },
    onRetry: { print("Retry tapped") },
    onCreateGroup: {},
    isFocused: $focus
  )
  .padding()
}
