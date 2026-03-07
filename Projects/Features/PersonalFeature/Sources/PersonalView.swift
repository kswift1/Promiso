import Clients
import ComposableArchitecture
import CreatePromiseFeature
import PromisoShared
import SharedFeature
import SwiftUI

extension PersonalMode {
  public struct RootView: View {
    @Bindable private var store: StoreOf<PersonalMode.Feature>

    public init(store: StoreOf<PersonalMode.Feature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        // 헤더
        headerSection
          .padding(.horizontal, 16)
          .padding(.top, 8)

        // 필터
        filterSegment
          .padding(.top, 12)

        // 컨텐츠
        contentView
      }
      .auroraBackground()
      .toolbarVisibility(.hidden, for: .navigationBar)
      .overlay(alignment: .bottomTrailing) {
        fabButton
      }
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
      .onAppear {
        store.send(.view(.onAppear))
      }
      .sheet(
        item: $store.scope(state: \.createEvent, action: \.createEvent)
      ) { createEventStore in
        CreatePersonalEvent.RootView(store: createEventStore)
          .presentationDetents([.large, .medium])
          .presentationDragIndicator(.visible)
      }
      .navigationDestination(
        item: $store.scope(state: \.eventDetail, action: \.eventDetail)
      ) { detailStore in
        PersonalEventDetail.RootView(store: detailStore)
      }
    }

    // MARK: - Header

    private var defaultMode: PromiseMode {
      let saved = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.defaultPromiseTabMode) ?? "group"
      return saved == "own" ? .personal : .group
    }

    @ViewBuilder
    private var headerSection: some View {
      PromiseTabHeader(
        selectedMode: .personal,
        defaultMode: defaultMode
      ) { mode in
        if mode == .group {
          store.send(.view(.switchToGroupMode))
        }
      }
    }

    // MARK: - Filter

    @ViewBuilder
    private var filterSegment: some View {
      CategoryFilterBar(
        selection: Binding(
          get: { store.selectedFilter },
          set: { newFilter in
            withAnimation(.snappy) {
              _ = store.send(.view(.filterChanged(newFilter)))
            }
          }
        ),
        counts: store.filterCounts
      )
    }

    // MARK: - Content

    private var isLoading: Bool {
      if store.selectedFilter == .past {
        return !store.pastEventsState.isLoaded && !store.pastEventsState.isFailed
      }
      return !store.eventsState.isLoaded && !store.eventsState.isFailed
    }

    private var currentError: Error? {
      if store.selectedFilter == .past {
        return store.pastEventsState.error
      }
      return store.eventsState.error
    }

    @ViewBuilder
    private var contentView: some View {
      Group {
        if isLoading {
          loadingView
        } else if let error = currentError {
          errorView(error: error)
        } else if store.filteredEvents.isEmpty {
          emptyView
        } else {
          eventListView
        }
      }
      .animation(.snappy, value: store.selectedFilter)
    }

    @ViewBuilder
    private var loadingView: some View {
      ScrollView {
        LazyVStack(spacing: 12) {
          ForEach(0..<3, id: \.self) { _ in
            PersonalEventCardSkeleton()
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
      }
    }

    @ViewBuilder
    private var emptyView: some View {
      ScrollView {
        VStack(spacing: 16) {
          Spacer()
            .frame(height: 120)

          Text(emptyFilterEmoji)
            .font(.system(size: 60))

          Text(emptyFilterDescription)
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)

          Spacer()
        }
        .frame(maxWidth: .infinity)
      }
      .refreshable {
        store.send(.view(.refreshEvents))
      }
    }

    private var emptyFilterEmoji: String {
      switch store.selectedFilter {
      case .today: return "☀️"
      case .future: return "🗓️"
      case .all: return "📭"
      case .past: return "🕐"
      }
    }

    private var emptyFilterDescription: String {
      switch store.selectedFilter {
      case .today:
        return LocalizedStrings.Personal.emptyToday
      case .future:
        return LocalizedStrings.Personal.emptyFuture
      case .all:
        return LocalizedStrings.Personal.emptyAll
      case .past:
        return LocalizedStrings.Personal.emptyPast
      }
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      ScrollView {
        VStack(spacing: 16) {
          Spacer()
            .frame(height: 120)

          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 50))
            .foregroundStyle(.secondary)

          Text(LocalizedStrings.Error.unknownError)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

          Button("다시 시도") {
            store.send(.view(.refreshEvents))
          }
          .buttonStyle(.bordered)

          Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
      }
      .refreshable {
        store.send(.view(.refreshEvents))
      }
    }

    @ViewBuilder
    private var eventListView: some View {
      List {
        ForEach(store.groupedEvents, id: \.day) { section in
          Section {
            ForEach(section.events) { event in
              PersonalEventCard(
                event: event,
                weather: store.weatherByEventId[event.id],
                conflicts: (store.conflictsByEventId[event.id] ?? []).map { conflict in
                  ConflictInfo(
                    title: conflict.title,
                    overlapMinutes: conflict.overlapMinutes,
                    gapMinutes: conflict.gapMinutes,
                    startAt: conflict.startAt,
                    endAt: conflict.endAt,
                    emoji: conflict.emoji,
                    severity: conflict.severity == .confirmed ? .confirmed : .pending
                  )
                },
                isCheckingConflicts: store.conflictCheckingIds.contains(event.id),
                onTap: {
                  store.send(.view(.eventTapped(event)))
                },
                onEdit: {
                  store.send(.view(.editEvent(event)))
                },
                onDelete: {
                  store.send(.view(.deleteEvent(event)))
                }
              )
              .id(event.id)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                  store.send(.view(.deleteEvent(event)))
                } label: {
                  Label("삭제", systemImage: "trash")
                }
                .tint(.red)

                Button {
                  store.send(.view(.editEvent(event)))
                } label: {
                  Label("수정", systemImage: "pencil")
                }
              }
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
              .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
          } header: {
            dateSectionHeader(section.title)
          }
          .listSectionSeparator(.hidden)
        }

        // FAB 공간 확보
        Color.clear
          .frame(height: 80)
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .refreshable {
        store.send(.view(.refreshEvents))
      }
      .animation(.snappy, value: store.eventListAnimationKey)
    }

    @ViewBuilder
    private func dateSectionHeader(_ date: String) -> some View {
      HStack(spacing: 12) {
        Text(date)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.primary)

        Rectangle()
          .fill(Color.primary.opacity(0.1))
          .frame(height: 1)
      }
      .padding(.vertical, 8)
    }

    // MARK: - FAB

    @ViewBuilder
    private var fabButton: some View {
      Button {
        store.send(.view(.createNewEventTapped))
      } label: {
        ZStack {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 56, height: 56)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)

          Image(systemName: "plus")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .padding(.trailing, 16)
      .padding(.bottom, 16)
    }
  }
}

// MARK: - Skeleton View

private struct PersonalEventCardSkeleton: View {
  @State private var isAnimating = false

  var body: some View {
    HStack(spacing: 12) {
      // 시간 컬럼 스켈레톤
      VStack(spacing: 6) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(UIColor.systemGray5))
          .frame(width: 40, height: 16)

        Circle()
          .fill(Color(UIColor.systemGray5))
          .frame(width: 7, height: 7)
      }
      .frame(width: 50)

      // 콘텐츠 스켈레톤
      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(UIColor.systemGray5))
          .frame(height: 18)
          .frame(maxWidth: 180)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color(UIColor.systemGray5))
          .frame(height: 14)
          .frame(maxWidth: 140)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color(UIColor.systemGray5))
          .frame(height: 14)
          .frame(maxWidth: 100)
      }

      Spacer()
    }
    .padding(14)
    .adaptiveGlassCard(cornerRadius: 14)
    .opacity(isAnimating ? 0.5 : 1.0)
    .onAppear {
      withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
        isAnimating = true
      }
    }
  }
}

// MARK: - Preview

#Preview {
  PersonalMode.RootView(
    store: Store(
      initialState: PersonalMode.Feature.State(
        currentUser: Shared(value: .exampleUser)
      )
    ) {
      PersonalMode.Feature()
    }
  )
}
