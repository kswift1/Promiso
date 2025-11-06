/// 그룹 리스트 뷰
struct GroupListView: View {
  let groupListState: LoadingState<[GroupModel]>
  let selectedGroupId: String?
  let onGroupSelected: (GroupModel) -> Void
  let onRetry: () -> Void
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
          isSelected: selectedGroupId == group.id
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
      Image(systemName: "person.2.slash")
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      
      Text("아직 가입한 그룹이 없어요")
        .font(.headline)
        .foregroundColor(.primary)
      
      Text("새로운 그룹을 만들어 친구들을 초대해보세요")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      
      Button {
        // TODO: 그룹 생성 화면으로 이동
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
          Text("새 그룹 만들기")
            .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(12)
      }
    }
    .padding(.vertical, 32)
    .frame(maxWidth: .infinity)
  }
  
  // MARK: - Error View
  
  private func errorView(error: Error) -> some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundColor(.orange)
      
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
        HStack {
          Image(systemName: "arrow.clockwise")
          Text("다시 시도")
            .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(12)
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
  let action: () -> Void
  
  init(model: GroupModel, isSelected: Bool, action: @escaping () -> Void) {
    self.model = model
    self.isSelected = isSelected
    self.action = action
  }
  
  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        // 그룹 이모지
        Text(model.emoji)
          .font(.system(size: 28))
          .frame(width: 48, height: 48)
          .clipShape(Circle())
        
        // 그룹 정보
        VStack(alignment: .leading, spacing: 4) {
          Text(model.title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.primary)
          
          Text("\(model.memberCount)명")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        // 선택 표시
        Image(systemName: "chevron.right")
          .font(.system(size: 13))
          .foregroundColor(isSelected ? .blue : Color(.systemGray4))
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(isSelected ? Color.blue.opacity(0.05) : Color(.systemGray6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
      )
    }
    .buttonStyle(PlainButtonStyle())
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
    onGroupSelected: { _ in },
    onRetry: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Loaded") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .loaded([
      .init(id: "g1", emoji: "👥", title: "지민과 나", memberCount: 2),
      .init(id: "g2", emoji: "🏢", title: "회사 동료들", memberCount: 8),
      .init(id: "g3", emoji: "🎓", title: "대학 친구들", memberCount: 12),
      .init(id: "g4", emoji: "👨‍👩‍👦", title: "가족", memberCount: 4)
    ]),
    selectedGroupId: "g2",
    onGroupSelected: { group in print("Selected: \(group.title)") },
    onRetry: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Empty") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .loaded([]),
    selectedGroupId: nil,
    onGroupSelected: { _ in },
    onRetry: {},
    isFocused: $focus
  )
  .padding()
}

#Preview("Error") {
  @Previewable @FocusState var focus: Bool
  GroupListView(
    groupListState: .failed(GroupClientError.networkError),
    selectedGroupId: nil,
    onGroupSelected: { _ in },
    onRetry: { print("Retry tapped") },
    isFocused: $focus
  )
  .padding()
}
