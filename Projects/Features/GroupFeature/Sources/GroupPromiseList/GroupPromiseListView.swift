import ComposableArchitecture
import Clients
import PromisoShared
import SwiftUI

extension GroupPromiseList {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      ScrollView {
        VStack(spacing: 16) {
          // 필터 버튼
          filterButtons

          // 약속 목록
          if store.filteredPromises.isEmpty {
            emptyStateView
          } else {
            promiseList
          }
        }
        .padding(.vertical, 16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("\(store.group.name) 약속")
      .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var filterButtons: some SwiftUI.View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(StatusFilter.allCases, id: \.self) { filter in
            FilterButton(
              title: filter.rawValue,
              isSelected: store.selectedFilter == filter,
              action: { store.send(.view(.filterChanged(filter))) }
            )
          }
        }
        .padding(.horizontal, 16)
      }
    }

    private var promiseList: some SwiftUI.View {
      LazyVStack(spacing: 12) {
        ForEach(store.filteredPromises) { promise in
          PromiseCard(
            promise: promise,
            currentUserId: store.currentUserId,
            groupMembers: store.groupMembers,
            respondingState: store.respondingStates[promise.id] ?? .idle,
            weather: store.weatherCache[promise.id],
            onTap: { store.send(.view(.promiseTapped(promise))) },
            onAccept: { store.send(.view(.acceptTapped(promise))) },
            onReject: { store.send(.view(.rejectTapped(promise))) },
            onEdit: nil,
            onDelete: nil,
            onChangeResponse: nil,
            onShare: nil,
            onDirections: nil
          )
          .onTapGesture {
            store.send(.view(.promiseTapped(promise)))
          }
        }
      }
      .padding(.horizontal, 16)
    }

    private var emptyStateView: some SwiftUI.View {
      VStack(spacing: 12) {
        Image(systemName: "calendar.badge.exclamationmark")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text(emptyStateMessage)
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
    }

    private var emptyStateMessage: String {
      switch store.selectedFilter {
      case .needResponse:
        return "응답이 필요한 약속이 없어요"
      case .responded:
        return "응답 완료된 약속이 없어요"
      case .confirmed:
        return "확정된 약속이 없어요"
      case .all:
        return "아직 약속이 없어요"
      }
    }
  }
}

// MARK: - FilterButton

private struct FilterButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          isSelected
            ? Color.pmindigo.n500
            : Color(.systemBackground)
        )
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(isSelected ? Color.clear : Color.pmgray.n200, lineWidth: 1)
        )
    }
    .buttonStyle(.scale)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    GroupPromiseList.View(
      store: Store(
        initialState: GroupPromiseList.Feature.State(
          group: GroupModel(
            id: "g1",
            name: "지민과 나",
            maxMembers: 10,
            inviteCode: "ABC123",
            createdBy: "user1"
          ),
          promises: PromiseModel.examples,
          currentUserId: PromiseModel.previewCurrentUserId,
          groupMembers: nil,
          initialFilter: .all
        )
      ) {
        GroupPromiseList.Feature()
      }
    )
  }
}
