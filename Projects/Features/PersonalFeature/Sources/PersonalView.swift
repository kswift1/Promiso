import SwiftUI
import ComposableArchitecture

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

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 4) {
        HStack {
          Text("개인 일정")
            .font(.system(size: 28, weight: .bold))

          Spacer()
        }

        HStack {
          Text("그룹 모드로 전환하려면 탭을 다시 눌러주세요")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

          Spacer()
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

    @ViewBuilder
    private var contentView: some View {
      Group {
        switch store.eventsState {
        case .idle, .loading:
          loadingView

        case .loaded:
          if store.filteredEvents.isEmpty {
            emptyView
          } else {
            eventListView
          }

        case .failed(let error):
          errorView(error: error)
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
      case .upcoming: return "🗓️"
      case .today: return "☀️"
      case .all: return "📭"
      case .past: return "🕐"
      }
    }

    private var emptyFilterDescription: String {
      switch store.selectedFilter {
      case .upcoming:
        return "예정된 일정이 없어요\n+ 버튼으로 새 일정을 만들어보세요"
      case .today:
        return "오늘 일정이 없어요\n여유로운 하루를 보내세요 ☕️"
      case .all:
        return "아직 일정이 없어요\n+ 버튼으로 새 일정을 만들어보세요"
      case .past:
        return "아직 지난 일정이 없어요\n완료된 일정 기록이 여기에 쌓여요"
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

          Text(error.localizedDescription)
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
        ForEach(store.groupedEvents, id: \.date) { section in
          Section {
            ForEach(section.events) { event in
              PersonalEventCard(
                event: event,
                onTap: {
                  store.send(.view(.eventTapped(event)))
                },
                onDelete: {
                  store.send(.view(.deleteEvent(event)))
                }
              )
              .id(event.id)
              .listRowSeparator(.hidden)
              .listRowBackground(Color.clear)
              .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
          } header: {
            dateSectionHeader(section.date)
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
