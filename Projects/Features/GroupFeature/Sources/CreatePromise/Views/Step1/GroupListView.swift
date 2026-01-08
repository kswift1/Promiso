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
              colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 96, height: 96)

        Image(systemName: "person.2.slash")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      Text("아직 가입한 그룹이 없어요")
        .font(.headline)
        .foregroundColor(.primary)

      Text("새로운 그룹을 만들어 친구들을 초대해보세요")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        onCreateGroup()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 18))
          Text("새 그룹 만들기")
            .font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
          LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
          color: .blue.opacity(0.3),
          radius: 10,
          x: 0,
          y: 5
        )
      }
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
              colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 96, height: 96)

        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(
            LinearGradient(
              colors: [.orange, .red],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      Text("그룹을 불러오지 못했어요")
        .font(.headline)
        .foregroundColor(.primary)

      Text(error.localizedDescription)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button {
        onRetry()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 18))
          Text("다시 시도")
            .font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
          LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
          color: .blue.opacity(0.3),
          radius: 10,
          x: 0,
          y: 5
        )
      }
    }
    .padding(.vertical, 32)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Group Card
struct GroupCard: View {
  let model: GroupModel
  let isSelected: Bool
  let activePromiseCount: Int?
  let maxActivePromises: Int
  let action: () -> Void

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
    model.memberIds.count <= 1
  }

  private var isDisabled: Bool {
    hasTooFewMembers || isAtLimit
  }

  private var disabledReason: String? {
    if hasTooFewMembers {
      return "약속을 만들려면 최소 2명 이상의 멤버가 필요합니다"
    } else if isAtLimit {
      return "활성 약속이 \(maxActivePromises)개에 도달했습니다"
    }
    return nil
  }

  var body: some View {
    Button(action: {
      if !isDisabled {
        action()
      }
    }) {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          // 그룹 아이콘
          Image(systemName: "person.2.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(.blue.opacity(0.6))
            .frame(width: 48, height: 48)
            .opacity(isDisabled ? 0.5 : 1.0)

          // 그룹 정보
          VStack(alignment: .leading, spacing: 4) {
            Text(model.name)
              .font(.system(size: 17, weight: .semibold))
              .foregroundColor(isDisabled ? .secondary : .primary)

            Text("\(model.memberIds.count)명")
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }

          Spacer()

          // 선택 표시 또는 경고 아이콘
          if isDisabled {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 16))
              .foregroundColor(.orange)
          } else {
            Image(systemName: "chevron.right")
              .font(.system(size: 13))
              .foregroundColor(isSelected ? .blue : Color(.systemGray4))
          }
        }
        .padding(16)

        // 비활성화 사유 메시지
        if let reason = disabledReason {
          HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
              .font(.system(size: 12))
              .foregroundColor(.orange)

            Text(reason)
              .font(.system(size: 12))
              .foregroundColor(.secondary)

            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 12)
          .background(Color.orange.opacity(0.05))
        }
      }
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(
            isDisabled
            ? Color(.systemGray6).opacity(0.5)
            : (isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            isDisabled
            ? Color(.systemGray4)
            : (isSelected ? Color.blue : Color.clear),
            lineWidth: isDisabled ? 1 : 2
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
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
