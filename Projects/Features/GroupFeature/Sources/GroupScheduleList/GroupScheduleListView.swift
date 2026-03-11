import ComposableArchitecture
import Clients
import PromisoShared
import SwiftUI

extension GroupScheduleList {
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

          // 일정 목록
          if store.filteredSchedules.isEmpty {
            emptyStateView
          } else {
            scheduleList
          }
        }
        .padding(.vertical, 16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle(LocalizedStrings.GroupScheduleList.navigationTitle(store.group.name))
      .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var filterButtons: some SwiftUI.View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(StatusFilter.allCases, id: \.self) { filter in
            FilterButton(
              title: filter.displayTitle,
              isSelected: store.selectedFilter == filter,
              action: { store.send(.view(.filterChanged(filter))) }
            )
          }
        }
        .padding(.horizontal, 16)
      }
    }

    private var scheduleList: some SwiftUI.View {
      LazyVStack(spacing: 12) {
        ForEach(store.filteredSchedules) { schedule in
          ScheduleCard(
            schedule: schedule,
            currentUserId: store.currentUserId,
            groupMembers: store.groupMembers,
            respondingState: store.respondingStates[schedule.id] ?? .idle,
            weather: store.weatherByScheduleId[schedule.id],
            onTap: { store.send(.view(.scheduleTapped(schedule))) },
            onAccept: { store.send(.view(.acceptTapped(schedule))) },
            onReject: { store.send(.view(.rejectTapped(schedule))) },
            onEdit: nil,
            onDelete: nil,
            onChangeResponse: nil,
            onShare: nil,
            onDirections: nil
          )
          .onTapGesture {
            store.send(.view(.scheduleTapped(schedule)))
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
        return LocalizedStrings.GroupScheduleList.emptyNeedResponse
      case .responded:
        return LocalizedStrings.GroupScheduleList.emptyResponded
      case .confirmed:
        return LocalizedStrings.GroupScheduleList.emptyConfirmed
      case .all:
        return LocalizedStrings.GroupScheduleList.emptyAll
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
    GroupScheduleList.View(
      store: Store(
        initialState: GroupScheduleList.Feature.State(
          group: GroupModel(
            id: "g1",
            name: "지민과 나",
            maxMembers: 10,
            inviteCode: "ABC123",
            createdBy: "user1"
          ),
          schedules: ScheduleModel.examples,
          currentUserId: ScheduleModel.previewCurrentUserId,
          groupMembers: nil,
          initialFilter: .all
        )
      ) {
        GroupScheduleList.Feature()
      }
    )
  }
}
