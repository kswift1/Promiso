import SwiftUI
import ComposableArchitecture
import PromisoShared

extension GroupMain {
  public struct RootView: View {
    @Bindable private var store: StoreOf<GroupMain.Feature>

    public init(store: StoreOf<GroupMain.Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStackStore(
        store.scope(state: \.path, action: \.path)) {
          rootContent
        } destination: { store in
          switch store.case {
          case .manageGroupFeature(let manageGroupStore):
            ManageGroup.RootView(store: manageGroupStore)
          case .groupSettings(let groupSettingsStore):
            GroupSettings.View(store: groupSettingsStore)
          case .groupPromiseList(let groupPromiseListStore):
            GroupPromiseList.View(store: groupPromiseListStore)
          case .promiseDetail(let promiseDetailStore):
            PromiseDetail.RootView(store: promiseDetailStore)
          case .pastPromises(let pastPromisesStore):
            PastPromises.RootView(store: pastPromisesStore)
          case .pastPromiseDetail(let pastPromiseDetailStore):
            PastPromiseDetail.RootView(store: pastPromiseDetailStore)
          }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
      Group {
        if store.shouldShowEmptyGroupView {
          groupDetailEmptyView
        } else {
          groupDetailView
        }
      }
      .auroraBackground()
      .toolbarVisibility(.hidden, for: .navigationBar)
      .onAppear { store.send(.view(.onAppear)) }
      .fullScreenCover(
        store: store.scope(state: \.$createPromise, action: \.createPromise)
      ) { childStore in
        CreatePromise.RootView(store: childStore)
      }
      .fullScreenCover(
        store: store.scope(state: \.$createGroup, action: \.createGroup)
      ) { childStore in
        NavigationStack {
          CreateGroup.RootView(store: childStore)
        }
      }
      .fullScreenCover(
        store: store.scope(state: \.$joinGroup, action: \.joinGroup)
      ) { childStore in
        NavigationStack {
          JoinGroup.RootView(store: childStore)
        }
      }
      .sheet(item: Binding(
        get: { store.sharePromise },
        set: { _ in store.send(.view(.sharePromiseDismissed)) }
      )) { promise in
        ShareSheet(items: [promise.shareText])
      }
      .sheet(
        store: store.scope(state: \.$editPromise, action: \.editPromise)
      ) { editStore in
        EditPromise.RootView(store: editStore)
      }
      .sheet(
        isPresented: Binding(
          get: { store.sortSettings != nil },
          set: { if !$0 { store.send(.sortSettingsDismissed) } }
        )
      ) {
        if let sortSettingsState = store.sortSettings {
          SortSettingsSheetContent(
            initialState: sortSettingsState,
            onOptionChanged: { option in
              store.send(.sortOptionChanged(option))
            },
            onDismiss: {
              store.send(.sortSettingsDismissed)
            }
          )
          .presentationDetents([.height(420)])
          .presentationDragIndicator(.visible)
        }
      }
      .alert(store: store.scope(state: \.$deleteAlert, action: \.deleteAlert))
      .confirmationDialog(
        store: store.scope(state: \.$groupActionSheet, action: \.groupActionSheet)
      )
    }


    // MARK: - New Group Detail View (섹션 기반)

    @ViewBuilder
    private var groupDetailView: some View {
      VStack(spacing: 0) {
        // 그룹 가로 바 (상단 고정)
        GroupHorizontalBar(
          groups: store.groupBarItems,
          onGroupTap: { groupId in
            store.send(.view(.groupTapped(groupId)))
          },
          onCreateGroup: {
            store.send(.view(.createGroup))
          },
          onJoinGroup: {
            store.send(.view(.joinGroup))
          },
          onSortSettings: {
            store.send(.view(.sortSettingsTapped))
          }
        )

        Divider()

        // 필터 세그먼트
        filterSegment
          .padding(.top, 8)

        // 약속 리스트 (스와이프 지원)
        if store.isOnboardingMode {
          ScrollView {
            onboardingCardsView
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else if isLoadingState {
          // .idle 또는 .loading 상태
          ScrollView {
            loadingView
          }
        } else if let error = currentError {
          ScrollView {
            errorView(error: error)
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else if store.filteredPromises.isEmpty {
          ScrollView {
            emptyFilteredView
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else {
          promiseListView
        }
      }
      .overlay {
        morphingFABMenu
      }
    }

    // MARK: - Morphing FAB Menu

    private var morphingFABMenu: some View {
      MorphingFABMenu(
        items: [
          FABMenuItem(
            title: "약속 생성",
            icon: "calendar.badge.plus",
            tintColor: .pmindigo.n500
          ) {
            store.send(.view(.createNewPromise))
          },
          FABMenuItem(
            title: "그룹 설정",
            icon: "gearshape",
            tintColor: .pmindigo.n500
          ) {
            store.send(.view(.groupSettingsTapped))
          }
        ],
        bottomPadding: fabBottomPadding
      )
    }

    private var fabBottomPadding: CGFloat {
      guard store.hasLiveActivity else { return 16 }
      // iOS 26+: BottomAccessory가 얇음
      if #available(iOS 26, *) {
        return 20
      } else {
        return 85
      }
    }

    @ViewBuilder
    private var loadingView: some View {
      LazyVStack(spacing: 12) {
        ForEach(0..<3, id: \.self) { _ in
          PromiseCardSkeleton()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 48) // 섹션 헤더 높이만큼
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button("다시 시도") {
          store.send(.view(.refreshTriggered))
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }


    // MARK: - Onboarding Cards

    @ViewBuilder
    private var onboardingCardsView: some View {
      LazyVStack(spacing: 12) {
        ForEach(GroupMain.OnboardingCard.allCases) { card in
          OnboardingCardView(card: card) {
            handleOnboardingCardTap(card)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 100)
    }

    private func handleOnboardingCardTap(_ card: GroupMain.OnboardingCard) {
      switch card {
      case .createGroup:
        store.send(.view(.createGroup))
      case .joinGroup:
        store.send(.view(.joinGroup))
      case .howToUse:
        // TODO: 튜토리얼 화면 연결
        break
      }
    }

    @ViewBuilder
    private var filterSegment: some View {
      CategoryFilterBar(
        selection: Binding(
          get: { store.selectedFilter },
          set: { store.send(.view(.filterChanged($0))) }
        ),
        counts: store.filterCounts
      )
    }

    @ViewBuilder
    private var promiseListView: some View {
      List {
        ForEach(store.groupedFilteredPromises, id: \.date) { section in
          Section {
            ForEach(section.promises, id: \.id) { promise in
              promiseRowView(for: promise)
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
        store.send(.view(.refreshTriggered))
      }
      .animation(.snappy, value: store.promiseListAnimationKey)
    }

    @ViewBuilder
    private func dateSectionHeader(_ date: String) -> some View {
      HStack(spacing: 12) {
        Text(date)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.primary)
          .textCase(nil)

        Rectangle()
          .fill(Color(UIColor.systemGray4))
          .frame(height: 1)
      }
      .padding(.top, 8)
      .padding(.bottom, 8)
    }

    @ViewBuilder
    private func promiseRowView(for promise: PromiseModel) -> some View {
      let promiseId = promise.id
      let myVoteStatus = promise.myVoteStatus(userId: store.currentUser.userId)

      PromiseCard(
        promise: promise,
        currentUserId: store.currentUser.userId,
        groupMembers: store.currentGroupMembers,
        respondingState: store.proposalResponding[promiseId] ?? .idle,
        isLive: store.liveActivityPromiseId == promiseId,
        onTap: {
          store.send(.view(.promiseTapped(promise)))
        },
        onAccept: {
          store.send(.view(.proposalAccepted(promiseId)))
        },
        onReject: {
          store.send(.view(.proposalRejected(promiseId)))
        },
        onEdit: {
          store.send(.view(.promiseEditTapped(promise)))
        },
        onDelete: {
          store.send(.view(.promiseDeleteRequested(promiseId)))
        },
        onChangeResponse: { status in
          store.send(.view(.responseChanged(promiseId, status)))
        },
        onShare: {
          store.send(.view(.promiseShared(promiseId)))
        }
      )
      .contentShape(Rectangle())
      .onTapGesture {
        store.send(.view(.promiseTapped(promise)))
      }
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        // 수락 / 되돌리기 (과거 약속은 제외)
        if !promise.isPast {
          if myVoteStatus == .accepted {
            Button {
              store.send(.view(.responseChanged(promiseId, .pending)))
            } label: {
              Label("되돌리기", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.blue)
          } else {
            Button {
              store.send(.view(.proposalAccepted(promiseId)))
            } label: {
              Label("수락", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
          }
        }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        // 거절 / 되돌리기 (과거 약속은 제외)
        if !promise.isPast {
          if myVoteStatus == .declined {
            Button {
              store.send(.view(.responseChanged(promiseId, .pending)))
            } label: {
              Label("되돌리기", systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.blue)
          } else {
            Button {
              store.send(.view(.proposalRejected(promiseId)))
            } label: {
              Label("거절", systemImage: "xmark.circle.fill")
            }
            .tint(.red)
          }
        }
      }
    }

    @ViewBuilder
    private var emptyFilteredView: some View {
      VStack(spacing: 0) {
        Spacer()
          .frame(height: 120)

        VStack(spacing: 16) {
          // 이모지 아이콘
          Text(emptyFilterEmoji)
            .font(.system(size: 47))

          // Description (2줄)
          Text(emptyFilterDescription)
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity)
    }

    private var emptyFilterEmoji: String {
      switch store.selectedFilter {
      case .needResponse: return "📨"
      case .responded: return "⏰"
      case .confirmed: return "✅"
      case .all: return "📬"
      case .past: return "🕐"
      }
    }

    private var emptyFilterDescription: String {
      switch store.selectedFilter {
      case .needResponse:
        return "지금은 응답이 필요한 약속이 없어요\n모든 약속에 응답한 상태예요 👍"
      case .responded:
        return "아직 응답한 약속이 없어요\n확정되면 자동으로 확정 탭으로 옮겨져요"
      case .confirmed:
        return "아직 확정된 약속이 없어요\n+ 버튼으로 새 약속을 만들어보세요"
      case .all:
        return "지금은 진행 중이거나 예정된 약속이 없어요\n새 약속이나 초대가 생기면 여기에 보여요"
      case .past:
        return "아직 지난 약속이 없어요\n완료된 약속 기록이 여기에 쌓여요"
      }
    }

    /// 로딩 상태 (과거 필터는 별도 상태 사용)
    private var isLoadingState: Bool {
      if store.selectedFilter == .past {
        return !store.pastPromisesState.isLoaded && store.pastPromisesState.error == nil
      }
      return !store.promisesState.isLoaded && store.promisesState.error == nil
    }

    /// 현재 에러 (과거 필터는 별도 상태 사용)
    private var currentError: Error? {
      if store.selectedFilter == .past {
        return store.pastPromisesState.error
      }
      return store.promisesState.error
    }


    // MARK: - Empty Group View

    @ViewBuilder
    private var groupDetailEmptyView: some View {
      ScrollView {
        // 그룹 가로 바 (빈 상태에서도 생성/참여 버튼 제공)
        GroupHorizontalBar(
          groups: store.groupBarItems,
          onGroupTap: { groupId in
            store.send(.view(.groupTapped(groupId)))
          },
          onCreateGroup: {
            store.send(.view(.createGroup))
          },
          onJoinGroup: {
            store.send(.view(.joinGroup))
          },
          onSortSettings: {
            store.send(.view(.sortSettingsTapped))
          }
        )

        Divider()

        VStack(spacing: 0) {
          // 필터 (비활성 상태로 유지)
          filterSegment
            .padding(.vertical, 8)
            .disabled(true)
            .opacity(0.5)

          // 빈 상태 컨텐츠
          VStack(spacing: 0) {
            Spacer()
              .frame(height: 120)

            VStack(spacing: 16) {
              // 이모지 아이콘
              Text("👥")
                .font(.system(size: 47))

              // Description (2줄)
              Text("아직 속한 그룹이 없어요\n상단의 + 버튼으로 그룹을 만들거나 참여해보세요")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            }

            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
      }
    }

  }
}

// MARK: - State Extensions

private extension GroupMain.Feature.State {

  /// 속한 그룹이 없는 경우
  private var hasNoGroups: Bool {
    allGroupSummaries?.isEmpty == true && currentGroup == nil
  }

  /// 빈 그룹 화면 표시 여부 (온보딩 모드로 대체되어 항상 false)
  var shouldShowEmptyGroupView: Bool {
    false  // 온보딩 모드에서 groupDetailView 재사용
  }

  /// 특정 약속의 응답 상태 조회
  func respondingState(for promiseId: String) -> GroupMain.RespondingState {
    proposalResponding[promiseId] ?? .idle
  }
}

// MARK: - Onboarding Card View

private struct OnboardingCardView: View {
  let card: GroupMain.OnboardingCard
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 14) {
        // 헤더
        HStack(spacing: 10) {
          // 아이콘
          iconView
            .frame(width: 32, height: 32)

          Text(card.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          // 화살표
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }

        Divider()

        // 설명
        Text(card.subtitle)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .padding(16)
      .contentShape(Rectangle())
      .adaptiveGlassCard()
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var iconView: some View {
    if card == .createGroup {
      Image("fingerPromise", bundle: .main)
        .resizable()
        .scaledToFit()
    } else {
      ZStack {
        Circle()
          .fill(card.color.opacity(0.15))

        Image(systemName: card.icon)
          .font(.system(size: 16))
          .foregroundStyle(card.color)
      }
    }
  }
}

// MARK: - ShareSheet

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SortSettingsSheetContent

/// 시트 내부에서 Store를 생성하여 애니메이션 문제 해결
private struct SortSettingsSheetContent: View {
  let initialState: GroupSortSettings.Feature.State
  let onOptionChanged: (GroupSortOption) -> Void
  let onDismiss: () -> Void

  var body: some View {
    GroupSortSettings.RootView(
      store: Store(initialState: initialState) {
        GroupSortSettings.Feature()
      },
      onConfirm: { option in
        onOptionChanged(option)
      },
      onCancel: {
        onDismiss()
      }
    )
  }
}
