import Clients
import SwiftUI
import ComposableArchitecture
import PromisoShared
import ResourceKit

extension PastSchedules {
  public struct RootView: View {
    @Bindable private var store: StoreOf<PastSchedules.Feature>

    public init(store: StoreOf<PastSchedules.Feature>) {
      self.store = store
    }

    private var groupedSchedules: [(date: String, schedules: [ScheduleModel])] {
      guard store.sortOption != .participants else {
        return [(LocalizedStrings.Common.all, store.filteredSchedules)]
      }

      var result: [(date: String, schedules: [ScheduleModel])] = []

      for schedule in store.filteredSchedules {
        let dateKey = formatDateHeader(schedule.startAt)
        if let lastIndex = result.indices.last, result[lastIndex].date == dateKey {
          result[lastIndex].schedules.append(schedule)
        } else {
          result.append((date: dateKey, schedules: [schedule]))
        }
      }

      return result
    }

    public var body: some View {
      Group {
        switch store.schedulesState {
        case .idle, .loading:
          loadingView

        case .loaded(let schedules):
          if schedules.isEmpty {
            emptyView
          } else if store.filteredSchedules.isEmpty {
            emptyFilteredView
          } else {
            scheduleListView
          }

        case .failed:
          errorView
        }
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.PastSchedules.title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { store.send(.view(.onAppear)) }
      .refreshable { store.send(.view(.refreshTriggered)) }
      .searchable(
        text: Binding(
          get: { store.searchQuery },
          set: { store.send(.view(.searchQueryChanged($0))) }
        ),
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: LocalizedStrings.PastSchedules.searchPlaceholder
      )
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      VStack {
        Spacer()
        ProgressView()
          .scaleEffect(1.2)
        Spacer()
      }
    }

    // MARK: - Empty View

    @ViewBuilder
    private var emptyView: some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "calendar.badge.clock")
          .font(.system(size: 64))
          .foregroundStyle(
            LinearGradient(
              colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        Text(LocalizedStrings.PastSchedules.emptyTitle)
          .font(.headline)
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastSchedules.emptySubtitle)
          .font(.subheadline)
          .foregroundStyle(.tertiary)

        Spacer()
      }
      .padding()
    }

    @ViewBuilder
    private var emptyFilteredView: some View {
      VStack(spacing: 12) {
        filterControlsContent
          .padding(12)
          .adaptiveGlassCard(cornerRadius: 14)
          .padding(.horizontal, 16)
          .padding(.top, 12)

        Spacer()

        Image(systemName: "magnifyingglass")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastSchedules.emptyFilteredTitle)
          .font(.headline)
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastSchedules.emptyFilteredSubtitle)
          .font(.subheadline)
          .foregroundStyle(.tertiary)

        Spacer()
      }
    }

    // MARK: - Error View

    @ViewBuilder
    private var errorView: some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 48))
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastSchedules.loadFailed)
          .font(.headline)
          .foregroundStyle(.secondary)

        Button(action: { store.send(.view(.refreshTriggered)) }) {
          Text(LocalizedStrings.Common.retry)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(Capsule())
        }

        Spacer()
      }
      .padding()
    }

    // MARK: - Schedule List View

    @ViewBuilder
    private var scheduleListView: some View {
      List {
        filterControlsRow

        if store.sortOption == .participants {
          ForEach(store.filteredSchedules) { schedule in
            scheduleRow(schedule)
          }
        } else {
          ForEach(groupedSchedules, id: \.date) { section in
            Section {
              ForEach(section.schedules) { schedule in
                scheduleRow(schedule)
              }
            } header: {
              sectionHeader(for: section.date)
            }
            .listSectionSeparator(.hidden)
          }
        }

        // 로딩 인디케이터
        if store.isLoadingMore {
          HStack {
            Spacer()
            ProgressView()
              .padding(.vertical, 16)
            Spacer()
          }
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .animation(.easeInOut(duration: 0.25), value: store.filteredSchedules.map(\.id))
      .animation(.easeInOut(duration: 0.25), value: store.sortOption)
      .animation(.easeInOut(duration: 0.25), value: store.statusFilter)
    }

    private func scheduleRow(_ schedule: ScheduleModel) -> some View {
      ScheduleCard(
        schedule: schedule,
        currentUserId: store.currentUserId,
        groupMembers: store.groupMembers,
        respondingState: .idle,
        onTap: { store.send(.view(.scheduleTapped(schedule))) },
        onAccept: {},
        onReject: {},
        statusOverride: schedule.isConfirmed ? .confirmed : .failed,
        showsResponseDetails: false
      )
      .contentShape(Rectangle())
      .onTapGesture {
        store.send(.view(.scheduleTapped(schedule)))
      }
      .transition(.opacity)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
      .onAppear {
        // 마지막 아이템이 나타나면 더 불러오기
        if schedule.id == store.filteredSchedules.last?.id {
          store.send(.view(.loadMoreTriggered))
        }
      }
    }

    private var filterControlsRow: some View {
      filterControlsContent
        .padding(12)
        .adaptiveGlassCard(cornerRadius: 14)
      .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
    }

    private var filterControlsContent: some View {
      HStack(spacing: 10) {
        filterChip(.all)
        filterChip(.confirmed)
        filterChip(.failed)

        Spacer()

        Menu {
          ForEach(PastSchedules.Feature.SortOption.allCases, id: \.self) { option in
            Button {
              store.send(.view(.sortOptionChanged(option)))
            } label: {
              if store.sortOption == option {
                Label(option.displayTitle, systemImage: "checkmark")
              } else {
                Text(option.displayTitle)
              }
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
              .font(.system(size: 13, weight: .semibold))
            Text(store.sortOption.displayTitle)
              .font(.system(size: 13, weight: .semibold))
          }
          .foregroundStyle(Color.pmindigo.n500)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.pmindigo.n500.opacity(0.12))
          .clipShape(Capsule())
        }
      }
    }

    private func filterChip(_ filter: PastSchedules.Feature.StatusFilter) -> some View {
      let isSelected = store.statusFilter == filter

      return Button {
        store.send(.view(.statusFilterChanged(filter)))
      } label: {
        Text(filter.displayTitle)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : .secondary)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            isSelected ? Color.pmindigo.n500.opacity(0.12) : Color.clear
          )
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(for date: String) -> some View {
      HStack {
        Text(date)
          .font(.system(size: 20, weight: .bold))
          .foregroundColor(.primary)
          .textCase(nil)

        Rectangle()
          .fill(Color(.systemGray4))
          .frame(height: 1)
      }
      .padding(.horizontal, 16)
      .padding(.top, date == groupedSchedules.first?.date ? 12 : 24)
      .padding(.bottom, 12)
    }

    // MARK: - Helpers

    private func formatDateHeader(_ date: Date) -> String {
      let currentYear = Calendar.current.component(.year, from: Date())
      let dateYear = Calendar.current.component(.year, from: date)

      if dateYear == currentYear {
        return LocalizedDateFormatters.monthDay.string(from: date)
      } else {
        return LocalizedDateFormatters.yearMonthDay.string(from: date)
      }
    }
  }
}
