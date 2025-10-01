//
//  GroupListView.swift
//  PromiseFeature
//
//  그룹 리스트 뷰 (LoadingState 기반)
//

import SwiftUI
import ComposableArchitecture
import Domain
import Shared

/// 그룹 리스트 뷰
struct GroupListView: View {
  let store: StoreOf<CreatePromise.Feature>

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // LoadingState에 따른 UI
      switch store.groupListState {
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
          isSelected: store.promiseProposal.groupID == group.id
        ) {
          store.send(.groupSelected(group.id))
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
        store.send(.retryLoadGroups)
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
          
          Text("\(model.membersCount)명")
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
  struct PreviewWrapper: View {
    var body: some View {
      let store = Store(initialState: CreatePromise.Feature.State()) {
        CreatePromise.Feature()
      } withDependencies: {
        $0.groupClient.fetchGroups = {
          try await Task.sleep(for: .seconds(100))
          return []
        }
      }

      GroupListView(store: store)
        .padding()
        .onAppear {
          store.send(._fetchGroupList)
        }
    }
  }

  return PreviewWrapper()
}

#Preview("Loaded") {
  struct PreviewWrapper: View {
    var body: some View {
      let store = Store(initialState: CreatePromise.Feature.State()) {
        CreatePromise.Feature()
      } withDependencies: {
        $0.groupClient.fetchGroups = {
          [
            GroupModel(id: "1", emoji: "👞", title: "구두", membersCount: 3),
            GroupModel(id: "2", emoji: "🥐", title: "빵", membersCount: 5),
          ]
        }
      }

      GroupListView(store: store)
        .padding()
        .onAppear {
          store.send(._fetchGroupList)
        }
    }
  }

  return PreviewWrapper()
}

#Preview("Empty") {
  struct PreviewWrapper: View {
    var body: some View {
      let store = Store(initialState: CreatePromise.Feature.State()) {
        CreatePromise.Feature()
      } withDependencies: {
        $0.groupClient.fetchGroups = { [] }
      }

      GroupListView(store: store)
        .padding()
        .onAppear {
          store.send(._fetchGroupList)
        }
    }
  }

  return PreviewWrapper()
}

#Preview("Error") {
  struct PreviewWrapper: View {
    var body: some View {
      let store = Store(initialState: CreatePromise.Feature.State()) {
        CreatePromise.Feature()
      } withDependencies: {
        $0.groupClient.fetchGroups = {
          throw GroupClientError.networkError
        }
      }

      GroupListView(store: store)
        .padding()
        .onAppear {
          store.send(._fetchGroupList)
        }
    }
  }

  return PreviewWrapper()
}
