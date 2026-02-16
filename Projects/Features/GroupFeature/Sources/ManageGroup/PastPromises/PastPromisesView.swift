import Clients
import SwiftUI
import ComposableArchitecture
import PromisoShared
import ResourceKit

extension PastPromises {
  public struct RootView: View {
    @Bindable private var store: StoreOf<PastPromises.Feature>

    public init(store: StoreOf<PastPromises.Feature>) {
      self.store = store
    }

    private var groupedPromises: [(date: String, promises: [PromiseModel])] {
      guard store.sortOption != .participants else {
        return [(LocalizedStrings.Common.all, store.filteredPromises)]
      }

      var result: [(date: String, promises: [PromiseModel])] = []

      for promise in store.filteredPromises {
        let dateKey = formatDateHeader(promise.startAt)
        if let lastIndex = result.indices.last, result[lastIndex].date == dateKey {
          result[lastIndex].promises.append(promise)
        } else {
          result.append((date: dateKey, promises: [promise]))
        }
      }

      return result
    }

    public var body: some View {
      Group {
        switch store.promisesState {
        case .idle, .loading:
          loadingView

        case .loaded(let promises):
          if promises.isEmpty {
            emptyView
          } else if store.filteredPromises.isEmpty {
            emptyFilteredView
          } else {
            promiseListView
          }

        case .failed:
          errorView
        }
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.PastPromises.title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear { store.send(.view(.onAppear)) }
      .refreshable { store.send(.view(.refreshTriggered)) }
      .searchable(
        text: Binding(
          get: { store.searchQuery },
          set: { store.send(.view(.searchQueryChanged($0))) }
        ),
        placement: .navigationBarDrawer(displayMode: .always),
        prompt: LocalizedStrings.PastPromises.searchPlaceholder
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

        Text(LocalizedStrings.PastPromises.emptyTitle)
          .font(.headline)
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastPromises.emptySubtitle)
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

        Text(LocalizedStrings.PastPromises.emptyFilteredTitle)
          .font(.headline)
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.PastPromises.emptyFilteredSubtitle)
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

        Text(LocalizedStrings.PastPromises.loadFailed)
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

    // MARK: - Promise List View

    @ViewBuilder
    private var promiseListView: some View {
      List {
        filterControlsRow

        if store.sortOption == .participants {
          ForEach(store.filteredPromises) { promise in
            promiseRow(promise)
          }
        } else {
          ForEach(groupedPromises, id: \.date) { section in
            Section {
              ForEach(section.promises) { promise in
                promiseRow(promise)
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
      .animation(.easeInOut(duration: 0.25), value: store.filteredPromises.map(\.id))
      .animation(.easeInOut(duration: 0.25), value: store.sortOption)
      .animation(.easeInOut(duration: 0.25), value: store.statusFilter)
    }

    private func promiseRow(_ promise: PromiseModel) -> some View {
      PromiseCard(
        promise: promise,
        currentUserId: store.currentUserId,
        groupMembers: store.groupMembers,
        respondingState: .idle,
        onTap: { store.send(.view(.promiseTapped(promise))) },
        onAccept: {},
        onReject: {},
        statusOverride: promise.isConfirmed ? .confirmed : .failed,
        showsResponseDetails: false
      )
      .contentShape(Rectangle())
      .onTapGesture {
        store.send(.view(.promiseTapped(promise)))
      }
      .transition(.opacity)
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
      .onAppear {
        // 마지막 아이템이 나타나면 더 불러오기
        if promise.id == store.filteredPromises.last?.id {
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
          ForEach(PastPromises.Feature.SortOption.allCases, id: \.self) { option in
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
            Text(store.sortOption.rawValue)
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

    private func filterChip(_ filter: PastPromises.Feature.StatusFilter) -> some View {
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
      .padding(.top, date == groupedPromises.first?.date ? 12 : 24)
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
